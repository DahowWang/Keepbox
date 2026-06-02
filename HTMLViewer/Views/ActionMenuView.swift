import SwiftUI
import SwiftData

// MARK: - Long-press action menu overlay
struct ActionMenuView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    let file: HTMLFile
    @Bindable var viewModel: FileViewModel
    let folders: [Folder]
    let tags: [Tag]
    let onClose: () -> Void
    let onOpen: (HTMLFile) -> Void

    @State private var showRename = false
    @State private var renameText = ""
    @State private var showMoveFolder = false
    @State private var showManageTag = false
    @State private var showAddTag = false
    @State private var newTagName = ""
    @State private var newTagColor = Tag.defaultColors[0]
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // Centered popup
            VStack(spacing: 14) {
                // File thumbnail
                HTMLThumbnailView(htmlContent: file.content, width: 120, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.4), radius: 20)

                // Action list
                VStack(spacing: 0) {
                    actionItem("開啟", icon: "arrow.up.right.square") { onOpen(file) }
                    divider
                    actionItem("重新命名", icon: "pencil") {
                        renameText = file.name; showRename = true
                    }
                    divider
                    actionItem("移動到資料夾", icon: "folder") { showMoveFolder = true }
                    divider
                    actionItem("加上標籤", icon: "tag") { showManageTag = true }
                    divider
                    actionItem("分享", icon: "square.and.arrow.up") { showShareSheet = true }
                    divider
                    actionItem("刪除", icon: "trash", destructive: true) {
                        viewModel.delete(file, from: modelContext)
                        onClose()
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .frame(width: 290)
            }
        }
        .alert("重新命名", isPresented: $showRename) {
            TextField("檔案名稱", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("確認") {
                viewModel.rename(file, to: renameText, context: modelContext)
                onClose()
            }
        }
        .sheet(isPresented: $showMoveFolder) {
            MoveFolderSheet(file: file, folders: folders, viewModel: viewModel,
                            isPresented: $showMoveFolder)
        }
        .sheet(isPresented: $showManageTag) {
            TagManagementSheet(file: file, tags: tags, viewModel: viewModel,
                               showAddTag: $showAddTag, newTagName: $newTagName,
                               newTagColor: $newTagColor, isPresented: $showManageTag)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [file.content])
        }
    }

    @ViewBuilder
    private func actionItem(_ label: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(destructive ? .red : Color.kbText(scheme))
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(destructive ? .red : Color.kbText(scheme).opacity(0.55))
            }
            .padding(.horizontal, 17).frame(height: 52)
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 17)
    }
}

// MARK: - Move to folder sheet
struct MoveFolderSheet: View {
    let file: HTMLFile
    let folders: [Folder]
    @Bindable var viewModel: FileViewModel
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                Button("無資料夾") {
                    viewModel.move(file, to: nil, context: modelContext)
                    isPresented = false
                }
                ForEach(folders) { folder in
                    Button(folder.name) {
                        viewModel.move(file, to: folder, context: modelContext)
                        isPresented = false
                    }
                }
            }
            .navigationTitle("移動到資料夾")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Tag management sheet
struct TagManagementSheet: View {
    let file: HTMLFile
    let tags: [Tag]
    @Bindable var viewModel: FileViewModel
    @Environment(\.modelContext) private var modelContext
    @Binding var showAddTag: Bool
    @Binding var newTagName: String
    @Binding var newTagColor: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(tags) { tag in
                        HStack {
                            Circle().fill(Color(hex: tag.colorHex)).frame(width: 12, height: 12)
                            Text(tag.name)
                            Spacer()
                            if file.tags.contains(where: { $0.id == tag.id }) {
                                Image(systemName: "checkmark").foregroundStyle(Color.kbAccent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if file.tags.contains(where: { $0.id == tag.id }) {
                                viewModel.removeTag(tag, from: file, context: modelContext)
                            } else {
                                viewModel.addTag(tag, to: file, context: modelContext)
                            }
                        }
                    }
                }
                Section {
                    Button { showAddTag = true } label: {
                        Label("新增標籤", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("管理標籤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { isPresented = false }
                }
            }
            .alert("新增標籤", isPresented: $showAddTag) {
                TextField("標籤名稱", text: $newTagName)
                Button("取消", role: .cancel) {}
                Button("新增") {
                    let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let tag = Tag(name: trimmed, colorHex: newTagColor)
                    modelContext.insert(tag)
                    try? modelContext.save()
                    newTagName = ""
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
