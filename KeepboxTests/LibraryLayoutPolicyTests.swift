import XCTest
@testable import HTMLViewer

/// 斷點依 docs/iphone-duo-design.md §2（Codex 修訂版）：瀏覽 600、並排閱讀 760、三欄 1100。
/// 實測數字來自 iOS 27.2 iPhone Duo 模擬器：外螢幕 W=382、內螢幕橫放 W=867、摺痕 x=455.5 寬 40。
final class LibraryLayoutPolicyTests: XCTestCase {
    private func input(_ w: CGFloat, h: CGFloat = 800, regular: Bool = true, reader: Bool = false,
                       a11y: Bool = false, divisions: [DivisionGeometry] = []) -> LibraryLayoutPolicy.Input {
        .init(width: w, height: h, horizontalRegular: regular, verticalRegular: regular,
              accessibilityText: a11y, readerOpen: reader, divisions: divisions)
    }

    private let duoFold = DivisionGeometry(frame: CGRect(x: 455.5, y: 0, width: 40, height: 669),
                                           leadingMargin: 20, trailingMargin: 20, isActive: false)

    func testCompactAndSmallWidthsStayNarrow() {
        XCTAssertEqual(LibraryLayoutPolicy.decide(input(382, regular: false)).mode, .narrow) // Duo 外螢幕實測
        XCTAssertEqual(LibraryLayoutPolicy.decide(input(599)).mode, .narrow)
        XCTAssertEqual(LibraryLayoutPolicy.decide(input(900, a11y: true)).mode, .narrow)
    }

    func testBrowseBreakpointAt600() {
        let d = LibraryLayoutPolicy.decide(input(600))
        XCTAssertEqual(d.mode, .medium)
        XCTAssertTrue(d.sidebarTiled)
        XCTAssertEqual(d.sidebarWidth, 200)
    }

    func testReadingBelow760IsSinglePageWithListPopover() {
        let d = LibraryLayoutPolicy.decide(input(669, reader: true)) // 內螢幕直放候選
        XCTAssertEqual(d.mode, .medium)
        XCTAssertFalse(d.readerAlongside)
        XCTAssertFalse(d.sidebarTiled)
    }

    func testReadingAlongsideKeepsReaderAt480OrMore() {
        for w in [760, 800, 867, 951, 1099] as [CGFloat] {
            let d = LibraryLayoutPolicy.decide(input(w, reader: true))
            XCTAssertTrue(d.readerAlongside, "W=\(w)")
            XCTAssertGreaterThanOrEqual(d.listWidth, LibraryLayoutPolicy.listMinWidth, "W=\(w)")
            XCTAssertLessThanOrEqual(d.listWidth, LibraryLayoutPolicy.listMaxWidth, "W=\(w)")
            XCTAssertGreaterThanOrEqual(w - d.listWidth - LibraryLayoutPolicy.hairline, 480, "W=\(w)")
        }
    }

    func testLargeThreeColumns() {
        let d = LibraryLayoutPolicy.decide(input(1100, reader: true))
        XCTAssertEqual(d.mode, .large)
        XCTAssertTrue(d.sidebarTiled)
        XCTAssertTrue(d.readerAlongside)
        XCTAssertGreaterThanOrEqual(1100 - d.sidebarWidth - d.listWidth - 2, 480)
    }

    func testDuoFoldNarrowsSidebarBeforeCollapsing() {
        // 實測：220 的分類欄讓左半邊只剩 194.5 → 先縮到 200（左半 214.5）仍並排。
        let d = LibraryLayoutPolicy.decide(input(867, divisions: [duoFold]))
        XCTAssertTrue(d.sidebarTiled)
        XCTAssertEqual(d.sidebarWidth, 200)
    }

    func testFoldTooCloseToSidebarCollapsesIt() {
        let fold = DivisionGeometry(frame: CGRect(x: 400, y: 0, width: 40, height: 669), leadingMargin: 20, trailingMargin: 20)
        let d = LibraryLayoutPolicy.decide(input(867, divisions: [fold]))
        XCTAssertFalse(d.sidebarTiled)
    }

    // MARK: Grid

    func testGridWithoutFold() {
        let plan = LibraryLayoutPolicy.gridPlan(containerWidth: 667, padding: 20, minCard: 200, divisions: [])
        XCTAssertEqual(plan.sides.count, 1)
        XCTAssertEqual(plan.totalColumns, 2) // (627+16)/(216) = 2.97 → 2
    }

    func testGridSplitsEvenlyAcrossFoldAndNeverOverlapsIt() {
        // 分類 200 並排時，收藏區座標系內摺痕在 455.5−201 = 254.5。
        let fold = DivisionGeometry(frame: CGRect(x: 254.5, y: 0, width: 40, height: 669), leadingMargin: 20, trailingMargin: 20, isActive: false)
        let plan = LibraryLayoutPolicy.gridPlan(containerWidth: 666, padding: 20, minCard: 200, divisions: [fold])
        XCTAssertEqual(plan.sides.count, 2)
        XCTAssertEqual(plan.sides[0].columns, plan.sides[1].columns)
        XCTAssertLessThanOrEqual(plan.sides[0].originX + plan.sides[0].width, fold.frame.minX)
        XCTAssertGreaterThanOrEqual(plan.sides[1].originX, fold.frame.maxX)
        XCTAssertGreaterThanOrEqual(plan.sides[1].originX - (plan.sides[0].originX + plan.sides[0].width), 16)
    }

    func testZeroWidthInactiveFoldStillSplits() {
        let fold = DivisionGeometry(frame: CGRect(x: 400, y: 0, width: 0, height: 900), isActive: false)
        let plan = LibraryLayoutPolicy.gridPlan(containerWidth: 800, padding: 20, minCard: 200, divisions: [fold])
        XCTAssertEqual(plan.sides.count, 2)
        XCTAssertGreaterThanOrEqual(plan.sides[1].originX - (plan.sides[0].originX + plan.sides[0].width), 16)
    }

    func testNarrowSideFallsBackToSingleColumnOnWiderSide() {
        let fold = DivisionGeometry(frame: CGRect(x: 150, y: 0, width: 40, height: 669), leadingMargin: 20, trailingMargin: 20)
        let plan = LibraryLayoutPolicy.gridPlan(containerWidth: 700, padding: 20, minCard: 200, divisions: [fold])
        XCTAssertEqual(plan.sides.count, 1)
        XCTAssertEqual(plan.sides[0].columns, 1)
        XCTAssertGreaterThanOrEqual(plan.sides[0].originX, fold.frame.maxX)
    }

    func testFoldOutsideContentKeepsNormalGrid() {
        let fold = DivisionGeometry(frame: CGRect(x: -100, y: 0, width: 40, height: 669))
        let plan = LibraryLayoutPolicy.gridPlan(containerWidth: 667, padding: 20, minCard: 200, divisions: [fold])
        XCTAssertEqual(plan.sides.count, 1)
    }

    func testHorizontalFoldDoesNotSplitColumns() {
        let fold = DivisionGeometry(frame: CGRect(x: 0, y: 455, width: 669, height: 40))
        let plan = LibraryLayoutPolicy.gridPlan(containerWidth: 669, padding: 20, minCard: 200, divisions: [fold])
        XCTAssertEqual(plan.sides.count, 1)
    }
}
