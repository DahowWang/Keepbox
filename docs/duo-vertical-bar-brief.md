# 設計需求：iPhone Duo 直式側邊工具列（Phase A.2）

交辦：Claude → Codex（2026-11-04）。請產出設計，寫成 `docs/iphone-duo-design.md` 新章節「§13 Duo 直式側邊工具列」；Claude 依此實作，最後再請 Codex 審查。

## 問題

大皓在 Duo 真機（TestFlight build 20）上發現：外螢幕閱讀時「上一頁」在左上角。Apple 規範是外螢幕右側有一條**直式工具列**：返回／關閉放最上面，主要動作在下，其餘工具列與分頁列項目依原分組排在下面。我們量到的外螢幕 W=382（466 扣掉右側約 84pt），那 84pt 就是這條直式工具列的位置，現在是空的。

原因：窄版（N 模式，外螢幕與一般 iPhone）的頂列、底部分頁列和閱讀工具列，全部是用 `safeAreaInset` 自己畫的 HStack，系統不會搬走。Apple 原話："When used to build custom bars, content from sub-components ... won't be considered." 只有 `NavigationStack`／`NavigationSplitView` 的 `.toolbar` 和系統 `TabView` 才會進直式工具列。

## Apple 規範重點（Tech Talk 111462，已用 iOS 27.2 SDK swiftinterface 核對名稱）

- 系統 bar 才會進直式工具列。SplitView 只有 detail 欄參與；sheet 在外螢幕的 toolbar 也會直排。
- 順序：最上面是主要導覽（返回／關閉，自訂的用 `ToolbarItem(placement: .cancellationAction)`），接著是主要動作（`.topBarPinnedTrailing`），其餘依原分組；上下兩組之間由系統隔開。
- 直式工具列寬度固定、高度彈性：有圖示的項目直排，純文字項目維持橫排。**每個項目都要有標題加圖示**（溢出選單和展開形式會用到）。
- 已核對的 API：
  - `.axisBehavior(_:)`：`.automatic`／`.horizontalOnly`／`.verticalPreferred`。@available(anyAppleOS 27.1)
  - `.toolbarVerticalBehavior(_:)`：`.automatic`／`.disabled`。27.1
  - `.toolbarVerticalCompressionBehavior(_:)`：`.automatic`／`.prefersToolbarItems`／`.prefersTabBar`。27.1
  - `.visibilityPriority(_:)`：`.automatic`／`.high`／`.low`。iOS 27.0
  - `ToolbarOverflowMenu { }`：系統溢出選單，iOS 可用。要統一收進這裡；`ellipsis` 圖示只能給溢出選單用。
  - 數字用 `.badge(n)`，不要把數字寫進標籤文字。
  - 規範有提到可讀取直式工具列所在邊的環境值（`toolbarVerticalEdge`），但 SwiftUI swiftinterface 裡沒查到，**不要依賴它**。
- 預設由 toolbar 先壓縮，適合以導覽為主的畫面；以任務為主的畫面可讓分頁列先壓縮。
- 底部按鈕很多的單頁畫面，或只有一顆關閉鈕的 sheet，可以考慮 `.disabled`。
- RTL 語系下工具列仍在同一個硬體邊。

## 範圍與限制

- Deployment target 是 iOS 17。上面這些 API 一律包在 `#available(iOS 27.1, *)`（visibilityPriority 是 27.0）。iOS 17–26 的一般 iPhone 外觀不能退化。
- 把 N 模式外殼改成系統容器：`TabView`（全部／資料夾／標籤三個分頁）加上各分頁的 `NavigationStack` 與 `.toolbar`，以及閱讀頁的 toolbar。請一併設計一般 iPhone 的外觀（系統 tab bar 與 Liquid Glass 會跟現在的自訂底列長得不一樣），大皓要能接受。
- 內螢幕（M/L）已經用系統 toolbar：WideLibraryView 的 NavigationSplitView／NavigationStack，以及 WideReaderView。請確認攤開時這些項目的直排行為、順序與 axisBehavior 也正確，例如排列 Menu、同步、新增、字級、標籤、分享、原文、焦點切換、收藏清單浮層按鈕。
- 不改的部分：斷點（600／760／1100）、ReaderSession 單一 WKWebView 換容器、錨點與 SceneStorage 行為、外螢幕不做橫式、多視窗留 Phase B、Mac 介面。
- 要保留的現有功能：三種排列、搜尋（預設全部，可切目前分類）、長按整理、同步狀態按鈕（44pt、VoiceOver 狀態）、匯入流程、ActionMenu、toast、閱讀頁的「內容已更新」橫幅、原文按鈕在沒有 URL 時隱藏。

## 請產出

1. 每個畫面的項目清單：首頁三個分頁、搜尋、閱讀、標籤 sheet、匯入 sheet、同步設定。每個項目列出 placement、標題、SF Symbol、axisBehavior、visibilityPriority、是否放進 ToolbarOverflowMenu、badge。
2. 外螢幕直式工具列由上到下的 ASCII 示意，以及一般 iPhone 的對照圖。
3. 壓縮策略：各畫面用 toolbar 先壓縮還是 tab bar 先壓縮。
4. 哪些畫面（或 sheet）用 `.toolbarVerticalBehavior(.disabled)`。
5. iOS 17–26 的退路，以及 VoiceOver、Dynamic Type 的注意事項。
6. 驗收清單：外螢幕、內螢幕攤開、一般 iPhone 17 Pro 26.5、iPad。

## 相關檔案

- `docs/iphone-duo-design.md`：既有設計。
- `HTMLViewer/Views/Library/AdaptiveLibraryView.swift`：NarrowLibraryView 與 WideLibraryView，含自訂底部分頁列。
- `HTMLViewer/Views/FileDetailView.swift`：窄版 ReaderView 的自訂頂列與底部工具列。
- `HTMLViewer/Views/FileListView.swift`（HomeView）、`HTMLViewer/Views/SearchView.swift`、`HTMLViewer/Views/FolderGridView.swift`、`HTMLViewer/Views/TagListView.swift`。
- `HTMLViewer/Views/Reader/ReaderChrome.swift`：WideReaderView 的 toolbar、ReaderFontMenu、ReaderTagSheet。
- `HTMLViewer/Sync/SyncStatusButton.swift`。

參考：https://developer.apple.com/videos/play/tech-talks/111462/
