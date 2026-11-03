import SwiftUI

/// 唯一接觸 iOS 27.1 摺痕 API 的地方：把 ReservedRegion 轉成 App 自有的 `DivisionGeometry`。
/// iOS 17–27.0 與沒有摺痕的裝置回傳空陣列，版面照一般自適應規則排。
enum DivisionRegionAdapter {
    /// 以 `proxy` 自己的座標系回傳 `.division`，含攤平時的 inactive 摺痕，
    /// 讓欄位結構不因開合角度改變而跳動。
    static func divisions(in proxy: GeometryProxy) -> [DivisionGeometry] {
        if #available(iOS 27.1, macCatalyst 27.1, *) {
            return proxy.reservedRegions(kind: .division, options: .includeInactive).map { region in
                DivisionGeometry(frame: region.frame,
                                 leadingMargin: region.margins.leading,
                                 trailingMargin: region.margins.trailing,
                                 isActive: region.isActive)
            }
        }
        return []
    }
}
