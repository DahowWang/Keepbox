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
            // A link alone (X / Facebook etc.) carries no title or image — fetch the
            // page's Open Graph preview to enrich the card. Falls back gracefully.
            if let url = sharedURL {
                self.fetchMetadata(url) { meta in
                    // Prefer the fetched caption (real post text) over the shared
                    // text, which is often just the bare URL.
                    let caption = self.firstNonEmpty(meta.description, sharedText) ?? ""
                    let title = self.firstNonEmpty(meta.title, self.firstLine(caption), url.host) ?? "收藏"
                    self.composeAndSave(url: url, title: title,
                                        caption: caption, imageData: imageData ?? meta.imageData)
                }
            } else {
                self.composeAndSave(url: nil,
                                    title: self.firstLine(sharedText ?? "") ?? "收藏",
                                    caption: sharedText ?? "", imageData: imageData)
            }
        }
    }

    private func composeAndSave(url: URL?, title: String, caption: String, imageData: Data?) {
        let card = buildCard(url: url, title: title, caption: caption, imageData: imageData)
        let ok = saveToAppGroup(content: card, filename: "url_\(sanitize(title)).html")
        showResult(ok)
    }

    // MARK: - Open Graph metadata

    struct PageMeta { var title: String?; var description: String?; var imageData: Data? }

    private func fetchMetadata(_ url: URL, completion: @escaping (PageMeta) -> Void) {
        var done = false
        let finish: (PageMeta) -> Void = { meta in
            if done { return }; done = true
            DispatchQueue.main.async { completion(meta) }
        }
        // Bail out if the network is slow so the share sheet never hangs.
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { finish(PageMeta()) }

        // X blocks crawlers, but its embed/syndication endpoint serves tweet
        // text, author and photos without login — use it for x.com / twitter.com.
        let host = url.host ?? ""
        if (host.contains("x.com") || host.contains("twitter.com")), let id = Self.tweetID(url) {
            fetchTweet(id: id, finish: finish)
            return
        }
        // 小紅書 has no OG tags but embeds the note (title, desc, images) in a
        // window.__INITIAL_STATE__ blob served to normal browsers.
        if host.contains("xiaohongshu.com") || host.contains("xhslink.com") {
            fetchXiaohongshu(url, finish: finish)
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue(Self.crawlerUserAgent(for: url), forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self, let data,
                  let html = String(data: data.prefix(400_000), encoding: .utf8)
                    ?? String(data: data.prefix(400_000), encoding: .isoLatin1) else {
                finish(PageMeta()); return
            }
            var meta = PageMeta()
            meta.title = self.metaContent(html, keys: ["og:title", "twitter:title", "title"]) ?? self.htmlTitle(html)
            // Facebook (and many sites) put the post caption in <meta name="description">
            // rather than og:description — check both.
            meta.description = self.metaContent(html, keys: ["og:description", "twitter:description", "description"])
            if let imgStr = self.metaContent(html, keys: ["og:image", "twitter:image", "og:image:url"]),
               let imgURL = URL(string: imgStr, relativeTo: url) {
                var ireq = URLRequest(url: imgURL); ireq.timeoutInterval = 8
                ireq.setValue(Self.crawlerUserAgent(for: url), forHTTPHeaderField: "User-Agent")
                URLSession.shared.dataTask(with: ireq) { idata, _, _ in
                    meta.imageData = idata
                    finish(meta)
                }.resume()
            } else {
                finish(meta)
            }
        }.resume()
    }

    private static func tweetID(_ url: URL) -> String? {
        let parts = url.pathComponents
        if let i = parts.firstIndex(of: "status"), i + 1 < parts.count {
            let id = parts[i + 1].prefix { $0.isNumber }
            return id.isEmpty ? nil : String(id)
        }
        return nil
    }

    private func fetchTweet(id: String, finish: @escaping (PageMeta) -> Void) {
        guard let api = URL(string:
            "https://cdn.syndication.twimg.com/tweet-result?id=\(id)&lang=en&token=a") else {
            finish(PageMeta()); return
        }
        var req = URLRequest(url: api); req.timeoutInterval = 10
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String else {
                finish(PageMeta()); return
            }
            var meta = PageMeta()
            let user = json["user"] as? [String: Any]
            let name = user?["name"] as? String ?? ""
            let screen = user?["screen_name"] as? String ?? ""
            let byline = screen.isEmpty ? name : "\(name) (@\(screen))"
            meta.title = self.firstLine(text) ?? (byline.isEmpty ? "貼文" : byline)
            meta.description = byline.isEmpty ? text : "\(text)\n\n— \(byline)"

            // Prefer an attached photo; fall back to the author's avatar.
            var imgURLString: String?
            if let photos = json["photos"] as? [[String: Any]], let u = photos.first?["url"] as? String {
                imgURLString = u
            } else if let media = json["mediaDetails"] as? [[String: Any]],
                      let u = media.first?["media_url_https"] as? String {
                imgURLString = u
            } else if let avatar = user?["profile_image_url_https"] as? String {
                imgURLString = avatar.replacingOccurrences(of: "_normal", with: "_400x400")
            }
            if let s = imgURLString, let imgURL = URL(string: s) {
                var ir = URLRequest(url: imgURL); ir.timeoutInterval = 8
                URLSession.shared.dataTask(with: ir) { idata, _, _ in
                    meta.imageData = idata; finish(meta)
                }.resume()
            } else {
                finish(meta)
            }
        }.resume()
    }

    private func fetchXiaohongshu(_ url: URL, finish: @escaping (PageMeta) -> Void) {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if comps?.scheme == "http" { comps?.scheme = "https" }  // ATS: upgrade
        guard let httpsURL = comps?.url else { finish(PageMeta()); return }
        var req = URLRequest(url: httpsURL); req.timeoutInterval = 12
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                     forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self, let data, let html = String(data: data, encoding: .utf8) else {
                finish(PageMeta()); return
            }
            var meta = PageMeta()
            if let t = self.firstGroup(html, #""title":"((?:[^"\\]|\\.){1,200})""#) { meta.title = self.jsonUnescape(t) }
            if let d = self.firstGroup(html, #""desc":"((?:[^"\\]|\\.){0,2000})""#) { meta.description = self.jsonUnescape(d) }
            if let raw = self.firstGroup(html, #""imageList":\[.{0,600}?"url":"(http[^"]+?)""#) {
                var s = raw.replacingOccurrences(of: "\\u002F", with: "/")
                    .replacingOccurrences(of: "\\u002f", with: "/")
                if s.hasPrefix("http://") { s = "https://" + s.dropFirst("http://".count) }
                if let imgURL = URL(string: s) {
                    var ir = URLRequest(url: imgURL); ir.timeoutInterval = 8
                    URLSession.shared.dataTask(with: ir) { idata, _, _ in
                        meta.imageData = idata; finish(meta)
                    }.resume()
                    return
                }
            }
            finish(meta)
        }.resume()
    }

    private func firstGroup(_ s: String, _ pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1
        else { return nil }
        let v = ns.substring(with: m.range(at: 1))
        return v.isEmpty ? nil : v
    }

    private func jsonUnescape(_ s: String) -> String {
        guard let data = "\"\(s)\"".data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? String
        else { return s }
        return obj
    }

    private static func crawlerUserAgent(for url: URL) -> String {
        let host = url.host ?? ""
        if host.contains("x.com") || host.contains("twitter.com") { return "Twitterbot/1.0" }
        if host.contains("facebook.com") || host.contains("fb.com") { return "facebookexternalhit/1.1" }
        return "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    }

    private func metaContent(_ html: String, keys: [String]) -> String? {
        for key in keys {
            // Match <meta ... (property|name)="key" ... content="...">  in either attribute order.
            let patterns = [
                "<meta[^>]+(?:property|name)=[\"']\(key)[\"'][^>]*content=[\"']([^\"']+)[\"']",
                "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]*(?:property|name)=[\"']\(key)[\"']",
            ]
            for p in patterns {
                if let r = html.range(of: p, options: [.regularExpression, .caseInsensitive]) {
                    let frag = String(html[r])
                    if let c = frag.range(of: "content=[\"']([^\"']+)", options: [.regularExpression, .caseInsensitive]) {
                        let v = String(frag[c]).replacingOccurrences(of: "content=", with: "")
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                        let decoded = Self.decodeEntities(v)
                        if !decoded.isEmpty { return decoded }
                    }
                }
            }
        }
        return nil
    }

    private func htmlTitle(_ html: String) -> String? {
        guard let r = html.range(of: "<title[^>]*>", options: [.regularExpression, .caseInsensitive]),
              let e = html.range(of: "</title>", options: .caseInsensitive, range: r.upperBound..<html.endIndex)
        else { return nil }
        let t = Self.decodeEntities(String(html[r.upperBound..<e.lowerBound]))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func decodeEntities(_ s: String) -> String {
        var out = s
        // Numeric entities — &#x65b0; (hex) and &#1234; (decimal); common in FB captions.
        for (pattern, radix) in [("&#x([0-9A-Fa-f]+);", 16), ("&#([0-9]+);", 10)] {
            guard let re = try? NSRegularExpression(pattern: pattern) else { continue }
            while let m = re.firstMatch(in: out, range: NSRange(out.startIndex..., in: out)),
                  let full = Range(m.range, in: out), let num = Range(m.range(at: 1), in: out),
                  let code = UInt32(out[num], radix: radix), let scalar = Unicode.Scalar(code) {
                out.replaceSubrange(full, with: String(scalar))
            }
        }
        return out
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    private func firstLine(_ text: String) -> String? {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : String(clean.prefix(60))
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        for v in values {
            if let v, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return v }
        }
        return nil
    }

    // MARK: - Collection card

    private func buildCard(url: URL?, title rawTitle: String, caption rawCaption: String, imageData: Data?) -> String {
        let host = url?.host?.replacingOccurrences(of: "www.", with: "") ?? "收藏"
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        // If the caption is just the title repeated, drop it to avoid duplication.
        let trimmedCaption = rawCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        let caption = (trimmedCaption == title ? "" : trimmedCaption)
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
