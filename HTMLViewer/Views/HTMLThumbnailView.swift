import SwiftUI
import WebKit

struct HTMLThumbnailView: UIViewRepresentable {
    let htmlContent: String
    let width: CGFloat
    let height: CGFloat
    private let renderWidth: CGFloat = 390

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.clipsToBounds = true

        let webView = buildWebView()
        container.addSubview(webView)

        context.coordinator.loadedContent = htmlContent
        webView.loadHTMLString(htmlContent, baseURL: nil)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let webView = uiView.subviews.first as? WKWebView,
              context.coordinator.loadedContent != htmlContent else { return }
        context.coordinator.loadedContent = htmlContent
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    private func buildWebView() -> WKWebView {
        let scale = width / renderWidth
        let renderHeight = height / scale

        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        webView.backgroundColor = .white
        webView.isOpaque = true
        // shift origin so top-left of scaled content lands at (0,0) in the container
        webView.frame = CGRect(
            x: -(renderWidth - width) / 2,
            y: -(renderHeight - height) / 2,
            width: renderWidth,
            height: renderHeight
        )
        webView.transform = CGAffineTransform(scaleX: scale, y: scale)
        return webView
    }

    class Coordinator {
        var loadedContent = ""
    }
}
