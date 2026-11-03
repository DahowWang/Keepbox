#if !targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

/// iPhone／iPad／iPhone Duo 的根版面。依實際可用寬度與 size class 決定單欄或寬版，
/// 不看裝置方向、不看機型。切換版面不重設 `LibrarySceneState`，閱讀 session 也沿用同一個。
struct AdaptiveLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var state: LibrarySceneState
    let session: ReaderSession
    let viewModel: FileViewModel
    let allFiles: [HTMLFile]
    let folders: [Folder]
    let tags: [Tag]
    let onImport: () -> Void
    let onSync: () -> Void
    let onLongPress: (HTMLFile) -> Void

    @State private var renameFile: HTMLFile?
    @State private var nameDraft = ""
    @State private var newCollectionKind: String?

    private var selectedFile: HTMLFile? {
        guard let id = state.selectedFileID else { return nil }
        return allFiles.first { $0.id == id }
    }

    var body: some View {
        GeometryReader { proxy in
            let input = LibraryLayoutPolicy.Input(
                width: proxy.size.width, height: proxy.size.height,
                horizontalRegular: horizontalSizeClass == .regular,
                verticalRegular: verticalSizeClass == .regular,
                accessibilityText: dynamicTypeSize.isAccessibilitySize,
                readerOpen: state.readerPresented && selectedFile != nil,
                divisions: DivisionRegionAdapter.divisions(in: proxy))
            let decision = LibraryLayoutPolicy.decide(input)
            #if DEBUG
            let _ = Self.logLayout(input, decision)
            #endif
            Group {
                if decision.mode == .narrow {
                    NarrowLibraryView(state: state, session: session, viewModel: viewModel,
                                      allFiles: allFiles, folders: folders, tags: tags, selectedFile: selectedFile,
                                      onImport: onImport, onSync: onSync, onLongPress: onLongPress)
                } else {
                    WideLibraryView(state: state, session: session, viewModel: viewModel, decision: decision,
                                    allFiles: allFiles, folders: folders, tags: tags, selectedFile: selectedFile,
                                    onImport: onImport, onSync: onSync,
                                    onRename: { beginRename($0) },
                                    onNewCollection: { beginCollection($0) })
                }
            }
        }
        .alert("重新命名收藏", isPresented: Binding(get: { renameFile != nil }, set: { if !$0 { renameFile = nil } })) {
            TextField("名稱", text: $nameDraft)
            Button("取消", role: .cancel) { renameFile = nil }
            Button("儲存") {
                if let file = renameFile, !trimmedName.isEmpty { viewModel.rename(file, to: trimmedName, context: modelContext) }
                renameFile = nil
            }.disabled(trimmedName.isEmpty)
        }
        .alert("新增\(newCollectionKind ?? "資料夾")", isPresented: Binding(get: { newCollectionKind != nil }, set: { if !$0 { newCollectionKind = nil } })) {
            TextField("名稱", text: $nameDraft)
            Button("取消", role: .cancel) { newCollectionKind = nil }
            Button("新增") { createCollection() }.disabled(trimmedName.isEmpty)
        }
    }

    private var trimmedName: String { nameDraft.trimmingCharacters(in: .whitespacesAndNewlines) }

    #if DEBUG
    /// `-layoutDebug`：印出實際量到的版面輸入，用於 Duo 驗收紀錄。
    private static var lastLogged: String?
    private static func logLayout(_ input: LibraryLayoutPolicy.Input, _ decision: LibraryLayoutDecision) {
        guard ProcessInfo.processInfo.arguments.contains("-layoutDebug") else { return }
        let line = "[KBLayout] W=\(input.width) H=\(input.height) h=\(input.horizontalRegular ? "R" : "C") v=\(input.verticalRegular ? "R" : "C") reader=\(input.readerOpen) divisions=\(input.divisions.map { "\($0.frame) active=\($0.isActive) m=\($0.leadingMargin)/\($0.trailingMargin)" }) -> \(decision)"
        guard line != lastLogged else { return }
        lastLogged = line
        print(line)
    }
    #endif

    private func beginRename(_ file: HTMLFile) { nameDraft = file.name; renameFile = file }
    private func beginCollection(_ kind: String) { nameDraft = ""; newCollectionKind = kind }

    private func createCollection() {
        guard !trimmedName.isEmpty else { return }
        if newCollectionKind == "標籤" {
            modelContext.insert(Tag(name: trimmedName, colorHex: Tag.defaultColors[tags.count % Tag.defaultColors.count]))
        } else {
            modelContext.insert(Folder(name: trimmedName))
        }
        try? modelContext.save()
        newCollectionKind = nil
    }
}

