import SwiftUI
import WebKit

// MARK: - ReaderView（外螢幕／單欄閱讀）
/// 窄版 NavigationStack 的閱讀目的頁。返回用系統導覽（Duo 外螢幕會在直式側邊列最上方），
/// 分享是主要動作；字級、標籤、原文與溢出選單都是系統工具列項目，不再自己畫頂列／底列。
struct ReaderView: View {
    @Environment(\.colorScheme) private var scheme
    let file: HTMLFile
    let session: ReaderSession
    @Bindable var state: LibrarySceneState
    let tags: [Tag]
    let viewModel: FileViewModel
    let onImport: () -> Void
    let onSync: () -> Void

    @State private var showTags = false
    @State private var source: CollectionSource?

    var body: some View {
        ReaderContentView(file: file, session: session, state: state)
            .background(Color.kbBg(scheme).ignoresSafeArea())
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ReaderToolbarItems(file: file, session: session, state: state,
                                   originalURL: source?.originalURL, compact: true,
                                   onTags: { showTags = true })
                KBOverflowMenu(fallbackPlacement: .bottomBar) {
                    Button(action: onImport) { Label("新增收藏", systemImage: "plus") }
                    Button(action: onSync) { Label("同步設定", systemImage: SyncStatusIcon.symbolName) }
                        .accessibilityValue(SyncStatusIcon.spokenState)
                }
            }
            .kbToolbarCompression(prefersTabBar: false)
            .onAppear(perform: updateSource)
            .onChange(of: file.content) { _, _ in updateSource() }
            .sheet(isPresented: $showTags) {
                ReaderTagSheet(file: file, tags: tags, viewModel: viewModel, isPresented: $showTags)
            }
    }

    private func updateSource() {
        source = CollectionSource.resolve(html: file.content, sourceApp: file.sourceApp)
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
