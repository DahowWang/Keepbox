import Foundation
import SwiftData

/// DEBUG-only sample data for App Store screenshots.
/// Triggered by launch argument `-seedScreenshots`; inserts a curated set of
/// real-world examples (meeting notes, an X post, a Facebook long post, news,
/// etc.) when the store is empty. Never compiled into release builds.
enum ScreenshotSeeder {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedScreenshots")
    }

    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        #if DEBUG
        guard isRequested else { return }
        let existing = try? context.fetch(FetchDescriptor<HTMLFile>())
        guard (existing?.isEmpty ?? true) else { return }

        let work = Tag(name: "工作", colorHex: "#0A7CFF")
        let life = Tag(name: "生活", colorHex: "#22C1C3")
        let study = Tag(name: "學習", colorHex: "#B08A3E")
        let travel = Tag(name: "旅遊", colorHex: "#2E7D5B")
        [work, life, study, travel].forEach { context.insert($0) }

        let folder = Folder(name: "工作")
        context.insert(folder)

        func file(_ name: String, _ html: String, _ tag: Tag, folder: Folder? = nil) {
            let f = HTMLFile(name: name, content: html)
            f.tags = [tag]
            f.folder = folder
            context.insert(f)
        }

        // Order matters: newest first in the grid. Lead with the requested cases.
        file("產品週會會議記錄", Samples.meeting, work, folder: folder)
        file("X · Qwen ASR 新版觀點", Samples.tweet, study)
        file("Facebook · 創業三年的體悟", Samples.fbPost, life)
        file("TechCrunch：AI 助理新趨勢", Samples.news, work, folder: folder)
        file("京都三天兩夜行程", Samples.itinerary, travel)
        file("草莓鮮奶油蛋糕食譜", Samples.recipe, life)

        try? context.save()
        #endif
    }
}

#if DEBUG
private enum Samples {
    // A real-looking meeting-notes document — the reader hero.
    static let meeting = """
    <html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{margin:0;font-family:-apple-system,'PingFang TC',system-ui;background:#fff;color:#1d1b3a;line-height:1.7}
    .hd{background:linear-gradient(135deg,#5B53E0,#8079ee);color:#fff;padding:30px 26px}
    .k{font-size:12px;letter-spacing:3px;opacity:.85}.t{font-size:26px;font-weight:800;margin-top:8px}
    .meta{font-size:13px;opacity:.85;margin-top:10px}
    .b{padding:24px 26px}h2{font-size:17px;color:#5B53E0;margin:24px 0 8px}
    li{margin:7px 0;font-size:15.5px}.chk{color:#1f8a5b;font-weight:700}.who{color:#9a96b5;font-size:13px}</style></head>
    <body><div class='hd'><div class='k'>MEETING NOTES</div><div class='t'>產品週會會議記錄</div>
    <div class='meta'>2026/06/22 · 與會:Hao、Shannie、Stephanie、Eric</div></div>
    <div class='b'>
    <h2>本週重點</h2>
    <ul><li>Keepbox TestFlight 外部測試開放,已邀請 8 位</li>
    <li>分享擴充支援 X / Facebook 內容擷取</li>
    <li>閱讀頁完成桌面版面自動置入</li></ul>
    <h2>決議</h2>
    <ul><li>下版優先做「批次匯出」與「iCloud 同步」</li>
    <li>正式上架目標訂在 7 月中</li></ul>
    <h2>待辦事項</h2>
    <ul><li><span class='chk'>☐</span> 收集測試回饋彙整 <span class='who'>— Shannie</span></li>
    <li><span class='chk'>☐</span> App Store 行銷截圖定稿 <span class='who'>— Hao</span></li>
    <li><span class='chk'>☑</span> 隱私政策上線 <span class='who'>— Eric</span></li></ul>
    </div></body></html>
    """

    // Collection card mirroring what the Share Extension builds for an X post.
    static let tweet = """
    <html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{margin:0;font-family:-apple-system,'PingFang TC',system-ui;background:#fff;color:#15202b}
    .card{max-width:680px;margin:0 auto}
    .hero{width:100%;height:210px;object-fit:cover;display:block}
    .b{padding:22px 22px 36px}.src{font-size:13px;font-weight:700;color:#1d9bf0;letter-spacing:.04em}
    .au{display:flex;align-items:center;gap:10px;margin:12px 0}.av{width:42px;height:42px;border-radius:99px;background:linear-gradient(135deg,#1d9bf0,#8ed0ff)}
    .nm{font-weight:800}.hd{color:#536471;font-size:14px}
    p{font-size:16px;line-height:1.7;margin:6px 0 0}.btn{display:inline-block;margin-top:22px;background:#1d9bf0;color:#fff;text-decoration:none;font-weight:700;padding:12px 22px;border-radius:14px}</style></head>
    <body><div class='card'><img class='hero' src='data:image/jpeg;base64,\(SeedImage.asr)'><div class='b'>
    <div class='src'>X · TWITTER</div>
    <div class='au'><div class='av'></div><div><div class='nm'>聲音轉錄小工具</div><div class='hd'>@asr_tool · 6月27日</div></div></div>
    <p>QwenASRMiniTool 新版影片,這個版本也可以當 WhisperDesktop 來用了,介面更現代,已支援 BreezeASR,也可接各種新的 ASR。新版字幕能邊播邊驗證,說話人分離還自動分色。</p>
    <a class='btn'>在 X 開啟 ↗</a></div></div></body></html>
    """

