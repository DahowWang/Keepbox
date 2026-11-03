import XCTest
@testable import HTMLViewer

/// 複查 G1：原生 resize 的兩個檢查點共用同一個不可逆閘門。
final class ResizeInteractionGateTests: XCTestCase {
    func testNoInteractionAllowsBothStages() {
        var gate = ResizeInteractionGate(generationAtStart: 3, busyAtStart: false)
        XCTAssertTrue(gate.checkpoint(generation: 3, busy: false)) // JS 位置復原
        XCTAssertTrue(gate.checkpoint(generation: 3, busy: false)) // 原生縮放復原
    }

    func testGestureStartedBeforeResizeAndEndedBeforeSecondStageStillBlocksZoom() {
        // pinch 在 resize 前開始（.began 已遞增）→ 第一個檢查點仍在操作 → 第二個檢查點前放手。
        var gate = ResizeInteractionGate(generationAtStart: 4, busyAtStart: true)
        XCTAssertFalse(gate.checkpoint(generation: 4, busy: true))
        XCTAssertFalse(gate.checkpoint(generation: 4, busy: false), "放手後也不能再套用舊縮放")
    }

    func testGestureStartedBeforeResizeButEndedBeforeFirstAwait() {
        var gate = ResizeInteractionGate(generationAtStart: 4, busyAtStart: true)
        XCTAssertFalse(gate.checkpoint(generation: 4, busy: false))
        XCTAssertFalse(gate.checkpoint(generation: 4, busy: false))
    }

    func testBusyAtFirstCheckpointBlocksSecond() {
        var gate = ResizeInteractionGate(generationAtStart: 1, busyAtStart: false)
        XCTAssertFalse(gate.checkpoint(generation: 1, busy: true))
        XCTAssertFalse(gate.checkpoint(generation: 1, busy: false))
    }

    func testNewGestureBetweenCheckpointsBlocksSecond() {
        var gate = ResizeInteractionGate(generationAtStart: 1, busyAtStart: false)
        XCTAssertTrue(gate.checkpoint(generation: 1, busy: false))
        XCTAssertFalse(gate.checkpoint(generation: 2, busy: false))
    }
}
