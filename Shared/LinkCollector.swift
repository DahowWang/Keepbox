import Foundation
import UIKit

/// Shared link → collection-card logic, used by both the Share Extension and
/// the in-app "貼上連結" import. Fetches a URL's metadata (X via syndication,
/// 小紅書 via __INITIAL_STATE__, Facebook/others via Open Graph) and builds a
/// styled offline card with title, caption, image and a link back to the source.
enum LinkCollector {

    struct Result { var title: String; var caption: String; var imageData: Data? }
    struct PageMeta { var title: String?; var description: String?; var imageData: Data? }

    /// High-level: resolve a URL (and optional already-shared text) into a
    /// card-ready Result.
    static func collect(_ url: URL, sharedText: String? = nil, completion: @escaping (Result) -> Void) {
        fetchMetadata(url) { meta in
            let caption = firstNonEmpty(meta.description, sharedText) ?? ""
            let title = firstNonEmpty(meta.title, firstLine(caption), url.host) ?? "收藏"
            completion(Result(title: title, caption: caption, imageData: meta.imageData))
        }
    }

    // MARK: - Metadata fetch

    static func fetchMetadata(_ url: URL, completion: @escaping (PageMeta) -> Void) {
        var done = false
        let finish: (PageMeta) -> Void = { meta in
            if done { return }; done = true
            DispatchQueue.main.async { completion(meta) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { finish(PageMeta()) }

        let host = url.host ?? ""
        if (host.contains("x.com") || host.contains("twitter.com")), let id = tweetID(url) {
            fetchTweet(id: id, finish: finish); return
        }
        if host.contains("xiaohongshu.com") || host.contains("xhslink.com") {
            fetchXiaohongshu(url, finish: finish); return
        }

        var req = URLRequest(url: url); req.timeoutInterval = 10
        req.setValue(crawlerUserAgent(for: url), forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let html = String(data: data.prefix(400_000), encoding: .utf8)
                    ?? String(data: data.prefix(400_000), encoding: .isoLatin1) else {
                finish(PageMeta()); return
            }
            var meta = PageMeta()
            meta.title = metaContent(html, keys: ["og:title", "twitter:title", "title"]) ?? htmlTitle(html)
            meta.description = metaContent(html, keys: ["og:description", "twitter:description", "description"])
            if let imgStr = metaContent(html, keys: ["og:image", "twitter:image", "og:image:url"]),
               let imgURL = URL(string: imgStr, relativeTo: url) {
                var ir = URLRequest(url: imgURL); ir.timeoutInterval = 8
                ir.setValue(crawlerUserAgent(for: url), forHTTPHeaderField: "User-Agent")
                URLSession.shared.dataTask(with: ir) { idata, _, _ in meta.imageData = idata; finish(meta) }.resume()
            } else { finish(meta) }
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

    private static func fetchTweet(id: String, finish: @escaping (PageMeta) -> Void) {
        guard let api = URL(string: "https://cdn.syndication.twimg.com/tweet-result?id=\(id)&lang=en&token=a") else {
            finish(PageMeta()); return
        }
        var req = URLRequest(url: api); req.timeoutInterval = 10
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String else { finish(PageMeta()); return }
            var meta = PageMeta()
            let user = json["user"] as? [String: Any]
            let name = user?["name"] as? String ?? ""
            let screen = user?["screen_name"] as? String ?? ""
            let byline = screen.isEmpty ? name : "\(name) (@\(screen))"
            meta.title = firstLine(text) ?? (byline.isEmpty ? "貼文" : byline)
            meta.description = byline.isEmpty ? text : "\(text)\n\n— \(byline)"
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
                URLSession.shared.dataTask(with: ir) { idata, _, _ in meta.imageData = idata; finish(meta) }.resume()
            } else { finish(meta) }
        }.resume()
    }

    private static func fetchXiaohongshu(_ url: URL, finish: @escaping (PageMeta) -> Void) {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if comps?.scheme == "http" { comps?.scheme = "https" }
        guard let httpsURL = comps?.url else { finish(PageMeta()); return }
        var req = URLRequest(url: httpsURL); req.timeoutInterval = 12
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                     forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data, let html = String(data: data, encoding: .utf8) else { finish(PageMeta()); return }
            var meta = PageMeta()
            if let t = firstGroup(html, #""title":"((?:[^"\\]|\\.){1,200})""#) { meta.title = jsonUnescape(t) }
            if let d = firstGroup(html, #""desc":"((?:[^"\\]|\\.){0,2000})""#) { meta.description = jsonUnescape(d) }
            if let raw = firstGroup(html, #""imageList":\[.{0,600}?"url":"(http[^"]+?)""#) {
                var s = raw.replacingOccurrences(of: "\\u002F", with: "/").replacingOccurrences(of: "\\u002f", with: "/")
                if s.hasPrefix("http://") { s = "https://" + s.dropFirst("http://".count) }
                if let imgURL = URL(string: s) {
                    var ir = URLRequest(url: imgURL); ir.timeoutInterval = 8
                    URLSession.shared.dataTask(with: ir) { idata, _, _ in meta.imageData = idata; finish(meta) }.resume()
                    return
                }
            }
            finish(meta)
        }.resume()
    }

    // MARK: - Parsing helpers

    private static func firstGroup(_ s: String, _ pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1
        else { return nil }
        let v = ns.substring(with: m.range(at: 1))
        return v.isEmpty ? nil : v
    }

    private static func jsonUnescape(_ s: String) -> String {
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

    private static func metaContent(_ html: String, keys: [String]) -> String? {
        for key in keys {
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
                        let decoded = decodeEntities(v)
                        if !decoded.isEmpty { return decoded }
                    }
                }
            }
        }
        return nil
    }

    private static func htmlTitle(_ html: String) -> String? {
        guard let r = html.range(of: "<title[^>]*>", options: [.regularExpression, .caseInsensitive]),
              let e = html.range(of: "</title>", options: .caseInsensitive, range: r.upperBound..<html.endIndex)
        else { return nil }
        let t = decodeEntities(String(html[r.upperBound..<e.lowerBound])).trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func decodeEntities(_ s: String) -> String {
        var out = s
        for (pattern, radix) in [("&#x([0-9A-Fa-f]+);", 16), ("&#([0-9]+);", 10)] {
            guard let re = try? NSRegularExpression(pattern: pattern) else { continue }
            while let m = re.firstMatch(in: out, range: NSRange(out.startIndex..., in: out)),
                  let full = Range(m.range, in: out), let num = Range(m.range(at: 1), in: out),
                  let code = UInt32(out[num], radix: radix), let scalar = Unicode.Scalar(code) {
                out.replaceSubrange(full, with: String(scalar))
            }
        }
        return out
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&nbsp;", with: " ")
    }

    static func firstLine(_ text: String) -> String? {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : String(clean.prefix(60))
    }

    static func firstNonEmpty(_ values: String?...) -> String? {
        for v in values where !(v?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) { return v }
        return nil
    }

    static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        if let m = detector?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let url = m.url, url.scheme?.hasPrefix("http") == true { return url }
        return nil
    }

    static func sanitize(_ name: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = name.components(separatedBy: bad).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "收藏" : String(cleaned.prefix(50))
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

    // MARK: - Card HTML

    static func cardHTML(url: URL?, title rawTitle: String, caption rawCaption: String, imageData: Data?) -> String {
        let host = url?.host?.replacingOccurrences(of: "www.", with: "") ?? "收藏"
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCaption = rawCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        let caption = (trimmedCaption == title ? "" : trimmedCaption)
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        var imageBlock = ""
        if let imageData, let jpeg = downscaledJPEG(imageData) {
            imageBlock = "<img class='hero' src='data:image/jpeg;base64,\(jpeg.base64EncodedString())'>"
        }
        var linkBlock = ""
        if let url { linkBlock = "<a class='btn' href='\(url.absoluteString)'>查看原文 ↗</a>" }
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
          font-size:16px;font-weight:700;padding:13px 24px;border-radius:14px;box-shadow:0 6px 18px rgba(91,83,224,.4)}
        </style></head>
        <body><div class="card">\(imageBlock)
        <div class="body"><div class="src">\(host)</div>\(titleBlock)\(captionBlock)\(linkBlock)</div>
        </div></body></html>
        """
    }
}
