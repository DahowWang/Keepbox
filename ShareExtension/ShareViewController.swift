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

    // Gather shared content (file / url / text / image), then build one card
    // via the shared LinkCollector.
    private func processItems() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { finish(); return }

        let group = DispatchGroup()
        var sharedURL: URL?
        var sharedText: String?
        var imageData: Data?
        var rawHTML: String?
        var rawHTMLName: String?

        for item in items {
            if let attributed = item.attributedContentText?.string,
               !attributed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sharedText = sharedText ?? attributed
            }
            for provider in (item.attachments ?? []) {
                if provider.hasItemConformingToTypeIdentifier(UTType.html.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.html.identifier) { data, _ in
                        if let s = Self.htmlString(from: data) { rawHTML = s; rawHTMLName = "shared" }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                        if let url = data as? URL, url.pathExtension.lowercased() == "html",
                           let s = try? String(contentsOf: url, encoding: .utf8) {
                            rawHTML = s; rawHTMLName = url.deletingPathExtension().lastPathComponent
                        }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.enter()
                    Self.loadImageData(provider) { data in if let data { imageData = data }; group.leave() }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { data, _ in
                        if let u = data as? URL, u.scheme?.hasPrefix("http") == true { sharedURL = u }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                        if let t = data as? String { sharedText = sharedText ?? t }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if let html = rawHTML {
                let ok = self.saveToAppGroup(content: html,
                    filename: "shared_\(LinkCollector.sanitize(rawHTMLName ?? "page")).html")
                self.showResult(ok); return
            }
            if sharedURL == nil, let text = sharedText, let found = LinkCollector.firstURL(in: text) {
                sharedURL = found
            }
            guard sharedURL != nil || sharedText != nil || imageData != nil else {
                self.showResult(false); return
            }
            if let url = sharedURL {
                LinkCollector.collect(url, sharedText: sharedText) { r in
                    let card = LinkCollector.cardHTML(url: url, title: r.title, caption: r.caption,
                                                      imageData: imageData ?? r.imageData)
                    self.showResult(self.saveToAppGroup(content: card,
                        filename: "url_\(LinkCollector.sanitize(r.title)).html"))
                }
            } else {
                let title = LinkCollector.firstLine(sharedText ?? "") ?? "收藏"
                let card = LinkCollector.cardHTML(url: nil, title: title, caption: sharedText ?? "", imageData: imageData)
                self.showResult(self.saveToAppGroup(content: card, filename: "url_\(LinkCollector.sanitize(title)).html"))
            }
        }
    }

    // MARK: - Helpers

    private static func htmlString(from data: Any?) -> String? {
        if let s = data as? String { return s }
        if let url = data as? URL, let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        if let d = data as? Data { return String(data: d, encoding: .utf8) }
        return nil
    }

    private static func loadImageData(_ provider: NSItemProvider, completion: @escaping (Data?) -> Void) {
        provider.loadItem(forTypeIdentifier: UTType.image.identifier) { data, _ in
            if let url = data as? URL, let d = try? Data(contentsOf: url) { completion(d) }
            else if let img = data as? UIImage { completion(img.jpegData(compressionQuality: 0.85)) }
            else if let d = data as? Data { completion(d) }
            else { completion(nil) }
        }
    }

    @discardableResult
    private func saveToAppGroup(content: String, filename: String) -> Bool {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return false }
        let pendingDir = containerURL.appendingPathComponent("pending", isDirectory: true)
        try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)
        let fileURL = pendingDir.appendingPathComponent(filename)
        do { try content.write(to: fileURL, atomically: true, encoding: .utf8); return true }
        catch { return false }
    }

    // MARK: - Result UI

    private func showResult(_ success: Bool) {
        let message = success ? "已存入 Keepbox" : "無法收藏此內容"
        let icon = success ? "checkmark.circle.fill" : "xmark.circle.fill"
        let color: UIColor = success ? .systemGreen : .systemRed
        let hostingVC = UIHostingController(rootView: SaveResultView(
            message: message, iconName: icon, iconColor: Color(color)) { self.finish() })
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
}

struct SaveResultView: View {
    let message: String
    let iconName: String
    let iconColor: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: iconName).font(.system(size: 60)).foregroundStyle(iconColor)
            Text(message).font(.title3).fontWeight(.medium)
            Button("完成") { onDismiss() }.buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
