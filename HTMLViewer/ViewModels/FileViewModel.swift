import Foundation
import SwiftData
import SwiftUI

@Observable
class FileViewModel {
    var searchText = ""
    var selectedFolder: Folder? = nil
    var selectedTag: Tag? = nil
    var sortOrder: SortOrder = .dateDesc

    enum SortOrder: String, CaseIterable, Identifiable {
        case dateDesc = "最新"
        case dateAsc = "最舊"
        case nameAsc = "名稱 A-Z"
        case nameDesc = "名稱 Z-A"
        var id: String { rawValue }
    }

    func filteredFiles(_ files: [HTMLFile]) -> [HTMLFile] {
        var result = files

        if let folder = selectedFolder {
            result = result.filter { $0.folder?.id == folder.id }
        } else if selectedTag != nil {
            result = result.filter { file in
                file.tags.contains { $0.id == selectedTag?.id }
            }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.content.lowercased().contains(query)
            }
        }

        switch sortOrder {
        case .dateDesc:  result.sort { $0.createdAt > $1.createdAt }
        case .dateAsc:   result.sort { $0.createdAt < $1.createdAt }
        case .nameAsc:   result.sort { $0.name < $1.name }
        case .nameDesc:  result.sort { $0.name > $1.name }
        }

        return result
    }

    func delete(_ file: HTMLFile, from context: ModelContext) {
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
        try? context.save()
    }

    func removeTag(_ tag: Tag, from file: HTMLFile, context: ModelContext) {
        file.tags.removeAll { $0.id == tag.id }
        try? context.save()
    }
}
