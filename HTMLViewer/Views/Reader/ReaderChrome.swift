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

/// 字級選單（並排閱讀工具列用）。
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
            Image(systemName: "textformat.size").frame(width: 44, height: 44)
        }
        .accessibilityLabel("字級：\(session.fontLabel)")
    }
}

/// 內螢幕並排／專注閱讀：文章上方的工具列放在安全區域內，不蓋住文章。
struct WideReaderView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    let file: HTMLFile
    let session: ReaderSession
    @Bindable var state: LibrarySceneState
    let tags: [Tag]
    let viewModel: FileViewModel
    /// 文章已不在目前搜尋／分類結果中（仍保留閱讀，顯示提示）。
    let isOutsideResults: Bool
    /// 單頁閱讀（600–759pt）時提供「收藏清單」浮層；並排時為 nil。參數是收起浮層的 callback。
    var collectionList: ((_ dismiss: @escaping () -> Void) -> AnyView)? = nil
    let onClose: () -> Void

    @State private var source: CollectionSource?
    @State private var showTags = false
    @State private var showList = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
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
        .onAppear(perform: updateSource)
        .onChange(of: file.id) { _, _ in updateSource(); showList = false }
        .onChange(of: file.content) { _, _ in updateSource() }
        .onChange(of: collectionList == nil) { _, alongside in if alongside { showList = false } }
        .sheet(isPresented: $showTags) {
            ReaderTagSheet(file: file, tags: tags, viewModel: viewModel, isPresented: $showTags)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            Button(action: onClose) { Image(systemName: collectionList == nil ? "xmark" : "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel("關閉閱讀，返回收藏")
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(file.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if let collectionList {
                // 開關浮層不改變文章寬度、不重載 HTML。
                Button { showList = true } label: { Image(systemName: "list.bullet.rectangle").frame(width: 44, height: 44) }
                    .accessibilityLabel("收藏清單")
                    .popover(isPresented: $showList) {
                        collectionList { showList = false }
                            .frame(idealWidth: 300, maxWidth: 320, idealHeight: 560)
                            .presentationCompactAdaptation(.sheet)
                    }
            }
            if collectionList == nil || state.focusReading {
                // 並排時：展開成只剩文章／返回並排。從 F 縮到單頁寬度時仍提供退出。
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { state.focusReading.toggle() }
                } label: {
                    Image(systemName: state.focusReading ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(state.focusReading ? (collectionList == nil ? "返回並排" : "返回閱讀") : "展開閱讀")
            }
            ReaderFontMenu(session: session, state: state)
            Button { showTags = true } label: { Image(systemName: "tag").frame(width: 44, height: 44) }
                .accessibilityLabel("標籤")
            ShareLink(item: file.content) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }
                .accessibilityLabel("分享 HTML 內容")
            if let url = source?.originalURL {
                Button { openURL(url) } label: { Image(systemName: "arrow.up.right.square").frame(width: 44, height: 44) }
                    .accessibilityLabel("在瀏覽器開啟原文")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.kbText(scheme))
        .padding(.horizontal, 8)
        .frame(minHeight: 56)
        .background(Color.kbSurface(scheme))
    }

    private func updateSource() {
        source = CollectionSource.resolve(html: file.content, sourceApp: file.sourceApp)
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
