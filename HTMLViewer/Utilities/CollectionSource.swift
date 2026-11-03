import Foundation

/// Source metadata only; a platform mentioned in an article is never a source.
/// Shared by the Mac library, the touch library and the readers.
struct CollectionSource: Equatable {
    let originalURL: URL?
    let platform: String?

    private static let tags = try! NSRegularExpression(pattern: #"<(a|link|meta)\b[^>]*>"#, options: .caseInsensitive)
    private static let attributes = try! NSRegularExpression(pattern: #"([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#)
    private static let ignoredMarkup = try! NSRegularExpression(pattern: #"<!--[\s\S]*?-->|<(script|style)\b[^>]*>[\s\S]*?</\1\s*>"#, options: .caseInsensitive)

    static func resolve(html: String, sourceApp: String?) -> Self {
        let url = sourceURL(in: html)
        // A known URL takes precedence over the app that happened to share it.
        let platform = url.flatMap { platform(forHost: $0.host ?? "") }
            ?? (url == nil ? platform(forApp: sourceApp) : nil)
        return Self(originalURL: url, platform: platform)
    }

    private static func sourceURL(in html: String) -> URL? {
        let cleaned = ignoredMarkup.stringByReplacingMatches(in: html, range: NSRange(html.startIndex..., in: html), withTemplate: "")
        let text = cleaned as NSString
        var canonical: URL?
        var openGraph: URL?
        for match in tags.matches(in: cleaned, range: NSRange(location: 0, length: text.length)) {
            let tag = text.substring(with: match.range)
            let kind = text.substring(with: match.range(at: 1)).lowercased()
            let nsTag = tag as NSString
            var values: [String: String] = [:]
            for attribute in attributes.matches(in: tag, range: NSRange(location: 0, length: nsTag.length)) {
                let key = nsTag.substring(with: attribute.range(at: 1)).lowercased()
                for index in 2...4 where attribute.range(at: index).location != NSNotFound {
                    values[key] = nsTag.substring(with: attribute.range(at: index))
                }
            }
            if kind == "a", values["class"]?.split(whereSeparator: { $0.isWhitespace }).contains("btn") == true {
                // LinkCollector's saved cards use this exact source action text.
                let following = text.substring(from: NSMaxRange(match.range))
                if following.hasPrefix("查看原文 ↗</a>"), let url = webURL(values["href"]) { return url }
            }
            if kind == "link", values["rel"]?.lowercased().split(whereSeparator: { $0.isWhitespace }).contains("canonical") == true {
                canonical = canonical ?? webURL(values["href"])
            }
            if kind == "meta", (values["property"] ?? values["name"])?.lowercased() == "og:url" {
                openGraph = openGraph ?? webURL(values["content"])
            }
        }
        return canonical ?? openGraph
    }

    private static func webURL(_ value: String?) -> URL? {
        guard let value,
              let url = URL(string: value.replacingOccurrences(of: "&amp;", with: "&").trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }

    static func platform(forHost rawHost: String) -> String? {
        let host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let platforms: [(String, [String])] = [
            ("Facebook", ["facebook.com", "fb.com", "fb.watch"]),
            ("X", ["x.com", "twitter.com", "t.co"]),
            ("小紅書", ["xiaohongshu.com", "xhslink.com"]),
            ("Instagram", ["instagram.com"]),
            ("YouTube", ["youtube.com", "youtu.be"]),
            ("Threads", ["threads.net", "threads.com"]),
            ("GitHub", ["github.com"])
        ]
        return platforms.first { _, domains in
            domains.contains { host == $0 || host.hasSuffix("." + $0) }
        }?.0
    }

    static func platform(forApp sourceApp: String?) -> String? {
        guard let value = sourceApp?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return nil }
        // Exact names / bundle identifiers only. "Safari" and arbitrary text stay unknown.
        let names: [String: String] = [
            "facebook": "Facebook", "com.facebook.facebook": "Facebook",
            "x": "X", "twitter": "X", "com.atebits.tweetie2": "X",
            "小紅書": "小紅書", "小红书": "小紅書", "xiaohongshu": "小紅書", "com.xingin.discover": "小紅書",
            "instagram": "Instagram", "com.burbn.instagram": "Instagram",
            "youtube": "YouTube", "com.google.ios.youtube": "YouTube",
            "threads": "Threads", "com.burbn.barcelona": "Threads", "github": "GitHub"
        ]
        return names[value]
    }
}
