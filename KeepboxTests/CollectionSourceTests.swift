import XCTest
@testable import HTMLViewer

/// 抽出成共用的來源辨識，規則與 Mac 版原本的 MacCollectionSource 相同。
final class CollectionSourceTests: XCTestCase {
    func testLinkCollectorCardButtonWins() {
        let html = #"<link rel="canonical" href="https://github.com/a/b"><a class="btn" href="https://x.com/u/status/1">查看原文 ↗</a>"#
        let s = CollectionSource.resolve(html: html, sourceApp: nil)
        XCTAssertEqual(s.platform, "X")
        XCTAssertEqual(s.originalURL?.host, "x.com")
    }

    func testCanonicalAndOpenGraphAnyAttributeOrder() {
        XCTAssertEqual(CollectionSource.resolve(html: #"<link href='https://m.facebook.com/p' rel=canonical>"#, sourceApp: nil).platform, "Facebook")
        XCTAssertEqual(CollectionSource.resolve(html: #"<meta content="https://www.xiaohongshu.com/x" property="og:url">"#, sourceApp: nil).platform, "小紅書")
    }

    func testURLPrecedesSharingApp() {
        let s = CollectionSource.resolve(html: #"<meta property="og:url" content="https://github.com/x">"#, sourceApp: "facebook")
        XCTAssertEqual(s.platform, "GitHub")
    }

    func testSourceAppOnlyWhenNoURL() {
        XCTAssertEqual(CollectionSource.resolve(html: "<p>hi</p>", sourceApp: "com.burbn.instagram").platform, "Instagram")
        XCTAssertNil(CollectionSource.resolve(html: "<p>hi</p>", sourceApp: "Safari").platform)
    }

    func testLookalikeDomainsAndArticleMentionsIgnored() {
        XCTAssertNil(CollectionSource.platform(forHost: "notfacebook.com"))
        XCTAssertEqual(CollectionSource.platform(forHost: "m.youtube.com"), "YouTube")
        let html = #"<p>看 <a href="https://facebook.com/x">FB</a></p><!-- <link rel="canonical" href="https://x.com"> -->"#
        XCTAssertNil(CollectionSource.resolve(html: html, sourceApp: nil).platform)
    }
}
