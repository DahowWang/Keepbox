import SwiftUI
import SwiftData

// MARK: - App-level enums
enum KBTab { case all, folders, tags }
enum KBLayout { case grid, gallery, list }

// MARK: - Root view
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allFiles: [HTMLFile]
    @Query private var folders: [Folder]
    @Query private var tags: [Tag]

    @State private var viewModel = FileViewModel()
    @State private var tab: KBTab = .all
    @State private var layout: KBLayout = .list
    @State private var openFile: HTMLFile?
    @State private var showImport = false
    @State private var actionFile: HTMLFile?
    @State private var showToast = false
    @State private var isSearching = false

    private let importer = FileImporter()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.kbBg(scheme).ignoresSafeArea()

            if isSearching {
                SearchView(
                    allFiles: allFiles, viewModel: viewModel,
                    onBack: { withAnimation { isSearching = false } },
                    onOpen: { f in withAnimation { isSearching = false }; openFile = f }
                )
                .transition(.opacity)
            } else if let file = openFile {
                ReaderView(file: file, onBack: { openFile = nil })
                    .transition(.opacity)
            } else {
                ZStack(alignment: .bottom) {
                    tabContent
                    bottomBar
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearching)
        .animation(.easeInOut(duration: 0.2), value: openFile?.id)
        .overlay {
            if let file = actionFile {
                ActionMenuView(
                    file: file, viewModel: viewModel,
                    folders: folders, tags: tags,
                    onClose: { actionFile = nil },
                    onOpen: { f in actionFile = nil; openFile = f }
                )
                .ignoresSafeArea()
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: actionFile?.id)
            }
        }
        .overlay(alignment: .bottom) {
            if showToast {
                toastBadge
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: showToast)
            }
        }
        .sheet(isPresented: $showImport) {
            ImportSheetView(modelContext: modelContext, onSaved: {
                showImport = false
                withAnimation { showToast = true }
                Task {
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    withAnimation { showToast = false }
                }
            })
        }
        .onAppear {
            importer.importPendingFiles(into: modelContext)
            applyScreenshotStateIfNeeded()
        }
        // Re-import whenever the app returns to the foreground — a share saved
        // while Keepbox was backgrounded would otherwise wait for a cold launch.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { importer.importPendingFiles(into: modelContext) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .importPending)) { _ in
            importer.importPendingFiles(into: modelContext)
        }
    }

    // DEBUG-only: drive initial UI state for App Store screenshots via launch args.
    private func applyScreenshotStateIfNeeded() {
        #if DEBUG
        ScreenshotSeeder.seedIfNeeded(modelContext)
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-screenshotLayout"), i + 1 < args.count {
            switch args[i + 1] {
            case "grid": layout = .grid
            case "gallery": layout = .gallery
            case "list": layout = .list
            default: break
            }
        }
        // Fetch fresh (the @Query result lags a same-tick insert) for the reader.
        let files = (try? modelContext.fetch(
            FetchDescriptor<HTMLFile>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
        if let i = args.firstIndex(of: "-screenshotScreen"), i + 1 < args.count {
            switch args[i + 1] {
            case "reader": openFile = files.first { $0.name.contains("邀請") } ?? files.first
            case "search": isSearching = true
            default: break
            }
        }
        #endif
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .all:
            HomeView(
                viewModel: viewModel, allFiles: allFiles, tags: tags,
                layout: layout, setLayout: { layout = $0 },
                onOpen: { openFile = $0 }, onLong: { actionFile = $0 },
                onSearch: { withAnimation { isSearching = true } }
            )
        case .folders:
            FolderGridView(
                folders: folders.filter { $0.parent == nil }, allFiles: allFiles,
                onOpen: { folder in
                    viewModel.selectedFolder = folder
                    viewModel.selectedTag = nil
                    withAnimation { tab = .all }
                }
            )
        case .tags:
            TagListView(
                tags: tags, allFiles: allFiles,
                onPick: { tag in
                    viewModel.selectedTag = tag
                    viewModel.selectedFolder = nil
                    withAnimation { tab = .all }
                }
            )
        }
    }

    // MARK: - Bottom bar
    private var bottomBar: some View {
        ZStack(alignment: .bottomTrailing) {
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
            .padding(.bottom, 24)

            Button { showImport = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.kbAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                    .shadow(color: Color.kbAccent.opacity(0.45), radius: 14, x: 0, y: 8)
            }
            .padding(.trailing, 22)
            .padding(.bottom, 100)
        }
    }

    @ViewBuilder
    private func tabButton(_ t: KBTab, _ label: String, _ icon: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { tab = t } } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(tab == t ? Color.kbAccent : Color.secondary)
            .frame(maxWidth: .infinity)
        }
    }

    private var toastBadge: some View {
        Label("已存入 Keepbox", systemImage: "checkmark")
            .font(.system(size: 14.5, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 11).padding(.horizontal, 20)
            .background(Color(hex: "#1fae5a"))
            .clipShape(Capsule())
            .shadow(color: Color(hex: "#1fae5a").opacity(0.4), radius: 16)
    }
}

// MARK: - Design tokens
extension Color {
    static let kbAccent = Color(hex: "#5B53E0")

    static func kbBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#0c0c0f") : Color(hex: "#F4F3FB")
    }
    static func kbSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#161619") : .white
    }
    static func kbText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#f3f3f6") : Color(hex: "#1d1b3a")
    }
    static func kbSub(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.45) : Color(hex: "#9a96b5")
    }
    static func kbCardShadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.07)
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
