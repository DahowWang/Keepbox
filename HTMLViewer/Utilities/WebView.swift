import SwiftUI
import WebKit

/// 每個 scene 一份的閱讀 session：持有唯一一個閱讀用 WKWebView。
/// 外螢幕單欄、內螢幕並排、專注閱讀切換時，同一個 web view 搬到新的容器，
/// 不重新 loadHTMLString，所以閱讀位置、縮放與字級都留著。
///
/// 版面仍保留原本的規則：
/// - 響應式／窄頁面用裝置寬度排版（像 mobile Safari）。
/// - 桌面設計頁（≥700px 固定寬、沒有 @media 斷點）以設計寬度排版再縮放，可 pinch zoom。
@MainActor
@Observable
final class ReaderSession {
    static let fontScales: [Double] = [0.85, 1.0, 1.14, 1.3]
    static let fontLabels = ["小", "標準", "大", "特大"]

    private(set) var fileID: UUID?
    /// 同步拿到新版內容時不直接換掉，讓使用者決定何時重新載入。
    private(set) var hasPendingUpdate = false
    private(set) var fontStep = 1

    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private let bridge = Bridge()
    @ObservationIgnored private var loadedHTML: String?
    @ObservationIgnored private var pendingHTML: String?
    @ObservationIgnored private var designWidth: CGFloat = 0
    @ObservationIgnored private var isLoaded = false
    @ObservationIgnored private var restoreOnLoad: ReaderAnchor?
    @ObservationIgnored private var lastAnchor: ReaderAnchor?
    @ObservationIgnored private var laidOutWidth: CGFloat = 0
    @ObservationIgnored private var resizeTask: Task<Void, Never>?
    /// 每次尺寸變化／換文章都遞增；過期的 resize 工作看到不同的 generation 就放棄。
    @ObservationIgnored private var resizeGeneration = 0
    /// 使用者 pinch／拖曳時遞增；待執行的縮放復原若看到變化就不再套用。
    @ObservationIgnored fileprivate var interactionGeneration = 0
    @ObservationIgnored weak var activeContainer: ReaderContainerView?
    /// 閱讀位置變動時回報給 scene state（存進 SceneStorage）。
    @ObservationIgnored var onAnchor: ((UUID, ReaderAnchor) -> Void)?

