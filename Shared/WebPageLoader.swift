import WebKit

/// Loads a URL in a real WKWebView (same engine as Safari) and returns the
/// fully-rendered DOM HTML. Used for sites like 小紅書 that serve bot requests
/// a redirect/empty page but give real browsers the note — and that populate
/// content via JavaScript. Self-contained: retains itself while loading, needs
/// no view hierarchy, and works in both the app and the Share Extension.
final class WebPageLoader: NSObject, WKNavigationDelegate {

    private var webView: WKWebView?
    private var completion: ((String?) -> Void)?
    private var settle: DispatchWorkItem?
    private static var live = Set<WebPageLoader>()

    /// Fetch the rendered outer HTML of `url`. Completion is called on the main
    /// thread with the HTML, or nil on failure/timeout.
    static func fetchRenderedHTML(_ url: URL, settleDelay: TimeInterval = 2.5,
                                  completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let loader = WebPageLoader()
            live.insert(loader)
            loader.start(url, settleDelay: settleDelay, completion: completion)
        }
    }

    private func start(_ url: URL, settleDelay: TimeInterval, completion: @escaping (String?) -> Void) {
        self.completion = completion
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 900), configuration: cfg)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        wv.navigationDelegate = self
        self.webView = wv
        self.settleDelay = settleDelay
        wv.load(URLRequest(url: url, timeoutInterval: 20))
        // Hard cap so a hung page never leaks the loader.
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in self?.done(nil) }
    }

    private var settleDelay: TimeInterval = 2.5

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give client-side JS a moment to populate content, then snapshot the DOM.
        settle?.cancel()
        let work = DispatchWorkItem { [weak self] in
            webView.evaluateJavaScript("document.documentElement.outerHTML") { result, _ in
                self?.done(result as? String)
            }
        }
        settle = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay, execute: work)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { done(nil) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { done(nil) }

    private func done(_ html: String?) {
        guard completion != nil else { return }
        let c = completion; completion = nil
        settle?.cancel()
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        c?(html)
        WebPageLoader.live.remove(self)
    }
}
