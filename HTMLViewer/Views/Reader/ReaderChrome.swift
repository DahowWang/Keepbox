import SwiftUI
import SwiftData

/// 文章本體：掛上 scene 的閱讀 session，處理內容下載中與「內容已更新」。
/// 單欄閱讀與並排閱讀都用它，所以版面切換時文章不重載。
struct ReaderContentView: View {
    @Environment(\.colorScheme) private var scheme
    let file: HTMLFile
    let session: ReaderSession
    @Bindable var state: LibrarySceneState

    private var isDownloading: Bool { file.needsContentDownload && file.content.isEmpty }

    var body: some View {
        ZStack {
            Color.white.opacity(scheme == .dark ? 0 : 1)
            ReaderWebView(session: session)
                .opacity(isDownloading ? 0 : 1)
            if isDownloading {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("內容下載中…").font(.subheadline).foregroundStyle(.secondary)
                    Button("重試") { Task { await SyncService.shared.syncNow() } }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                }
            }
        }
        .overlay(alignment: .top) {
            if session.hasPendingUpdate && session.fileID == file.id {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise.circle.fill").foregroundStyle(Color.kbAccent)
                    Text("內容已更新").font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Button("重新載入") { session.applyPendingUpdate() }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear(perform: show)
        .onChange(of: file.id) { _, _ in show() }
        .onChange(of: file.content) { _, _ in show() }
    }

    private func show() {
        session.show(fileID: file.id, html: file.content, fontStep: state.readerFontStep,
                     restoring: state.anchor(for: file.id))
    }
}

/// 字級選單（系統工具列項目）。標題固定「字級」，目前選取由 Picker 勾選並朗讀。
struct ReaderFontMenu: View {
    let session: ReaderSession
    @Bindable var state: LibrarySceneState

    var body: some View {
        Menu {
            Picker("字級", selection: Binding(get: { session.fontStep }, set: { step in
                session.setFontStep(step)
                state.readerFontStep = session.fontStep
            })) {
                ForEach(ReaderSession.fontLabels.indices, id: \.self) { i in
                    Text(ReaderSession.fontLabels[i]).tag(i)
                }
            }
        } label: {
            Label("字級", systemImage: "textformat.size")
        }
        .accessibilityValue(session.fontLabel)
    }
}

/// 閱讀共用的工具列項目（窄版、寬版都用）：分享（主要動作）、字級、標籤、原文。
/// 返回／關閉、收藏清單、焦點切換與溢出選單由各自的容器加，避免重複。
/// 每項都是獨立 ToolbarItem，系統才能在 Duo 直式列逐項排列、壓縮。
struct ReaderToolbarItems: ToolbarContent {
    let file: HTMLFile
    let session: ReaderSession
    let state: LibrarySceneState
    let originalURL: URL?
    /// 窄版：次要工具放底部工具列；寬版：放頂端（文章與清單並排，底列會橫跨兩欄）。
    let compact: Bool
    let onTags: () -> Void

    private var secondary: ToolbarItemPlacement { compact ? .bottomBar : .topBarTrailing }

    var body: some ToolbarContent {
        ToolbarItem(placement: .kbPrimary) {
            ShareLink(item: file.content) { Label("分享", systemImage: "square.and.arrow.up") }
        }
        .kbPriority(.high)
        ToolbarItem(placement: secondary) {
            ReaderFontMenu(session: session, state: state)
        }
        ToolbarItem(placement: secondary) {
            Button(action: onTags) { Label("標籤", systemImage: "tag") }
                .kbToolbarBadge(file.tags.count)
                .accessibilityValue(file.tags.isEmpty ? "尚未加標籤" : "已加 \(file.tags.count) 個標籤")
        }
        if let originalURL {
            ToolbarItem(placement: secondary) {
                Link(destination: originalURL) { Label("開啟原文", systemImage: "arrow.up.right.square") }
            }
            .kbPriority(.low)
        }
    }
}

/// 內螢幕並排／單頁／專注閱讀的文章區。工具列由 WideLibraryView 的 detail 根頁統一提供
/// （系統 toolbar，Duo 攤開時可直排），這裡只放「不在目前結果」提示與文章本體。
struct WideReaderView: View {
    @Environment(\.colorScheme) private var scheme
    let file: HTMLFile
    let session: ReaderSession
    @Bindable var state: LibrarySceneState
    /// 文章已不在目前搜尋／分類結果中（仍保留閱讀，顯示提示）。
    let isOutsideResults: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isOutsideResults {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(.secondary)
                    Text("此收藏不在目前結果").font(.footnote)
                    Spacer()
                    Button("關閉閱讀", action: onClose).font(.footnote.weight(.semibold)).frame(minHeight: 44)
                }
                .padding(.horizontal, 16)
                .background(Color.secondary.opacity(0.08))
            }
            ReaderContentView(file: file, session: session, state: state)
        }
        .background(Color.kbSurface(scheme))
    }
}

/// 閱讀時管理標籤（單欄與並排共用）。
struct ReaderTagSheet: View {
    let file: HTMLFile
    let tags: [Tag]
    let viewModel: FileViewModel
    @Binding var isPresented: Bool
    @State private var showAddTag = false
    @State private var newTagName = ""
    @State private var newTagColor = Tag.defaultColors[0]

    var body: some View {
        TagManagementSheet(file: file, tags: tags, viewModel: viewModel,
                           showAddTag: $showAddTag, newTagName: $newTagName,
                           newTagColor: $newTagColor, isPresented: $isPresented)
    }
}
