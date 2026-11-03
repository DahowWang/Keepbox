import SwiftUI
import SwiftData

/// 觸控寬版的分類欄：全部／資料夾（保留巢狀）／標籤／同步。
/// 外螢幕的「資料夾」「標籤」分頁與這裡寫回同一個 `state.filter`。
struct LibrarySidebarView: View {
    @Environment(\.colorScheme) private var scheme
    @Bindable var state: LibrarySceneState
    let allFiles: [HTMLFile]
    let folders: [Folder]
    let tags: [Tag]
    let onSelect: () -> Void
    let onNewFolder: () -> Void
    let onNewTag: () -> Void
    let onSync: () -> Void

    private var sortedTags: [Tag] { tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }

    /// 深度優先攤成有縮排的列，子資料夾仍掛在父資料夾底下。
    private var folderRows: [(folder: Folder, depth: Int)] {
        let byName: (Folder, Folder) -> Bool = { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        var rows: [(Folder, Int)] = []
        var visited = Set<UUID>()
        func walk(_ folder: Folder, _ depth: Int) {
            guard visited.insert(folder.id).inserted else { return }
            rows.append((folder, depth))
            for child in folder.children.sorted(by: byName) { walk(child, depth + 1) }
        }
        for root in folders.filter({ $0.parent == nil }).sorted(by: byName) { walk(root, 0) }
        return rows
    }

    var body: some View {
        List {
            Section {
                row("全部收藏", icon: "square.stack", count: allFiles.count, filter: .all)
            }
            Section {
                if folders.isEmpty { hint("新增資料夾，整理收藏") }
                ForEach(folderRows, id: \.folder.id) { item in
                    row(item.folder.name, icon: "folder", count: item.folder.files.count,
                        filter: .folder(item.folder.id), indent: CGFloat(item.depth) * 16)
                }
            } header: {
                heading("資料夾", action: onNewFolder)
            }
            Section {
                if tags.isEmpty { hint("用標籤串起不同主題") }
                ForEach(sortedTags) { tag in
                    row(tag.name, icon: "number", count: tag.files.count, filter: .tag(tag.id),
                        color: Color(hex: tag.colorHex))
                }
            } header: {
                heading("標籤", action: onNewTag)
            }
            Section {
                Button(action: onSync) {
                    HStack(spacing: 10) {
                        SyncStatusIcon()
                        Text("同步設定").foregroundStyle(Color.kbText(scheme))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("同步設定")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Keepbox")
    }

    private func row(_ name: String, icon: String, count: Int, filter: LibraryFilter,
                     indent: CGFloat = 0, color: Color = .kbAccent) -> some View {
        let selected = state.filter == filter
        return Button {
            // 閱讀中換分類：保留文章（不在結果時顯示提示），返回目的地改成新分類。
            state.selectWhileReading(filter)
            onSelect()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(color).frame(width: 20)
                Text(name).fontWeight(selected ? .semibold : .regular).lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 2)
                Text("\(count)").font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                    .fixedSize()
            }
            .padding(.leading, indent)
            .frame(minHeight: 44)
            .foregroundStyle(selected ? Color.kbAccent : Color.kbText(scheme))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(selected ? Color.kbAccent.opacity(0.12) : nil)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func heading(_ name: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(name)
            Spacer()
            Button(action: action) {
                Image(systemName: "plus").frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.kbAccent)
            .accessibilityLabel("新增\(name)")
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(.tertiary)
    }
}
