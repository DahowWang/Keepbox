import Foundation
import SwiftData

@MainActor
class FileImporter {
    private let appGroupID = "group.tw.mixxin.htmlviewer"

    func importPendingFiles(into context: ModelContext) {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }

        let pendingDir = containerURL.appendingPathComponent("pending", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: pendingDir,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in files where fileURL.pathExtension.lowercased() == "html" {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let name = fileURL.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "shared_", with: "")
                .replacingOccurrences(of: "url_", with: "")
            let displayName = name.isEmpty ? "Untitled" : name
            let file = HTMLFile(name: displayName, content: content)
            context.insert(file)
            try? FileManager.default.removeItem(at: fileURL)
        }

        try? context.save()
    }
}
