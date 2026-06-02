import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String
    var files: [HTMLFile]

    init(name: String, colorHex: String = "#4A90D9") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.files = []
    }
}

extension Tag {
    static let defaultColors = [
        "#4A90D9", "#E74C3C", "#2ECC71", "#F39C12",
        "#9B59B6", "#1ABC9C", "#E67E22", "#34495E"
    ]
}
