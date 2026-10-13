import SwiftUI
import SwiftData

@main
struct HTMLViewerApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: HTMLFile.self, Folder.self, Tag.self, SyncTombstone.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        #if DEBUG
        // 測試用：`-syncServerURL <url> -syncToken <token>` 直接指定同步伺服器（可用本機 http）
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-syncServerURL"), i + 1 < args.count {
            SyncSettings.serverURL = URL(string: args[i + 1])
        }
        if let i = args.firstIndex(of: "-syncToken"), i + 1 < args.count {
            SyncSettings.token = args[i + 1]
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .onOpenURL { url in
                    NotificationCenter.default.post(name: .openHTMLFile, object: url)
                }
        }
    }
}

extension Notification.Name {
    static let openHTMLFile = Notification.Name("openHTMLFile")
    static let importPending = Notification.Name("importPending")
}
