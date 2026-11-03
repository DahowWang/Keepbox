import XCTest
import JavaScriptCore
@testable import HTMLViewer

/// 以 JavaScriptCore 執行 App 實際注入的 readerScript（mock DOM／計時器／時鐘），
/// 驗證審查 F1／F2：新 resize 會作廢舊修正；使用者互動後不自動捲回；沒有互動時照常還原。
@MainActor
final class ReaderScriptTests: XCTestCase {
    private var ctx: JSContext!

    override func setUp() async throws {
        ctx = JSContext()
        ctx.exceptionHandler = { _, e in XCTFail("JS exception: \(e?.toString() ?? "?")") }
        ctx.evaluateScript(#"""
        var __now = 1000000, __timers = [], __restores = 0, __listeners = {};
        Date.now = function(){ return __now; };
        function setTimeout(fn, ms){ __timers.push({at: __now + ms, fn: fn}); return __timers.length; }
        function clearTimeout(id){ if (id && __timers[id-1]) __timers[id-1].fn = null; }
        function advance(ms){ var end = __now + ms;
          while (true) { var next = null;
            __timers.forEach(function(t){ if (t.fn && t.at <= end && (!next || t.at < next.at)) next = t; });
            if (!next) break; __now = next.at; var f = next.fn; next.fn = null; f(); }
          __now = end; }
        var p = {getBoundingClientRect: function(){ return {top: -10, height: 100}; }};
        var body = {children: [p]}; p.parentElement = body;
        var meta = {attrs: {}, getAttribute: function(k){ return this.attrs[k] || null; }, setAttribute: function(k,v){ this.attrs[k]=v; }};
        var document = {
          body: body, head: {appendChild: function(){}},
          documentElement: {scrollHeight: 10000, appendChild: function(){}},
          querySelector: function(){ return meta; },
          getElementById: function(){ return null; },
          createElement: function(){ return {}; },
          elementFromPoint: function(){ return p; }
        };
        // 瀏覽器裡 window 就是全域物件（readerScript 以 window.__kb 建立、以 __kb 呼叫）。
        var window = this;
        window.scrollY = 500; window.innerWidth = 600; window.innerHeight = 800;
        window.scrollTo = function(x, y){ __restores++; window.scrollY = y; };
        window.addEventListener = function(type, fn){ __listeners[type] = fn; };
        window.webkit = {messageHandlers: {}};
        function touch(type, n){ __listeners[type]({touches: {length: n}}); }
        """#)
        ctx.evaluateScript(ReaderSession.readerScript)
        ctx.evaluateScript("__kb.setup(0, 600, 100, null); advance(3000); __restores = 0;")
    }

    private func restores() -> Int32 { ctx.evaluateScript("__restores").toInt32() }

    func testNoInteractionRestoresWithCorrections() {
        ctx.evaluateScript("__kb.suspend(); advance(120); __kb.relayout(0, 400, true); advance(1000);")
        XCTAssertEqual(restores(), 3) // 立即一次＋250／700ms 兩次修正
    }

    func testNewResizeInvalidatesPendingCorrections() {
        ctx.evaluateScript("__kb.suspend(); __kb.relayout(0, 400, true); __restores = 0; advance(200); __kb.suspend(); advance(600);")
        XCTAssertEqual(restores(), 0, "舊一輪的 250／700ms 修正不該在新 resize 開始後執行")
    }

    func testTouchDuringResizeSkipsAutoRestore() {
        ctx.evaluateScript("__kb.suspend(); advance(50); touch('touchstart', 1); advance(70); __kb.relayout(0, 400, true); advance(1000);")
        XCTAssertEqual(restores(), 0, "使用者開始操作後不應自動捲回")
        XCTAssertNotNil(ctx.evaluateScript("__kb.last").toDictionary()) // 保留穩定錨點
    }

    func testFingerStillDownBeforeResizeSkipsAutoRestore() {
        ctx.evaluateScript("touch('touchstart', 1); __kb.suspend(); advance(120); __kb.relayout(0, 400, true); advance(1000);")
        XCTAssertEqual(restores(), 0, "resize 前就在畫面上的手指也算互動")
    }

    func testNativeReportedInteractionSkipsAutoRestore() {
        ctx.evaluateScript("__kb.suspend(); advance(120); __kb.relayout(0, 400, false); advance(1000);")
        XCTAssertEqual(restores(), 0)
    }

    func testTouchAfterRestoreStopsLaterCorrections() {
        ctx.evaluateScript("__kb.suspend(); advance(120); __kb.relayout(0, 400, true); advance(100); touch('touchstart', 1); touch('touchend', 0); advance(1000);")
        XCTAssertEqual(restores(), 1, "只剩立即那一次，使用者一碰就停止後續修正")
    }
}
