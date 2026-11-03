import SwiftUI
import SwiftData

// MARK: - Root view
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allFiles: [HTMLFile]
    @Query private var folders: [Folder]
    @Query private var tags: [Tag]

    /// 每個 scene 的瀏覽狀態快照（版本化 JSON）；不含同步憑證，也不跨裝置同步。
    @SceneStorage("keepbox.libraryState") private var storedState = ""
    @State private var state = LibrarySceneState()
    @State private var session = ReaderSession()
    @State private var viewModel = FileViewModel()
    @State private var restored = false
    @State private var showImport = false
    @State private var actionFile: HTMLFile?
    @State private var toastText: String?
    @State private var showSyncSettings = false

    private let importer = FileImporter()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.kbBg(scheme).ignoresSafeArea()

            #if targetEnvironment(macCatalyst)
            MacLibraryView(
                state: state, viewModel: viewModel, allFiles: allFiles, folders: folders, tags: tags,
                onImport: { showImport = true },
                onSync: { showSyncSettings = true }
            )
            #else
            AdaptiveLibraryView(
                state: state, session: session, viewModel: viewModel,
                allFiles: allFiles, folders: folders, tags: tags,
                onImport: { showImport = true },
                onSync: { showSyncSettings = true },
                onLongPress: { actionFile = $0 }
            )
            #endif
        }
        .overlay {
            if let file = actionFile {
                ActionMenuView(
                    file: file, viewModel: viewModel,
                    folders: folders, tags: tags,
                    onClose: { actionFile = nil },
                    onOpen: { f in actionFile = nil; state.open(f) }
                )
                .ignoresSafeArea()
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: actionFile?.id)
            }
        }
        .overlay(alignment: .bottom) {
            if let toastText {
                toastBadge(toastText)
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: toastText)
        // sheet 掛在穩定的根層：摺疊／展開切換版面時不會被重建，匯入草稿不會遺失。
        .sheet(isPresented: $showImport) {
            ImportSheetView(modelContext: modelContext, onSaved: {
                showImport = false
                flashToast(state.filter == .all ? "已存入 Keepbox" : "已存入全部收藏")
            })
        }
        .sheet(isPresented: $showSyncSettings) {
            SyncSettingsView()
        }
        .onAppear {
            if !restored {
                state.restore(from: storedState)
                restored = true
            }
            session.onAnchor = { [state] fileID, anchor in
                state.setAnchor(anchor, for: fileID)
            }
            importer.importPendingFiles(into: modelContext)
            applyScreenshotStateIfNeeded()
            SyncService.shared.attach(modelContext)
            reconcile()
        }
        .onChange(of: state.snapshot) { _, _ in storedState = state.encodedSnapshot() }
        .onChange(of: allFiles.map(\.id)) { _, _ in reconcile() }
        .onChange(of: folders.map(\.id)) { _, _ in reconcile() }
        .onChange(of: tags.map(\.id)) { _, _ in reconcile() }
        .onChange(of: state.notice) { _, notice in
            guard let notice else { return }
            state.notice = nil
            flashToast(notice)
        }
        // 前景時每分鐘拉一次其他裝置的新資料；本機改動由存檔自動觸發
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await SyncService.shared.syncNow()
                try? await Task.sleep(for: .seconds(60))
            }
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

    /// 被刪除的收藏或分類：關閉閱讀／退回全部收藏，不顯示空白假文章。
    private func reconcile() {
        guard restored else { return }
        state.reconcile(fileIDs: Set(allFiles.map(\.id)),
                        folderIDs: Set(folders.map(\.id)),
                        tagIDs: Set(tags.map(\.id)))
    }

    private func flashToast(_ text: String) {
        toastText = text
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toastText == text { toastText = nil }
        }
    }

    // DEBUG-only: drive initial UI state for App Store screenshots via launch args.
    private func applyScreenshotStateIfNeeded() {
        #if DEBUG
        ScreenshotSeeder.seedIfNeeded(modelContext)
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-screenshotLayout"), i + 1 < args.count {
            switch args[i + 1] {
            case "grid": state.layout = .grid
            case "gallery": state.layout = .gallery
            case "list": state.layout = .list
            default: break
            }
        }
        // Fetch fresh (the @Query result lags a same-tick insert) for the reader.
        let files = (try? modelContext.fetch(
            FetchDescriptor<HTMLFile>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
        let readerPick = (args.firstIndex(of: "-readerPick").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }) ?? "會議"
        if let i = args.firstIndex(of: "-screenshotScreen"), i + 1 < args.count {
            switch args[i + 1] {
            case "reader":
                if let file = files.first(where: { $0.name.contains(readerPick) }) ?? files.first { state.open(file) }
            case "search": state.searchActive = true
            default: break
            }
        }
        #endif
    }

    private func toastBadge(_ text: String) -> some View {
        Label(text, systemImage: "checkmark")
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
