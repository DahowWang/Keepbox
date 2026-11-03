import CoreGraphics
import SwiftUI

/// App 自有的摺痕幾何，與 iOS 27.1 的 ReservedRegion 解耦，舊系統也能編譯與測試。
struct DivisionGeometry: Equatable {
    var frame: CGRect
    var leadingMargin: CGFloat = 0
    var trailingMargin: CGFloat = 0
    var isActive: Bool = true

    /// 直立的摺痕（左右兩頁）。零寬的 inactive 摺痕仍算，靠高度判斷方向。
    var isVertical: Bool { frame.height >= frame.width }
}

/// 版面模式（產品設計斷點，不是 Apple 裝置尺寸）。見 docs/iphone-duo-design.md §2。
/// 瀏覽與閱讀分開判斷：600pt 起寬版瀏覽，760pt 起閱讀才並排。
enum LibraryMode: Equatable {
    /// 單欄：外螢幕、窄 Split View、超大字級。沿用原手機介面。
    case narrow
    /// 寬版：分類＋收藏；閱讀依 `readerAlongside` 決定並排或單頁＋清單浮層。
    case medium
    /// 三欄：分類＋收藏清單＋文章。
    case large
}

struct LibraryLayoutDecision: Equatable {
    var mode: LibraryMode
    /// 分類欄是否並排顯示（false = 收起，可由工具列叫出浮層）。
    var sidebarTiled: Bool
    var sidebarWidth: CGFloat
    /// 閱讀時收藏清單是否常駐在文章旁；false = 單頁文章＋「收藏清單」浮層。
    var readerAlongside: Bool
    var listWidth: CGFloat
}

enum LibraryLayoutPolicy {
    // 斷點與欄寬（pt），欄寬已含欄內 padding。
    static let wideBrowseMinWidth: CGFloat = 600
    static let alongsideReadMinWidth: CGFloat = 760
    static let largeMinWidth: CGFloat = 1100
    static let readerMinWidth: CGFloat = 480
    static let listMinWidth: CGFloat = 260
    static let listMaxWidth: CGFloat = 280
    static let listMaxWidthLarge: CGFloat = 300
    static let hairline: CGFloat = 1
    static let sidebarMinWidth: CGFloat = 200

    struct Input: Equatable {
        var width: CGFloat
        var height: CGFloat
        var horizontalRegular: Bool
        var verticalRegular: Bool
        var accessibilityText: Bool
        var readerOpen: Bool
        /// 以整個 scene 根容器座標表示的摺痕。
        var divisions: [DivisionGeometry] = []
    }

    static func sidebarWidth(for width: CGFloat) -> CGFloat {
        if width < alongsideReadMinWidth { return 200 }
        if width < largeMinWidth { return 220 }
        return 240
    }

    static func decide(_ input: Input) -> LibraryLayoutDecision {
        let W = input.width
        guard input.horizontalRegular, input.verticalRegular, !input.accessibilityText,
              W >= wideBrowseMinWidth else {
            return LibraryLayoutDecision(mode: .narrow, sidebarTiled: false, sidebarWidth: 0,
                                         readerAlongside: false, listWidth: 0)
        }
        let mode: LibraryMode = W >= largeMinWidth ? .large : .medium
        let sidebar = sidebarWidth(for: W)

        guard input.readerOpen else {
            // 直立摺痕落在收藏區時：分類欄先縮到下限 200；仍讓左半邊放不下一張卡片，才收成浮層（§5）。
            if let division = input.divisions.first(where: \.isVertical), division.frame.minX > sidebar {
                let right = W - division.frame.maxX - max(division.trailingMargin, 8) - 20
                func leftOfFold(_ width: CGFloat) -> CGFloat {
                    division.frame.minX - max(division.leadingMargin, 8) - width - hairline - 20
                }
                if right >= touchCardMinWidth, leftOfFold(sidebar) < touchCardMinWidth {
                    let narrowed = sidebarMinWidth
                    let fits = leftOfFold(narrowed) >= touchCardMinWidth
                    return LibraryLayoutDecision(mode: mode, sidebarTiled: fits, sidebarWidth: fits ? narrowed : sidebar,
                                                 readerAlongside: false, listWidth: 0)
                }
            }
            return LibraryLayoutDecision(mode: mode, sidebarTiled: true, sidebarWidth: sidebar,
                                         readerAlongside: false, listWidth: 0)
        }

        // 閱讀：不足 760 → 單頁＋清單浮層；寬版瀏覽仍保留，不降回 N。
        guard W >= alongsideReadMinWidth else {
            return LibraryLayoutDecision(mode: mode, sidebarTiled: false, sidebarWidth: sidebar,
                                         readerAlongside: false, listWidth: 0)
        }
        if mode == .large {
            let list = min(listMaxWidthLarge, max(listMinWidth, W - sidebar - readerMinWidth - 2 * hairline))
            let sidebarFits = W - sidebar - list - 2 * hairline >= readerMinWidth
            if sidebarFits {
                return LibraryLayoutDecision(mode: .large, sidebarTiled: true, sidebarWidth: sidebar,
                                             readerAlongside: true, listWidth: list)
            }
        }
        let list = min(listMaxWidth, max(listMinWidth, W - readerMinWidth - hairline))
        return LibraryLayoutDecision(mode: mode, sidebarTiled: false, sidebarWidth: sidebar,
                                     readerAlongside: W - list - hairline >= readerMinWidth, listWidth: list)
    }

