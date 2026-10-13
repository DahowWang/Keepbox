import Foundation
import SwiftData

/// 與 Cloudflare 同步伺服器（server/）雙向同步檔案、資料夾、標籤。
/// 流程：先推本機改動（含刪除紀錄、HTML 內容）→ 再拉伺服器異動 → 補下載缺的 HTML。
/// 同一筆兩邊都改時，以 updatedAt 較新者為準。
@MainActor
@Observable
final class SyncService {
    static let shared = SyncService()

    enum State: Equatable {
        case idle
        case syncing
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var lastSyncAt: Date? = SyncSettings.lastSyncAt

    private var context: ModelContext?
    private var debounceTask: Task<Void, Never>?
    private var isApplyingRemote = false
    private var rerunRequested = false

    private init() {}

    func attach(_ context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        // 任何本機存檔都排一次同步；套用遠端資料時的存檔不算
        NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isApplyingRemote else { return }
                self.requestSync()
            }
        }
    }

    /// 合併短時間內的多次觸發，延遲後同步一次。
    func requestSync(after delay: Duration = .seconds(2)) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await syncNow()
        }
    }

    func syncNow() async {
        guard !ScreenshotSeeder.isRequested,
              let context,
              let baseURL = SyncSettings.serverURL,
              let token = SyncSettings.token else { return }
        if state == .syncing {
            rerunRequested = true
            return
        }

        state = .syncing
        let client = SyncClient(baseURL: baseURL, token: token)
        do {
            try await push(context: context, client: client)
            try await pull(context: context, client: client)
            try await downloadMissingContent(context: context, client: client)
            let now = Date()
            lastSyncAt = now
            SyncSettings.lastSyncAt = now
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }

        if rerunRequested {
            rerunRequested = false
            await syncNow()
        }
    }

    // MARK: - Push

    private func push(context: ModelContext, client: SyncClient) async throws {
        let tags = try context.fetch(FetchDescriptor<Tag>()).filter { $0.syncedAt != $0.updatedAt }
        let folders = try context.fetch(FetchDescriptor<Folder>()).filter { $0.syncedAt != $0.updatedAt }
        let files = try context.fetch(FetchDescriptor<HTMLFile>()).filter { $0.syncedAt != $0.updatedAt }
        let tombstones = try context.fetch(FetchDescriptor<SyncTombstone>())

        // HTML 內容先上傳，其他裝置拉到檔案時才下載得到
        let uploads = files.filter { !$0.contentUploaded }.map { ($0, $0.id, $0.content) }
        for (file, id, content) in uploads {
            try await client.putContent(id: id, html: content)
            if !file.isDeleted { file.contentUploaded = true }
        }

        // 送出前先記下版本；推送期間若又被改，updatedAt 會變，下一輪會再推
        var pending: [(record: SyncRecord, markSynced: () -> Void)] = []
        for tag in tags {
            let stamp = tag.updatedAt
            pending.append((SyncRecord(tag: tag), { if !tag.isDeleted { tag.syncedAt = stamp } }))
        }
        for folder in folders {
            let stamp = folder.updatedAt
            pending.append((SyncRecord(folder: folder), { if !folder.isDeleted { folder.syncedAt = stamp } }))
        }
        for file in files {
            let stamp = file.updatedAt
            pending.append((SyncRecord(file: file), { if !file.isDeleted { file.syncedAt = stamp } }))
        }
        for tombstone in tombstones {
            pending.append((SyncRecord(tombstone: tombstone), { context.delete(tombstone) }))
        }

        for start in stride(from: 0, to: pending.count, by: SyncClient.maxPushBatch) {
            let chunk = pending[start..<min(start + SyncClient.maxPushBatch, pending.count)]
            try await client.push(chunk.map(\.record))
            chunk.forEach { $0.markSynced() }
            saveQuietly(context)
        }
    }

    // MARK: - Pull

    private func pull(context: ModelContext, client: SyncClient) async throws {
        var cursor = SyncSettings.cursor
        var latest: [String: SyncRecord] = [:]
        var more = true
        while more {
            let page = try await client.changes(since: cursor)
            for record in page.records { latest["\(record.type)/\(record.id)"] = record }
            cursor = page.cursor
            more = page.more
        }
        guard !latest.isEmpty else {
            SyncSettings.cursor = cursor
            return
        }

        let records = Array(latest.values)
        try apply(records, in: context)
        SyncSettings.cursor = cursor
    }

    /// 依標籤 → 資料夾 → 檔案的順序套用，關聯才找得到對象。
    private func apply(_ records: [SyncRecord], in context: ModelContext) throws {
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        var tagsByID = Dictionary(try context.fetch(FetchDescriptor<Tag>()).map { ($0.id, $0) },
                                  uniquingKeysWith: { a, _ in a })
        var foldersByID = Dictionary(try context.fetch(FetchDescriptor<Folder>()).map { ($0.id, $0) },
                                     uniquingKeysWith: { a, _ in a })
        let filesByID = Dictionary(try context.fetch(FetchDescriptor<HTMLFile>()).map { ($0.id, $0) },
                                   uniquingKeysWith: { a, _ in a })

        for r in records where r.type == .tag {
            let local = tagsByID[r.id]
            if let local, local.updatedAt.syncMillis >= r.updatedAt { continue }
            if r.deleted {
                if let local { context.delete(local); tagsByID[r.id] = nil }
                continue
            }
            let tag = local ?? {
                let t = Tag(name: "")
                t.id = r.id
                context.insert(t)
                tagsByID[r.id] = t
                return t
            }()
            tag.name = r.string("name") ?? tag.name
            tag.colorHex = r.string("colorHex") ?? tag.colorHex
            tag.markSynced(at: r.updatedAt)
        }

        var foldersToLink: [(Folder, UUID?)] = []
        for r in records where r.type == .folder {
            let local = foldersByID[r.id]
            if let local, local.updatedAt.syncMillis >= r.updatedAt { continue }
            if r.deleted {
                if let local { context.delete(local); foldersByID[r.id] = nil }
                continue
            }
            let folder = local ?? {
                let f = Folder(name: "")
                f.id = r.id
                context.insert(f)
                foldersByID[r.id] = f
                return f
            }()
            folder.name = r.string("name") ?? folder.name
            if let created = r.date("createdAt") { folder.createdAt = created }
            folder.markSynced(at: r.updatedAt)
            foldersToLink.append((folder, r.uuid("parentID")))
        }
        for (folder, parentID) in foldersToLink {
            folder.parent = parentID.flatMap { foldersByID[$0] }
        }

        for r in records where r.type == .file {
            let local = filesByID[r.id]
            if let local, local.updatedAt.syncMillis >= r.updatedAt { continue }
            if r.deleted {
                if let local { context.delete(local) }
                continue
            }
            let file = local ?? {
                let f = HTMLFile(name: "", content: "")
                f.id = r.id
                f.contentUploaded = true
                f.needsContentDownload = true
                context.insert(f)
                return f
            }()
            file.name = r.string("name") ?? file.name
            file.sourceApp = r.string("sourceApp")
            if let created = r.date("createdAt") { file.createdAt = created }
            file.folder = r.uuid("folderID").flatMap { foldersByID[$0] }
            file.tags = r.uuids("tagIDs").compactMap { tagsByID[$0] }
            file.markSynced(at: r.updatedAt)
        }

        try context.save()
    }

    private func downloadMissingContent(context: ModelContext, client: SyncClient) async throws {
        let missing = try context.fetch(FetchDescriptor<HTMLFile>(predicate: #Predicate { $0.needsContentDownload }))
        for (file, id) in missing.map({ ($0, $0.id) }) {
            guard let html = try await client.getContent(id: id) else { continue }
            guard !file.isDeleted else { continue }
            isApplyingRemote = true
            file.content = html
            file.needsContentDownload = false
            saveQuietly(context)
            isApplyingRemote = false
        }
    }

    private func saveQuietly(_ context: ModelContext) {
        let wasApplying = isApplyingRemote
        isApplyingRemote = true
        try? context.save()
        isApplyingRemote = wasApplying
    }
}

// MARK: - Record mapping

private extension Date {
    var syncMillis: Int64 { Int64((timeIntervalSince1970 * 1000).rounded(.down)) }
    init(syncMillis: Int64) { self.init(timeIntervalSince1970: Double(syncMillis) / 1000) }
}

private extension Tag {
    func markSynced(at millis: Int64) {
        updatedAt = Date(syncMillis: millis)
        syncedAt = updatedAt
    }
}

private extension Folder {
    func markSynced(at millis: Int64) {
        updatedAt = Date(syncMillis: millis)
        syncedAt = updatedAt
    }
}

private extension HTMLFile {
    func markSynced(at millis: Int64) {
        updatedAt = Date(syncMillis: millis)
        syncedAt = updatedAt
    }
}

private extension SyncRecord {
    init(tag: Tag) {
        self.init(type: .tag, id: tag.id, updatedAt: tag.updatedAt.syncMillis, deleted: false, data: [
            "name": tag.name,
            "colorHex": tag.colorHex,
        ])
    }

    init(folder: Folder) {
        var data: [String: Any] = [
            "name": folder.name,
            "createdAt": folder.createdAt.syncMillis,
        ]
        if let parent = folder.parent { data["parentID"] = parent.id.uuidString }
        self.init(type: .folder, id: folder.id, updatedAt: folder.updatedAt.syncMillis, deleted: false, data: data)
    }

    init(file: HTMLFile) {
        var data: [String: Any] = [
            "name": file.name,
            "createdAt": file.createdAt.syncMillis,
            "tagIDs": file.tags.map(\.id.uuidString),
        ]
        if let folder = file.folder { data["folderID"] = folder.id.uuidString }
        if let sourceApp = file.sourceApp { data["sourceApp"] = sourceApp }
        self.init(type: .file, id: file.id, updatedAt: file.updatedAt.syncMillis, deleted: false, data: data)
    }

    init(tombstone: SyncTombstone) {
        self.init(type: RecordType(rawValue: tombstone.recordType) ?? .file, id: tombstone.recordID,
                  updatedAt: tombstone.deletedAt.syncMillis, deleted: true, data: [:])
    }

    func string(_ key: String) -> String? { data[key] as? String }
    func date(_ key: String) -> Date? { (data[key] as? NSNumber).map { Date(syncMillis: $0.int64Value) } }
    func uuid(_ key: String) -> UUID? { string(key).flatMap(UUID.init(uuidString:)) }
    func uuids(_ key: String) -> [UUID] { (data[key] as? [String] ?? []).compactMap(UUID.init(uuidString:)) }
}
