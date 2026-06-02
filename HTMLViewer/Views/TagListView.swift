import SwiftUI

struct TagListView: View {
    @Environment(\.colorScheme) private var scheme
    let tags: [Tag]
    let allFiles: [HTMLFile]
    let onPick: (Tag) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("標籤")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Color.kbText(scheme))
                    .padding(.horizontal, 18)
                    .padding(.top, 28).padding(.bottom, 14)

                if tags.isEmpty {
                    emptyState
                } else {
                    tagList
                }
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(Color.kbBg(scheme))
    }

    private var tagList: some View {
        VStack(spacing: 0) {
            ForEach(Array(tags.enumerated()), id: \.element.id) { i, tag in
                let count = allFiles.filter { $0.tags.contains { $0.id == tag.id } }.count
                Button { onPick(tag) } label: {
                    HStack(spacing: 13) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: tag.colorHex).opacity(0.15))
                                .frame(width: 26, height: 26)
                            Circle()
                                .fill(Color(hex: tag.colorHex))
                                .frame(width: 11, height: 11)
                        }
                        Text(tag.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.kbText(scheme))
                        Spacer()
                        Text("\(count)")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.kbSub(scheme))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.kbSub(scheme))
                    }
                    .padding(.vertical, 15).padding(.horizontal, 16)
                    .overlay(alignment: .bottom) {
                        if i < tags.count - 1 {
                            Divider().padding(.leading, 55)
                        }
                    }
                }
            }
        }
        .background(Color.kbSurface(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.kbCardShadow(scheme), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundStyle(Color.kbSub(scheme))
            Text("還沒有標籤")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.kbSub(scheme))
            Text("長按檔案 → 加上標籤")
                .font(.system(size: 14))
                .foregroundStyle(Color.kbSub(scheme).opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
