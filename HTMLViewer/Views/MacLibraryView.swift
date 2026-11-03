#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData
import WebKit
import UniformTypeIdentifiers

/// Desktop library: persistent navigation, a collection browser, and an inline reader.
struct MacLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @Bindable var state: LibrarySceneState
    let viewModel: FileViewModel
    let allFiles: [HTMLFile]
    let folders: [Folder]
    let tags: [Tag]
    let onImport: () -> Void
    let onSync: () -> Void

    @AppStorage("macLibraryUsesGrid") private var usesGrid = true
    @State private var renameFile: HTMLFile?
    @State private var nameDraft = ""
    @State private var showRename = false
    @State private var newCollection: String?
    @State private var showNewCollection = false
    @FocusState private var searchFocused: Bool

    private var files: [HTMLFile] { state.results(from: allFiles) }
    private var openFile: HTMLFile? {
        guard state.readerPresented, let id = state.selectedFileID else { return nil }
        return allFiles.first { $0.id == id }
    }
    private var sortedFolders: [Folder] { folders.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
    private var sortedTags: [Tag] { tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }

    var body: some View {
        GeometryReader { proxy in
            // 閱讀時文章至少 480：視窗不夠寬（例如最小 900）就先收起分類欄。
            let showsSidebar = openFile == nil || proxy.size.width - 210 - 1 - 280 - 1 >= 480
            library(showsSidebar: showsSidebar)
        }
    }

    private func library(showsSidebar: Bool) -> some View {
        HStack(spacing: 0) {
            if showsSidebar {
                sidebar.frame(width: 210)
                Divider()
            }
            VStack(spacing: 0) {
                toolbar
                Divider()
                HStack(spacing: 0) {
                    CollectionBrowserView(state: state, files: files, folders: folders, tags: tags,
                                          viewModel: viewModel, density: .desktop,
                                          isReadingAlongside: openFile != nil,
                                          desktopUsesGrid: usesGrid, showsSearchField: false, allowsDelete: false,
                                          onOpen: { state.open($0) },
                                          onRename: { file in renameFile = file; nameDraft = file.name; showRename = true },
                                          onImport: onImport)
                        .frame(width: openFile == nil ? nil : 280)
                        .frame(maxWidth: openFile == nil ? .infinity : nil, maxHeight: .infinity)
                    if let file = openFile {
                        Divider()
                        VStack(spacing: 0) {
                            if !files.contains(where: { $0.id == file.id }) {
                                // 搜尋／分類改變後文章不在結果內：保留閱讀，不暗中關閉。
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle").foregroundStyle(.secondary)
                                    Text("此收藏不在目前結果").font(.system(size: 12))
                                    Spacer()
                                    Button("關閉閱讀") { state.closeReader(anchoringWithin: allFiles) }.font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 16).frame(height: 34)
                                .background(Color.secondary.opacity(0.08))
                            }
                            MacReaderView(file: file, onClose: { state.closeReader(anchoringWithin: allFiles) })
                                .id(file.id)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .background(Color.kbBg(scheme))
        .tint(Color.kbAccent)
        .buttonStyle(.plain)
        .alert("重新命名收藏", isPresented: $showRename) {
            TextField("名稱", text: $nameDraft)
            Button("取消", role: .cancel) { renameFile = nil }
            Button("儲存") {
                if let file = renameFile, !trimmedName.isEmpty {
                    viewModel.rename(file, to: trimmedName, context: modelContext)
                }
                renameFile = nil
            }
            .disabled(trimmedName.isEmpty)
        }
        .alert("新增\(newCollection ?? "資料夾")", isPresented: $showNewCollection) {
            TextField("名稱", text: $nameDraft)
            Button("取消", role: .cancel) { }
            Button("新增") { createCollection() }.disabled(trimmedName.isEmpty)
        }
        .background {
            Button("搜尋收藏") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command).hidden()
        }
        .onAppear {
            for scene in UIApplication.shared.connectedScenes {
                (scene as? UIWindowScene)?.sizeRestrictions?.minimumSize = CGSize(width: 900, height: 560)
            }
        }
    }

    private var trimmedName: String { nameDraft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 35, height: 35)
                    .background(Color.kbAccent, in: RoundedRectangle(cornerRadius: 10))
                Text("Keepbox").font(.system(size: 21, weight: .bold))
            }
            .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 28)
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    sidebarRow("全部收藏", icon: "square.stack", count: allFiles.count,
                               selected: state.filter == .all) {
                        select(.all)
                    }
                    sidebarHeading("資料夾") { beginCollection("資料夾") }
                    if sortedFolders.isEmpty { sidebarHint("新增資料夾，整理收藏") }
                    ForEach(sortedFolders) { folder in
                        sidebarRow(folder.name, icon: "folder", count: folder.files.count,
                                   selected: state.filter == .folder(folder.id)) {
                            select(.folder(folder.id))
                        }
                    }
                    sidebarHeading("標籤") { beginCollection("標籤") }
                    if sortedTags.isEmpty { sidebarHint("用標籤串起不同主題") }
                    ForEach(sortedTags) { tag in
                        sidebarRow(tag.name, icon: "number", count: tag.files.count,
                                   selected: state.filter == .tag(tag.id), color: Color(hex: tag.colorHex)) {
                            select(.tag(tag.id))
                        }
                    }
                }.padding(.horizontal, 12)
            }
            Spacer(minLength: 0)
            Divider().padding(.horizontal, 18)
            Button(action: onSync) {
                HStack(spacing: 9) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("同步設定")
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .padding(20)
            }.help("查看同步狀態與設定")
        }
        .background(Color.kbSurface(scheme).opacity(scheme == .dark ? 0.6 : 0.75))
    }

    private func sidebarRow(_ name: String, icon: String, count: Int, selected: Bool,
                            color: Color = .kbAccent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color).frame(width: 18)
                Text(name).font(.system(size: 14, weight: selected ? .semibold : .regular)).lineLimit(1)
                Spacer(minLength: 4)
                Text("\(count)").font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).frame(height: 37)
            .foregroundStyle(selected ? Color.kbAccent : Color.kbText(scheme))
            .background(selected ? Color.kbAccent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func sidebarHeading(_ name: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(name).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            Button(action: action) { Image(systemName: "plus").font(.system(size: 11, weight: .medium)) }
                .help("新增\(name)").accessibilityLabel("新增\(name)")
        }.padding(.horizontal, 10).padding(.top, 24).padding(.bottom, 6)
    }

    private func sidebarHint(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.tertiary).padding(.horizontal, 10).padding(.vertical, 6)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜尋名稱或內容", text: searchText)
                    .textFieldStyle(.plain).focused($searchFocused)
                    .accessibilityLabel("搜尋名稱或內容")
                if state.searchActive {
                    Button { state.clearSearch() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .help("清除搜尋").accessibilityLabel("清除搜尋")
                }
            }
            .font(.system(size: 13)).padding(.horizontal, 10).frame(maxWidth: 310).frame(height: 33)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            if state.searchActive, state.filter != .all {
                Picker("搜尋範圍", selection: $state.scope) {
                    ForEach(SearchScope.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 170)
                .help("搜尋範圍").accessibilityLabel("搜尋範圍")
            }
            Spacer(minLength: 0)
            Menu {
                Picker("排序", selection: $state.sort) {
                    ForEach(LibrarySort.allCases) { order in Text(order.rawValue).tag(order) }
                }
            } label: { Image(systemName: "arrow.up.arrow.down").frame(width: 30, height: 32) }
                .help("排序：\(state.sort.rawValue)").accessibilityLabel("排序")
            if openFile == nil {
                HStack(spacing: 2) {
                    layoutButton(grid: true, icon: "square.grid.2x2")
                    layoutButton(grid: false, icon: "list.bullet")
                }.padding(3).background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            }
            SyncStatusButton(action: onSync).help("同步狀態與設定")
            Button(action: onImport) {
                Label("新增收藏", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(height: 33)
                    .background(Color.kbAccent, in: RoundedRectangle(cornerRadius: 8))
            }.keyboardShortcut("n", modifiers: .command)
        }.padding(.horizontal, 22).frame(height: 66)
        .background(Color.kbSurface(scheme))
    }

    private func layoutButton(grid: Bool, icon: String) -> some View {
        Button { usesGrid = grid } label: {
            Image(systemName: icon).font(.system(size: 13)).frame(width: 29, height: 26)
                .foregroundStyle(usesGrid == grid ? Color.kbAccent : .secondary)
                .background(usesGrid == grid ? Color.kbSurface(scheme) : .clear, in: RoundedRectangle(cornerRadius: 5))
        }.help(grid ? "網格顯示" : "清單顯示").accessibilityLabel(grid ? "網格顯示" : "清單顯示")
    }

    private var searchText: Binding<String> {
        Binding(get: { state.searchActive ? state.query : "" },
                set: { state.query = $0; state.searchActive = !$0.isEmpty })
    }

    private func select(_ filter: LibraryFilter) {
        // 閱讀中換分類：保留文章（不在結果時顯示提示），返回目的地改成新分類。
        state.selectWhileReading(filter)
    }

    private func beginCollection(_ kind: String) {
        newCollection = kind; nameDraft = ""; showNewCollection = true
    }

    private func createCollection() {
        guard !trimmedName.isEmpty else { return }
        if newCollection == "標籤" {
            modelContext.insert(Tag(name: trimmedName, colorHex: Tag.defaultColors[tags.count % Tag.defaultColors.count]))
        } else { modelContext.insert(Folder(name: trimmedName)) }
        try? modelContext.save()
    }
}

