import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupID = "group.com.dahow.keepbox"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        processItems()
    }

    private func processItems() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            finish()
            return
        }

        let group = DispatchGroup()
        var savedCount = 0

        for item in items {
            for provider in (item.attachments ?? []) {
                if provider.hasItemConformingToTypeIdentifier(UTType.html.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.html.identifier) { [weak self] data, _ in
                        defer { group.leave() }
                        if let saved = self?.handle(data: data) { if saved { savedCount += 1 } }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] data, _ in
                        defer { group.leave() }
                        if let url = data as? URL, url.pathExtension.lowercased() == "html" {
                            if let saved = self?.handleFileURL(url) { if saved { savedCount += 1 } }
                        }
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.showResult(savedCount > 0)
        }
    }

    private func showResult(_ success: Bool) {
        let message = success ? "已儲存到 HTML Viewer" : "找不到 HTML 檔案"
        let icon = success ? "checkmark.circle.fill" : "xmark.circle.fill"
        let color: UIColor = success ? .systemGreen : .systemRed

        let hostingVC = UIHostingController(rootView: SaveResultView(
            message: message,
            iconName: icon,
            iconColor: Color(color)
        ) {
            self.finish()
        })
        hostingVC.view.backgroundColor = .clear
        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingVC.didMove(toParent: self)
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: - File handling

    @discardableResult
    private func handle(data: Any?) -> Bool {
        let htmlContent: String?
        if let string = data as? String {
            htmlContent = string
        } else if let url = data as? URL, let content = try? String(contentsOf: url, encoding: .utf8) {
            htmlContent = content
        } else if let nsData = data as? Data, let content = String(data: nsData, encoding: .utf8) {
            htmlContent = content
        } else {
            htmlContent = nil
        }
        guard let content = htmlContent else { return false }
        return saveToAppGroup(content: content, filename: "shared_\(Int(Date().timeIntervalSince1970)).html")
    }

    @discardableResult
    private func handleFileURL(_ url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        let filename = url.lastPathComponent.isEmpty
            ? "shared_\(Int(Date().timeIntervalSince1970)).html"
            : url.lastPathComponent
        return saveToAppGroup(content: content, filename: filename)
    }

    @discardableResult
    private func saveToAppGroup(content: String, filename: String) -> Bool {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return false }
        let pendingDir = containerURL.appendingPathComponent("pending", isDirectory: true)
        try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)
        let fileURL = pendingDir.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}

struct SaveResultView: View {
    let message: String
    let iconName: String
    let iconColor: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundStyle(iconColor)
            Text(message)
                .font(.title3)
                .fontWeight(.medium)
            Button("完成") { onDismiss() }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
