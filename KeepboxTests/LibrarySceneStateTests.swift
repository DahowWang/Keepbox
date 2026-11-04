import XCTest
import SwiftData
@testable import HTMLViewer

final class LibrarySceneStateTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(for: HTMLFile.self, Folder.self, Tag.self, SyncTombstone.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
    }

    private func makeLibrary() -> (files: [HTMLFile], work: Folder) {
        let work = Folder(name: "工作")
        context.insert(work)
        let a = HTMLFile(name: "會議記錄", content: "<p>keepbox roadmap</p>")
        let b = HTMLFile(name: "京都行程", content: "<p>keepbox travel</p>")
        a.folder = work
        [a, b].forEach(context.insert)
        try? context.save()
        return ([a, b], work)
    }

    func testSearchScopeAllVsCurrent() {
        let (files, work) = makeLibrary()
        let state = LibrarySceneState()
        state.select(.folder(work.id))
        XCTAssertEqual(state.results(from: files).map(\.name), ["會議記錄"])

        state.query = "keepbox"
        state.searchActive = true
        state.scope = .all
        XCTAssertEqual(Set(state.results(from: files).map(\.name)), ["會議記錄", "京都行程"]) // 預設全部收藏
        state.scope = .current
        XCTAssertEqual(state.results(from: files).map(\.name), ["會議記錄"])
    }

    func testDraftQueryIgnoredUntilSearchActive() {
        let (files, _) = makeLibrary()
        let state = LibrarySceneState()
        state.query = "京都"
        XCTAssertEqual(state.results(from: files).count, 2) // 取消搜尋保留草稿但不套用
        state.searchActive = true
        XCTAssertEqual(state.results(from: files).map(\.name), ["京都行程"])
    }

    func testCloseReaderReturnsToOrigin() {
        let (files, work) = makeLibrary()
        let state = LibrarySceneState()
        state.tab = .all
        state.select(.folder(work.id))
        state.query = "keepbox"; state.searchActive = true
        state.open(files[0])
        state.select(.all)        // 閱讀中換了分類
        state.searchActive = false
        state.closeReader()
        XCTAssertEqual(state.filter, .folder(work.id))
        XCTAssertTrue(state.searchActive)
        XCTAssertEqual(state.selectedFileID, files[0].id) // highlight 保留
        XCTAssertFalse(state.readerPresented)
    }

    func testReconcileClosesDeletedReaderAndInvalidFilter() {
        let (files, work) = makeLibrary()
        let state = LibrarySceneState()
        state.select(.folder(work.id))
        state.open(files[0])
        state.reconcile(fileIDs: [files[1].id], folderIDs: [], tagIDs: [])
        XCTAssertFalse(state.readerPresented)
        XCTAssertNil(state.selectedFileID)
        XCTAssertEqual(state.notice, "這則收藏已刪除")
        XCTAssertEqual(state.filter, .all)
    }

    func testSnapshotRoundTrip() {
        let state = LibrarySceneState()
        let id = UUID()
        state.tab = .tags; state.filter = .tag(id); state.query = "x"; state.searchActive = true
        state.scope = .current; state.layout = .grid; state.selectedFileID = id; state.readerPresented = true
        state.setAnchor(ReaderAnchor(path: [3, 1], fraction: 0.4, ratio: 0.5), for: id)
        let restored = LibrarySceneState()
        restored.restore(from: state.encodedSnapshot())
        XCTAssertEqual(restored.snapshot, state.snapshot)
        restored.restore(from: "not json")  // 壞資料不影響現況
        XCTAssertEqual(restored.snapshot, state.snapshot)
    }

    // MARK: 審查修正（R1／R4／R5）

    func testSelectingCategoryWhileReadingKeepsArticleAndNewFilter() {
        let (files, work) = makeLibrary()
        let state = LibrarySceneState()
        state.select(.folder(work.id))
        state.open(files[0])
        state.selectWhileReading(.all)
        XCTAssertTrue(state.readerPresented)          // 文章保留
        state.closeReader()
        XCTAssertEqual(state.filter, .all)            // 不被還原成舊分類
    }

    func testCloseReaderRestoresQueryAndScopeAndAnchorsOpenedFile() {
        let (files, work) = makeLibrary()
        let state = LibrarySceneState()
        state.select(.folder(work.id))
        state.query = "會議"; state.searchActive = true; state.scope = .current
        state.open(files[0])
        state.query = "京都"; state.scope = .all   // 閱讀中改了搜尋
        state.clearSearch()
        state.closeReader(anchoringWithin: files)
        XCTAssertEqual(state.query, "會議")
        XCTAssertEqual(state.scope, .current)
        XCTAssertTrue(state.searchActive)
        XCTAssertEqual(state.listAnchors[state.listAnchorKey], files[0].id) // 定位到剛才讀的那則
    }

    func testPerFileAnchorsSurviveSwitchingArticles() {
        let (files, _) = makeLibrary()
        let state = LibrarySceneState()
        let a = ReaderAnchor(path: [10], fraction: 0.3, ratio: 0.5)
        state.open(files[0]); state.setAnchor(a, for: files[0].id)
        state.open(files[1]); state.setAnchor(ReaderAnchor(path: [2], fraction: 0, ratio: 0.1), for: files[1].id)
        state.open(files[0])
        XCTAssertEqual(state.anchor(for: files[0].id), a)   // A → B → A 續讀
    }

    func testAnchorLRUIsBounded() {
        let state = LibrarySceneState()
        for _ in 0..<(LibrarySceneState.readerAnchorLimit + 5) {
            state.setAnchor(ReaderAnchor(path: [], fraction: 0, ratio: 0), for: UUID())
        }
        XCTAssertEqual(state.readerAnchors.count, LibrarySceneState.readerAnchorLimit)
    }

    func testDeletingOpenArticleReturnsToOriginWithoutAnchoringDeletedID() {
        let (files, work) = makeLibrary()
        let state = LibrarySceneState()
        state.select(.folder(work.id))
        state.open(files[0])
        state.selectWhileReading(.all)
        state.setAnchor(ReaderAnchor(path: [], fraction: 0, ratio: 0), for: files[0].id)
        state.reconcile(fileIDs: [files[1].id], folderIDs: [work.id], tagIDs: [])
        XCTAssertFalse(state.readerPresented)
        XCTAssertEqual(state.filter, .all)
        XCTAssertNil(state.anchor(for: files[0].id))
        XCTAssertFalse(state.listAnchors.values.contains(files[0].id))
    }

    // MARK: 複查 F3：返回錨點只用「還原後結果內」的收藏

    func testCloseAfterOpeningOtherResultKeepsOriginalAnchor() {
        let (files, work) = makeLibrary()
        let state = LibrarySceneState()
        state.select(.folder(work.id))
        state.query = "keepbox"; state.searchActive = true; state.scope = .current
        let key = state.listAnchorKey
        state.listAnchors[key] = files[0].id
        state.open(files[0])
        state.selectWhileReading(.all); state.query = "京都"; state.scope = .all
        state.open(files[1])                      // B 不在返回的「工作／keepbox／目前分類」結果
        state.selectWhileReading(.folder(work.id))
        state.closeReader(anchoringWithin: files)
        XCTAssertEqual(state.listAnchorKey, key)
        XCTAssertEqual(state.listAnchors[key], files[0].id, "不在結果內的 B 不能覆寫原錨點")
    }

    func testCloseAfterSwitchingFolderDoesNotAnchorForeignFile() {
        let (files, work) = makeLibrary()
        let other = Folder(name: "旅行"); context.insert(other)
        let state = LibrarySceneState()
        state.select(.folder(work.id))
        state.open(files[0])                      // A 屬於「工作」
        state.selectWhileReading(.folder(other.id))
        state.closeReader(anchoringWithin: files)
        XCTAssertEqual(state.filter, .folder(other.id))
        XCTAssertNil(state.listAnchors[state.listAnchorKey], "A 不在「旅行」結果中，不寫成它的錨點")
    }

    // MARK: Duo 展開→折疊：過渡寬度期間的列表回報不可覆寫錨點

    @MainActor
    func testListReportsIgnoredWhileWidthIsChanging() async throws {
        let state = LibrarySceneState()
        let a = UUID(), b = UUID()
        let key = state.listAnchorKey
        XCTAssertTrue(state.reportListTop(a, key: key))
        XCTAssertEqual(state.listAnchors[key], a)

        state.containerWidthDidChange()           // 867 → 466 → 382 的過渡
        XCTAssertTrue(state.listAnchorsFrozen)
        XCTAssertFalse(state.reportListTop(b, key: key), "過渡排版的頂端不可寫回")
        XCTAssertEqual(state.listAnchors[key], a)

        let generation = state.listSettleGeneration
        try await Task.sleep(for: .milliseconds(1100))
        XCTAssertFalse(state.listAnchorsFrozen)
        XCTAssertEqual(state.listSettleGeneration, generation + 1, "穩定後通知列表捲回記錄位置")
        XCTAssertTrue(state.reportListTop(b, key: key))
        XCTAssertEqual(state.listAnchors[key], b)
    }

    @MainActor
    func testRepeatedWidthChangesSettleOnceAfterTheLast() async throws {
        let state = LibrarySceneState()
        let generation = state.listSettleGeneration
        state.containerWidthDidChange()
        try await Task.sleep(for: .milliseconds(500))
        state.containerWidthDidChange()           // 第二個過渡寬度：重新計時
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertTrue(state.listAnchorsFrozen, "距離最後一次變動未滿 900ms")
        XCTAssertEqual(state.listSettleGeneration, generation)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertFalse(state.listAnchorsFrozen)
        XCTAssertEqual(state.listSettleGeneration, generation + 1)
    }

    @MainActor
    func testUserScrollDuringFreezeWinsAndCancelsRestore() async throws {
        let state = LibrarySceneState()
        let a = UUID(), b = UUID()
        let key = state.listAnchorKey
        state.reportListTop(a, key: key)
        state.containerWidthDidChange()
        let generation = state.listSettleGeneration
        state.listUserDidInteract()               // 開合後立刻自己滑動
        XCTAssertFalse(state.listAnchorsFrozen)
        XCTAssertTrue(state.reportListTop(b, key: key), "使用者的新位置要採用")
        try await Task.sleep(for: .milliseconds(1100))
        XCTAssertEqual(state.listSettleGeneration, generation, "已取消復原，不可再拉回 A")
        XCTAssertEqual(state.listAnchors[key], b)
    }

    @MainActor
    func testWidthChangeDuringOngoingDragDoesNotRefreezeOrRestore() async throws {
        let state = LibrarySceneState()
        let a = UUID(), c = UUID(), dragOwner = UUID()
        let key = state.listAnchorKey
        state.reportListTop(a, key: key)
        let generation = state.listSettleGeneration
        state.setListUserScrolling(true, owner: dragOwner)          // 開始拖動
        state.containerWidthDidChange()           // 拖動途中再次改寬
        XCTAssertFalse(state.listAnchorsFrozen)
        XCTAssertTrue(state.reportListTop(c, key: key))
        state.setListUserScrolling(false, owner: dragOwner)
        try await Task.sleep(for: .milliseconds(1100))
        XCTAssertEqual(state.listSettleGeneration, generation, "使用者拖動中的寬度變化不可排程復原")
        XCTAssertEqual(state.listAnchors[key], c)
    }

    @MainActor
    func testScrollStartedWhileWaitingSkipsRestore() async throws {
        let state = LibrarySceneState()
        let generation = state.listSettleGeneration
        state.containerWidthDidChange()
        let owner = UUID()
        try await Task.sleep(for: .milliseconds(300))
        state.setListUserScrolling(true, owner: owner)
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(state.listSettleGeneration, generation)
        state.setListUserScrolling(false, owner: owner)
    }

    func testOneListLeavingDoesNotClearAnotherListsScrolling() {
        let state = LibrarySceneState()
        let oldList = UUID(), newList = UUID()
        state.setListUserScrolling(true, owner: oldList)
        state.setListUserScrolling(true, owner: newList)
        state.setListUserScrolling(false, owner: oldList)   // 舊列表離開
        XCTAssertTrue(state.listUserScrolling, "新列表仍在捲動")
        state.containerWidthDidChange()
        XCTAssertFalse(state.listAnchorsFrozen)
        state.setListUserScrolling(false, owner: newList)
        XCTAssertFalse(state.listUserScrolling)
    }
}
