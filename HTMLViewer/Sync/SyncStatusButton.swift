import SwiftUI

/// 首頁右上角的同步按鈕，圖示反映目前同步狀態。
/// 視覺 34pt，觸控命中範圍 44pt。
struct SyncStatusButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SyncStatusIcon()
                .frame(width: 34, height: 34)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("同步設定")
        .accessibilityValue(SyncStatusIcon.spokenState)
    }
}

/// 同步狀態圖示，也用在寬版分類欄。
struct SyncStatusIcon: View {
    @Environment(\.colorScheme) private var scheme
    private var sync: SyncService { SyncService.shared }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .symbolEffect(.pulse, isActive: sync.state == .syncing)
            .accessibilityHidden(true)
    }

    @MainActor static var spokenState: String {
        guard SyncSettings.isConfigured else { return "尚未設定" }
        switch SyncService.shared.state {
        case .idle: return "已同步"
        case .syncing: return "同步中"
        case .failed: return "同步失敗"
        }
    }

    private var icon: String { Self.symbolName }

    /// 系統工具列用的 SF Symbol（失敗時換成驚嘆號版本）。
    @MainActor static var symbolName: String {
        if !SyncSettings.isConfigured { return "arrow.triangle.2.circlepath" }
        switch SyncService.shared.state {
        case .failed: return "exclamationmark.arrow.triangle.2.circlepath"
        default: return "arrow.triangle.2.circlepath"
        }
    }

    @MainActor static var isFailed: Bool {
        if case .failed = SyncService.shared.state { return true }
        return false
    }

    private var tint: Color {
        if case .failed = sync.state { return .orange }
        return SyncSettings.isConfigured ? Color.kbAccent : Color.kbSub(scheme)
    }
}

/// 系統工具列裡的同步按鈕：標準 Label（標題＋圖示），讓 Duo 直式列與溢出選單都能正確顯示。
/// 不疊自訂背景，避免和系統 bar 的玻璃背景重疊。
struct SyncToolbarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("同步設定", systemImage: SyncStatusIcon.symbolName)
        }
        .symbolEffect(.pulse, isActive: SyncService.shared.state == .syncing)
        .accessibilityValue(SyncStatusIcon.spokenState)
    }
}
