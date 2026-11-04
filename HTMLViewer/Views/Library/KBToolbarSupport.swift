import SwiftUI

/// iPhone Duo 直式側邊工具列（docs/iphone-duo-design.md §13）的版本隔離。
/// iOS 27.0／27.1 才有的 toolbar API 全部集中在這裡包 `#available`；
/// iOS 17–26 與 Mac Catalyst 走一般水平工具列，不引用新型別。

enum KBToolbarPriority {
    case low, automatic, high
}

extension ToolbarItemPlacement {
    /// 主要動作（新增、分享、儲存）。27.1 起用 pinned trailing，讓它在直式列緊接在返回下方。
    static var kbPrimary: ToolbarItemPlacement {
        #if targetEnvironment(macCatalyst)
        return .primaryAction
        #else
        if #available(iOS 27.1, *) { return .topBarPinnedTrailing }
        return .topBarTrailing
        #endif
    }

    /// 表單提交（擷取並存入、儲存設定）。
    static var kbConfirm: ToolbarItemPlacement {
        #if targetEnvironment(macCatalyst)
        return .confirmationAction
        #else
        if #available(iOS 27.1, *) { return .topBarPinnedTrailing }
        return .confirmationAction
        #endif
    }
}

extension ToolbarContent {
    /// 空間不足時的保留順序；只給主要導覽／主動作 high，低頻項目 low。
    @ToolbarContentBuilder
    func kbPriority(_ priority: KBToolbarPriority) -> some ToolbarContent {
        #if targetEnvironment(macCatalyst)
        self
        #else
        if #available(iOS 27.0, *) {
            switch priority {
            case .low: self.visibilityPriority(.low)
            case .automatic: self
            case .high: self.visibilityPriority(.high)
            }
        } else {
            self
        }
        #endif
    }
}

extension View {
    /// 直式列空間不足時誰先壓縮：瀏覽保留分頁（prefersTabBar），任務畫面保留工具（prefersToolbarItems）。
    @ViewBuilder
    func kbToolbarCompression(prefersTabBar: Bool) -> some View {
        #if targetEnvironment(macCatalyst)
        self
        #else
        if #available(iOS 27.1, *) {
            self.toolbarVerticalCompressionBehavior(prefersTabBar ? .prefersTabBar : .prefersToolbarItems)
        } else {
            self
        }
        #endif
    }

    /// 只有一顆完成鈕的短 sheet：維持水平列，內容用完整寬度。
    @ViewBuilder
    func kbVerticalToolbarDisabled() -> some View {
        #if targetEnvironment(macCatalyst)
        self
        #else
        if #available(iOS 27.1, *) {
            self.toolbarVerticalBehavior(.disabled)
        } else {
            self
        }
        #endif
    }

    /// 工具列項目的數量徽章（27.1 路徑）；0 不顯示。舊版不仿製小圓點。
    @ViewBuilder
    func kbToolbarBadge(_ count: Int) -> some View {
        #if targetEnvironment(macCatalyst)
        self
        #else
        if #available(iOS 27.1, *), count > 0 {
            self.badge(count)
        } else {
            self
        }
        #endif
    }
}

/// 單一溢出選單：27.1 用系統 `ToolbarOverflowMenu`，舊版用一顆「更多」Menu。
/// 每個畫面至多一個；同一動作不可同時出現在一般列與這裡。
struct KBOverflowMenu<Content: View>: ToolbarContent {
    /// 舊版「更多」放的位置（窄版放底部工具列，寬版放頂端）。
    var fallbackPlacement: ToolbarItemPlacement = .bottomBar
    @ViewBuilder var content: () -> Content

    var body: some ToolbarContent {
        #if targetEnvironment(macCatalyst)
        ToolbarItem(placement: fallbackPlacement) { fallbackMenu }
        #else
        if #available(iOS 27.1, *) {
            ToolbarOverflowMenu { content() }
        } else {
            ToolbarItem(placement: fallbackPlacement) { fallbackMenu }
        }
        #endif
    }

    private var fallbackMenu: some View {
        Menu { content() } label: { Label("更多", systemImage: "ellipsis") }
    }
}