    // Collection card for a Facebook long post.
    static let fbPost = """
    <html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{margin:0;font-family:-apple-system,'PingFang TC',system-ui;background:#fff;color:#1c1e21}
    .card{max-width:680px;margin:0 auto}
    .hero{width:100%;height:210px;object-fit:cover;display:block}
    .b{padding:20px 22px 36px}.src{font-size:13px;font-weight:700;color:#1877f2;letter-spacing:.04em}
    h1{font-size:21px;font-weight:800;margin:10px 0 0;line-height:1.35}
    p{font-size:15.5px;line-height:1.8;margin:14px 0 0;color:#3a3b3c}
    .btn{display:inline-block;margin-top:22px;background:#1877f2;color:#fff;text-decoration:none;font-weight:700;padding:12px 22px;border-radius:14px}</style></head>
    <body><div class='card'><img class='hero' src='data:image/jpeg;base64,\(SeedImage.startup)'><div class='b'>
    <div class='src'>FACEBOOK</div>
    <h1>創業三年的體悟</h1>
    <p>三年前辭掉工作開始做產品,最深的體會是:把一件事做到讓使用者真心推薦,比追逐流量更難、也更值得。</p>
    <p>這一路上學到——先解決一個人的真實問題,再想規模;能留住的內容,才值得收藏。謝謝每一位早期使用者的回饋。</p>
    <a class='btn'>在 Facebook 開啟 ↗</a></div></div></body></html>
    """

    static let news = """
    <html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{margin:0;font-family:Georgia,'PingFang TC',serif;background:#fff;color:#111}
    .hero{width:100%;height:210px;object-fit:cover;display:block}
    .b{padding:24px 26px 36px}.k{font-family:system-ui;font-size:12px;letter-spacing:2px;color:#16a34a;font-weight:700}
    h1{font-size:25px;line-height:1.3;margin:10px 0}.by{font-family:system-ui;color:#888;font-size:13px}
    p{font-size:16px;line-height:1.8;margin:14px 0 0}</style></head>
    <body><img class='hero' src='data:image/jpeg;base64,\(SeedImage.tech)'><div class='b'><div class='k'>TECHCRUNCH</div>
    <h1>AI 個人助理進入「主動式」新階段</h1>
    <div class='by'>By Jane Doe · 2026/06/20</div>
    <p>新一代 AI 助理不再只是被動回答,而是能主動規劃、串接工具完成多步驟任務,為生產力工具帶來新想像。</p>
    <p>分析師指出,具備記憶與工具使用能力的代理人,將成為下一波 App 競爭的核心。</p></div></body></html>
    """

    static let itinerary = """
    <html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{margin:0;font-family:system-ui,'PingFang TC';background:#f7f9fc;color:#222;padding:34px 28px}
    .k{font-size:13px;letter-spacing:3px;color:#2e7d5b;font-weight:700}h1{font-size:28px;margin:8px 0 0}
    .s{display:flex;gap:12px;margin-top:18px}.dot{width:12px;height:12px;border-radius:99px;background:#2e7d5b;margin-top:4px;flex-shrink:0}
    .tt{font-size:13px;color:#8a94a6;font-weight:600}.p{font-size:16px;margin-top:3px}</style></head>
    <body><div class='k'>3 天 2 夜</div><h1>京都漫步行程</h1>
    <div class='s'><div class='dot'></div><div><div class='tt'>Day 1</div><div class='p'>伏見稻荷、清水寺、二年坂</div></div></div>
    <div class='s'><div class='dot'></div><div><div class='tt'>Day 2</div><div class='p'>嵐山竹林、渡月橋、金閣寺</div></div></div>
    <div class='s'><div class='dot'></div><div><div class='tt'>Day 3</div><div class='p'>錦市場、祇園、八坂神社</div></div></div></body></html>
    """

    static let recipe = """
    <html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{margin:0;font-family:system-ui,'PingFang TC';background:#fffdf8;color:#2a211a}
    .h{height:190px;background:linear-gradient(135deg,#ff9a8b,#ff6a88 45%,#ff99ac);position:relative}
    .t{position:absolute;left:24px;bottom:18px;color:#fff;font-family:Georgia;font-size:30px;font-weight:700;line-height:1.1}
    .b{padding:22px 24px}.k{font-size:13px;letter-spacing:2px;color:#c8506a;font-weight:700}li{margin:9px 0;font-size:16px}</style></head>
    <body><div class='h'><div class='t'>草莓<br>鮮奶油蛋糕</div></div><div class='b'><div class='k'>材料 · 6 人份</div>
    <ul><li>低筋麵粉 120g</li><li>新鮮草莓 2 盒</li><li>動物性鮮奶油 400ml</li><li>雞蛋 4 顆</li></ul></div></body></html>
    """
}
#endif
