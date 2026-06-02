import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID
    var name: String
    var createdAt: Date
    var parent: Folder?
    @Relationship(deleteRule: .cascade, inverse: \Folder.parent) var children: [Folder]
    @Relationship(deleteRule: .nullify, inverse: \HTMLFile.folder) var files: [HTMLFile]

    init(name: String, parent: Folder? = nil) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.parent = parent
        self.children = []
        self.files = []
    }
}
