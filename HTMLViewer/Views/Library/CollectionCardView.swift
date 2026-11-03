import SwiftUI
import SwiftData

/// 觸控（Duo 內螢幕、iPad）與桌面（Mac）的尺寸策略。
enum CollectionDensity {
    case touch
    case desktop
}

// MARK: - Card

struct CollectionCardView: View {
    @Environment(\.colorScheme) private var scheme
    let file: HTMLFile
    let density: CollectionDensity
    var isSelected = false
    let onOpen: () -> Void

    @State private var hovered = false
    @State private var source: CollectionSource?

    private var thumbHeight: CGFloat { density == .desktop ? 210 : 150 }
    private var cornerRadius: CGFloat { density == .desktop ? 12 : 16 }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { geo in
                    HTMLThumbnailView(htmlContent: file.content, width: geo.size.width, height: thumbHeight)
                }.frame(height: thumbHeight).clipped()
                Divider()
                VStack(alignment: .leading, spacing: density == .desktop ? 10 : 8) {
                    title
                    HStack {
                        Text(file.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(density == .desktop ? .system(size: 11) : .caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        if let tag = file.tags.first {
                            Text(tag.name).font(density == .desktop ? .system(size: 10, weight: .medium) : .caption2.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(Color(hex: tag.colorHex))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Color(hex: tag.colorHex).opacity(0.10), in: Capsule())
                        }
                        if let platform = source?.platform {
                            SourceBadge(platform: platform, diameter: density == .desktop ? 28 : 24)
                        }
                    }.frame(minHeight: density == .desktop ? 30 : 26)
                }.padding(density == .desktop ? 14 : 12)
            }
            .background(Color.kbSurface(scheme), in: RoundedRectangle(cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(borderColor, lineWidth: isSelected ? 2 : 1))
            .shadow(color: .black.opacity(hovered ? 0.08 : 0.025), radius: hovered ? 12 : 4, y: 3)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onAppear { updateSource() }
        .onChange(of: file.content) { _, _ in updateSource() }
        .onChange(of: file.sourceApp) { _, _ in updateSource() }
    }

    @ViewBuilder private var title: some View {
        if density == .desktop {
            Text(file.name).font(.system(size: 16, weight: .semibold)).lineLimit(3)
                .frame(height: 60, alignment: .topLeading).frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color.kbText(scheme))
        } else {
            // 觸控版隨 Dynamic Type 長高，不固定標題高度。
            Text(file.name).font(.subheadline.weight(.semibold)).lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color.kbText(scheme))
        }
    }

    private var borderColor: Color {
        if isSelected { return Color.kbAccent }
        return hovered ? Color.kbAccent.opacity(0.5) : Color.secondary.opacity(0.12)
    }

    private func updateSource() {
        source = CollectionSource.resolve(html: file.content, sourceApp: file.sourceApp)
    }
}

// MARK: - Row（並排閱讀時的收藏清單、清單排列）

