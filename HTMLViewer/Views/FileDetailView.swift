import SwiftUI
import WebKit

// MARK: - ReaderView（外螢幕／單欄閱讀）
/// 頂端列與底部工具列都放在 safe area inset 裡，不再用固定像素定位，
/// 所以左右不對稱的安全區域與 Dynamic Type 不會蓋住文章或按鈕。
struct ReaderView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    let file: HTMLFile
    let session: ReaderSession
    @Bindable var state: LibrarySceneState
    let tags: [Tag]
    let viewModel: FileViewModel
    let onBack: () -> Void

    @State private var showTextPanel = false
    @State private var showShareSheet = false
    @State private var showTags = false
    @State private var source: CollectionSource?

    var body: some View {
        ReaderContentView(file: file, session: session, state: state)
            .safeAreaInset(edge: .top, spacing: 0) { topBar }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if showTextPanel {
                        textPanel.transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    readerToolbar
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .animation(.spring(response: 0.3), value: showTextPanel)
            }
            .background(Color.kbBg(scheme).ignoresSafeArea())
            .onAppear(perform: updateSource)
            .onChange(of: file.content) { _, _ in updateSource() }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [file.content])
            }
            .sheet(isPresented: $showTags) {
                ReaderTagSheet(file: file, tags: tags, viewModel: viewModel, isPresented: $showTags)
            }
    }

    private func updateSource() {
        source = CollectionSource.resolve(html: file.content, sourceApp: file.sourceApp)
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.kbText(scheme))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityLabel("返回")
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.kbText(scheme))
                    .lineLimit(1)
                Text("即時渲染 · HTML")
                    .font(.caption2)
                    .foregroundStyle(Color.kbSub(scheme))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Bottom toolbar
    private var readerToolbar: some View {
        HStack {
            toolbarBtn("textformat.size", label: "字級", active: showTextPanel) {
                withAnimation(.spring(response: 0.3)) { showTextPanel.toggle() }
            }
            Spacer()
            toolbarBtn("tag", label: "標籤", active: false) { showTags = true; showTextPanel = false }
            Spacer()
            toolbarBtn("square.and.arrow.up", label: "分享", active: false) {
                showShareSheet = true; showTextPanel = false
            }
            if let url = source?.originalURL {
                Spacer()
                toolbarBtn("arrow.up.right.square", label: "開啟原文", active: false) { openURL(url) }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
    }

    @ViewBuilder
    private func toolbarBtn(_ icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.kbText(scheme))
                .frame(width: 44, height: 44)
                .background(active
                    ? (scheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.07))
                    : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel(label)
    }

    // MARK: - Text settings panel
    private var textPanel: some View {
        HStack(spacing: 0) {
            Button {
                setStep(session.fontStep - 1)
            } label: {
                Text("A")
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(Color.kbText(scheme))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityLabel("縮小字級")
            Divider().frame(height: 26)
            Text(session.fontLabel)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.kbSub(scheme))
                .frame(maxWidth: .infinity)
            Divider().frame(height: 26)
            Button {
                setStep(session.fontStep + 1)
            } label: {
                Text("A")
                    .font(.system(size: 24, design: .serif))
                    .foregroundStyle(Color.kbText(scheme))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityLabel("放大字級")
        }
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.25), radius: 24)
    }

    private func setStep(_ step: Int) {
        session.setFontStep(step)
        state.readerFontStep = session.fontStep
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
