import Foundation
import Observation

// MARK: - Shared value types

enum KBTab: String, Codable { case all, folders, tags }
enum KBLayout: String, Codable { case grid, gallery, list }

/// 目前瀏覽的分類；三者互斥。以 UUID 引用 SwiftData 物件，方便存進 SceneStorage。
enum LibraryFilter: Hashable, Codable {
    case all
    case folder(UUID)
    case tag(UUID)
}

enum SearchScope: String, Codable, CaseIterable, Identifiable {
    case all = "全部收藏"
    case current = "目前分類"
    var id: String { rawValue }
}

enum LibrarySort: String, CaseIterable, Identifiable, Codable {
    case dateDesc = "最新"
    case dateAsc = "最舊"
    case nameAsc = "名稱 A-Z"
    case nameDesc = "名稱 Z-A"
    var id: String { rawValue }
}

/// 閱讀位置：DOM 元素路徑＋元素內相對位置，失效時退回整頁比例。
struct ReaderAnchor: Codable, Equatable {
    var path: [Int]
    var fraction: Double
    var ratio: Double
}

/// 開啟閱讀前所在的位置，返回時原子還原（含搜尋條件）。
struct ReturnContext: Codable, Equatable {
    var tab: KBTab
    var filter: LibraryFilter
    var searchActive: Bool
    var query: String
    var scope: SearchScope
}

// MARK: - Scene state

/// 每個視窗唯一的瀏覽狀態來源。外螢幕單欄、內螢幕雙／三欄、Mac 都讀寫同一份，
/// 所以摺疊／展開切換版面時不會遺失分類、搜尋、選取與閱讀位置。
@Observable
final class LibrarySceneState {
    var tab: KBTab = .all
    var filter: LibraryFilter = .all
    /// 搜尋字串草稿；只有 `searchActive` 時才套用到結果。
    var query = ""
    var searchActive = false
    var scope: SearchScope = .all
    var sort: LibrarySort = .dateDesc
    /// 使用者的排列偏好（觸控版）。並排閱讀時暫用清單只是呈現覆寫，不改這個值。
    var layout: KBLayout = .list

    var selectedFileID: UUID?
    var readerPresented = false
    /// 使用者手動選的「展開閱讀」：只留文章。
    var focusReading = false
    var returnContext: ReturnContext?

    /// 列表捲動錨點：鍵為 filter＋query＋sort＋layout。
    var listAnchors: [String: UUID] = [:]
    /// 每篇收藏的閱讀位置（有上限的 LRU，只存值型別，不保留多個 WKWebView）。
    var readerAnchors: [UUID: ReaderAnchor] = [:]
    var readerAnchorOrder: [UUID] = []
    static let readerAnchorLimit = 30
    var readerFontStep = 1

    /// 一次性提示（刪除、已存入等）。
    var notice: String?

    // MARK: Derived

    var effectiveQuery: String {
        searchActive ? query.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }

    func folderID() -> UUID? { if case .folder(let id) = filter { return id }; return nil }
    func tagID() -> UUID? { if case .tag(let id) = filter { return id }; return nil }

