import SwiftUI

struct SyncSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var serverURL = SyncSettings.serverURL?.absoluteString ?? ""
    @State private var token = SyncSettings.token ?? ""
    @State private var urlError: String?

    private var sync: SyncService { SyncService.shared }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://keepbox-sync.example.workers.dev", text: $serverURL)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                    SecureField("同步 token", text: $token)
                } header: {
                    Text("同步伺服器")
                } footer: {
                    if let urlError {
                        Text(urlError).foregroundStyle(.red)
                    } else {
                        Text("手機和 Mac 填同一組網址與 token，就會互相同步。")
                    }
                }

                Section {
                    LabeledContent("狀態", value: statusText)
                    if let last = sync.lastSyncAt {
                        LabeledContent("上次同步", value: last.formatted(date: .abbreviated, time: .shortened))
                    }
                    Button("立即同步") {
                        guard save() else { return }
                        Task { await sync.syncNow() }
                    }
                    .disabled(sync.state == .syncing)
                }
            }
            .navigationTitle("同步")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if targetEnvironment(macCatalyst)
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存", action: saveAndClose)
                }
                #else
                // iOS：標題＋圖示的系統項目，Duo 外螢幕直排時取消在上、儲存其次（§13.3 F）。
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("取消", systemImage: "xmark") }
                }
                .kbPriority(.high)
                ToolbarItem(placement: .kbConfirm) {
                    Button(action: saveAndClose) { Label("儲存", systemImage: "checkmark") }
                }
                .kbPriority(.high)
                #endif
            }
            .kbToolbarCompression(prefersTabBar: false)
        }
    }

    private func saveAndClose() {
        guard save() else { return }
        sync.requestSync(after: .zero)
        dismiss()
    }

    private var statusText: String {
        switch sync.state {
        case .idle: return SyncSettings.isConfigured ? "已設定" : "尚未設定"
        case .syncing: return "同步中…"
        case .failed(let message): return message
        }
    }

    private func save() -> Bool {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            SyncSettings.serverURL = nil
        } else {
            guard let url = URL(string: trimmed), url.scheme == "https", url.host != nil else {
                urlError = "網址要以 https:// 開頭"
                return false
            }
            SyncSettings.serverURL = url
        }
        urlError = nil
        SyncSettings.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
    }
}