private struct MacReaderView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    let file: HTMLFile
    let onClose: () -> Void
    @State private var zoom: Double = 1
    @State private var showExporter = false
    @State private var exportError: String?
    @State private var source: CollectionSource?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onClose) { Image(systemName: "sidebar.right").frame(width: 28, height: 30) }
                    .help("關閉閱讀，返回收藏").accessibilityLabel("關閉閱讀，返回收藏")
                    .keyboardShortcut(.escape, modifiers: [])
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Text(file.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Menu {
                    Picker("閱讀大小", selection: $zoom) {
                        Text("85%").tag(0.85)
                        Text("100%").tag(1.0)
                        Text("115%").tag(1.15)
                        Text("130%").tag(1.3)
                        Text("150%").tag(1.5)
                    }
                } label: { Image(systemName: "textformat.size").frame(width: 28, height: 30) }
                    .help("閱讀大小：\(Int(zoom * 100))%").accessibilityLabel("閱讀大小")
                Menu {
                    ShareLink(item: file.content) { Label("分享 HTML 內容", systemImage: "square.and.arrow.up") }
                    Button("匯出 HTML 檔案", systemImage: "arrow.down.doc") { showExporter = true }
                } label: { Image(systemName: "square.and.arrow.up").frame(width: 28, height: 30) }
                    .help("分享與匯出").accessibilityLabel("分享與匯出")
                if let url = source?.originalURL {
                    Button { openURL(url) } label: { Image(systemName: "arrow.up.right.square").frame(width: 28, height: 30) }
                        .help("在瀏覽器開啟原文").accessibilityLabel("在瀏覽器開啟原文")
                }
            }.padding(.horizontal, 16).frame(height: 69)
            .background(Color.kbSurface(scheme))
            Divider()
            MacReaderWebView(html: file.content, zoom: zoom)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { updateSource() }
        .onChange(of: file.content) { _, _ in updateSource() }
        .onChange(of: file.sourceApp) { _, _ in updateSource() }
        .fileExporter(isPresented: $showExporter, document: MacHTMLDocument(content: file.content), contentType: .html, defaultFilename: file.name) { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
        }
        .alert("無法匯出", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("好", role: .cancel) { exportError = nil }
        } message: { Text(exportError ?? "") }
    }

    private func updateSource() {
        source = CollectionSource.resolve(html: file.content, sourceApp: file.sourceApp)
    }
}

/// Desktop page zoom updates without reloading HTML or losing the reading position.
private struct MacReaderWebView: UIViewRepresentable {
    let html: String
    let zoom: Double
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = context.coordinator
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        if context.coordinator.loaded != html {
            context.coordinator.loaded = html
            view.loadHTMLString(html, baseURL: nil)
        }
        view.pageZoom = zoom
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded: String?
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
    }
}

private struct MacHTMLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.html] }
    var content: String
    init(content: String) { self.content = content }
    init(configuration: ReadConfiguration) throws {
        content = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(content.utf8))
    }
}
#endif
