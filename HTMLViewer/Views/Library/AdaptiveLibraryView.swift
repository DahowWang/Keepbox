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
            // 開合／Split View 改寬度：過渡排版期間列表位置不寫回，穩定後捲回記錄的那則。
            .onChange(of: proxy.size.width) { _, _ in state.containerWidthDidChange() }
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

// MARK: - Narrow（外螢幕、一般 iPhone、窄 Split View、超大字級）

/// 窄版導覽堆疊的目的頁。路徑完全由 scene state 推導（單一真值），不另存一份。
private enum NarrowRoute: Hashable {
    case search
    case reader
}

/// 系統 TabView（全部／資料夾／標籤）＋每個分頁自己的 NavigationStack。
/// 標題、新增、搜尋、同步、排列、排序都是系統工具列項目：一般 iPhone 顯示水平列，
/// Duo 外螢幕由系統搬進右側直式列（返回在最上方）。搜尋與閱讀 push 在目前分頁的 stack 上並隱藏分頁列。
private struct NarrowLibraryView: View {
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
        TabView(selection: $state.tab) {
            stack(for: .all) {
                HomeView(state: state, allFiles: allFiles, folders: folders, tags: tags,
                         onOpen: { state.open($0) }, onLong: onLongPress)
            }
            .tabItem { Label("全部", systemImage: "doc.text") }
            .tag(KBTab.all)

            stack(for: .folders) {
                FolderGridView(
                    folders: folders.filter { $0.parent == nil }, allFiles: allFiles,
                    onOpen: { folder in
                        state.select(.folder(folder.id))
                        state.tab = .all
                    })
            }
            .tabItem { Label("資料夾", systemImage: "folder") }
            .tag(KBTab.folders)

            stack(for: .tags) {
                TagListView(
                    tags: tags, allFiles: allFiles,
                    onPick: { tag in
                        state.select(.tag(tag.id))
                        state.tab = .all
                    })
            }
            .tabItem { Label("標籤", systemImage: "tag") }
            .tag(KBTab.tags)
        }
        .tint(Color.kbAccent)
    }

    // MARK: Navigation（state → path；系統返回／滑動返回 → 既有 closeReader／取消搜尋）

    /// 目前分頁的導覽路徑。閱讀中是否還在搜尋，看開文當時的返回上下文。
    private var route: [NarrowRoute] {
        let reading = state.readerPresented && selectedFile != nil
        let inSearch = reading ? (state.returnContext?.searchActive ?? false) : state.searchActive
        var path: [NarrowRoute] = []
        if inSearch { path.append(.search) }
        if reading { path.append(.reader) }
        return path
    }

    /// 只有作用中的分頁有路徑；其他分頁保持在根層，避免同時掛兩個文章視圖。
    private func path(for tab: KBTab) -> Binding<[NarrowRoute]> {
        Binding(
            get: { tab == state.tab ? route : [] },
            set: { newPath in
                guard tab == state.tab else { return }
                if state.readerPresented && !newPath.contains(.reader) {
                    state.closeReader(anchoringWithin: allFiles)
                }
                // 從搜尋返回：關閉搜尋模式但保留 query 草稿（清除按鈕才清空）。
                if state.searchActive && !newPath.contains(.search) && !state.readerPresented {
                    state.searchActive = false
                }
            })
    }

    private func stack<Root: View>(for tab: KBTab, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: path(for: tab)) {
            root()
                .navigationTitle(title(for: tab))
                .toolbar { browseToolbar(for: tab) }
                .kbToolbarCompression(prefersTabBar: true)
                .navigationDestination(for: NarrowRoute.self) { destination($0) }
        }
    }

    private func title(for tab: KBTab) -> String {
        switch tab {
        case .all: return "Keepbox"
        case .folders: return "資料夾"
        case .tags: return "標籤"
        }
    }

    @ViewBuilder
    private func destination(_ route: NarrowRoute) -> some View {
        switch route {
        case .search:
            SearchView(state: state, allFiles: allFiles, onOpen: { state.open($0) })
                .navigationTitle("搜尋")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .tabBar)
                .toolbar { searchToolbar }
                .kbToolbarCompression(prefersTabBar: false)
        case .reader:
            if let file = selectedFile {
                ReaderView(file: file, session: session, state: state, tags: tags, viewModel: viewModel,
                           onImport: onImport, onSync: onSync)
            }
        }
    }

    // MARK: Toolbars（docs/iphone-duo-design.md §13.3 A／B）

    @ToolbarContentBuilder
    private func browseToolbar(for tab: KBTab) -> some ToolbarContent {
        ToolbarItem(placement: .kbPrimary) {
            Button(action: onImport) { Label("新增收藏", systemImage: "plus") }
        }
        .kbPriority(.high)
        ToolbarItem(placement: .topBarTrailing) {
            Button { state.searchActive = true } label: { Label("搜尋收藏", systemImage: "magnifyingglass") }
        }
        ToolbarItem(placement: .topBarTrailing) {
            SyncToolbarButton(action: onSync)
        }
        .kbPriority(SyncStatusIcon.isFailed ? .high : .automatic)
        if tab == .all {
            // 不放 .bottomBar：iOS 26 在 TabView 裡底部工具列會疊在分頁列上。
            // 排列與排序合成一個選單（兩組 Picker 保留各自的選取語意），低優先，空間不足先進溢出。
            ToolbarItem(placement: .topBarTrailing) { displayMenu }
                .kbPriority(.low)
        }
    }

    @ToolbarContentBuilder
    private var searchToolbar: some ToolbarContent {
        ToolbarItem(placement: .kbPrimary) {
            Button(action: onImport) { Label("新增收藏", systemImage: "plus") }
        }
        .kbPriority(.high)
        ToolbarItem(placement: .bottomBar) { sortMenu }
            .kbPriority(.low)
        KBOverflowMenu(fallbackPlacement: .bottomBar) {
            Button(action: onSync) { Label("同步設定", systemImage: SyncStatusIcon.symbolName) }
                .accessibilityValue(SyncStatusIcon.spokenState)
        }
    }

    private var displayMenu: some View {
        Menu {
            Section("排列") {
                Picker("排列", selection: $state.layout) {
                    Label("網格", systemImage: "square.grid.2x2").tag(KBLayout.grid)
                    Label("圖文", systemImage: "rectangle.grid.1x2").tag(KBLayout.gallery)
                    Label("清單", systemImage: "list.bullet").tag(KBLayout.list)
                }
                .pickerStyle(.inline)
            }
            Section("排序") {
                Picker("排序", selection: $state.sort) {
                    ForEach(LibrarySort.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.inline)
            }
        } label: {
            Label("排列與排序", systemImage: layoutSymbol)
        }
    }

    private var layoutSymbol: String {
        switch state.layout {
        case .grid: return "square.grid.2x2"
        case .gallery: return "rectangle.grid.1x2"
        case .list: return "list.bullet"
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("排序", selection: $state.sort) {
                ForEach(LibrarySort.allCases) { Text($0.rawValue).tag($0) }
            }
        } label: { Label("排序", systemImage: "arrow.up.arrow.down") }
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
    @State private var showList = false
    @State private var showTags = false
    @State private var readingSource: CollectionSource?

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

    /// detail 根頁統一掛系統 toolbar（Duo 攤開時只有 detail 欄參與直式列）。
    /// 瀏覽掛瀏覽組、閱讀掛閱讀組，不同時加兩組。
    private var detailWithToolbar: some View {
        detail
            .toolbar {
                if let file = readingFile {
                    readingToolbar(file)
                } else {
                    browseToolbar
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .kbToolbarCompression(prefersTabBar: readingFile == nil)
            .sheet(isPresented: $showTags) {
                if let file = readingFile {
                    ReaderTagSheet(file: file, tags: tags, viewModel: viewModel, isPresented: $showTags)
                }
            }
            .onAppear(perform: updateReadingSource)
            .onChange(of: state.selectedFileID) { _, _ in updateReadingSource(); showList = false }
            .onChange(of: readingFile?.content) { _, _ in updateReadingSource() }
            .onChange(of: decision.readerAlongside) { _, alongside in if alongside { showList = false } }
    }

    private func updateReadingSource() {
        readingSource = readingFile.map { CollectionSource.resolve(html: $0.content, sourceApp: $0.sourceApp) }
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
                WideReaderView(file: file, session: session, state: state,
                               isOutsideResults: !results.contains { $0.id == file.id },
                               onClose: closeReader)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(readingFile?.name ?? state.title(folders: folders, tags: tags))
    }

    private func closeReader() { state.closeReader(anchoringWithin: allFiles) }

    private func browser(isReadingAlongside: Bool, afterOpen: @escaping () -> Void = {}) -> CollectionBrowserView {
        CollectionBrowserView(state: state, files: results, folders: folders, tags: tags,
                              viewModel: viewModel, density: .touch,
                              isReadingAlongside: isReadingAlongside,
                              onOpen: { state.open($0); afterOpen() }, onRename: onRename, onImport: onImport)
    }

    // MARK: Toolbars（docs/iphone-duo-design.md §13.3 A／C）

    /// 分類欄沒並排時的「分類」入口（popover 需要錨在這顆按鈕上，所以不收進溢出選單）。
    @ToolbarContentBuilder
    private var categoriesItem: some ToolbarContent {
        if !sidebarTiled && !(readingFile != nil && state.focusReading) {
            ToolbarItem(placement: .topBarLeading) {
                Button { showCategories = true } label: { Label("分類", systemImage: "sidebar.leading") }
                    .popover(isPresented: $showCategories) {
                        NavigationStack { sidebar }
                            .frame(idealWidth: 280, maxWidth: 320, idealHeight: 560)
                            .presentationCompactAdaptation(.sheet)
                    }
            }
            .kbPriority(.high)
        }
    }

    @ToolbarContentBuilder
    private var browseToolbar: some ToolbarContent {
        categoriesItem
        ToolbarItem(placement: .kbPrimary) {
            Button(action: onImport) { Label("新增收藏", systemImage: "plus") }
        }
        .kbPriority(.high)
        ToolbarItem(placement: .topBarTrailing) {
            SyncToolbarButton(action: onSync)
        }
        .kbPriority(SyncStatusIcon.isFailed ? .high : .automatic)
        ToolbarItem(placement: .topBarTrailing) { layoutMenu }
            .kbPriority(.low)
        ToolbarItem(placement: .topBarTrailing) { sortMenu }
            .kbPriority(.low)
    }

    @ToolbarContentBuilder
    private func readingToolbar(_ file: HTMLFile) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(action: closeReader) { Label("關閉閱讀", systemImage: "xmark") }
        }
        .kbPriority(.high)
        categoriesItem
        if !decision.readerAlongside {
            // 單頁閱讀（600–759pt）：叫出收藏清單浮層；開關不改文章寬度、不重載 HTML。
            ToolbarItem(placement: .topBarTrailing) {
                Button { showList = true } label: { Label("收藏清單", systemImage: "list.bullet.rectangle") }
                    .popover(isPresented: $showList) {
                        browser(isReadingAlongside: true, afterOpen: { showList = false })
                            .background(Color.kbBg(scheme))
                            .frame(idealWidth: 300, maxWidth: 320, idealHeight: 560)
                            .presentationCompactAdaptation(.sheet)
                    }
            }
            .kbPriority(.high)
        }
        ReaderToolbarItems(file: file, session: session, state: state,
                           originalURL: readingSource?.originalURL, compact: false,
                           onTags: { showTags = true })
        if decision.readerAlongside || state.focusReading {
            // 並排時：展開成只剩文章／返回並排。從專注縮到單頁寬度時仍提供退出。
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { state.focusReading.toggle() }
                } label: {
                    Label(state.focusReading ? (decision.readerAlongside ? "返回並排" : "返回閱讀") : "展開閱讀",
                          systemImage: state.focusReading ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
            }
            .kbPriority(state.focusReading ? .high : .automatic)
        }
        KBOverflowMenu(fallbackPlacement: .topBarTrailing) {
            sortMenu
            Button(action: onImport) { Label("新增收藏", systemImage: "plus") }
            Button(action: onSync) { Label("同步設定", systemImage: SyncStatusIcon.symbolName) }
                .accessibilityValue(SyncStatusIcon.spokenState)
        }
    }

    private var layoutMenu: some View {
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

    private var sortMenu: some View {
        Menu {
            Picker("排序", selection: $state.sort) {
                ForEach(LibrarySort.allCases) { Text($0.rawValue).tag($0) }
            }
        } label: { Label("排序", systemImage: "arrow.up.arrow.down") }
    }
}

#endif
