import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportSheetView: View {
    @Environment(\.colorScheme) private var scheme
    let modelContext: ModelContext
    let onSaved: () -> Void

    @State private var step: Step = .source
    @State private var pastedHTML = ""
    @State private var fileName = "匯入的 HTML"
    @State private var showFilePicker = false

    enum Step { case source, paste, done }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .source: sourceView
                case .paste:  pasteView
                case .done:   doneView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step == .source {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消", action: onSaved)
                    }
                }
                if step == .paste {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            step = .source
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("返回")
                            }
                            .foregroundStyle(Color.kbAccent)
                        }
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.7), .large])
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [UTType.html]) { result in
            guard case .success(let url) = result,
                  url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
            let name = url.deletingPathExtension().lastPathComponent
            fileName = name.isEmpty ? "匯入的 HTML" : name
            pastedHTML = content
            saveFile()
        }
    }

    // MARK: - Source selection
    private var sourceView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("新增到 Keepbox")
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundStyle(Color.kbText(scheme))
                    .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 20)

                VStack(spacing: 0) {
                    sourceRow("貼上 HTML 原始碼", icon: "chevron.left.forwardslash.chevron.right") {
                        step = .paste
                    }
                    Divider().padding(.leading, 51)
                    sourceRow("從「檔案」App 匯入", icon: "folder") {
                        showFilePicker = true
                    }
                    Divider().padding(.leading, 51)
                    sourceRow("透過分享功能存入（說明）", icon: "square.and.arrow.up") { }
                }
                .background(Color.kbSurface(scheme))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)

                Text("在 Line、Messenger 或 Safari 點「分享」→「存到 Keepbox」，頁面會自動儲存。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.kbSub(scheme))
                    .padding(.horizontal, 24).padding(.top, 10)
            }
            .padding(.bottom, 40)
        }
        .background(Color.kbBg(scheme))
    }

    @ViewBuilder
    private func sourceRow(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 18)).foregroundStyle(Color.kbAccent).frame(width: 22)
                Text(label)
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(Color.kbText(scheme))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.kbSub(scheme))
            }
            .padding(.vertical, 14).padding(.horizontal, 16)
        }
    }

    // MARK: - Paste view
    private var pasteView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("貼上 HTML 原始碼")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(Color.kbText(scheme))
                .padding(.horizontal, 20).padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("檔案名稱")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Color.kbSub(scheme))
                    .padding(.horizontal, 20)
                TextField("匯入的 HTML", text: $fileName)
                    .font(.system(size: 15.5))
                    .padding(.horizontal, 14).padding(.vertical, 13)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("HTML 原始碼")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Color.kbSub(scheme))
                    .padding(.horizontal, 20)
                TextEditor(text: $pastedHTML)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 160)
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .padding(.horizontal, 20)
            }

            Spacer()

            let trimmed = pastedHTML.trimmingCharacters(in: .whitespacesAndNewlines)
            Button { saveFile() } label: {
                Text("存入 Keepbox")
                    .font(.system(size: 16.5, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(trimmed.isEmpty ? Color.kbAccent.opacity(0.4) : Color.kbAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: Color.kbAccent.opacity(trimmed.isEmpty ? 0 : 0.5), radius: 12)
            }
            .disabled(trimmed.isEmpty)
            .padding(.horizontal, 20).padding(.bottom, 30)
        }
        .background(Color.kbBg(scheme))
    }

    // MARK: - Done view
    private var doneView: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(Color(hex: "#1fae5a")).frame(width: 72, height: 72)
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
            }
            Text("已存入 Keepbox")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Color.kbText(scheme))
            Text("「\(fileName)」現在可離線開啟")
                .font(.system(size: 14)).foregroundStyle(Color.kbSub(scheme))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { onSaved() }
        }
    }

    private func saveFile() {
        let content = pastedHTML.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let file = HTMLFile(
            name: fileName.trimmingCharacters(in: .whitespaces).isEmpty ? "匯入的 HTML" : fileName.trimmingCharacters(in: .whitespaces),
            content: content
        )
        modelContext.insert(file)
        try? modelContext.save()
        withAnimation { step = .done }
    }
}
