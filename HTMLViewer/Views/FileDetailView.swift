import SwiftUI
import WebKit

// MARK: - ReaderView
struct ReaderView: View {
    @Environment(\.colorScheme) private var scheme
    let file: HTMLFile
    let onBack: () -> Void

    @State private var showTextPanel = false
    @State private var showShareSheet = false
    @State private var fontSizeStep = 1  // 0=小 1=標準 2=大 3=特大

    private var fontScales: [CGFloat] { [0.85, 1.0, 1.14, 1.3] }
    private var fontLabels: [String] { ["小", "標準", "大", "特大"] }
    private var currentScale: CGFloat { fontScales[fontSizeStep] }

    var body: some View {
        ZStack {
            // Full-screen web content
            WebView(htmlContent: sizedHTML)
                .ignoresSafeArea()

            // Top gradient + chrome
            VStack {
                LinearGradient(
                    colors: [scheme == .dark ? .black.opacity(0.55) : Color(hex: "#e9e7f2").opacity(0.96), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 110)
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 10) {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(scheme == .dark ? .white : Color(hex: "#1d1b3a"))
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.1), radius: 4)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name)
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundStyle(scheme == .dark ? .white : Color(hex: "#1d1b3a"))
                                .lineLimit(1)
                            Text("即時渲染 · HTML")
                                .font(.system(size: 11))
                                .foregroundStyle(scheme == .dark ? .white.opacity(0.6) : Color(hex: "#9a96b5"))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 56)
                }
                Spacer()
            }
            .ignoresSafeArea()

            // Bottom toolbar + text panel
            VStack(spacing: 0) {
                Spacer()
                if showTextPanel {
                    textPanel
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                readerToolbar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
            .animation(.spring(response: 0.3), value: showTextPanel)
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [file.content])
        }
    }

    // Inject font-size CSS into the HTML
    private var sizedHTML: String {
        let pct = Int(currentScale * 100)
        let css = "<style>html{font-size:\(pct)%!important}body{font-size:\(pct)%!important}</style>"
        if let headRange = file.content.range(of: "<head>", options: .caseInsensitive) {
            var html = file.content
            html.insert(contentsOf: css, at: headRange.upperBound)
            return html
        }
        return "<html><head>\(css)</head><body>\(file.content)</body></html>"
    }

    // MARK: - Bottom toolbar
    private var readerToolbar: some View {
        HStack {
            toolbarBtn("textformat.size", active: showTextPanel) {
                withAnimation(.spring(response: 0.3)) { showTextPanel.toggle() }
            }
            Spacer()
            toolbarBtn("tag", active: false) { }
            Spacer()
            toolbarBtn("square.and.arrow.up", active: false) {
                showShareSheet = true; showTextPanel = false
            }
            Spacer()
            toolbarBtn("arrow.up.right.square", active: false) { }
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
    }

    @ViewBuilder
    private func toolbarBtn(_ icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(scheme == .dark ? .white : Color(hex: "#1d1b3a"))
                .frame(width: 44, height: 44)
                .background(active
                    ? (scheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.07))
                    : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Text settings panel
    private var textPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                // Decrease
                Button {
                    withAnimation { fontSizeStep = max(0, fontSizeStep - 1) }
                } label: {
                    Text("A")
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(Color.kbText(scheme))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                }
                Divider().frame(height: 26)
                Text(fontLabels[fontSizeStep])
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.kbSub(scheme))
                    .frame(maxWidth: .infinity)
                Divider().frame(height: 26)
                // Increase
                Button {
                    withAnimation { fontSizeStep = min(3, fontSizeStep + 1) }
                } label: {
                    Text("A")
                        .font(.system(size: 24, design: .serif))
                        .foregroundStyle(Color.kbText(scheme))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                }
            }
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.25), radius: 24)
        .contentShape(Rectangle())
        .onTapGesture { }  // prevent dismissal when tapping inside panel
    }
}

// MARK: - Share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
