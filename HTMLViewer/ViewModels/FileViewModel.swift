import Foundation
import SwiftData
import SwiftUI

/// 收藏的整理動作（刪除、移動、改名、標籤）。
/// 篩選／搜尋／排序狀態在 `LibrarySceneState`，這裡不再持有第二份。
@Observable
class FileViewModel {
    func delete(_ file: HTMLFile, from context: ModelContext) {
        context.insert(SyncTombstone(recordType: "file", recordID: file.id))
        context.delete(file)
        try? context.save()
    }

    func move(_ file: HTMLFile, to folder: Folder?, context: ModelContext) {
        file.folder = folder
        file.updatedAt = Date()
        try? context.save()
    }

    func rename(_ file: HTMLFile, to name: String, context: ModelContext) {
        file.name = name
        file.updatedAt = Date()
        try? context.save()
    }

    func addTag(_ tag: Tag, to file: HTMLFile, context: ModelContext) {
        guard !file.tags.contains(where: { $0.id == tag.id }) else { return }
        file.tags.append(tag)
        file.updatedAt = Date()
        try? context.save()
    }

    func removeTag(_ tag: Tag, from file: HTMLFile, context: ModelContext) {
        file.tags.removeAll { $0.id == tag.id }
        file.updatedAt = Date()
        try? context.save()
    }
}