    /// 同一組 query／scope／filter／sort 在任何版面都得到相同結果。
    func results(from files: [HTMLFile]) -> [HTMLFile] {
        let q = effectiveQuery.lowercased()
        var result: [HTMLFile]
        if q.isEmpty || scope == .current {
            result = files.filter(matchesFilter)
        } else {
            result = files
        }
        if !q.isEmpty {
            result = result.filter { $0.name.lowercased().contains(q) || $0.content.lowercased().contains(q) }
        }
        switch sort {
        case .dateDesc: result.sort { $0.createdAt > $1.createdAt }
        case .dateAsc:  result.sort { $0.createdAt < $1.createdAt }
        case .nameAsc:  result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .nameDesc: result.sort { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        }
        return result
    }

    func matchesFilter(_ file: HTMLFile) -> Bool {
        switch filter {
        case .all: return true
        case .folder(let id): return file.folder?.id == id
        case .tag(let id): return file.tags.contains { $0.id == id }
        }
    }

    func title(folders: [Folder], tags: [Tag]) -> String {
        switch filter {
        case .all: return "全部收藏"
        case .folder(let id): return folders.first { $0.id == id }?.name ?? "全部收藏"
        case .tag(let id): return tags.first { $0.id == id }?.name ?? "全部收藏"
        }
    }

    var listAnchorKey: String {
        "\(filter)|\(effectiveQuery)|\(scope.rawValue)|\(sort.rawValue)|\(layout.rawValue)"
    }

    // MARK: Actions

    func select(_ filter: LibraryFilter) {
        self.filter = filter
    }

    /// 開啟一則收藏：記住返回位置。`highlight` 與 `readerPresented` 分離。
    func open(_ file: HTMLFile) {
        if !readerPresented {
            returnContext = ReturnContext(tab: tab, filter: filter, searchActive: searchActive,
                                          query: query, scope: scope)
        }
        selectedFileID = file.id
        readerPresented = true
        touchAnchor(file.id)
    }

    /// 開文時更新 LRU 使用順序，避免重讀舊文時尚未回報位置就被淘汰。
    private func touchAnchor(_ id: UUID) {
        guard readerAnchors[id] != nil else { return }
        readerAnchorOrder.removeAll { $0 == id }
        readerAnchorOrder.append(id)
    }

    /// 閱讀中由分類欄／浮層換分類：保留文章，並把「返回」的目的地也改成新分類
    /// （使用者明確導航過，關閉閱讀不應退回舊分類）。
    func selectWhileReading(_ filter: LibraryFilter) {
        self.filter = filter
        if readerPresented { returnContext?.filter = filter }
    }

    /// 關閉閱讀：原子還原開啟前的分類與搜尋條件。
    /// 剛才讀的那則「確實在還原後的結果中」才當返回錨點；否則保留來源清單原本的錨點。
    /// `files` 是全部收藏（用來算還原後的結果成員）；不給就不改錨點。
    func closeReader(anchoringWithin files: [HTMLFile] = []) {
        readerPresented = false
        focusReading = false
        if let ctx = returnContext {
            tab = ctx.tab
            filter = ctx.filter
            searchActive = ctx.searchActive
            query = ctx.query
            scope = ctx.scope
        }
        returnContext = nil
        if let id = selectedFileID, results(from: files).contains(where: { $0.id == id }) {
            listAnchors[listAnchorKey] = id
        }
    }

    func clearSearch() {
        query = ""
        searchActive = false
    }

    // MARK: Reading positions

    func anchor(for fileID: UUID) -> ReaderAnchor? { readerAnchors[fileID] }

    func setAnchor(_ anchor: ReaderAnchor, for fileID: UUID) {
        readerAnchors[fileID] = anchor
        readerAnchorOrder.removeAll { $0 == fileID }
        readerAnchorOrder.append(fileID)
        while readerAnchorOrder.count > Self.readerAnchorLimit {
            readerAnchors[readerAnchorOrder.removeFirst()] = nil
        }
    }

    /// 資料被刪除或同步移除時呼叫；失效的選取／分類／錨點退回安全狀態。
    func reconcile(fileIDs: Set<UUID>, folderIDs: Set<UUID>, tagIDs: Set<UUID>) {
        func valid(_ f: LibraryFilter) -> LibraryFilter {
            switch f {
            case .folder(let id) where !folderIDs.contains(id): return .all
            case .tag(let id) where !tagIDs.contains(id): return .all
            default: return f
            }
        }
        filter = valid(filter)
        if let ctx = returnContext {
            // 先讀出再寫回：同一敘述內讀寫 @Observable 屬性會觸發 exclusivity 衝突。
            let fixed = valid(ctx.filter)
            if fixed != ctx.filter { returnContext?.filter = fixed }
        }

        if let id = selectedFileID, !fileIDs.contains(id) {
            if readerPresented {
                notice = "這則收藏已刪除"
                // 與「返回」同一套語意回到來源，但不定位到已刪除的那則。
                selectedFileID = nil
                closeReader()
            }
            selectedFileID = nil
        }
        for id in readerAnchorOrder where !fileIDs.contains(id) { readerAnchors[id] = nil }
        readerAnchorOrder.removeAll { !fileIDs.contains($0) }
        listAnchors = listAnchors.filter { fileIDs.contains($0.value) }
    }

    // MARK: Persistence (SceneStorage)

    struct Snapshot: Codable, Equatable {
        var version = 2
        var tab: KBTab
        var filter: LibraryFilter
        var query: String
        var searchActive: Bool
        var scope: SearchScope
        var sort: LibrarySort
        var layout: KBLayout
        var selectedFileID: UUID?
        var readerPresented: Bool
        var focusReading: Bool
        var returnContext: ReturnContext?
        var listAnchors: [String: UUID]
        var readerAnchors: [UUID: ReaderAnchor]
        var readerAnchorOrder: [UUID]
        var readerFontStep: Int
    }

    var snapshot: Snapshot {
        Snapshot(tab: tab, filter: filter, query: query, searchActive: searchActive, scope: scope,
                 sort: sort, layout: layout, selectedFileID: selectedFileID, readerPresented: readerPresented,
                 focusReading: focusReading, returnContext: returnContext,
                 listAnchors: listAnchors.count > 24 ? [:] : listAnchors,
                 readerAnchors: readerAnchors, readerAnchorOrder: readerAnchorOrder, readerFontStep: readerFontStep)
    }

    func encodedSnapshot() -> String {
        guard let data = try? JSONEncoder().encode(snapshot) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    func restore(from encoded: String) {
        guard !encoded.isEmpty,
              let s = try? JSONDecoder().decode(Snapshot.self, from: Data(encoded.utf8)),
              s.version == 2 else { return }
        tab = s.tab; filter = s.filter; query = s.query; searchActive = s.searchActive
        scope = s.scope; sort = s.sort; layout = s.layout
        selectedFileID = s.selectedFileID; readerPresented = s.readerPresented
        focusReading = s.focusReading; returnContext = s.returnContext
        listAnchors = s.listAnchors; readerAnchors = s.readerAnchors
        readerAnchorOrder = s.readerAnchorOrder; readerFontStep = s.readerFontStep
    }
}
