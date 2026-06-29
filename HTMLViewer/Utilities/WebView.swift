import SwiftUI
import WebKit

/// Renders saved HTML for comfortable reading on a phone:
/// - Responsive / narrow pages render at device width (like mobile Safari).
/// - Desktop-designed pages (wide fixed layouts, no responsive breakpoints)
///   are laid out at their design width and scaled to fit the screen — so a
///   two-column report stays intact instead of collapsing into one-character
///   columns. Pinch-zoom is always enabled so fine print stays readable.
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
        context.coordinator.designWidth = Self.desktopDesignWidth(htmlContent)
        webView.loadHTMLString(injectViewport(htmlContent), baseURL: nil)
    }

    private func injectViewport(_ html: String) -> String {
        guard html.range(of: "name=[\"']?viewport", options: .regularExpression) == nil else { return html }
        let tag = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        if let head = html.range(of: "<head>", options: .caseInsensitive) {
            var out = html; out.insert(contentsOf: tag, at: head.upperBound); return out
        }
        return "<html><head>\(tag)</head><body>\(html)</body></html>"
    }

    /// Returns the design width (px) when the page looks desktop-built — i.e. it
    /// declares a wide layout (≥700px) and has no responsive @media breakpoints.
    /// Returns 0 for responsive or narrow (mobile-first) pages.
    static func desktopDesignWidth(_ html: String) -> CGFloat {
        let hasBreakpoints = html.range(
            of: "@media[^{]*(min-width|max-width)", options: [.regularExpression, .caseInsensitive]) != nil
        if hasBreakpoints { return 0 }

        var widest: CGFloat = 0
        let pattern = "(?:max-width|width)\\s*:\\s*(\\d{3,})px"
        if let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let ns = html as NSString
            re.enumerateMatches(in: html, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
                if let m, let r = Range(m.range(at: 1), in: html), let v = Double(html[r]) {
                    widest = max(widest, CGFloat(v))
                }
            }
        }
        return widest >= 700 ? min(widest, 1400) : 0
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded: String?
        var designWidth: CGFloat = 0

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let target = Int(designWidth)
            // Desktop page → lay out at design width, scale to fit, keep zoomable.
            // Otherwise → device width, just guarantee pinch-zoom works.
            let js = """
            (function(){
              var m=document.querySelector('meta[name=viewport]');
              if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}
              var target=\(target), screenW=window.innerWidth;
              if(target>0 && target>screenW){
                var s=screenW/target;
                m.setAttribute('content','width='+target+', initial-scale='+s+', minimum-scale='+s+', maximum-scale=5, user-scalable=yes');
              } else {
                var c=(m.getAttribute('content')||'width=device-width, initial-scale=1')
                  .replace(/,?\\s*user-scalable\\s*=\\s*(no|0)/ig,'')
                  .replace(/,?\\s*maximum-scale\\s*=\\s*[0-9.]+/ig,'');
                m.setAttribute('content', c + ', maximum-scale=5');
              }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
