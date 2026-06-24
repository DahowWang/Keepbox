import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let htmlContent: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = true
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loaded != htmlContent else { return }
        context.coordinator.loaded = htmlContent
        webView.loadHTMLString(injectViewport(htmlContent), baseURL: nil)
    }

    /// Ensure a mobile viewport so responsive pages lay out at screen width
    /// instead of overflowing and getting clipped.
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

        // After load, if the content is still wider than the screen (fixed-width
        // layouts), scale the whole page down so nothing is clipped off the edge.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let js = """
            (function(){
              var d=document.documentElement, b=document.body;
              var w=Math.max(d.scrollWidth, b?b.scrollWidth:0, d.offsetWidth);
              var win=window.innerWidth;
              if(w > win+1){
                var s=win/w;
                var m=document.querySelector('meta[name=viewport]');
                if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}
                m.setAttribute('content','width='+w+', initial-scale='+s+', maximum-scale='+s);
              }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
