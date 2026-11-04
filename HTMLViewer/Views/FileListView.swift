import SwiftUI
import SwiftData

// MARK: - HomeView (全部 tab content)
/// 窄版「全部」分頁內容。標題、新增、搜尋、同步、排列、排序都在系統工具列（AdaptiveLibraryView），
/// 這裡只放分類 chips 與收藏內容，讓 Duo 外螢幕可把工具搬進直式側邊列。
struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Bindable var state: LibrarySceneState
    let allFiles: [HTMLFile]
    let folders: [Folder]
    let tags: [Tag]
    let onOpen: (HTMLFile) -> Void
    let onLong: (HTMLFile) -> Void

    private var files: [HTMLFile] { state.results(from: allFiles) }
    private var layout: KBLayout { state.layout }
    private var selectedFolder: Folder? { state.folderID().flatMap { id in folders.first { $0.id == id } } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                filterChips
                if let folder = selectedFolder {
                    Text(folder.name)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(Color.kbText(scheme))
                        .padding(.horizontal, 18)
                        .padding(.top, 14).padding(.bottom, 12)
                }
                contentArea
            }
            .padding(.bottom, 16)
        }
        .listAnchorScroll(state, key: state.listAnchorKey)
        .scrollIndicators(.hidden)
        .background(Color.kbBg(scheme))
    }

    // MARK: - Filter chips
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "全部", tag: nil)
                ForEach(tags) { tag in chip(label: tag.name, tag: tag) }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func chip(label: String, tag: Tag?) -> some View {
        let isOn = tag.map { state.filter == .tag($0.id) } ?? (state.filter == .all)
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                state.select(tag.map { .tag($0.id) } ?? .all)
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? .white : Color.kbSub(scheme))
                .padding(.vertical, 6).padding(.horizontal, 14)
                .background(isOn ? Color.kbAccent : Color.kbSurface(scheme))
                .clipShape(Capsule())
                .shadow(color: isOn ? Color.kbAccent.opacity(0.3) : (scheme == .light ? .black.opacity(0.06) : .clear), radius: 6)
        }
    }

    // MARK: - Content area
    @ViewBuilder
    private var contentArea: some View {
        if files.isEmpty {
            emptyState
        } else {
            switch layout {
            case .grid:    gridLayout
            case .gallery: galleryLayout
            case .list:    listLayout
            }
        }
    }

    private var gridLayout: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(files) { file in
                KBGridCard(file: file, onOpen: { onOpen(file) }, onLong: { onLong(file) })
            }
        }
        .scrollTargetLayout()
        .padding(.horizontal, 16)
    }

    private var listLayout: some View {
        VStack(spacing: 0) {
            ForEach(Array(files.enumerated()), id: \.element.id) { i, file in
                KBListRow(file: file, isLast: i == files.count - 1,
                          onOpen: { onOpen(file) }, onLong: { onLong(file) })
            }
        }
        .scrollTargetLayout()
        .background(Color.kbSurface(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.kbCardShadow(scheme), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var galleryLayout: some View {
        if let featured = files.first {
            VStack(spacing: 14) {
                KBFeaturedCard(file: featured, onOpen: { onOpen(featured) }, onLong: { onLong(featured) })
                    .id(featured.id)
                ForEach(Array(files.dropFirst())) { file in
                    KBGalleryRow(file: file, onOpen: { onOpen(file) }, onLong: { onLong(file) })
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.kbSurface(scheme))
                    .frame(width: 100, height: 90)
                    .shadow(color: Color.kbCardShadow(scheme), radius: 10)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.kbAccent.opacity(0.15))
                    .frame(width: 96, height: 26)
                    .offset(y: -32)
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(Color.kbAccent)
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.kbAccent.opacity(0.5), radius: 12)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(y: -46)
            }
            .padding(.top, 60)

            Text("Keepbox 還是空的")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.kbText(scheme))

            Text("從 Line、Messenger 或瀏覽器分享 HTML 頁面，\n或點工具列的 ＋ 新增收藏。")
                .font(.system(size: 14.5))
                .foregroundStyle(Color.kbSub(scheme))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Grid card
struct KBGridCard: View {
    @Environment(\.colorScheme) private var scheme
    let file: HTMLFile
    let onOpen: () -> Void
    let onLong: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { geo in
                    HTMLThumbnailView(htmlContent: file.content, width: geo.size.width, height: 118)
                }
                .frame(height: 118)
                    .overlay(alignment: .topLeading) {
                        if let tag = file.tags.first {
                            Text(tag.name)
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 3).padding(.horizontal, 8)
                                .background(Color(hex: tag.colorHex))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(8)
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name)
                        .font(.system(size: 13.5, weight: .bold))
                        .lineLimit(1)
                        .foregroundStyle(Color.kbText(scheme))
                    Text(file.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.kbSub(scheme))
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
        }
        .background(Color.kbSurface(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.kbCardShadow(scheme), radius: 12, x: 0, y: 4)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in onLong() })
    }
}

// MARK: - List row
struct KBListRow: View {
    @Environment(\.colorScheme) private var scheme
    let file: HTMLFile
    let isLast: Bool
    let onOpen: () -> Void
    let onLong: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                HTMLThumbnailView(htmlContent: file.content, width: 44, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(Color.kbText(scheme))
                    Text(file.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.kbSub(scheme))
                }
                Spacer()
                if let tag = file.tags.first {
                    Text(tag.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: tag.colorHex))
                        .padding(.vertical, 3).padding(.horizontal, 8)
                        .background(Color(hex: tag.colorHex).opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }
            .padding(.vertical, 9).padding(.horizontal, 12)
            .overlay(alignment: .bottom) {
                if !isLast { Divider().padding(.leading, 68) }
            }
        }
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in onLong() })
    }
}

// MARK: - Featured card (gallery)
struct KBFeaturedCard: View {
    let file: HTMLFile
    let onOpen: () -> Void
    let onLong: () -> Void

    var body: some View {
        Button(action: onOpen) {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    HTMLThumbnailView(htmlContent: file.content,
                                     width: geo.size.width, height: 190)
                    LinearGradient(colors: [.clear, .black.opacity(0.82)],
                                   startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 7) {
                        if let tag = file.tags.first {
                            Text(tag.name)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 3).padding(.horizontal, 9)
                                .background(Color(hex: tag.colorHex))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Text(file.name)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white).lineLimit(2)
                        Text(file.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 16).padding(.bottom, 14)
                }
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in onLong() })
    }
}

// MARK: - Gallery compact row
struct KBGalleryRow: View {
    @Environment(\.colorScheme) private var scheme
    let file: HTMLFile
    let onOpen: () -> Void
    let onLong: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 13) {
                HTMLThumbnailView(htmlContent: file.content, width: 58, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name)
                        .font(.system(size: 15, weight: .bold)).lineLimit(1)
                        .foregroundStyle(Color.kbText(scheme))
                    Text(file.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.kbSub(scheme))
                }
                Spacer()
                if let tag = file.tags.first {
                    Circle()
                        .fill(Color(hex: tag.colorHex))
                        .frame(width: 9, height: 9)
                        .padding(.trailing, 6)
                }
            }
            .padding(9)
            .background(Color.kbSurface(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.08), lineWidth: 0.5))
        }
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in onLong() })
    }
}
