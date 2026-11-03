import SwiftUI
import SwiftData

/// 收藏區：Duo 內螢幕（觸控）與 Mac（桌面）共用。
/// - 瀏覽時依排列偏好顯示卡片格或清單；並排閱讀時暫用清單（不改偏好）。
/// - 觸控卡片格以收藏區自己的座標系查詢摺痕，讓卡片不壓在摺痕上。
struct CollectionBrowserView: View {
    @Environment(\.colorScheme) private var scheme
    @Bindable var state: LibrarySceneState
    let files: [HTMLFile]
    let folders: [Folder]
    let tags: [Tag]
    let viewModel: FileViewModel
    let density: CollectionDensity
    /// 並排閱讀中：收藏區縮成清單欄。
    let isReadingAlongside: Bool
    var desktopUsesGrid = true
    var showsSearchField = true
    var allowsDelete = true
    let onOpen: (HTMLFile) -> Void
    let onRename: (HTMLFile) -> Void
    let onImport: () -> Void

    @FocusState private var searchFocused: Bool

    private var usesGrid: Bool {
        guard !isReadingAlongside else { return false }
        return density == .desktop ? desktopUsesGrid : state.layout != .list
    }
    private var horizontalPadding: CGFloat { isReadingAlongside ? 12 : (density == .desktop ? 24 : 20) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if files.isEmpty {
                emptyState
            } else {
                GeometryReader { proxy in
                    let divisions = density == .touch ? DivisionRegionAdapter.divisions(in: proxy) : []
                    content(width: proxy.size.width, divisions: divisions)
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.title(folders: folders, tags: tags))
                    .font(isReadingAlongside ? .title3.bold() : (density == .desktop ? .system(size: 26, weight: .bold) : .title.bold()))
                    .lineLimit(1)
                    .foregroundStyle(Color.kbText(scheme))
                Spacer()
                Text("\(files.count) 個收藏").font(.caption).foregroundStyle(.secondary)
            }
            if showsSearchField { searchField }
            if state.searchActive, state.filter != .all {
                Picker("搜尋範圍", selection: $state.scope) {
                    ForEach(SearchScope.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("搜尋範圍")
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, isReadingAlongside ? 14 : 22)
        .padding(.bottom, 14)
    }

    private var searchText: Binding<String> {
        Binding(get: { state.searchActive ? state.query : "" },
                set: { state.query = $0; state.searchActive = !$0.isEmpty })
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.kbSub(scheme))
            TextField("搜尋名稱或內容", text: searchText)
                .focused($searchFocused)
                .submitLabel(.search)
                .accessibilityLabel("搜尋名稱或內容")
            if state.searchActive {
                Button { state.clearSearch() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.kbSub(scheme))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜尋")
            }
        }
        .padding(.leading, 12)
        .frame(minHeight: 44)
        .background(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Content

    @ViewBuilder
    private func content(width: CGFloat, divisions: [DivisionGeometry]) -> some View {
        if usesGrid && density == .desktop {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 370, maximum: 480), spacing: 18)], spacing: 18) {
                    ForEach(files) { file in card(file) }
                }
                .scrollTargetLayout()
                .padding(.horizontal, horizontalPadding).padding(.bottom, 24)
            }
            .scrollPosition(id: anchorBinding(columns: 1), anchor: .top)
        } else if usesGrid {
            let plan = LibraryLayoutPolicy.gridPlan(containerWidth: width, padding: horizontalPadding,
                                                    minCard: LibraryLayoutPolicy.touchCardMinWidth,
                                                    divisions: divisions)
            let columns = max(plan.totalColumns, 1)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: LibraryLayoutPolicy.gridSpacing) {
                    ForEach(rowStarts(columns: columns), id: \.self) { start in
                        gridRow(plan: plan, start: start).id(files[start].id)
                    }
                }
                .scrollTargetLayout()
                .padding(.bottom, 24)
            }
            .scrollPosition(id: anchorBinding(columns: columns), anchor: .top)
            .animation(nil, value: plan)
        } else {
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(files) { file in
                        CollectionRowView(file: file, density: density,
                                          isSelected: state.readerPresented && state.selectedFileID == file.id) {
                            onOpen(file)
                        }
                        .contextMenu { menu(file) }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, isReadingAlongside ? 8 : horizontalPadding - 8).padding(.bottom, 16)
            }
            .scrollPosition(id: anchorBinding(columns: 1), anchor: .top)
        }
    }

    private func card(_ file: HTMLFile) -> some View {
        CollectionCardView(file: file, density: density,
                           isSelected: state.selectedFileID == file.id && !state.readerPresented && density == .touch) {
            onOpen(file)
        }
        .contextMenu { menu(file) }
    }

    @ViewBuilder
    private func menu(_ file: HTMLFile) -> some View {
        CollectionMenu(file: file, folders: folders, tags: tags, viewModel: viewModel,
                       onOpen: { onOpen(file) }, onRename: { onRename(file) }, allowsDelete: allowsDelete)
    }

    private func rowStarts(columns: Int) -> [Int] {
        Array(stride(from: 0, to: files.count, by: columns))
    }

    /// 一列卡片：跨摺痕時分成左右兩組，中間留出摺痕 gutter。
    private func gridRow(plan: LibraryLayoutPolicy.GridPlan, start: Int) -> some View {
        var cursor = start
        var groups: [(side: LibraryLayoutPolicy.GridPlan.Side, items: [HTMLFile?])] = []
        for side in plan.sides {
            var items: [HTMLFile?] = []
            for _ in 0..<side.columns {
                items.append(cursor < files.count ? files[cursor] : nil)
                cursor += 1
            }
            groups.append((side, items))
        }
        return HStack(alignment: .top, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                let previousEnd = index == 0 ? 0 : plan.sides[index - 1].originX + plan.sides[index - 1].width
                Color.clear.frame(width: max(0, group.side.originX - previousEnd), height: 1)
                HStack(alignment: .top, spacing: LibraryLayoutPolicy.gridSpacing) {
                    ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                        if let item {
                            card(item).frame(maxWidth: .infinity)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                        }
                    }
                }
                .frame(width: group.side.width)
            }
            Spacer(minLength: 0)
        }
    }

    /// 錨點存的是收藏 UUID；欄數改變時對應到包含它的那一列。
    private func anchorBinding(columns: Int) -> Binding<UUID?> {
        let key = state.listAnchorKey
        return Binding(
            get: {
                guard let id = state.listAnchors[key], let index = files.firstIndex(where: { $0.id == id }) else { return nil }
                return files[(index / columns) * columns].id
            },
            set: { newValue in
                if let newValue { state.listAnchors[key] = newValue }
            })
    }

    // MARK: Empty

    private var emptyState: some View {
        ContentUnavailableView {
            Label(state.searchActive ? "找不到符合的收藏" : "這裡還沒有收藏",
                  systemImage: state.searchActive ? "magnifyingglass" : "tray")
        } description: {
            Text(state.searchActive
                 ? (state.scope == .current && state.filter != .all ? "試試其他關鍵字，或把範圍切到全部收藏。" : "試試其他關鍵字。")
                 : "新增連結、文字、圖片或 HTML，留待下次閱讀。")
        } actions: {
            if state.searchActive {
                Button("清除搜尋") { state.clearSearch() }.buttonStyle(.bordered)
            } else {
                Button("新增收藏", action: onImport).buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
