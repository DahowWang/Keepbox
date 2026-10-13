import SwiftUI

/// 首頁右上角的同步按鈕，圖示反映目前同步狀態。
struct SyncStatusButton: View {
    @Environment(\.colorScheme) private var scheme
    let action: () -> Void

    private var sync: SyncService { SyncService.shared }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: sync.state == .syncing)
                .frame(width: 34, height: 34)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("同步設定")
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
