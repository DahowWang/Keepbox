import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date = Date(timeIntervalSince1970: 0)
    var parent: Folder?
    @Relationship(deleteRule: .cascade, inverse: \Folder.parent) var children: [Folder]
    @Relationship(deleteRule: .nullify, inverse: \HTMLFile.folder) var files: [HTMLFile]

    var syncedAt: Date? = nil

    init(name: String, parent: Folder? = nil) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.parent = parent
        self.children = []
        self.files = []
    }
}
