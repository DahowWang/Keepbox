import SwiftUI

/// 收藏列表的捲動錨點（外螢幕首頁、搜尋、內螢幕／Mac 收藏區共用）。
///
/// 位置存在 `LibrarySceneState.listAnchors[key]`（收藏 UUID）。和直接綁 `scrollPosition(id:)` 的差別：
/// - 容器寬度變動中（Duo 開合的過渡寬度）列表回報的頂端不寫回，避免過渡排版覆寫正確位置；
/// - 寬度穩定後明確捲回記錄的那一則並貼齊頂端（即使頂端仍是同一張、只是位移，也重新對齊）；
/// - 使用者在這段期間自己捲動，就以使用者的位置為準，取消復原。
/// `target` 把記錄的收藏對應到實際的捲動目標（卡片格以「列」為單位時對應到該列第一張）。
struct ListAnchorScroll: ViewModifier {
    let state: LibrarySceneState
    let key: String
    let target: (UUID?) -> UUID?

    @State private var position: UUID?
    /// 這個列表在 scene state 裡的捲動 owner。
    @State private var owner = UUID()

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .scrollPosition(id: $position, anchor: .top)
                .modifier(UserScrollDetector { state.setListUserScrolling($0, owner: owner) })
                .onAppear { restore() }
                // 慣性滑動中被換頁（開文章）收不到 idle：離開時重設，避免一直當成使用者在捲動。
                .onDisappear { state.setListUserScrolling(false, owner: owner) }
                .onChange(of: position) { _, new in
                    guard let new else { return }
                    state.reportListTop(new, key: key)
                    #if DEBUG
                    ListAnchorScroll.log("report key=\(key.prefix(40)) top=\(new.uuidString.prefix(8)) frozen=\(state.listAnchorsFrozen)")
                    #endif
                }
                // 寬度穩定：不以 UUID 相等判定已對齊，明確捲到目標並貼齊頂端。
                .onChange(of: state.listSettleGeneration) { _, _ in
                    guard let wanted = target(state.listAnchors[key]) else { return }
                    #if DEBUG
                    ListAnchorScroll.log("settle key=\(key.prefix(40)) scrollTo=\(wanted.uuidString.prefix(8)) current=\(position?.uuidString.prefix(8) ?? "nil")")
                    #endif
                    proxy.scrollTo(wanted, anchor: .top)
                    position = wanted
                }
                .onChange(of: key) { _, _ in restore() }
                // 外部改了錨點（關閉閱讀後定位到剛讀的那則）：跟上。
                .onChange(of: state.listAnchors[key]) { _, _ in
                    if !state.listAnchorsFrozen { restore() }
                }
        }
    }

    private func restore() {
        let wanted = target(state.listAnchors[key])
        #if DEBUG
        ListAnchorScroll.log("restore key=\(key.prefix(40)) wanted=\(wanted?.uuidString.prefix(8) ?? "nil") current=\(position?.uuidString.prefix(8) ?? "nil")")
        #endif
        if let wanted, wanted != position { position = wanted }
    }

    #if DEBUG
    static func log(_ message: String) {
        guard ProcessInfo.processInfo.arguments.contains("-layoutDebug") else { return }
        print("[KBList] \(message)")
    }
    #endif
}

/// 偵測使用者主動捲動（拖動＋慣性；不含程式捲動與排版造成的位移）。
/// 只有 iOS 18+ 有實際捲動階段；iOS 17 不偵測，對應的凍結／復原也不啟用（見 `listFreezeSupported`）。
private struct UserScrollDetector: ViewModifier {
    let onScrollingChange: (Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macCatalyst 18.0, *) {
            content.onScrollPhaseChange { _, phase in
                switch phase {
                case .interacting, .decelerating: onScrollingChange(true)
                default: onScrollingChange(false)
                }
            }
        } else {
            content
        }
    }
}

extension View {
    /// 套用收藏列表捲動錨點；`target` 預設原樣使用記錄的 ID。
    func listAnchorScroll(_ state: LibrarySceneState, key: String,
                          target: @escaping (UUID?) -> UUID? = { $0 }) -> some View {
        modifier(ListAnchorScroll(state: state, key: key, target: target))
    }
}
