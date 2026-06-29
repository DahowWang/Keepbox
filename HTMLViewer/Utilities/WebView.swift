import SwiftUI
import WebKit

/// Renders saved HTML like mobile Safari: lay out at device width, allow
/// horizontal scrolling for wider sections, and always allow pinch-to-zoom so
/// nothing is clipped and small text stays readable. We deliberately do NOT
/// shrink the whole page to fit — that made dense reports unreadable.
struct WebView: UIViewRepresentable {
    let htmlContent: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = true
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 5
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loaded != htmlContent else { return }
        context.coordinator.loaded = htmlContent
        webView.loadHTMLString(injectViewport(htmlContent), baseURL: nil)
    }

    /// Add a mobile viewport when the page lacks one (older exports render at a
    /// 980px desktop width otherwise).
    private func injectViewport(_ html: String) -> String {
        guard html.range(of: "name=[\"']?viewport", options: .regularExpression) == nil else { return html }
        let tag = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        if let head = html.range(of: "<head>", options: .caseInsensitive) {
            var out = html; out.insert(contentsOf: tag, at: head.upperBound); return out
        }
        return "<html><head>\(tag)</head><body>\(html)</body></html>"
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded: String?

        // Guarantee the reader is always zoomable: some pages ship
        // user-scalable=no / maximum-scale, which would trap small text at an
        // unreadable size. Strip those so pinch-zoom works like Safari.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let js = """
            (function(){
              var m=document.querySelector('meta[name=viewport]');
              if(m){
                var c=m.getAttribute('content')||'';
                c=c.replace(/,?\\s*user-scalable\\s*=\\s*(no|0)/ig,'')
                   .replace(/,?\\s*maximum-scale\\s*=\\s*[0-9.]+/ig,'');
                m.setAttribute('content', c + ', maximum-scale=5');
              }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