// MARK: - Narrow（外螢幕、窄 Split View、超大字級）

/// 原本的手機介面：全部／資料夾／標籤三分頁、三種排列、全畫面閱讀。
private struct NarrowLibraryView: View {
    @Environment(\.colorScheme) private var scheme
    @Bindable var state: LibrarySceneState
    let session: ReaderSession
    let viewModel: FileViewModel
    let allFiles: [HTMLFile]
    let folders: [Folder]
    let tags: [Tag]
    let selectedFile: HTMLFile?
    let onImport: () -> Void
    let onSync: () -> Void
    let onLongPress: (HTMLFile) -> Void

    var body: some View {
        ZStack {
            if state.readerPresented, let file = selectedFile {
                ReaderView(file: file, session: session, state: state, tags: tags, viewModel: viewModel,
                           onBack: { withAnimation(.easeInOut(duration: 0.2)) { state.closeReader(anchoringWithin: allFiles) } })
                    .transition(.opacity)
            } else if state.searchActive {
                SearchView(state: state, allFiles: allFiles,
                           onBack: { withAnimation { state.searchActive = false } },
                           onOpen: { state.open($0) })
                    .transition(.opacity)
            } else {
                tabContent
                    .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.searchActive)
        .animation(.easeInOut(duration: 0.2), value: state.readerPresented)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch state.tab {
        case .all:
            HomeView(state: state, allFiles: allFiles, folders: folders, tags: tags,
                     onOpen: { state.open($0) }, onLong: onLongPress,
                     onSearch: { withAnimation { state.searchActive = true } },
                     onSync: onSync)
        case .folders:
            FolderGridView(
                folders: folders.filter { $0.parent == nil }, allFiles: allFiles,
                onOpen: { folder in
                    state.select(.folder(folder.id))
                    withAnimation { state.tab = .all }
                })
        case .tags:
            TagListView(
                tags: tags, allFiles: allFiles,
                onPick: { tag in
                    state.select(.tag(tag.id))
                    withAnimation { state.tab = .all }
                })
        }
    }

    // MARK: Bottom bar（safeAreaInset：捲動內容自動避開，不用硬編碼底部高度）
    private var bottomBar: some View {
        VStack(alignment: .trailing, spacing: 14) {
            Button(action: onImport) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.kbAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                    .shadow(color: Color.kbAccent.opacity(0.45), radius: 14, x: 0, y: 8)
            }
            .accessibilityLabel("新增收藏")
            .padding(.trailing, 22)

            HStack(spacing: 0) {
                tabButton(.all, "全部", "doc.text")
                tabButton(.folders, "資料夾", "folder")
                tabButton(.tags, "標籤", "tag")
            }
            .frame(height: 62)
            .padding(.horizontal, 24)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func tabButton(_ t: KBTab, _ label: String, _ icon: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { state.tab = t } } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(state.tab == t ? Color.kbAccent : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(state.tab == t ? [.isSelected] : [])
    }
}

// MARK: - Wide（Duo 內螢幕、iPad）

private struct WideLibraryView: View {
    @Environment(\.colorScheme) private var scheme
    @Bindable var state: LibrarySceneState
    let session: ReaderSession
    let viewModel: FileViewModel
    let decision: LibraryLayoutDecision
    let allFiles: [HTMLFile]
    let folders: [Folder]
    let tags: [Tag]
    let selectedFile: HTMLFile?
    let onImport: () -> Void
    let onSync: () -> Void
    let onRename: (HTMLFile) -> Void
    let onNewCollection: (String) -> Void

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showCategories = false

    private var results: [HTMLFile] { state.results(from: allFiles) }
    private var readingFile: HTMLFile? { state.readerPresented ? selectedFile : nil }
    /// 分類欄並排：只在 policy 允許、且不是專注閱讀／單頁閱讀時。
    private var sidebarTiled: Bool {
        decision.sidebarTiled && !(readingFile != nil && (state.focusReading || !decision.readerAlongside))
    }

    var body: some View {
        // 分類欄並排用 NavigationSplitView；不並排時改用 NavigationStack＋自己的「分類」浮層。
        // （iOS 27 寬版上 split view 會把程式設定的 detailOnly 改回 all，無法可靠收起。）
        // 兩種容器共用同一份 scene state 與閱讀 session，切換時不重設狀態、不重載文章。
        if sidebarTiled {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebar
                    .navigationSplitViewColumnWidth(min: LibraryLayoutPolicy.sidebarMinWidth, ideal: decision.sidebarWidth, max: 260)
            } detail: {
                detailWithToolbar
            }
            .navigationSplitViewStyle(.balanced)
            .tint(Color.kbAccent)
            .onAppear { columnVisibility = .all; showCategories = false }
        } else {
            NavigationStack {
                detailWithToolbar
            }
            .tint(Color.kbAccent)
        }
    }

    private var detailWithToolbar: some View {
        detail
            .toolbar { toolbarContent }
            .toolbarTitleDisplayMode(.inline)
    }

    private var sidebar: some View {
        LibrarySidebarView(state: state, allFiles: allFiles, folders: folders, tags: tags,
                           onSelect: { showCategories = false },
                           onNewFolder: { showCategories = false; onNewCollection("資料夾") },
                           onNewTag: { showCategories = false; onNewCollection("標籤") },
                           onSync: { showCategories = false; onSync() })
    }

    private var detail: some View {
        HStack(spacing: 0) {
            let alongside = decision.readerAlongside && !state.focusReading
            if readingFile == nil || alongside {
                browser(isReadingAlongside: readingFile != nil)
                    .frame(width: readingFile != nil ? decision.listWidth : nil)
                    .frame(maxWidth: readingFile != nil ? nil : .infinity, maxHeight: .infinity)
                    .background(Color.kbBg(scheme))
            }
            if let file = readingFile {
                if alongside { Divider() }
                WideReaderView(file: file, session: session, state: state, tags: tags, viewModel: viewModel,
                               isOutsideResults: !results.contains { $0.id == file.id },
                               collectionList: decision.readerAlongside ? nil : { dismiss in
                                   AnyView(browser(isReadingAlongside: true, afterOpen: dismiss).background(Color.kbBg(scheme)))
                               },
                               onClose: { state.closeReader(anchoringWithin: allFiles) })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(state.title(folders: folders, tags: tags))
    }

    private func browser(isReadingAlongside: Bool, afterOpen: @escaping () -> Void = {}) -> CollectionBrowserView {
        CollectionBrowserView(state: state, files: results, folders: folders, tags: tags,
                              viewModel: viewModel, density: .touch,
                              isReadingAlongside: isReadingAlongside,
                              onOpen: { state.open($0); afterOpen() }, onRename: onRename, onImport: onImport)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !sidebarTiled && !(readingFile != nil && state.focusReading) {
            ToolbarItem(placement: .navigation) {
                Button { showCategories = true } label: { Label("分類", systemImage: "sidebar.leading") }
                    .popover(isPresented: $showCategories) {
                        NavigationStack { sidebar }
                            .frame(idealWidth: 280, maxWidth: 320, idealHeight: 560)
                            .presentationCompactAdaptation(.sheet)
                    }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Picker("排序", selection: $state.sort) {
                    ForEach(LibrarySort.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: { Label("排序", systemImage: "arrow.up.arrow.down") }
            if readingFile == nil {
                Menu {
                    Picker("排列", selection: Binding(get: { state.layout == .list ? KBLayout.list : .grid },
                                                     set: { state.layout = $0 })) {
                        Label("網格", systemImage: "square.grid.2x2").tag(KBLayout.grid)
                        Label("清單", systemImage: "list.bullet").tag(KBLayout.list)
                    }
                } label: {
                    Label("排列", systemImage: state.layout == .list ? "list.bullet" : "square.grid.2x2")
                }
            }
            Button(action: onSync) { Label("同步設定", systemImage: "arrow.triangle.2.circlepath") }
                .accessibilityValue(SyncStatusIcon.spokenState)
            Button(action: onImport) { Label("新增收藏", systemImage: "plus") }
        }
    }
}

#endif