    // MARK: - Crease-aware grid

    static let touchCardMinWidth: CGFloat = 200
    static let narrowCardMinWidth: CGFloat = 150
    static let gridSpacing: CGFloat = 16

    struct GridPlan: Equatable {
        struct Side: Equatable {
            var originX: CGFloat
            var width: CGFloat
            var columns: Int
        }
        /// 一般格子只有一側；跨摺痕時兩側欄數相同。
        var sides: [Side]
        var totalColumns: Int { sides.reduce(0) { $0 + $1.columns } }
    }

    static func columns(for width: CGFloat, minCard: CGFloat, spacing: CGFloat = gridSpacing) -> Int {
        max(1, Int(((width + spacing) / (minCard + spacing)).rounded(.down)))
    }

    /// `containerWidth` 與 `divisions` 必須在收藏區自己的座標系。
    static func gridPlan(containerWidth: CGFloat, padding: CGFloat, minCard: CGFloat,
                         divisions: [DivisionGeometry], spacing: CGFloat = gridSpacing) -> GridPlan {
        let contentMinX = padding
        let contentMaxX = containerWidth - padding
        let whole = GridPlan(sides: [.init(originX: contentMinX, width: max(0, contentMaxX - contentMinX),
                                           columns: columns(for: contentMaxX - contentMinX, minCard: minCard, spacing: spacing))])
        guard let division = divisions.first(where: { $0.isVertical }),
              division.frame.maxX > contentMinX, division.frame.minX < contentMaxX else { return whole }

        // 摺痕兩側可用區：frame 外緣加各自 margin，整體 gutter 至少 16。
        var leadGap = max(division.leadingMargin, spacing / 2)
        var trailGap = max(division.trailingMargin, spacing / 2)
        let extra = spacing - (leadGap + trailGap + division.frame.width)
        if extra > 0 { leadGap += extra / 2; trailGap += extra / 2 }
        let leftWidth = division.frame.minX - leadGap - contentMinX
        let rightOrigin = division.frame.maxX + trailGap
        let rightWidth = contentMaxX - rightOrigin

        // 摺痕剛好在欄間邊界上：維持正常格子。
        if gapContainsDivision(whole.sides[0], spacing: spacing, division: division, leadGap: leadGap, trailGap: trailGap) {
            return whole
        }

        if leftWidth >= minCard, rightWidth >= minCard {
            let k = columns(for: min(leftWidth, rightWidth), minCard: minCard, spacing: spacing)
            return GridPlan(sides: [
                .init(originX: contentMinX, width: leftWidth, columns: k),
                .init(originX: rightOrigin, width: rightWidth, columns: k),
            ])
        }
        // 一側太窄：只用較寬的一側排單欄，不讓卡片壓在摺痕上。
        if leftWidth >= rightWidth, leftWidth > 0 {
            return GridPlan(sides: [.init(originX: contentMinX, width: leftWidth, columns: 1)])
        }
        if rightWidth > 0 {
            return GridPlan(sides: [.init(originX: rightOrigin, width: rightWidth, columns: 1)])
        }
        return whole
    }

    /// 正常格子的欄間空隙若完整包住摺痕（含 margin），就不用特別處理。
    private static func gapContainsDivision(_ side: GridPlan.Side, spacing: CGFloat, division: DivisionGeometry,
                                            leadGap: CGFloat, trailGap: CGFloat) -> Bool {
        guard side.columns > 1 else { return false }
        let cardWidth = (side.width - spacing * CGFloat(side.columns - 1)) / CGFloat(side.columns)
        for i in 1..<side.columns {
            let gapStart = side.originX + CGFloat(i) * cardWidth + CGFloat(i - 1) * spacing
            let gapEnd = gapStart + spacing
            if gapStart <= division.frame.minX - leadGap + 0.5, gapEnd >= division.frame.maxX + trailGap - 0.5 {
                return true
            }
        }
        return false
    }
}
