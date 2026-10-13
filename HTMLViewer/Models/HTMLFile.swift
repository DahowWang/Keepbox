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

    // 同步狀態：syncedAt 與 updatedAt 不同代表本機有改動還沒推上去
    var syncedAt: Date? = nil
    var contentUploaded: Bool = false
    var needsContentDownload: Bool = false

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
