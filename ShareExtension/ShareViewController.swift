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

    // MARK: - Collect shared content, then compose one collection card

    private func processItems() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            finish(); return
        }

        let group = DispatchGroup()
        var sharedURL: URL?
        var sharedText: String?
        var imageData: Data?
        var rawHTML: String?          // a genuine .html file/content shared in
        var rawHTMLName: String?

        for item in items {
            // The app's own item-level text (e.g. a tweet caption) is a good fallback.
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
                    Self.loadImageData(provider) { data in
                        if let data { imageData = data }
                        group.leave()
                    }
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
            // A real HTML document was shared — keep it verbatim.
            if let html = rawHTML {
                let ok = self.saveToAppGroup(content: html,
                    filename: "shared_\(self.sanitize(rawHTMLName ?? "page")).html")
                self.showResult(ok); return
            }
            // 小紅書-style text often embeds the link — pull it out for the source button.
            if sharedURL == nil, let text = sharedText, let found = Self.firstURL(in: text) {
                sharedURL = found
            }
            guard sharedURL != nil || sharedText != nil || imageData != nil else {
                self.showResult(false); return
            }
            let card = self.buildCard(url: sharedURL, text: sharedText, imageData: imageData)
            let name = self.cardName(url: sharedURL, text: sharedText)
            let ok = self.saveToAppGroup(content: card, filename: "url_\(self.sanitize(name)).html")
            self.showResult(ok)
        }
    }

    // MARK: - Collection card

    private func buildCard(url: URL?, text: String?, imageData: Data?) -> String {
        let host = url?.host?.replacingOccurrences(of: "www.", with: "") ?? "收藏"
        let title = cardName(url: url, text: text)
        let caption = (text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        var imageBlock = ""
        if let imageData, let jpeg = Self.downscaledJPEG(imageData) {
            imageBlock = "<img class='hero' src='data:image/jpeg;base64,\(jpeg.base64EncodedString())'>"
        }
        var linkBlock = ""
        if let url {
            linkBlock = "<a class='btn' href='\(url.absoluteString)'>查看原文 ↗</a>"
        }
        let captionBlock = caption.isEmpty ? "" : "<p class='cap'>\(caption)</p>"
        let titleBlock = title.isEmpty ? "" : "<h1>\(title.replacingOccurrences(of: "<", with: "&lt;"))</h1>"

        return """
        <!DOCTYPE html><html lang="zh-Hant"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>\(title.isEmpty ? host : title)</title>
        <style>
        :root{color-scheme:light dark}
        *{box-sizing:border-box}
        body{margin:0;font-family:-apple-system,"PingFang TC",system-ui,sans-serif;
          background:#f4f3fb;color:#1d1b3a;-webkit-font-smoothing:antialiased}
        @media(prefers-color-scheme:dark){body{background:#0c0c0f;color:#f3f3f6}}
        .card{max-width:680px;margin:0 auto;min-height:100vh;background:#fff;display:flex;flex-direction:column}
        @media(prefers-color-scheme:dark){.card{background:#161619}}
        .hero{width:100%;display:block;object-fit:cover}
        .body{padding:24px 22px 40px}
        .src{font-size:13px;font-weight:700;letter-spacing:.04em;color:#5B53E0;text-transform:uppercase}
        h1{font-size:24px;line-height:1.3;margin:10px 0 0;font-weight:800}
        .cap{font-size:16px;line-height:1.7;white-space:pre-wrap;margin:16px 0 0;color:inherit;opacity:.85}
        .btn{display:inline-block;margin-top:24px;background:#5B53E0;color:#fff;text-decoration:none;
          font-size:16px;font-weight:700;padding:13px 24px;border-radius:14px;
          box-shadow:0 6px 18px rgba(91,83,224,.4)}
        </style></head>
        <body><div class="card">\(imageBlock)
        <div class="body"><div class="src">\(host)</div>\(titleBlock)\(captionBlock)\(linkBlock)</div>
        </div></body></html>
        """
    }

    private func cardName(url: URL?, text: String?) -> String {
        if let text {
            let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
            let clean = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { return String(clean.prefix(50)) }
        }
        if let host = url?.host?.replacingOccurrences(of: "www.", with: "") { return host }
        return "收藏"
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

    private static func downscaledJPEG(_ data: Data, maxDimension: CGFloat = 1400) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        if scale >= 1 { return image.jpegData(compressionQuality: 0.85) ?? data }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.85)
    }

    private static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        if let match = detector?.firstMatch(in: text, range: range), let url = match.url,
           url.scheme?.hasPrefix("http") == true { return url }
        return nil
    }

    private func sanitize(_ name: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = name.components(separatedBy: bad).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "收藏" : String(cleaned.prefix(50))
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
            message: message, iconName: icon, iconColor: Color(color)
        ) { self.finish() })
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