struct CollectionRowView: View {
    @Environment(\.colorScheme) private var scheme
    let file: HTMLFile
    let density: CollectionDensity
    let isSelected: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 11) {
                HTMLThumbnailView(htmlContent: file.content, width: 46, height: 48)
                    .frame(width: 46, height: 48).clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 5) {
                    Text(file.name)
                        .font(density == .desktop ? .system(size: 13, weight: .semibold) : .subheadline.weight(.semibold))
                        .foregroundStyle(Color.kbText(scheme)).lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(file.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(density == .desktop ? .system(size: 11) : .caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.kbAccent)
                        .accessibilityHidden(true)
                } else if let tag = file.tags.first {
                    Circle().fill(Color(hex: tag.colorHex)).frame(width: 6, height: 6)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: density == .touch ? 60 : nil, alignment: .leading)
            .background(isSelected ? Color.kbAccent.opacity(0.10) : Color.kbSurface(scheme), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(isSelected ? Color.kbAccent.opacity(0.6) : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Source badge

/// Compact brand cues drawn locally; the full source name remains available on hover / VoiceOver.
struct SourceBadge: View {
    let platform: String
    var diameter: CGFloat = 28
    private var size: CGFloat { platform == "小紅書" ? diameter + 2 : diameter }
    private var k: CGFloat { diameter / 28 }

    var body: some View {
        ZStack {
            Circle().fill(background)
            symbol.foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        .contentShape(Circle())
        .help(platform)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("來源：\(platform)")
    }

    private var background: LinearGradient {
        let colors: [Color]
        switch platform {
        case "Facebook": colors = [Color(hex: "#1877F2")]
        case "小紅書": colors = [Color(hex: "#FF2442")]
        case "Instagram": colors = [Color(hex: "#833AB4"), Color(hex: "#E1306C"), Color(hex: "#FCAF45")]
        case "YouTube": colors = [Color(hex: "#FF0000")]
        case "GitHub": colors = [Color(hex: "#24292F")]
        default: colors = [.black]
        }
        return LinearGradient(colors: colors, startPoint: .topTrailing, endPoint: .bottomLeading)
    }

    @ViewBuilder private var symbol: some View {
        switch platform {
        case "Facebook":
            Text("f").font(.custom("HelveticaNeue-Bold", size: 29 * k)).offset(x: 1 * k, y: 4 * k)
        case "X":
            Text("X").font(.system(size: 17 * k, weight: .semibold))
        case "小紅書":
            Text("小紅書").font(.system(size: 8.5 * k, weight: .heavy)).tracking(-0.6)
        case "Instagram":
            Image(systemName: "camera").font(.system(size: 17 * k, weight: .semibold))
        case "YouTube":
            Image(systemName: "play.fill").font(.system(size: 12 * k, weight: .bold)).offset(x: 1)
        case "Threads":
            Text("@").font(.system(size: 21 * k, weight: .medium))
        case "GitHub":
            // Unmodified GitHub Invertocat (Octocat mark), © GitHub, Inc.
            // Official asset: https://brand.github.com/GitHub_Logos.zip
            // Usage / attribution: https://brand.github.com/foundations/logo
            Image("GitHubMark").resizable().scaledToFit().frame(width: 21 * k, height: 21 * k)
        default:
            Image(systemName: "link").font(.system(size: 13 * k, weight: .semibold))
        }
    }
}

// MARK: - Shared organise actions（右鍵選單與長按共用）

struct CollectionMenu: View {
    @Environment(\.modelContext) private var modelContext
    let file: HTMLFile
    let folders: [Folder]
    let tags: [Tag]
    let viewModel: FileViewModel
    let onOpen: () -> Void
    let onRename: () -> Void
    var allowsDelete = true

    private var sortedFolders: [Folder] { folders.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
    private var sortedTags: [Tag] { tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }

    var body: some View {
        Button("開啟收藏", systemImage: "doc.text", action: onOpen)
        Button("重新命名", systemImage: "pencil", action: onRename)
        Menu("移動到資料夾", systemImage: "folder") {
            Button("不使用資料夾") { viewModel.move(file, to: nil, context: modelContext) }
            ForEach(sortedFolders) { folder in
                Button {
                    viewModel.move(file, to: folder, context: modelContext)
                } label: { Label(folder.name, systemImage: file.folder?.id == folder.id ? "checkmark" : "folder") }
            }
        }
        Menu("標籤", systemImage: "tag") {
            if sortedTags.isEmpty { Button("尚無標籤，請從分類欄新增") { }.disabled(true) }
            ForEach(sortedTags) { tag in
                let hasTag = file.tags.contains { $0.id == tag.id }
                Button {
                    if hasTag { viewModel.removeTag(tag, from: file, context: modelContext) }
                    else { viewModel.addTag(tag, to: file, context: modelContext) }
                } label: { Label(tag.name, systemImage: hasTag ? "checkmark" : "number") }
            }
        }
        ShareLink(item: file.content) { Label("分享 HTML 內容", systemImage: "square.and.arrow.up") }
        if allowsDelete {
            Divider()
            Button("刪除", systemImage: "trash", role: .destructive) {
                viewModel.delete(file, from: modelContext)
            }
        }
    }
}
