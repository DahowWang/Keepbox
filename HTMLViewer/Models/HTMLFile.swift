import Foundation
import SwiftData

@Model
final class HTMLFile {
    var id: UUID
    var name: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var sourceApp: String?
    var folder: Folder?
    @Relationship(inverse: \Tag.files) var tags: [Tag]

    init(name: String, content: String, sourceApp: String? = nil) {
        self.id = UUID()
        self.name = name
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sourceApp = sourceApp
        self.tags = []
    }
}
