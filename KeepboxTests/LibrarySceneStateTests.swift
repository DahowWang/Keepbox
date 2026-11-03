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
}
