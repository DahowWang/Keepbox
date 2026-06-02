import SwiftUI

struct SearchView: View {
    @Environment(\.colorScheme) private var scheme
    let allFiles: [HTMLFile]
    @Bindable var viewModel: FileViewModel
    let onBack: () -> Void
    let onOpen: (HTMLFile) -> Void

    @State private var query = ""
    @FocusState private var focused: Bool

    private var results: [HTMLFile] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return allFiles.filter {
            $0.name.lowercased().contains(q) || $0.content.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar row
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.kbSub(scheme))
                    TextField("搜尋檔案名稱或內容", text: $query)
                        .focused($focused)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.kbText(scheme))
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.kbSub(scheme))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(scheme == .dark ? Color.white.opacity(0.1) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: scheme == .light ? .black.opacity(0.06) : .clear, radius: 3)

                Button("取消", action: onBack)
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(Color.kbAccent)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20).padding(.bottom, 12)

            // Results
            ScrollView {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    emptyQueryView
                } else if results.isEmpty {
                    noResultsView
                } else {
                    resultsView
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.kbBg(scheme).ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }

    // MARK: - Results list
    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(results.count) 個結果")
                .font(.system(size: 13))
                .foregroundStyle(Color.kbSub(scheme))
                .padding(.horizontal, 18).padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { i, file in
                    Button { onOpen(file) } label: {
                        HStack(spacing: 12) {
                            HTMLThumbnailView(htmlContent: file.content, width: 44, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9)
                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5))
                            VStack(alignment: .leading, spacing: 3) {
                                highlightedText(file.name, query: query)
                                    .font(.system(size: 15, weight: .semibold)).lineLimit(1)
                                Text(file.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Color.kbSub(scheme))
                            }
                            Spacer()
                            if let tag = file.tags.first {
                                Text(tag.name)
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(Color(hex: tag.colorHex))
                                    .padding(.vertical, 3).padding(.horizontal, 7)
                                    .background(Color(hex: tag.colorHex).opacity(0.13))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(.vertical, 11).padding(.horizontal, 12)
                        .overlay(alignment: .bottom) {
                            if i < results.count - 1 { Divider().padding(.leading, 68) }
                        }
                    }
                }
            }
            .background(Color.kbSurface(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.kbCardShadow(scheme), radius: 12, x: 0, y: 4)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Highlighted text helper
    @ViewBuilder
    private func highlightedText(_ text: String, query: String) -> some View {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if let range = text.lowercased().range(of: q), !q.isEmpty {
            let before = String(text[text.startIndex..<range.lowerBound])
            let match  = String(text[range])
            let after  = String(text[range.upperBound...])
            (Text(before)
             + Text(match).foregroundStyle(Color.kbAccent).fontWeight(.bold)
             + Text(after))
                .foregroundStyle(Color.kbText(scheme))
        } else {
            Text(text).foregroundStyle(Color.kbText(scheme))
        }
    }

    private var emptyQueryView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("輸入關鍵字搜尋")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.kbSub(scheme))
                .padding(.horizontal, 18).padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.07)).frame(width: 64, height: 64)
                Image(systemName: "magnifyingglass").font(.system(size: 24))
                    .foregroundStyle(Color.kbSub(scheme))
            }
            Text("找不到「\(query)」")
                .font(.system(size: 16.5, weight: .bold))
                .foregroundStyle(Color.kbText(scheme))
            Text("試試其他關鍵字，或分享新頁面到 Keepbox。")
                .font(.system(size: 13.5))
                .foregroundStyle(Color.kbSub(scheme))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity).padding(.top, 70)
    }
}
