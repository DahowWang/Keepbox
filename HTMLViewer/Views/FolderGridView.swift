import SwiftUI

struct FolderGridView: View {
    @Environment(\.colorScheme) private var scheme
    let folders: [Folder]
    let allFiles: [HTMLFile]
    let onOpen: (Folder) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("資料夾")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Color.kbText(scheme))
                    .padding(.horizontal, 18)
                    .padding(.top, 28).padding(.bottom, 14)

                if folders.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(folders) { folder in
                            let files = allFiles.filter { $0.folder?.id == folder.id }
                            FolderCard(folder: folder, files: files)
                                .onTapGesture { onOpen(folder) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(Color.kbBg(scheme))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(Color.kbSub(scheme))
            Text("還沒有資料夾")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.kbSub(scheme))
            Text("長按檔案 → 移動到資料夾")
                .font(.system(size: 14))
                .foregroundStyle(Color.kbSub(scheme).opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - Folder card
struct FolderCard: View {
    @Environment(\.colorScheme) private var scheme
    let folder: Folder
    let files: [HTMLFile]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Stacked thumbnails
            ZStack(alignment: .bottomLeading) {
                if files.count >= 3 {
                    thumbStack(files[2], dx: 32, dy: 8, rot: 8)
                }
                if files.count >= 2 {
                    thumbStack(files[1], dx: 16, dy: 4, rot: 4)
                }
                if let first = files.first {
                    thumbStack(first, dx: 0, dy: 0, rot: 0)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 48, height: 60)
                }
            }
            .frame(height: 72)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)

            HStack(spacing: 7) {
                Circle()
                    .fill(Color.kbAccent)
                    .frame(width: 10, height: 10)
                Text(folder.name)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(Color.kbText(scheme))
                    .lineLimit(1)
            }
            Text("\(files.count) 個檔案")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.kbSub(scheme))
        }
        .padding(14)
        .background(Color.kbSurface(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.kbCardShadow(scheme), radius: 12, x: 0, y: 4)
    }

    @ViewBuilder
    private func thumbStack(_ file: HTMLFile, dx: CGFloat, dy: CGFloat, rot: Double) -> some View {
        HTMLThumbnailView(htmlContent: file.content, width: 48, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.18), radius: 4)
            .rotationEffect(.degrees(rot))
            .offset(x: dx, y: -dy)
    }
}
