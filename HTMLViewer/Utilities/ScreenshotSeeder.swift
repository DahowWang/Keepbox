import Foundation
import SwiftData

/// DEBUG-only sample data for App Store screenshots.
/// Triggered by launch argument `-seedScreenshots`; inserts a curated set of
/// HTML files, tags, and a folder when the store is empty. Never compiled into
/// release builds.
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
        let travel = Tag(name: "旅遊", colorHex: "#2E7D5B")
        let study = Tag(name: "學習", colorHex: "#B08A3E")
        [work, life, travel, study].forEach { context.insert($0) }

        let folder = Folder(name: "工作")
        context.insert(folder)

        func file(_ name: String, _ html: String, _ tag: Tag, folder: Folder? = nil) {
            let f = HTMLFile(name: name, content: html)
            f.tags = [tag]
            f.folder = folder
            context.insert(f)
        }

        file("產品發表會邀請函", Samples.invite, work, folder: folder)
        file("2025 Q2 報價單", Samples.invoice, work, folder: folder)
        file("草莓鮮奶油蛋糕食譜", Samples.recipe, life)
        file("京都三天兩夜行程", Samples.itinerary, travel)
        file("原子習慣讀書筆記", Samples.notes, study)
        file("社團活動報名表單", Samples.form, life)

        try? context.save()
        #endif
    }
}

#if DEBUG
private enum Samples {
    static let invite = """
    <html><head><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{margin:0;font-family:Georgia,serif;background:#0b0d12;color:#fff}
    .hero{padding:54px 30px 40px;background:radial-gradient(120% 90% at 30% 10%,#7c4dff,#2a1a6b 55%,#0b0d12)}
    .k{font-family:system-ui;font-size:13px;letter-spacing:4px;opacity:.7}
    h1{font-size:46px;line-height:1.05;margin:70px 0 0}.d{font-family:system-ui;opacity:.75;margin-top:16px}
    .b{font-family:system-ui;padding:24px 30px}.btn{display:inline-block;background:#7c4dff;padding:13px 26px;border-radius:999px;font-size:15px;margin-top:20px}</style></head>
    <body><div class='hero'><div class='k'>KEEPBOX × 2025</div><h1>Spring<br>Showcase</h1><div class='d'>5 月 18 日 · 台北華山</div></div>
    <div class='b'>誠摯邀請您參加今年度的春季產品發表會，我們將揭曉全新系列與互動體驗。<div class='btn'>立即報名</div></div></body></html>
    """

    static let invoice = """
    <html><head><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{margin:0;font-family:system-ui;background:#fff;color:#111;padding:40px 30px}
    h1{font-size:30px;letter-spacing:-.5px;margin:0}.no{color:#888;margin-top:6px}
    .row{display:flex;justify-content:space-between;padding:14px 0;border-bottom:1px solid #eee;font-size:16px}
    .tot{display:flex;justify-content:space-between;margin-top:24px;font-weight:800;font-size:22px}</style></head>
    <body><h1>INVOICE</h1><div class='no'>No. 2025-0418</div>
    <div style='margin-top:34px'>
    <div class='row'><span>品牌識別設計</span><span>NT$ 12,000</span></div>
    <div class='row'><span>網站開發</span><span>NT$ 9,600</span></div>
    <div class='row'><span>社群代管（季）</span><span>NT$ 4,800</span></div>
    <div class='row'><span>攝影製作</span><span>NT$ 3,200</span></div></div>
    <div class='tot'><span>合計</span><span>NT$ 29,600</span></div></body></html>
    """

    static let recipe = """
    <html><head><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{margin:0;font-family:system-ui;background:#fffdf8;color:#2a211a}
    .h{height:230px;background:linear-gradient(135deg,#ff9a8b,#ff6a88 45%,#ff99ac);position:relative}
    .t{position:absolute;left:26px;bottom:22px;color:#fff;font-family:Georgia;font-size:34px;font-weight:700;line-height:1.1}
    .b{padding:24px 26px}.k{font-size:13px;letter-spacing:2px;color:#c8506a;font-weight:700}
    li{margin:10px 0;font-size:16px}</style></head>
    <body><div class='h'><div class='t'>草莓<br>鮮奶油蛋糕</div></div>
    <div class='b'><div class='k'>材料 · 6 人份</div>
    <ul><li>低筋麵粉 120g</li><li>新鮮草莓 2 盒</li><li>動物性鮮奶油 400ml</li><li>雞蛋 4 顆</li><li>細砂糖 90g</li></ul></div></body></html>
    """

    static let itinerary = """
    <html><head><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{margin:0;font-family:system-ui;background:#f7f9fc;color:#222;padding:34px 28px}
    .k{font-size:13px;letter-spacing:3px;color:#2e7d5b;font-weight:700}h1{font-size:30px;margin:8px 0 0}
    .s{display:flex;gap:12px;margin-top:18px}.dot{width:12px;height:12px;border-radius:99px;background:#2e7d5b;margin-top:4px;flex-shrink:0}
    .tt{font-size:13px;color:#8a94a6;font-weight:600}.p{font-size:16px;margin-top:3px}</style></head>
    <body><div class='k'>3 天 2 夜</div><h1>京都漫步行程</h1>
    <div class='s'><div class='dot'></div><div><div class='tt'>Day 1 · 09:00</div><div class='p'>伏見稻荷大社、清水寺、二年坂散策</div></div></div>
    <div class='s'><div class='dot'></div><div><div class='tt'>Day 2 · 10:00</div><div class='p'>嵐山竹林、渡月橋、金閣寺</div></div></div>
    <div class='s'><div class='dot'></div><div><div class='tt'>Day 3 · 11:00</div><div class='p'>錦市場、祇園、八坂神社</div></div></div></body></html>
    """

    static let notes = """
    <html><head><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{margin:0;font-family:Georgia,serif;background:#fcfbf7;color:#1c1a16;padding:38px 32px}
    .k{font-family:system-ui;font-size:13px;letter-spacing:2px;color:#b08a3e;font-weight:700}
    h1{font-size:30px;line-height:1.15;margin:10px 0 18px}p{font-size:16px;line-height:1.8}</style></head>
    <body><div class='k'>讀書筆記</div><h1>原子習慣的<br>四個法則</h1>
    <p>1. 讓提示顯而易見。<br>2. 讓習慣有吸引力。<br>3. 讓行動輕而易舉。<br>4. 讓獎賞令人滿足。</p>
    <p>微小的改變經由複利累積，會在長期帶來驚人的成果。</p></body></html>
    """

    static let form = """
    <html><head><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{margin:0;font-family:system-ui;background:#fff;color:#16181d;padding:34px 30px}
    .logo{width:46px;height:46px;border-radius:12px;background:linear-gradient(135deg,#22c1c3,#0a7cff)}
    h1{font-size:26px;margin:18px 0 4px}.d{color:#8a94a6}
    label{display:block;font-size:13px;color:#8a94a6;margin:18px 0 6px}
    .f{height:42px;background:#f1f3f7;border:1px solid #e3e7ee;border-radius:10px}
    .btn{height:48px;background:#0a7cff;border-radius:12px;margin-top:22px}</style></head>
    <body><div class='logo'></div><h1>社團活動報名</h1><div class='d'>填寫資料以確認名額</div>
    <label>姓名</label><div class='f'></div><label>Email</label><div class='f'></div><div class='btn'></div></body></html>
    """
}
#endif
