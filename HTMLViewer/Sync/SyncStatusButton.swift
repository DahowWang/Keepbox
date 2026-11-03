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

    private var icon: String {
        if !SyncSettings.isConfigured { return "arrow.triangle.2.circlepath" }
        switch sync.state {
        case .failed: return "exclamationmark.arrow.triangle.2.circlepath"
        default: return "arrow.triangle.2.circlepath"
        }
    }

    private var tint: Color {
        if case .failed = sync.state { return .orange }
        return SyncSettings.isConfigured ? Color.kbAccent : Color.kbSub(scheme)
    }
}
