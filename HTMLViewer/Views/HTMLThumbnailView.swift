import SwiftUI
import WebKit

/// Renders a saved HTML page as a thumbnail — a true miniature of the real page.
/// The page is laid out at `renderWidth` CSS px, snapshotted from the top once it
/// finishes loading, and the resulting image is scaled to fill the thumbnail box.
/// This `View` carries its own frame so call sites get the right size without
/// each needing to remember a `.frame(...)` modifier.
struct HTMLThumbnailView: View {
    let htmlContent: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        WebSnapshotView(htmlContent: htmlContent, width: width, height: height)
            .frame(width: width, height: height)
    }
}

/// The underlying WebKit-backed snapshot renderer.
private struct WebSnapshotView: UIViewRepresentable {
    let htmlContent: String
    let width: CGFloat
    let height: CGFloat
    private let renderWidth: CGFloat = 390

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        container.backgroundColor = .white
        container.clipsToBounds = true

        // Capture the top region at the page's natural width, matching the box aspect.
        let snapHeight = renderWidth * height / max(width, 1)
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: renderWidth, height: snapHeight))
        webView.navigationDelegate = context.coordinator
        // Behind an opaque cover so it renders (alpha 0 would skip rendering) but
        // its unscaled content is never seen — only the snapshot we draw on top.
        container.addSubview(webView)

        let imageView = UIImageView(frame: container.bounds)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .white
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(imageView)
        context.coordinator.imageView = imageView

        context.coordinator.webView = webView
        context.coordinator.snapshotSize = CGSize(width: renderWidth, height: snapHeight)
        context.coordinator.loadedContent = htmlContent
        webView.loadHTMLString(htmlContent, baseURL: nil)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard context.coordinator.loadedContent != htmlContent,
              let webView = context.coordinator.webView else { return }
        context.coordinator.loadedContent = htmlContent
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        weak var imageView: UIImageView?
        weak var webView: WKWebView?
        var snapshotSize: CGSize = .zero
        var loadedContent = ""

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let config = WKSnapshotConfiguration()
            config.rect = CGRect(origin: .zero, size: snapshotSize)
            // Brief delay so first paint (gradients, web fonts) lands in the snapshot.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                webView.takeSnapshot(with: config) { image, _ in
                    if let image { self?.imageView?.image = image }
                }
            }
        }
    }
}