    init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.userContentController.add(bridge, name: "kbAnchor")
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-layoutDebug") {
            config.userContentController.add(bridge, name: "kbLog")
        }
        #endif
        config.userContentController.addUserScript(
            WKUserScript(source: Self.readerScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = true
        webView.navigationDelegate = bridge
        bridge.session = self
        webView.scrollView.panGestureRecognizer.addTarget(bridge, action: #selector(Bridge.userInteracted(_:)))
        observePinch()
    }

    /// WKWebView 的 pinch recognizer 可能在頁面可縮放後才建立：載入完成時補掛一次。
    @ObservationIgnored private weak var observedPinch: UIPinchGestureRecognizer?
    private func observePinch() {
        guard let pinch = webView.scrollView.pinchGestureRecognizer, pinch !== observedPinch else { return }
        pinch.addTarget(bridge, action: #selector(Bridge.userInteracted(_:)))
        observedPinch = pinch
    }

    // MARK: Loading

    func show(fileID: UUID, html: String, fontStep: Int, restoring anchor: ReaderAnchor?) {
        if fileID == self.fileID {
            if loadedHTML?.isEmpty ?? true {
                if !html.isEmpty { restoreOnLoad = anchor; load(html) }
            } else if html != loadedHTML, html != pendingHTML, !html.isEmpty {
                pendingHTML = html
                hasPendingUpdate = true
            }
            return
        }
        self.fileID = fileID
        self.fontStep = min(max(fontStep, 0), Self.fontScales.count - 1)
        hasPendingUpdate = false
        pendingHTML = nil
        lastAnchor = nil
        restoreOnLoad = anchor
        if html.isEmpty {
            loadedHTML = ""
            webView.loadHTMLString("", baseURL: nil)
        } else {
            load(html)
        }
    }

    func applyPendingUpdate() {
        guard let html = pendingHTML else { return }
        pendingHTML = nil
        hasPendingUpdate = false
        restoreOnLoad = lastAnchor
        load(html)
    }

    private func load(_ html: String) {
        // 換文章／重新載入：取消上一篇尚未完成的 resize 復原。
        resizeTask?.cancel()
        resizeGeneration += 1
        loadedHTML = html
        isLoaded = false
        designWidth = Self.desktopDesignWidth(html)
        webView.loadHTMLString(Self.injectViewport(html), baseURL: nil)
    }

    fileprivate func didFinishLoad() {
        guard !(loadedHTML?.isEmpty ?? true) else { return }
        isLoaded = true
        observePinch()
        laidOutWidth = webView.bounds.width
        var anchor = restoreOnLoad
        restoreOnLoad = nil
        #if DEBUG
        // 驗收用：`-readerScrollRatio 0.5` 開啟後捲到文章一半，模擬讀到中段。
        let args = ProcessInfo.processInfo.arguments
        if anchor == nil, let i = args.firstIndex(of: "-readerScrollRatio"), i + 1 < args.count,
           let ratio = Double(args[i + 1]) {
            anchor = ReaderAnchor(path: [], fraction: 0, ratio: ratio)
        }
        #endif
        evaluate("window.__kb&&__kb.setup(\(Int(designWidth)),\(Int(laidOutWidth)),\(fontPercent),\(Self.json(anchor)))")
    }

    // MARK: Reading controls

    var fontLabel: String { Self.fontLabels[fontStep] }
    private var fontPercent: Int { Int((Self.fontScales[fontStep] * 100).rounded()) }

    func setFontStep(_ step: Int) {
        let clamped = min(max(step, 0), Self.fontScales.count - 1)
        guard clamped != fontStep else { return }
        fontStep = clamped
        guard isLoaded else { return }
        evaluate("window.__kb&&__kb.setFont(\(fontPercent))")
    }

    // MARK: Resize（摺疊／展開、Split View、欄寬變化）

    /// 容器寬度改變：只更新 viewport 並還原錨點，不重新載入相同 HTML。
    func containerDidResize(width: CGFloat, zoomRelative: CGFloat) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-layoutDebug") {
            print("[KBReader] native resize \(laidOutWidth) -> \(width) loaded=\(isLoaded) zoomRel=\(zoomRelative) zoom=\(webView.scrollView.zoomScale)/\(webView.scrollView.minimumZoomScale)")
        }
        #endif
        guard isLoaded, abs(width - laidOutWidth) >= 1 else { return }
        // 先暫停 JS 記錄錨點：網頁自己的 resize 事件可能晚於重排造成的捲動。
        evaluate("window.__kb&&__kb.suspend()")
        resizeTask?.cancel()
        resizeGeneration += 1
        let generation = resizeGeneration
        let fileID = self.fileID
        let startScroll = webView.scrollView
        // 整輪共用的互動閘門：resize 前就在操作、或任何一個檢查點看到操作，這一輪就不再自動復原位置／縮放。
        var gate = ResizeInteractionGate(generationAtStart: interactionGeneration,
                                         busyAtStart: startScroll.isTracking || startScroll.isDragging || startScroll.isZooming)
        resizeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard let self, !Task.isCancelled, self.resizeGeneration == generation, self.fileID == fileID else { return }
            self.laidOutWidth = self.webView.bounds.width
            let scrollView = self.webView.scrollView
            // 等待期間使用者開始 pan／pinch（或 resize 前就在操作）：只更新 viewport，不自動捲回。
            let allowRestore = gate.checkpoint(generation: self.interactionGeneration,
                                               busy: scrollView.isTracking || scrollView.isDragging || scrollView.isZooming)
            self.evaluate("window.__kb&&__kb.relayout(\(Int(self.designWidth)),\(Int(self.laidOutWidth)),\(allowRestore))")
            // 縮放以「相對目前 fit 倍率」保存，避免內外螢幕沿用不適合的絕對倍率：
            // viewport 換了之後回到 fit × 使用者原本的相對倍率（未縮放就是剛好塞滿）。
            try? await Task.sleep(for: .milliseconds(260))
            // 每個 await 之後都重新確認：沒被新的 resize／換文章取代，使用者也沒有開始 pinch／拖曳。
            guard !Task.isCancelled, self.resizeGeneration == generation, self.fileID == fileID else { return }
            let scroll = self.webView.scrollView
            guard gate.checkpoint(generation: self.interactionGeneration,
                                  busy: scroll.isZooming || scroll.isTracking || scroll.isDragging) else { return }
            let target = min(scroll.maximumZoomScale, scroll.minimumZoomScale * max(1, zoomRelative))
            if abs(target - scroll.zoomScale) > 0.01 { scroll.setZoomScale(target, animated: false) }
        }
    }

    fileprivate func receiveAnchor(_ body: Any) {
        guard let dict = body as? [String: Any], let fileID else { return }
        let path = (dict["path"] as? [NSNumber] ?? []).map(\.intValue)
        let anchor = ReaderAnchor(path: path,
                                  fraction: (dict["fraction"] as? NSNumber)?.doubleValue ?? 0,
                                  ratio: (dict["ratio"] as? NSNumber)?.doubleValue ?? 0)
        lastAnchor = anchor
        onAnchor?(fileID, anchor)
    }

    private func evaluate(_ js: String) {
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private static func json(_ anchor: ReaderAnchor?) -> String {
        guard let anchor, let data = try? JSONEncoder().encode(anchor) else { return "null" }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: HTML helpers

    static func injectViewport(_ html: String) -> String {
        guard html.range(of: "name=[\"']?viewport", options: .regularExpression) == nil else { return html }
        let tag = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        if let head = html.range(of: "<head>", options: .caseInsensitive) {
            var out = html; out.insert(contentsOf: tag, at: head.upperBound); return out
        }
        return "<html><head>\(tag)</head><body>\(html)</body></html>"
    }

    /// Returns the design width (px) when the page looks desktop-built — i.e. it
    /// declares a wide layout (≥700px) and has no responsive @media breakpoints.
    /// Returns 0 for responsive or narrow (mobile-first) pages.
    static func desktopDesignWidth(_ html: String) -> CGFloat {
        let hasBreakpoints = html.range(
            of: "@media[^{]*(min-width|max-width)", options: [.regularExpression, .caseInsensitive]) != nil
        if hasBreakpoints { return 0 }

        var widest: CGFloat = 0
        let pattern = "(?:max-width|width)\\s*:\\s*(\\d{3,})px"
        if let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let ns = html as NSString
            re.enumerateMatches(in: html, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
                if let m, let r = Range(m.range(at: 1), in: html), let v = Double(html[r]) {
                    widest = max(widest, CGFloat(v))
                }
            }
        }
        return widest >= 700 ? min(widest, 1400) : 0
    }

    // MARK: Delegate bridge（避免 WKUserContentController 強引用 session）

    @MainActor
    private final class Bridge: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var session: ReaderSession?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            session?.didFinishLoad()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        @objc func userInteracted(_ gesture: UIGestureRecognizer) {
            if gesture.state == .began { session?.interactionGeneration += 1 }
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "kbLog" { print("[KBReader] \(message.body)"); return }
            session?.receiveAnchor(message.body)
        }
    }

    /// 錨點：畫面頂端元素的 DOM 路徑＋元素內比例；失效時用整頁比例。
    /// 尺寸變化期間忽略 reflow 造成的捲動，最多修正 2 次，使用者一碰觸就停止自動修正。
    static let readerScript = #"""
    (function(){
      if (window.__kb) return;
      // ig：使用者互動的單調遞增計數；fingers：目前在畫面上的手指數；gen：位置修正排程的世代。
      var kb = window.__kb = {last:null, lastResize:0, timer:null, base:null, ig:0, fingers:0, gen:0, igAtSuspend:0, resizing:false};
      kb.log=function(m){ try { window.webkit.messageHandlers.kbLog.postMessage(m+' y='+Math.round(window.scrollY)+' w='+window.innerWidth+' top='+((document.elementFromPoint(window.innerWidth/2,4)||{}).id||'?')); } catch(e){} };
      function pathOf(el){ var p=[]; while(el && el!==document.body && el.parentElement){ p.unshift(Array.prototype.indexOf.call(el.parentElement.children, el)); el=el.parentElement; } return el===document.body ? p : null; }
      function elOf(path){ var el=document.body; for(var i=0;i<path.length;i++){ el=el&&el.children[path[i]]; } return el||null; }
      function maxY(){ return Math.max(0, document.documentElement.scrollHeight - window.innerHeight); }
      kb.capture=function(){
        var y=window.scrollY, h=maxY(), a={path:[], fraction:0, ratio: h>0 ? Math.min(1, y/h) : 0};
        var x=Math.max(1, window.innerWidth/2), probes=[4,24,60], el=null;
        for (var i=0;i<probes.length && !el;i++){ var c=document.elementFromPoint(x, probes[i]); if(c && c!==document.body && c!==document.documentElement) el=c; }
        if (el){ var p=pathOf(el); if(p){ var r=el.getBoundingClientRect(); a.path=p; a.fraction = r.height>0 ? Math.max(0, Math.min(1, -r.top/r.height)) : 0; } }
        kb.last=a; kb.log('capture path='+a.path.join('.')+' frac='+a.fraction.toFixed(2)+' ratio='+a.ratio.toFixed(3)); return a;
      };
      kb.restore=function(a){
        if(!a) return;
        var el = a.path && a.path.length ? elOf(a.path) : null;
        if (el){ var r=el.getBoundingClientRect(); window.scrollTo(0, Math.max(0, window.scrollY + r.top + a.fraction*r.height)); }
        else { window.scrollTo(0, a.ratio*maxY()); }
        kb.log('restore path='+(a.path||[]).join('.')+' found='+(!!el));
      };
      kb.restoreWithCorrections=function(a){
        if(!a) return; kb.lastResize=Date.now(); kb.last=a;
        var gen = kb.gen = kb.gen+1, ig = kb.ig;
        kb.restore(a);
        // 延遲修正：這一輪沒被新的 resize 作廢、使用者也沒碰過畫面才執行。
        [250, 700].forEach(function(t){ setTimeout(function(){ if(kb.gen===gen && kb.ig===ig && kb.fingers===0){ kb.lastResize=Date.now(); kb.restore(a); } }, t); });
        // 穩定後改存「元素路徑」錨點：之後換寬度依元素還原，不靠整頁比例（比例在不同寬度只是近似）。
        setTimeout(function(){ if(kb.gen===gen && kb.stable()){ kb.capture(); kb.post(); } }, 1700);
      };
      kb.post=function(){ try { window.webkit.messageHandlers.kbAnchor.postMessage(kb.last); } catch(e){} };
      // 只在版面寬度等於上次 fit 的寬度時記錄：尺寸變化中（resize 事件可能晚到）的捲動不算數。
      kb.stable=function(){ return Date.now()-kb.lastResize >= 900 && (!kb.layoutW || Math.abs(window.innerWidth-kb.layoutW) <= 1.5); };
      // 新的尺寸變化開始：作廢所有已排定的修正與穩定後 capture；記住這一輪開始時的互動計數。
      kb.suspend=function(){
        kb.lastResize=Date.now(); clearTimeout(kb.timer); kb.gen++;
        if(!kb.resizing){ kb.resizing=true; kb.igAtSuspend=kb.ig; }
      };
      window.addEventListener('scroll', function(){
        clearTimeout(kb.timer);
        kb.timer=setTimeout(function(){ if(!kb.stable()) return; kb.capture(); kb.post(); }, 220);
      }, {passive:true});
      window.addEventListener('resize', function(){ kb.lastResize=Date.now(); clearTimeout(kb.timer); kb.log('resize event'); }, {passive:true});
      window.addEventListener('touchstart', function(e){ kb.ig++; kb.fingers=e.touches.length; }, {passive:true});
      window.addEventListener('touchend', function(e){ kb.fingers=e.touches.length; }, {passive:true});
      window.addEventListener('touchcancel', function(e){ kb.fingers=e.touches.length; }, {passive:true});
      kb.fit=function(target, width){
        var m=document.querySelector('meta[name=viewport]');
        if(!m){ m=document.createElement('meta'); m.name='viewport'; (document.head||document.documentElement).appendChild(m); }
        if(kb.base===null){ kb.base=(m.getAttribute('content')||'width=device-width, initial-scale=1').replace(/,?\s*user-scalable\s*=\s*(no|0)/ig,'').replace(/,?\s*maximum-scale\s*=\s*[0-9.]+/ig,''); }
        if(target>0 && target>width){ var s=width/target; m.setAttribute('content','width='+target+', initial-scale='+s+', minimum-scale='+s+', maximum-scale=5, user-scalable=yes'); kb.layoutW=target; }
        else { m.setAttribute('content', kb.base+', maximum-scale=5'); kb.layoutW=width; }
      };
      kb.font=function(pct){
        var st=document.getElementById('kb-font');
        if(!st){ st=document.createElement('style'); st.id='kb-font'; (document.head||document.documentElement).appendChild(st); }
        st.textContent='html{font-size:'+pct+'%!important}body{font-size:'+pct+'%!important}';
      };
      kb.setup=function(target, width, pct, anchor){ kb.fit(target,width); kb.font(pct); if(anchor){ kb.restoreWithCorrections(anchor); } else { kb.capture(); } };
      // viewport 一定跟著容器更新；自動捲回原位只在「這一輪尺寸變化開始後使用者沒互動、手指也不在畫面上」時做。
      // 錨點一律用上次穩定時記下的值（實測 466pt 過渡態的畫面位置不可信）。
      kb.relayout=function(target, width, allowRestore){
        var a=kb.last||kb.capture();
        var interacted = !allowRestore || kb.ig!==kb.igAtSuspend || kb.fingers>0;
        kb.log('relayout to '+width+' using path='+a.path.join('.')+(interacted?' (user interacted, no auto-restore)':''));
        kb.resizing=false; kb.lastResize=Date.now(); kb.fit(target,width);
        if(!interacted){ kb.restoreWithCorrections(a); } else { kb.gen++; }
      };
      kb.setFont=function(pct){ var a=kb.capture(); kb.font(pct); kb.restoreWithCorrections(a); };
    })();
    """#
}

/// 一輪 resize 的互動閘門（不可逆）：只要開始時或任何檢查點觀察到使用者操作，
/// 之後所有檢查點都回傳 false。用來同時約束 JS 位置復原與原生縮放復原。
struct ResizeInteractionGate {
    let generationAtStart: Int
    let busyAtStart: Bool
    private(set) var allowsRestore: Bool

    init(generationAtStart: Int, busyAtStart: Bool) {
        self.generationAtStart = generationAtStart
        self.busyAtStart = busyAtStart
        self.allowsRestore = !busyAtStart
    }

    /// `generation`：目前的互動計數（手勢 `.began` 遞增）；`busy`：此刻是否正在 tracking／dragging／zooming。
    mutating func checkpoint(generation: Int, busy: Bool) -> Bool {
        if busy || generation != generationAtStart { allowsRestore = false }
        return allowsRestore
    }
}

/// 承載 session 的 web view。容器換了（版面切換）就把同一個 web view 搬過來。
final class ReaderContainerView: UIView {
    weak var session: ReaderSession?

    override func layoutSubviews() {
        super.layoutSubviews()
        // 搬家或還沒排版時容器可能是 0 寬：先不動 web view，避免頁面被排成 0 寬、縮放倍率算錯。
        guard let session, session.webView.superview === self, bounds.width >= 1, bounds.height >= 1 else { return }
        let webView = session.webView
        let oldWidth = webView.frame.width
        let scroll = webView.scrollView
        // 只有新舊寬度都有效時才保存「相對 fit 倍率」；上限 3 倍，避免換螢幕後被放大。
        var zoomRelative: CGFloat = 1
        if oldWidth >= 1, scroll.minimumZoomScale > 0 {
            zoomRelative = min(3, max(1, scroll.zoomScale / scroll.minimumZoomScale))
        }
        webView.frame = bounds
        if abs(oldWidth - bounds.width) >= 1 {
            session.containerDidResize(width: bounds.width, zoomRelative: oldWidth >= 1 ? zoomRelative : 1)
        }
    }
}

struct ReaderWebView: UIViewRepresentable {
    let session: ReaderSession

    func makeUIView(context: Context) -> ReaderContainerView {
        let container = ReaderContainerView()
        container.session = session
        adopt(into: container)
        return container
    }

    func updateUIView(_ container: ReaderContainerView, context: Context) {
        if session.activeContainer == nil || session.activeContainer === container,
           session.webView.superview !== container {
            adopt(into: container)
        }
    }

    static func dismantleUIView(_ container: ReaderContainerView, coordinator: ()) {
        guard let session = container.session, session.activeContainer === container else { return }
        session.activeContainer = nil
        if session.webView.superview === container { session.webView.removeFromSuperview() }
    }

    private func adopt(into container: ReaderContainerView) {
        session.activeContainer = container
        container.addSubview(session.webView)
        // 尺寸交給 layoutSubviews；這裡不先套用可能為 0 的 bounds。
        if container.bounds.width >= 1 { session.webView.frame = container.bounds }
        container.setNeedsLayout()
    }
}
