import SwiftUI
import SwiftData

@main
struct HTMLViewerApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: HTMLFile.self, Folder.self, Tag.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
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
