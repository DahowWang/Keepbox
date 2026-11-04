# Keepbox iPhone Duo 介面設計

日期：2026-11-03。狀態：設計交付，尚未實作／建置／操作驗收。

本輪只新增／修訂這份設計文件；不修改 Swift、資產、Info.plist、project.yml 或 Xcode 專案，不 commit。下列檔案清單是後續 Claude 的實作規格，不代表已完成。Obsidian 另存工作紀錄與目前計畫。

## 1. 設計結論與證據

外螢幕保留「全部／資料夾／標籤」與三種排列的熟悉操作，補上安全區域適應，外螢幕維持直式。內螢幕採「瀏覽時分類＋收藏，閱讀依寬度並排或單頁＋清單浮層」，空間足夠才同時展示三欄。分類可暫時收起，閱讀不因摺疊跳回首頁。Mac 共用內容元件與狀態規則，保留桌面外殼、快捷鍵、滑鼠操作及現有卡片尺度。

### 已確認

- 已閱讀 ContentView、FileDetailView、MacLibraryView、FolderGridView、TagListView、FileListView、ImportSheetView、SearchView、SyncStatusButton、WebView、HTMLViewerApp、FileViewModel、HTMLFile、ShareViewController 與 project.yml。
- 本機 `xcodebuild -version`：Xcode 27.2（27B52）；`xcrun --sdk iphoneos --show-sdk-path` 指向 iPhoneOS27.2.sdk。第 9 節 API 以此 SDK 的 swiftinterface／標頭為依據。
- 初稿查核時，`simctl list devicetypes` 有 `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`；但 `simctl list devices available` 沒有已建立的 Duo，已安裝 iOS runtime 只有 26.4、26.5、27.0。**有裝置型別不等於可驗收 27.1 API**；本次沒有啟動或新增模擬器，也沒有下載 runtime。
- 後續 Claude 回報已在 iOS 27.2 Duo 以 `simctl io enumerate` 取得 framebuffer；尺寸與待確認的 pt 換算見 §2。此為收到的實測回報，本次未自行重跑，初稿 runtime 限制不再視為目前環境結論。
- 工作區已有未提交變更：ContentView.swift、ImportSheetView.swift、HTMLViewer.xcodeproj/project.pbxproj，以及未追蹤的 MacLibraryView.swift、GitHubMark.imageset。後續實作須以當下檔案為基礎，不能 reset、覆寫或整批提交他人變更。

官方資料確認：內螢幕 regular/regular，不能靠 supported orientations 限制版面；SDK 27.1 起有新的滿版與系統直向工具列處理；安全區域可能左右不對稱。採 size class、實際容器與標準導覽元件，背景才延伸至安全區外。[Apple Tech Talk](https://developer.apple.com/videos/play/tech-talks/111461/)

硬體面板為外螢幕 1398 × 2034、內螢幕 1878 × 2670，兩面支援 Apple Pencil（USB-C）。**像素不是 SwiftUI point，也不是商店截圖規格**；本文件不從面板解析度猜測邏輯寬度。[Apple 技術規格](https://www.apple.com/iphone-duo/specs/)

## 2. 尺寸、版面判斷與視覺規範

所有介面尺寸均為 pt，商店截圖另標 px。`W`／`H` 是目前 scene 根內容的安全區域可用寬／高，包含系統工具列布局後的結果；已在 safe area 內量測就不能再扣一次 inset。左右 inset 各自處理。格子用自身容器 `C`，不用整個螢幕寬度。

判斷順序：使用者的全螢幕閱讀選擇 → 可讀性（含 Dynamic Type）→ size class 與 W → 摺痕資訊。方向與鉸鏈角度都不是版面開關。以下為**產品設計斷點，非 Apple 裝置尺寸**；實測系統欄寬限制後可調整，但不能犧牲最低可讀寬度。

瀏覽與閱讀採**獨立門檻**：瀏覽在 600pt 起進入 M，閱讀在 760pt 起才並排。M 是 regular 寬版體驗，**不代表每個頁面必須同時顯示兩欄**；600–759pt 的閱讀為單頁＋可叫出清單，仍保留寬版分類、搜尋與返回上下文。

| 模式 | 條件 | 無閱讀選取 | 已開啟收藏 |
|---|---|---|---|
| N 單欄 | horizontal compact，或 W < 600，或 vertical compact，或輔助使用超大字體 | 原有三分頁，單一瀏覽區 | 單頁閱讀；返回原瀏覽位置 |
| M 窄幅寬版 | regular/regular 且 600 ≤ W < 760 | 分類 200–220（理想 200）＋收藏區至少 379；依剩餘空間排一／兩欄卡片 | **單頁文章＋「收藏清單」按鈕**；清單以浮層叫出，不常駐擠壓文章 |
| M 並排寬版 | regular/regular 且 760 ≤ W < 1100 | 分類 200–240（理想 220）＋收藏區 | 清單 260–280（理想 260）＋閱讀 ≥ 480；分類由按鈕叫出 |
| L 三欄 | regular/regular 且 W ≥ 1100 | 分類 220–260＋收藏區 | 分類 220–260＋清單 260–300＋閱讀 ≥ 480 |
| F 專注閱讀 | 使用者點「展開閱讀」，任何寬度 | 不適用 | 只留文章與必要工具；回原模式時，W < 760 用「返回閱讀」，W ≥ 760 用「返回並排」 |
| Mac | Catalyst，沿用目前最小視窗 900 × 560 | 側邊欄 210＋自適應卡片 | 夠寬時 210＋280＋閱讀 ≥ 480；不足先收側邊欄，不能把文章擠到 400 以下 |

欄寬包含欄內 padding；分隔線為一個實體像素（記為 d），**不可再在總寬外加一次欄內邊距**。600pt 時分類固定 200，收藏區為 400−d，可先顯示一張寬卡；不為塞兩張卡壓縮標題。M 窄幅的分類以 200 為預設，只有使用者／系統需要時才擴到 220。無摺痕限制時，兩張 200pt 卡＋16 間距＋40 內距需 C ≥ 456，所以預設分類下 W ≥ 656＋d 才顯示兩張；達不到就一張。摺痕處理仍以第 5 節優先。

760pt 閱讀下界採清單 260＋閱讀 480＋d，保留約 20pt 餘裕。清單理想 260，在 W ≥ 760 時可放寬至 `min(280, W − 480 − d)`；不能因系統強制欄寬而把閱讀壓到 480 以下。若系統實際分配不滿足最低寬度，閱讀改單頁＋清單浮層，**不要連瀏覽模式也降回 N**。1100pt 三欄門檻不變。切換欄數不重設任何資料狀態。

Claude 回報的 iOS 27.2 Duo framebuffer：內螢幕 2007 × 2853px、外螢幕 1398 × 2034px（`simctl io enumerate`）。若 scale 為 3，整個視窗候選尺寸為內直 669 × 951pt、內橫 951 × 669pt、外直 466 × 678pt；**這是待 App 驗證的推算，並非已量測的 W/H**。須用 GeometryReader、displayScale 與每側 safe-area inset 確認：

- 內直候選 669：扣除安全區後若 W 仍 ≥ 600，瀏覽進 M 窄幅、分類 200；閱讀為單頁＋清單浮層。只有在實際 W = 669 時，收藏區才是 469−d，而不是直接以 framebuffer 推算後套用。
- 內橫候選 951：若實際 W ≥ 760，瀏覽進 M 並排寬版，閱讀用 260–280 清單＋至少 480 文章；若 inset 使 W 跌破 760，改單頁＋清單浮層。
- 外直候選 466：horizontal compact，仍走 N；外螢幕橫式本版不做。
- 若內直實測 W < 600，按真實尺寸降級並記錄 inset／系統欄寬；先確認是否重複扣除 safe area，再評估設計。不得為了讓裝置名稱符合預期而偽造 W 或強制雙欄。

視覺沿用現有紫色 `#5B53E0`、淺底 `#F4F3FB`／深底 `#0c0c0f` 與卡片底色。觸控按鈕至少 44 × 44；Mac 允許現有較小視覺尺寸。內容邊距 N 16、M/L 20，卡片間距 16、圓角 16。文字用系統語意字級，標題可兩至三行且隨字級長高，不沿用 Mac 卡片固定 60pt 標題高到觸控版。

來源小圓圖示位於右下日期列，視覺 20–24pt；預設只是來源資訊，不做過小的點擊目標。未知來源隱藏；提供 VoiceOver 來源名稱，保留 GitHub 官方圖檔。選取同時用邊框／勾選及語音標示，不能只靠紫色。Pencil 可執行點選與捲動，不新增筆記或 hover 才能發現的操作。

## 3. 各姿態 ASCII 線框圖

線框圖的工具列表示功能集合；內螢幕實際由系統排到上方或左右邊緣，不額外畫一條重複工具列。

### 3.1 外螢幕直式：N

```text
+-----------------------------+
| 安全區／系統狀態列           |
| 全部收藏      搜尋 同步 排列  | 觸控 >= 44
| [資料夾／標籤篩選]    排序    |
| +-------------------------+ |
| | 清單列／雙欄格／圖文排列 | | 內距 16
| | 日期、標籤、來源圓圖示   | |
| +-------------------------+ |
|                  [ + ]      | 新增 52，與內容留距
| [全部] [資料夾] [標籤]       | 底部 safeAreaInset
+-----------------------------+
        開啟收藏 ↓
+-----------------------------+
| < 返回       收藏標題   更多 |
|                             |
|           WKWebView         |
|                             |
| 字級   標籤   分享   原文     | safeAreaInset／系統 bar
+-----------------------------+
```

保留 grid、gallery、list 與預設 list。網格最小卡片寬 150；容器放不下兩欄時一欄，gallery 維持單欄。所有捲動區尾端須可捲過底部導覽與新增按鈕。閱讀返回恢復原分頁、資料夾／標籤、搜尋結果與捲動錨點。原文不存在時隱藏該動作，不能保留目前沒有動作的空按鈕。

### 3.2 外螢幕橫式／帳篷：未來參考，本版不做

```text
+----------------------------------------------------+
| < 返回   標題                         字級 分享 更多 | >=44
|                                                    |
|       文章／目前收藏清單；使用完整可用寬度           |
|                                                    |
+----------------------------------------------------+
  左右 inset 分別量測；H < 420 時收起浮動底部工具列
```

依 §12 已確認決定：本版不開放外螢幕與一般 iPhone 橫式，不修改 project.yml 的 iPhone orientations；上圖僅留作未來參考，不列入本版實作與驗收。內螢幕仍須依容器完整適應兩方向，不能以此決定跳過內螢幕橫放驗收。

### 3.3 內螢幕全螢幕：瀏覽 600 起寬版，閱讀 760 起並排

```text
M 窄幅瀏覽：600 <= W < 760（內直 669 為未扣 inset 的候選）
+--------------+-------------------------------------+
| Keepbox      | 搜尋                 排列 同步 新增 |
| 全部收藏     | 分類名稱 / 數量                     |
| 資料夾       | [卡片 A] [卡片 B]  <- C >= 456 才兩欄|
|   工作       | [卡片 C] [卡片 D]                   |
| 標籤         | 較窄時一張寬卡；摺痕另依第 5 節   |
| 同步設定     |                                     |
+--------------+-------------------------------------+
  200 理想             C = W - 200 - d
  實際 W=669 時 C=469-d；W=620 時 C=420-d，改一欄卡片

M 窄幅閱讀：600 <= W < 760
+----------------------------------------------------+
| < 返回收藏   收藏清單   標題          字級 分享 更多 |
|                                                    |
|              單一 WKWebView 使用全寬                |
|                                                    |
+----------------------------------------------------+
  「收藏清單」點擊後，出現 280–320 寬的系統 popover：
  +------------------+
  | 搜尋 / 分類      |  不改底下文章 frame 或 viewport
  | [A：目前文章]    |  點 B → 同一閱讀區開 B，浮層收起
  | [B] [C] …        |  點外側／取消 → 留在 A 原位置
  +------------------+

M 並排閱讀：760 <= W < 1100（內橫候選 951 需先扣 inset）
+--------------------+-------------------------------+
| 分類 搜尋          | 標題     展開閱讀 字級 分享 …  |
| [收藏 A：選取]     |                               |
| [收藏 B]           |          WKWebView            |
| [收藏 C]           |                               |
+--------------------+-------------------------------+
   260 理想、最多 280           >= 480

L 閱讀：W >= 1100
+--------------+-----------------+-------------------+
| 全部／分類   | 搜尋／收藏清單  | 標題與閱讀工具    |
| 資料夾       | [選取 A]        |                   |
| 標籤         | [B]             |    WKWebView      |
| 同步設定     | [C]             |                   |
+--------------+-----------------+-------------------+
    220–260         260–300              >= 480
```

同一時間只有一個主要文章視圖。未選取文章時不放空白閱讀欄。點卡片後，600–759pt 開單頁文章，760pt 起開並排；「關閉閱讀／返回收藏」回收藏格並定位該收藏，不改排列偏好。M 窄幅**不是外螢幕 N 的三分頁畫面**：瀏覽保留分類＋收藏；閱讀的「收藏清單」是可叫出、帶目前選取與搜尋／分類入口的上下文清單。

分類浮層建議寬 280；閱讀清單浮層理想寬 300、範圍 280–320，兩者都不得超過 W−32，高度不得超過可用 H−32，內容可捲動。用系統 popover，系統判斷不適合時可轉 sheet；一次只開一個浮層，清單中的分類入口在同一浮層切換內容，不再堆一個 popover。開／關浮層不調整 WKWebView 寬度、不重載 HTML。更換文章後關閉浮層，保留 query、scope 與清單錨點。

regular/regular 的 W < 600 才進 N。M 的瀏覽與閱讀分別判斷，不再共用單一「雙欄是否啟用」布林值。NavigationSplitView 可管理常駐欄位，M 窄幅閱讀用 detailOnly＋清單 popover；M 並排閱讀顯示 content＋detail，分類由按鈕叫出。無閱讀時顯示分類＋瀏覽區。若系統自動 collapse，依實際欄寬降級閱讀呈現，但 state 與寬版分類入口不丟失。

跨 760pt 時：窄變寬把清單還原為常駐欄、收起同一清單浮層；寬變窄收起常駐清單，保留目前文章與「收藏清單」按鈕，不自動彈浮層。ReaderSession 仍是同一份。只有使用者主動開 F 才維持專注閱讀、不隨放寬自動出現清單。

### 3.4 內螢幕 Split View

```text
+----------------------+||+---------------------------+
| Keepbox：N           |||  其他 App                   |
| 返回 / 搜尋 / 更多   |||                             |
| 收藏清單 或 文章     |||                             |
|                      |||                             |
+----------------------+||+---------------------------+
   W < 600 為 N；regular/regular 的瀏覽 >= 600 寬版、閱讀 >= 760 並排
```

以 App 自己的容器量測，不根據「佔全螢幕一半」推算寬度。左右分割各測一次，不對稱系統工具列不可遮住返回或新增。拖曳分隔線跨斷點時保留目前文章；窄版返回能到正確分類／搜尋結果，放寬再恢復並排。

### 3.5 Mac

```text
+------------+-----------------------------------------------+
| Keepbox    | 即時搜尋          排序 排列 同步 新增         |
| 全部       +------------------+----------------------------+
| 資料夾     | 收藏清單 280     | 閱讀工具列                 |
| 標籤       | A（選取）        |                            |
| 同步       | B                | 文章                       |
+------------+------------------+----------------------------+
     210                            閱讀 >= 480
```

未閱讀時中右合併為網格，維持現有 370–480pt 卡片、可放三欄時三欄；不強迫每個視窗三欄。最窄 900pt 視窗閱讀時先收分類，保留可讀文章。保留 Cmd-F、Cmd-N、Escape、右鍵整理、滑鼠 hover 與匯出。Mac 特有視窗尺寸限制只能留在 Catalyst 分支。

## 4. 元件共用與後續逐檔工作計畫

**不要直接拿掉 MacLibraryView.swift 最外層的 Catalyst guard。** 它包含桌面視窗限制、尺寸、快捷鍵與獨立 WebView 策略，須先抽內容，再做各自外殼。共用依據是可用空間與輸入方式，不是名稱含 Mac 或 Duo。

### 新增檔案（後續實作）

| 路徑 | 責任 |
|---|---|
| `HTMLViewer/ViewModels/LibrarySceneState.swift` | 每 scene 的路由、filter、query、layout、sort、選取 UUID、返回上下文、sheet 草稿與列表錨點；可序列化的復原快照 |
| `HTMLViewer/Views/Library/AdaptiveLibraryView.swift` | 依第 2 節決定 N/M/L/F；持有導航欄可見狀態，接收 scene state，不持有另一份選取 |
| `HTMLViewer/Views/Library/LibrarySidebarView.swift` | 全部／資料夾／標籤共用內容；觸控與桌面密度參數；保留巢狀資料夾關係，不將子資料夾當根資料夾攤平 |
| `HTMLViewer/Views/Library/CollectionBrowserView.swift` | 共用結果清單、空狀態、排序與排列；接收已過濾資料；穩定 UUID 錨點 |
| `HTMLViewer/Views/Library/CollectionCardView.swift` | 卡片／清單共同資訊與右下來源徽章；尺寸策略區分觸控與桌面 |
| `HTMLViewer/Views/Library/CollectionActions.swift` | 改名、移動、標籤、刪除、分享與開原文的共同動作；長按與右鍵共用 |
| `HTMLViewer/Utilities/CollectionSource.swift` | 從 MacCollectionSource 抽出的來源判定與原文網址；沿用規則及現有資產，不用內文提到的平台充當來源 |
| `HTMLViewer/Utilities/LibraryLayoutPolicy.swift` | 純尺寸／可讀性判斷；輸入 W/H、size classes、字級及一般化 division rectangles，輸出欄配置 |
| `HTMLViewer/Utilities/DivisionRegionAdapter.swift` | 唯一 27.1 摺痕 API 邊界；將 ReservedRegion 轉為自有幾何值；舊版回傳空集合 |
| `HTMLViewer/ViewModels/ReaderSession.swift` | scene＋收藏 UUID 的閱讀 session；捲動錨點、字級、縮放；協調 WebView 重掛載 |
| `HTMLViewer/Views/Reader/ReaderChrome.swift` | 觸控用標準 toolbar／safe area 工具列；桌面以同一組動作產生桌面列 |

### 修改檔案（後續實作）

| 路徑 | 變更與邊界 |
|---|---|
| `Views/ContentView.swift` | 保留匯入、同步掛接與通知行為；把導航狀態提升到 scene state，接 AdaptiveLibraryView；sheet presenter 留在穩定根層，不能因欄數切換重建 |
| `Views/MacLibraryView.swift` | 抽共用卡片、來源、清單與動作，保留 Catalyst 外殼；移除「過濾結果不含文章就關閉閱讀」副作用，按第 6 節處理 |
| `Views/FileListView.swift` | HomeView 改接共同 state／browser；保留 grid/gallery/list，消除硬編碼底部遮擋高度 |
| `Views/FolderGridView.swift`、`Views/TagListView.swift` | 保留外螢幕入口；選擇回寫同一 filter，雙欄用 sidebar 呈現相同資料 |
| `Views/SearchView.swift` | 移除本地獨立 query；明示搜尋範圍，綁定共同 query；避免重新出現就無條件搶鍵盤焦點 |
| `Views/FileDetailView.swift` | ReaderView 改接 ReaderSession／共用動作；替換頂部 56、漸層 110、底部 30 等定位魔術數字；標籤與原文按鈕必須有功能或隱藏 |
| `Utilities/WebView.swift` | 保留桌面設計寬度判斷與 pinch zoom；增加容器 resize 後 viewport 更新與讀取位置復原；禁止每次 resize 都 loadHTMLString |
| `Views/ActionMenuView.swift` | 共用整理動作；compact 依舊可長按，regular 用 context menu／popover，避免全螢幕遮罩掩住另一欄 |
| `Views/ImportSheetView.swift` | 草稿移至穩定狀態、呈現依容器適應；保留既有 Mac 修改及 fileImporter 安全存取流程 |
| `Sync/SyncStatusButton.swift` | 觸控命中範圍至少 44；顯示可朗讀的同步狀態，保留既有狀態來源 |
| `Sync/SyncSettingsView.swift` | 表單內容可捲動、窄寬與大字型不裁切；不改憑證／同步協定 |
| `HTMLViewerApp.swift` | 每 scene 建立獨立 state，共用既有 ModelContainer；先完成復原，再考慮多視窗 |
| `project.yml`、`HTMLViewer/Info.plist` | 本版維持 iPhone 直式 orientations 與 deployment target 17.0；不因斷點修訂更改專案設定或手改 pbxproj |
| `ShareExtension/ShareViewController.swift` | 僅呈現檢查及必要 safe-area／大字體修正；保留 App Group pending 寫檔與完成流程 |

以上相對路徑除 project.yml／ShareExtension 外均在 HTMLViewer 下。`HTMLThumbnailView.swift` 如需變更，只限依所在 view 的 displayScale 與尺寸產生縮圖，避免旋轉重新渲染全部卡片；不可每卡長駐一個閱讀用 WKWebView。

**刪除：無。** 舊 private 型別只有在引用全數改接共用元件、確認功能對等後才移除其宣告，不刪既有 Swift 檔或資產。SwiftData schema、Cloudflare server、Shared 的收藏解析與同步資料格式不在此階段變更範圍。

### Claude 的實作順序與完成門檻

1. 記錄當下 git diff、檢查現有 AGENTS.md；保護未提交 Mac 工作。先加 scene state、layout policy、SDK adapter，不改資料模型。
2. 抽來源、動作、卡片／清單；先驗 Mac 原功能與外螢幕三分頁／三排列未退化。
3. 加 M/L/F 外殼、搜尋共用與 safe area；處理摺痕格子。不要同時引入 TabView sidebar 與 NavigationSplitView sidebar，避免兩套分類入口。
4. 完成 ReaderSession、resize／viewport／錨點復原，驗收摺疊及 Split View；不接受「畫面有保留但閱讀回頂端」。
5. 調整 sheet、匯入草稿、內螢幕兩方向與輔助使用。Phase A 完成此步及第 10 節基本驗收即可，不依賴 Phase B 多視窗。
6. Phase B 才實作新視窗，依第 7 節建立可靠交付與錯誤處理，再驗證多 scene 同步協調。

後續驗證指令（本次未執行）：

```sh
xcodegen generate
xcodebuild -list -project HTMLViewer.xcodeproj
xcodebuild -project HTMLViewer.xcodeproj -scheme HTMLViewer -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/keepbox-duo-ios CODE_SIGNING_ALLOWED=NO build
xcodebuild -project HTMLViewer.xcodeproj -scheme HTMLViewer -destination 'generic/platform=macOS,variant=Mac Catalyst' -derivedDataPath /private/tmp/keepbox-duo-mac CODE_SIGNING_ALLOWED=NO build
```

先確認實際 scheme 名稱；目前 repo 未看到測試 target，不能宣稱 `xcodebuild test` 已有涵蓋。後續應為純 layout policy、scene 狀態轉換與來源解析建立有意義的測試；WebView resize／互動另做 UI 驗收。執行 xcodegen 前後須比對 project.pbxproj，保留原有未提交變更。

## 5. 摺痕策略

查詢必須發生在**收藏區自己的 GeometryProxy 座標系**；不能把整個視窗的中線硬套到扣除 sidebar 後的網格。查 `.division` 並以 `.includeInactive` 保留攤平後的結構。使用回傳 frame 與 margins，不猜測摺痕寬度，也不能用非零 rect intersection 把零寬的 inactive division 過濾掉。

### 卡片格

- 無 division：觸控寬版最小卡片 200，間距 16，左右內距 20；`n = max(1, floor((C - 40 + 16) / (200 + 16)))`。N 模式改最小 150、內距 16。Mac 維持 370–480，不套觸控公式。
- 垂直 division 穿過網格：先算左右可用區（frame 外緣加各自 margins；一般 gutter 至少 16）。兩側都 ≥ 200 時，各側放相同 `k` 欄：`k = floor((min(leftWidth, rightWidth) + 16) / 216)`，至少 1。整體為 2k 欄，一個共同垂直捲動容器，資料按視覺列由左至右填入，VoiceOver 同序。
- **偶數欄本身不保證避開摺痕**：側邊欄可能令兩側不對稱。網格需對準實際 division；若一側小於 200，先將分類收為浮層、重新量測，再嘗試雙區格子。仍不夠就用較寬側的單欄清單，不讓卡片標題／按鈕壓在 division 上；另一側留白，提供專注閱讀入口。
- division 在收藏區外，不因為裝置可摺疊就改成偶數欄。若 division 已在欄間邊界，保留正常格子。
- 橫向 division：不用「偶數欄」解決。收藏仍是連續可捲動內容，允許卡片捲過中線；固定控制項不得停在區域內。若需要常駐操作，放安全的頂／底邊，不能不停插入空白讓捲動跳動。
- 開合只更新幾何，不用角度閾值反覆重排；停用大幅欄位動畫，尊重 Reduce Motion。攤平後維持原來結構，直到視窗尺寸／篩選／排列真正改變。

### 閱讀

WKWebView 保持單一連續頁面，可跨摺痕，不切成兩個 web view、不注入中線空白、不為鉸鏈角度改 CSS 欄數。只有容器真正改變才重新計算 viewport，並按第 6 節復原位置。原本桌面頁 700–1400px 設計寬度偵測仍保留，且允許手動縮放。

閱讀工具列採系統 toolbar，或放安全區域內；自訂浮動按鈕若與 active division 重疊，移到同側可用邊緣，移動按鈕不能移動文章。使用者需要時可手動進入 F，不能自動把文章「吸」到摺痕某側。

本案首版**不使用 ArrangementView 與 onHingeChange**。NavigationSplitView 已承擔導覽，沒有理由再疊一層 arrangement；鉸鏈只允許未來的細微效果，不作資料／版面狀態依據。

## 6. 狀態與摺疊連續性

`LibrarySceneState` 是每個視窗唯一來源，不能由 N/M/L view 分別建立。SwiftData 模型用 UUID 引用，不能把 HTMLFile 物件直接序列化進 SceneStorage。`FileViewModel` 可保留整理操作，但 filter/query/sort 要從同一 state 衍生，避免兩份可寫值。

| 狀態 | 規則 |
|---|---|
| 分類 | `all / folder(UUID) / tag(UUID)` 互斥；外螢幕的分頁與所選分類分開存。子資料夾保留父子路徑 |
| 搜尋 | 一份 query＋scope；外螢幕搜尋維持預設「全部收藏」，可切「目前分類」；寬版明示範圍，與相同 query/scope 得到相同結果。取消搜尋關閉搜尋模式但保留 query 草稿，清除按鈕才清空 |
| 開啟與選取 | `selectedFileID` 與 `readerPresented` 分離。摺起保留正在閱讀的 ID；展開仍開同一則。關閉閱讀保留清單 highlight，不能因 highlight 而在展開時重開 |
| 返回上下文 | 開閱讀前記錄 tab、filter、searchActive、scope、query、scroll anchor；返回回到來源，包含搜尋結果，不固定跳全部 |
| 排列／排序 | 使用者的 grid/gallery/list 偏好保留；並排閱讀暫用清單是呈現覆寫，不改偏好。可各存觸控／桌面預設，不能每次折疊重設 |
| 列表位置 | 以 filter＋query＋sort＋layout 為鍵保存首個可見收藏 UUID；iOS 17 `scrollPosition(id:)`＋`scrollTargetLayout()`；格子改欄後錨點移至最近同列，允許一列內差距 |
| 閱讀位置 | 每 scene、每收藏保存 DOM 錨點＋錨點內相對位置；fallback 使用可捲動範圍的比例，最後才是頂端。另存使用者字級與縮放倍率 |
| sheet／草稿 | stable root presenter 維持單一 modal enum（import/sync/share/rename 等）；匯入 step、URL、HTML、名稱不隨欄切換重建；不把 token 放進 scene 快照 |
| 焦點 | 尺寸變化不主動打開鍵盤；搜尋原已編輯則保留焦點，進文章後退鍵盤。VoiceOver 保留目前文章／返回入口的合理焦點 |

### WebView 生命週期與復原順序

1. ReaderSession 存活時間長於任何 N/M/L 外殼；同一 scene 的同一文章最多一個活躍 WKWebView，不讓兩個 representable 同時持有它。外殼重掛載可由 session 暫存 web view，釋放時先移除 delegate／觀察者，避免循環引用。
2. 尺寸改變前持續節流記錄可見元素錨點；無法提供穩定 DOM ID 時以可重定位元素路徑加文內比例降級。只存位置資料，不保存任意網頁腳本或額外個資。
3. 更新容器 bounds／viewport，等待 navigation 完成及 DOM 布局穩定，再恢復錨點。圖片延遲載入時有限次修正（最多 2 次），使用者開始拖曳就停止自動修正，不可無限搶回捲動。
4. 本機相同 HTML 的 resize 不重新 loadHTMLString；目前 WebView 的 viewport 只在 didFinish 注入，後續必須新增 resize 處理，不能只靠 SwiftUI 換 frame。
5. 縮放以「使用者倍率相對於目前 fit scale」保存，重新夾在允許範圍內，避免內外螢幕沿用不適合的絕對 zoomScale。字級變更也要記錄／復原錨點。
6. 記憶體回收或 scene 重建才重新載入；內容版本不同時嘗試原錨點，失效回比例。復原快照以版本化 Codable JSON 字串存 SceneStorage；不改 SwiftData schema，不同步跨裝置閱讀位置。

### 篩選、刪除與同步衝突

搜尋字串或分類切換使已讀文章不在結果時，寬版保留文章並顯示「此收藏不在目前結果」與「關閉閱讀」；不能沿用 Mac 現有 `files.map(id)` 改變就關閉文章的行為。外螢幕在閱讀中不暗中改返回上下文。

文章真正被本機／同步刪除才關閉閱讀，顯示「這則收藏已刪除」，回原結果並選最近有效錨點。分類被刪除則退回全部、保留 query；內容尚未下載顯示進度／重試，不把空 HTML 當正常文章。同步取得新版內容時保留舊閱讀 session 並提示「內容已更新，重新載入」，由使用者點擊後恢復位置，避免閱讀中途跳動。

## 7. Split View 與多視窗

**Phase A 必須支援縮窄／放寬與其他 App 並排；Phase B 才增加「在新視窗開啟」。** 不把多視窗當成首版適應的前置條件；Phase A 不顯示不能工作的選單。這是建議的交付分期，不代表本次已得到實作或發布授權。

Phase B 設定：在 project.yml 生成的 UIApplicationSceneManifest 宣告 UIApplicationSupportsMultipleScenes，並驗證 WindowGroup 的 scene 接收與 restoration；避免手寫 manifest 與 SwiftUI 自動 scene 設定衝突。此設定只在 Phase B 啟用。

Phase B 行為：在收藏長按／右鍵的更多選單增加「在新視窗開啟」，新視窗預設閱讀該收藏、各有獨立 query／filter／字級／位置；同一收藏可在兩個視窗各讀不同段落。資料層共用既有 ModelContainer；scene state、WKWebView、modal 不共用。

以實際 `supportsMultipleWindows`／`supportsMultipleScenes` 能力與系統 scene activation 結果判斷，不以 regular 或 iPhone 型號假設成功。外螢幕不可建立新視窗時，隱藏動作或說明「目前無法開啟新視窗」，仍可在目前視窗閱讀。

實作前先驗證 UIKit scene activation 到 SwiftUI WindowGroup 的路由橋接：用 NSUserActivity 傳 app 自訂活動型別與收藏 UUID，接收端解析，禁止攜帶整段 HTML 或同步憑證。建議採 iOS 17 起的 `UISceneSessionActivationRequest` 與 `activateSceneSessionForRequest:errorHandler:`（此處為已驗證的 ObjC selector；Swift 匯入拼法由實作時編譯確認），必須處理 errorHandler。舊 `requestSceneSessionActivation` 的標頭標示 `API_TO_BE_DEPRECATED`，不能自行宣稱已於 iOS 26 棄用。`openWindow` 存在但基本呼叫不提供可靠失敗回報，不能呼叫後直接 toast「已開啟」。

使用 request ID 與新 scene 回報完成交接；失敗維持原視窗與閱讀位置，提示重試／「在此閱讀」。未收到交接回報顯示「尚未確認新視窗已開啟」，不能逾時就自動再開一次。每個請求至多建立一個視窗。關閉／摺起時系統如何保留其他 scene，必須以 Duo 實測為準，不主動關閉其他 scene。

多視窗另須把 ContentView 現有每分鐘 sync loop、pending 匯入改為 App 層協調／去重；避免每多一個視窗就新增同樣的網路輪詢與重複匯入。使用同一個 SyncService，驗證並行呼叫與 modelContext 生命週期後才上線。

## 8. Sheet、匯入、同步設定與分享擴充

| 情境 | 呈現 |
|---|---|
| 外螢幕匯入 | 保留來源 → 連結／HTML → 完成流程；一般高度沿用 0.7／large detents，矮版或鍵盤出現用 large；內容可捲動 |
| 內螢幕／iPad 匯入 | 使用系統置中 sheet；內容理想寬 520、上限 600，實際不得超過容器扣 32；不自製全螢幕遮罩或固定絕對高度 |
| 同步設定 | 系統 sheet，表單理想寬 480–560；狀態、手動同步、錯誤／重試可見；密碼欄照原方式保護，不放寬存取 |
| 分享／匯出 | 系統 share sheet／fileExporter；iPad／regular 使用正確錨點；取消不改閱讀位置，匯出失敗顯示可重試訊息 |
| 改名／整理 | 簡單改名用 alert；資料夾／標籤長清單使用可捲動 sheet 或 popover，不超出視窗 |
| Share Extension | 由來源 App／系統管理容器；只讓 SaveResultView 內容在 safe area 內置中且可縮小，完成按鈕 >=44。不從 extension 啟動新的閱讀 scene，也不假裝能指定主 App sheet 尺寸 |

匯入成功後只建立一次資料、顯示一次成功提示；摺疊不重送請求。下載中可離開呈現層但工作由穩定 session 管理；取消的語意須明確，不因 View 消失而意外再儲存。尚未儲存的輸入被關閉時詢問捨棄，單純 resize 不詢問。新增資料若不符合目前 filter，可提示「已存入全部收藏」，不要強行清除篩選或打斷閱讀。

## 9. API 查核與相容性

本機查核根目錄：

```text
/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.2.sdk/System/Library/Frameworks/
  SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface
  SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface
  UIKit.framework/Modules/UIKit.swiftmodule/arm64e-apple-ios.swiftinterface
  UIKit.framework/Headers/UIViewReservedRegion.h
  UIKit.framework/Headers/UIView.h
  UIKit.framework/Headers/UIApplication.h
  UIKit.framework/Headers/UISceneSessionActivationRequest.h
  UIKit.framework/Headers/UIWindowScene.h
  UIKit.framework/Headers/UITraitCollection.h
```

「已驗證」指宣告存在與 availability 已讀取，**不代表編譯過新程式或模擬器行為通過**。SwiftUICore 宣告經 SwiftUI 使用；SDK 顯示 `anyAppleOS` 的項目下表換成這個 iOS／Catalyst 專案所需的版本條件。

| API | 本機查核／availability | 使用與 guard |
|---|---|---|
| `NavigationSplitView`、`navigationSplitViewColumnWidth` | 已確認，iOS 16 | Phase A 使用；deployment 17 不需額外 guard |
| `preferredCompactColumn:` initializer | 已確認，iOS 17 | 折起時優先目前閱讀；基線直接可用，與自有 compact 外殼只能有一套導航真值 |
| `scrollPosition(id:anchor:)`、`scrollTargetLayout()` | 已確認，iOS 17 | 列表錨點；不要誤用另一個 iOS 18 的 ScrollPosition overload |
| `presentationDetents` | 已確認，iOS 16 | 基線可用；實際 sheet 外觀交給系統，內容依容器縮放 |
| `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)` | 已確認，`anyAppleOS 27.1` | `if #available(iOS 27.1, macCatalyst 27.1, *)`；以 `.division` 與 `options: .includeInactive` 查詢；**不是 View modifier** |
| `ReservedRegion`、`.Kind.division`、`.QueryOptions.includeInactive` | 已確認，27.1；有 frame、margins、isActive | adapter 限定 `@available(iOS 27.1, macCatalyst 27.1, *)`；舊系統只收到自有幾何型別／空陣列 |
| `UIView.reservedRegions(kind:options:)`／`UIView.ReservedRegion` | 已確認，iOS 27.1；ObjC 名稱 `UIViewReservedRegion` | UIKit 備選，不需與 SwiftUI 同時讀取；相同 27.1 guard。Swift 不直接照抄 ObjC 型別名 |
| `ArrangementView { … } secondary: { … }` | 已確認，27.1；`.arrangementViewStyle(.split)`／`.overlay` | 本版不用；未來用時獨立於 NavigationSplitView，不嵌入 List／ScrollView；27.1 guard |
| `.onHingeChange(isEnabled:_:)`／`DeviceHingeContext.hinge` | 已確認，27.1；closure 收 old/new context，hinge optional | 本版不用；未來僅效果，nil 正常、27.1 guard |
| `.defaultTabBarPlacement(.sidebar)` | 已確認，modifier 為 **27.0**，參數 `AdaptableTabBarPlacement`（型別 iOS 18） | 本版不用，避免雙 sidebar；如採用需 `if #available(iOS 27.0, macCatalyst 27.0, *)`，不能把 modifier 誤認為 iOS 18 |
| `EnvironmentValues.supportsMultipleWindows`、`OpenWindowAction` | 已確認，iOS 16 | Phase B 能力查詢／開啟入口可用；不表示目前姿態一定能開成功 |
| `UIApplication.supportsMultipleScenes` | 已確認 UIKit header，iOS 13 | Phase B 能力檢查；依 runtime 與宣告，不靠機型 |
| `UISceneSessionActivationRequest`、`activateSceneSessionForRequest:errorHandler:` | 已確認 UIKit headers，iOS 17 起；request 有 userActivity | Phase B 建議通道；基線無須 guard，Swift 拼法與 SwiftUI scene 橋接仍須編譯／操作驗證 |
| `requestSceneSessionActivation:…errorHandler:` | 已確認 UIKit header，iOS 13 起，棄用版本為 `API_TO_BE_DEPRECATED`，不是已確認的 26.0 | 僅列供辨識舊做法；採上列 iOS 17 通道 |
| `UIWindowScene.screen`／`UITraitCollection.displayScale` | 已確認 header；UIWindowScene iOS 13、trait collection 的 displayScale 為既有 iOS 8 API | 基線可用；從目前 view.window.windowScene 取值，不能任取 connectedScenes.first；不使用 UIScreen.main |

`horizontalSizeClass`、`verticalSizeClass`、GeometryReader、NavigationStack、SceneStorage、WKWebView、UIViewRepresentable、safeAreaInset 與標準 toolbar 為基線設計所用既有 API；專案已有其中多項用法。此表的逐宣告查核聚焦新增／易誤用項目；新增實作仍須用 iOS 17 deployment target 完整建置驗證，不把 SDK 存在等同部署可用。

27.1 的型別不可洩漏到舊版會初始化的 stored property 或 public initializer。guard 內查詢再轉成 `[DivisionGeometry]`；iOS 17–27.0 回空值，按一般 adaptive grid／safe area 渲染。新 SDK 建置與最低支援 iOS 17 是兩回事；不提高 deployment target。Catalyst 分支不能引用僅 native macOS 可用的 API。

## 10. 模擬器與回歸驗收清單

以下介面測試全部是**待實作後執行**。Claude 已回報 iOS 27.2 Duo framebuffer，但 App 的 GeometryReader／displayScale 尚待確認；這次只修文件，未自行跑 App。使用已備妥的 Duo 環境透過 Device Hub 開合／旋轉／調整姿態，先記錄 scene bounds、scale、四側 insets、根內容 W/H，再判斷模式；不能用 framebuffer 除 3 直接當成安全區 W。

| 測試 | 操作 | 通過標準 |
|---|---|---|
| 外螢幕直式 | 三分頁、三排列、長按整理、搜尋、同步、匯入 | 操作可達、底列不遮最後一筆；不新增空動作 |
| 外螢幕橫式／帳篷 | 本版不實作、不驗收 | 維持原 iPhone 直式 orientations；不影響內螢幕兩方向驗收 |
| 內螢幕完整姿態 | 攤平、部分摺疊、兩方向；記錄實際 W/H、size classes、insets、division | 根據實際尺寸進 N/M/L；控制項不碰狀態列／相機／division |
| 斷點 | regular/regular 下測 W=599/600/601（瀏覽）、759/760/761（閱讀）、1099/1100/1101pt（三欄）；另測 C=455/456/457 的卡片欄數 | 600 起瀏覽寬版但閱讀單頁；760 起清單＋至少 480 文章；1100 起三欄；只有 C≥456 才放兩張 200 卡，無摺痕時成立 |
| Duo 內直候選 669×951 | 先驗 scale／safe area；再以實際 W 測瀏覽、開文章、叫出／關閉清單、換文章 | 若 600≤W<760：分類理想 200＋收藏區；閱讀單頁＋清單浮層，不落回 N；實際 W=669 時 C=469−d，可放兩張卡（摺痕可能另行降級） |
| Duo 內橫候選 951×669 | 測兩方向的不對稱 inset，確認實際 W；開文章再轉回內直 | W≥760 時清單 260–280＋閱讀≥480；轉回窄幅保留文章錨點，清單改按鈕且不自動彈出 |
| 外直候選 466×678／安全區邊界 | 確認 horizontal compact；額外用 W=620、599、760 的 regular 容器模擬 inset／Split View | 外螢幕仍 N；W=620 瀏覽 M 單欄卡片、閱讀單頁＋浮層；599 才降 N；不重複扣 safe area |
| 清單浮層連續性 | M 窄幅閱讀開清單、搜尋／換分類、取消、選另一篇；浮層開著跨 760 | 開關不改 WebView frame／viewport；取消保留位置；選篇後關閉；放寬僅一份常駐清單，不留下重複浮層 |
| 核心連續性 | 在分類搜尋結果中開第 30 筆，捲到中段、改字級／縮放，連續開合 5 次 | 收藏 UUID、query、scope、filter、排列不變；同一段落仍可見；fallback 誤差 ≤ 一個可見頁高並記錄原因 |
| 返回來源 | 從搜尋／資料夾／標籤開文章，折疊、返回、展開 | 回正確來源，列表錨點誤差 ≤ 一列，已關閱讀不自行重開 |
| 閱讀 resize | responsive HTML、固定 1200px 桌面頁、長文、圖片延遲載入 | 不重載相同 HTML；無單字直排；手動 zoom 可用；使用者拖曳後不搶位置 |
| 摺痕網格 | 對稱／偏移 division、零寬 inactive、division 在欄外、橫向 division | 偶數欄對準真實位置，狹側能降級；閱讀不插空白；攤平不突然換欄 |
| Split View | Keepbox 放左／右，各比例拖至最窄再還原 | safe area 各自正確；文章、鍵盤輸入與 sheet 草稿不丟失 |
| Sheet | URL／HTML 輸入到一半開合、轉向、分割；取消與存檔各測 | 不重複儲存／下載、不清草稿，鍵盤不蓋完成按鈕；失敗可重試 |
| Share Extension | Safari 分享網址／圖片／文字／HTML；內外螢幕與分割 | 顯示成功／失敗及完成；主 App 回前景只匯入一次 |
| 資料變動 | 另一裝置刪除文章／分類、更新內容，及內容待下載 | 按第 6 節提示、回退與保留位置；不崩潰或空白假成功 |
| 輔助使用 | VoiceOver、最大 Dynamic Type、深淺色、Reduce Motion、Pencil 點選 | ≥44 命中，文字可讀，閱讀順序合理，無必須 hover 的功能 |
| 一般 iPhone／iPad | iOS 17 最低版本與現有可用 runtime、iPad 直橫／分割 | 不誤呼叫 27.1 API；三排列與匯入同步仍可用 |
| Mac | 900×560、寬視窗，Cmd-F/N/Escape、右鍵、來源徽章、分享／匯出 | 原功能不退化；窄視窗文章不被三欄擠壓 |
| Phase B 多視窗 | 成功、能力不支援、activation 失敗、相同文章兩視窗、關一窗 | 原視窗不丟狀態；有錯誤回饋；不重複開窗、不增加同步輪詢 |

驗收證據需記錄 SDK/runtime、裝置、實際 pt 尺寸、姿態、操作步驟、預期／實際與截圖。新版本可建置不代表 iOS 17 runtime 已驗；缺 runtime 時明示未驗，不省略相容性門檻。

## 11. App Store 截圖

截至本次查核，Apple 的 Duo 截圖規格與內螢幕面板像素不同，以下採 **App Store Connect screenshot specifications**，不可直接用硬體規格當上傳尺寸。[Apple 截圖規格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

| 類別 | 直式 px | 橫式 px | 本案用途 |
|---|---|---|---|
| Duo 外螢幕 | 1398 × 2034 | 2034 × 1398 | 原三分頁首頁、收藏閱讀 |
| Duo 內螢幕 | **2007 × 2853** | **2853 × 2007** | 分類＋卡片、清單＋閱讀；以實際能達到的欄模式拍攝 |
| 一般大型 Dynamic Island iPhone | 1320 × 2868 | 2868 × 1320 | 保留一般 iPhone 素材；官方亦接受其他列出的尺寸 |
| iPad 13 吋（若 App 支援 iPad） | 2064 × 2752 | 2752 × 2064 | 寬版閱讀；官方另接受 2048 × 2732 及其橫式 |

官方目前註記：自 **2027 年 4 月**起，使用 iOS 27.1 SDK 以上的 App 需提供 Duo 截圖；送出 Duo 截圖可顯示最佳化標章。提交前再確認當時規格與實際 App Store Connect 欄位。這是素材規劃，不是已上傳或已取得標章。[Apple 截圖規格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

建議每組先準備 3 張：收藏整理、並排閱讀（外螢幕改單頁閱讀）、搜尋／來源辨識；內螢幕兩方向與 Split View 作驗收素材（外螢幕橫式／帳篷本版排除），視行銷需要增補。尺寸不合時先確認模擬器正確 screenshot 輸出，不拉伸內容、不用面板解析度硬改 metadata，也不把未達斷點的 Duo 畫成三欄。

## 12. 需要大皓決定的產品問題

以下獨立列出建議，不影響本次設計文件完成，也不代表已替使用者作發布決定。

1. **外螢幕／一般 iPhone 是否一起開放橫式？** 建議是；提供完整單欄功能，閱讀優先，避免帳篷時只有一半功能。若先不做，Phase A 明列外螢幕橫式未支援，內螢幕仍要適應。
2. **Duo 首版是否強制三欄？** 建議否；採本文件 M 雙欄優先，W ≥ 1100 才三欄，避免犧牲文章寬度。實際 Duo 可能大多落在 M，這是預期設計。
3. **新視窗要與首版同上嗎？** 建議獨立 Phase B；首版先完成 Split View 與連續閱讀。若要同上，必須把 activation 失敗、交接、scene 復原及同步去重一起驗收，不能只加選單。
4. **搜尋要跟著分類，還是全域？** 建議維持手機預設全域，增加清楚的「全部收藏／目前分類」scope；跨螢幕保留所選 scope。這會改變 Mac 現行隱含分類搜尋，實作需一起更新提示。
5. **是否新增 Pencil 註記？** 建議本版不做；現階段保留選取、捲動及系統文字互動，註記需要獨立儲存／同步設計，不能混入這次布局改造。

以上保留原提案脈絡；實作以以下「大皓決定」為準，斷點以修訂後 §2／§3.3 為準，不回用原 700pt 門檻。本次未啟動 Claude、未修改程式、未執行建置或模擬器驗收。

### 大皓決定（2026-11-03）

1. 橫式：**先不做**。外螢幕與一般 iPhone 維持直式；project.yml 的 iPhone orientations 不動。3.2 節與第 10 節「外螢幕橫式／帳篷」本版不實作、不驗收。內螢幕仍須完整適應（系統本來就不理會 orientations）。
2. 三欄：照建議，M 優先、W ≥ 1100 才三欄。斷點修訂：瀏覽 W ≥ 600 進 M；閱讀 W ≥ 760 才並排，600–759 採單頁＋清單浮層。
3. 新視窗：照建議，留到 Phase B；本版不宣告 UIApplicationSupportsMultipleScenes，不顯示「在新視窗開啟」。
4. 搜尋：照建議，預設全部收藏，可切換到目前分類，跨螢幕保留選擇；Mac 一起改。
5. Pencil 註記：本版不做。
6. 模擬器：同意下載 iOS 27.2 simulator runtime 供 Duo 驗收。

## 13. Duo 直式側邊工具列

日期：2026-11-04。階段：Phase A.2 設計交付，尚未實作。本章依 `docs/duo-vertical-bar-brief.md`、目前程式與本機 iOS 27.2 SDK 撰寫；build 20 真機現象及外螢幕 W=382／硬體寬466、約84pt側邊區域為需求提供的量測，非本次重新測得。

### 13.1 目標、優先順序與外觀決策

**將 iOS 的導覽與工具動作交給系統容器。** 外螢幕閱讀的返回位於系統直式列頂端，主要動作其次；一般 iPhone 顯示正常水平導覽與工具列。約84pt僅是觀察值，不自行畫一條84pt側欄、不補 padding 填滿它，也不以裝置名稱或 W 推測工具列在哪邊。

本章取代 §3.1 的自訂膠囊底列／浮動新增、§3.3 的閱讀自訂橫列，以及 §4 對觸控 ReaderChrome 的自訂 bar 選項；其他資料與閱讀規則維持。600／760／1100pt 斷點、ReaderSession／WKWebView 生命週期、位置復原、SceneStorage schema、外螢幕直式限定、多視窗 Phase B、Mac 外觀均不變。本章所列未決項目是視覺與操作排序的建議值，並非已經大皓確認。

系統 bar 隨姿態決定軸向；內螢幕橫放可直排，內螢幕直放可回水平，不能要求所有內螢幕姿態一律直排。SplitView 只有 detail 欄參與側邊 bar；側欄／清單內容不全數搬過去。外螢幕 sheet 與內螢幕置中 sheet 也可能有不同軸向。[Apple：Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/)

**一般 iPhone 的建議外觀**：iOS 17 起一起改用原生 TabView 與 NavigationStack，保留紫色 tint、內容卡片、三分頁、三排列與所有動作。iOS 17–18 使用該版本原生外觀，iOS 26 採系統 Liquid Glass；不人工模擬玻璃、不再疊一條自訂膠囊。這是刻意的外觀改版，不將它描述為像素完全不變。iPad 沿用 M/L 分類架構，不另外套一層三分頁側欄。

### 13.2 容器與導航整合

1. **N 的瀏覽根層**：`TabView(selection:)` 綁定既有 state.tab，三個分頁各有 `NavigationStack`，標籤為「全部／資料夾／標籤」。以 iOS 17 可用的 `.tabItem { Label(...) }`＋`.tag(...)` 建立，不為了新版 Tab 語法提高部署版本。首頁改 `.navigationTitle("Keepbox")`，分類名稱留內容區，移除 HomeView 重複的大標題工具按鈕。
2. **搜尋與閱讀**：在目前分頁的 stack 中呈現目的頁，目的頁隱藏系統 tab bar（`.toolbar(.hidden, for: .tabBar)`），回瀏覽才恢復；搜尋不新增第四個分頁。收藏從哪個分頁開啟，就回哪個來源；沿用 state 的 query/scope/filter/returnContext 與已修正的 closeReader(anchoringWithin:)。
3. **單一導航真值**：stack path／destination binding 只做既有 state 的呈現映射，不新增另一份可寫 selectedFileID、searchActive、readerPresented 或獨立 SceneStorage 快照。push／pop 的 binding setter 呼叫現有 open／closeReader／搜尋取消動作；同步刪除導致 state 關閉時，不可再由 pop 重複還原。若啟用邊緣返回手勢，必須走相同返回語意。
4. **避免雙返回**：正常 push 用系統自帶 back；不要再加第二顆 chevron。若 compact/regular 切換使文章直接成為 stack 根頁而無系統 back，才用 `.cancellationAction` 補單一「返回收藏／返回搜尋」。該按鈕執行原有返回流程，不額外 dismiss 整個 scene。表格中的「返回」是這兩種表示的同一動作。
5. **M/L**：保留目前 policy 控制的 NavigationSplitView／NavigationStack 切換。將閱讀動作定義為共用 `ToolbarContent`，由 `WideLibraryView` 的 **detail 根頁** 統一掛 `.toolbar`；不要讓 WideReaderView 內的 HStack 或嵌入的另一個 NavigationStack 嘗試參與直排。瀏覽時掛瀏覽組，閱讀時掛閱讀組；不把兩組全加上而產生重複新增／分享／關閉。
6. **穩定 presenter**：匯入與同步 sheet 繼續掛穩定根層；popover／標籤 sheet 只變入口呈現，保留草稿與既有操作。TabView 非作用中分頁不能意外掛載第二個 ReaderWebView。N↔M/L 換容器仍沿用同一 ReaderSession，不能以改 toolbar 為由重載 HTML。
7. **舊自訂列移除範圍**：N 的 bottomBar／浮動新增、ReaderView 的 topBar／readerToolbar、WideReaderView 的閱讀 toolbar HStack，改由原生列取代。文章內容、文字大小選項、標籤操作、內容更新橫幅繼續使用。搜尋輸入與範圍 picker 留內容區，不做直式字串輸入框。

### 13.3 項目規格與表格讀法

- 每個可搬入 bar 的 Button／Menu／ShareLink 都提供完整 `Label(標題, systemImage:)`；不要只放 Image 再補 accessibilityLabel。標題即下表文字，按鈕內不放另一組 HStack 動作。
- 下表 axis／priority 作用在 **ToolbarItem／ToolbarItemGroup（ToolbarContent）**，不是貼到任意 View 上。標準 Label 預設 `.automatic`；只有保留自訂同步狀態表示的項目採 `.verticalPreferred`，仍需圖示＋標題與可供系統溢出顯示的語意表示。
- 「低／自動／高」對應 `.low`／`.automatic`／`.high`，是保留優先權，不是保證固定座標或永不溢出。只把主要導覽／主動作設高，避免所有項目都高而失去效果。
- 「系統」表示正常 toolbar 項目，由系統必要時收入同一個 overflow；「固定」表示只宣告在唯一 `ToolbarOverflowMenu` 內。其內部是一般 Menu／Button View，沒有個別 placement、axisBehavior 或 ToolbarContent visibilityPriority，表內寫「—」以免 Claude 套錯型別。不得把同一動作同時放正常列與固定 overflow。
- badge「—」表示不用。僅閱讀的「標籤」可使用目前已套用的標籤數 n，n=0 隱藏；27.1 路徑用 `.badge(n)`，不把「標籤（3）」寫進標題。舊版省略 toolbar badge、保留 VoiceOver 數量。所有分頁不顯示總收藏數 badge，避免誤解為未讀數。
- 非 toolbar 的內容操作仍列於表中；placement／axis／priority 為「內容／—／—」，不強行移進直式列。表單內數量與結果數是內容文字，不受 badge 規則限制。

#### A. 三個瀏覽分頁（N）與 M/L 瀏覽

| 畫面／項目 | placement | 標題／SF Symbol | axis | priority | overflow | badge |
|---|---|---|---|---|---|---|
| 全部分頁 | TabView tabItem | 全部／doc.text | —（系統 tab） | — | 系統 tab 壓縮 | — |
| 資料夾分頁 | TabView tabItem | 資料夾／folder | — | — | 系統 tab 壓縮 | — |
| 標籤分頁 | TabView tabItem | 標籤／tag | — | — | 系統 tab 壓縮 | — |
| 三分頁共通新增 | .topBarPinnedTrailing | 新增收藏／plus | .automatic | 高 | 系統 | — |
| 三分頁共通搜尋 | .topBarTrailing | 搜尋收藏／magnifyingglass | .automatic | 自動 | 系統 | — |
| 三分頁共通同步 | .topBarTrailing | 同步設定／arrow.triangle.2.circlepath | .verticalPreferred | 自動；失敗時高 | 系統 | — |
| 全部：排列 Menu | .bottomBar | 排列／square.grid.2x2 | .automatic | 低 | 系統 | — |
| 全部：排序 Menu | .bottomBar | 排序／arrow.up.arrow.down | .automatic | 低 | 系統 | — |
| M/L：叫出分類（分類未常駐時） | .topBarLeading | 分類／sidebar.leading | .automatic | 高 | 系統 | — |
| 分類／標籤列、長按整理 | 內容／contextMenu | 沿用各列名稱與整理動作圖示 | — | — | 不進全頁 overflow | — |

全部的排列 Menu 需完整提供「網格／square.grid.2x2」「圖文／rectangle.grid.1x2」「清單／list.bullet」，選中項有系統勾選，入口圖示可隨目前排列切換但標題固定「排列」。排序沿用最新、最舊、名稱 A–Z、名稱 Z–A；選項用 Picker 的選取語意，不另造三個排列 toolbar 按鈕。資料夾／標籤索引頁不顯示檔案排列／排序，選分類後的收藏結果才顯示。

M/L 瀏覽使用同一動作集合，已有常駐搜尋欄時不再放 magnifyingglass 按鈕；搜尋欄與 scope 保持水平內容，系統沒有足夠高度時由內容捲動處理。三分頁的「新增收藏」都維持原匯入行為，不因在資料夾頁就改成新增資料夾；寬版既有新增資料夾／標籤入口仍留 sidebar 內容。

同步正常／未設定圖示沿用現況，失敗換 `exclamationmark.arrow.triangle.2.circlepath`，同步中保留同一 Label 的語意，不用純 ProgressView 取代整顆按鈕。VoiceOver value 說明「同步中／同步失敗／尚未設定／已設定」。不用 badge(1) 表達錯誤；失敗不是待讀通知數。

#### B. 搜尋目的頁

| 項目 | placement | 標題／SF Symbol | axis | priority | overflow | badge |
|---|---|---|---|---|---|---|
| 返回來源／取消搜尋 | 系統 back；無 back 才 .cancellationAction | 返回收藏（或對應來源）／chevron.backward | .automatic（自訂時） | 高 | 不主動收入 | — |
| 新增收藏 | .topBarPinnedTrailing | 新增收藏／plus | .automatic | 高 | 系統 | — |
| 排序 | .bottomBar | 排序／arrow.up.arrow.down | .automatic | 低 | 系統 | — |
| 同步設定 | ToolbarOverflowMenu 子項 | 同步設定／同步狀態圖示 | — | — | 固定 | — |
| 搜尋輸入 | 內容 TextField | 搜尋名稱或內容／magnifyingglass | — | — | 否 | — |
| 清除 query | 輸入框內 Button | 清除搜尋／xmark.circle.fill | — | — | 否 | — |
| 搜尋範圍 | 內容 Picker | 搜尋範圍；全部收藏／目前分類 | — | — | 否 | — |

搜尋頁不另放「搜尋」按鈕，也不在搜尋框旁保留第二個「取消」重複入口。返回只關閉 searchActive、保留 query 草稿；清除按鈕才清空 query。鍵盤的搜尋提交與關閉由輸入元件處理，不把鍵盤配件移入側邊 bar。既有單欄結果列表、捲動錨點與返回位置不可因原生 stack 遷移而退化。

#### C. 閱讀（N／M／L／F 共用）

| 項目 | placement | 標題／SF Symbol | axis | priority | overflow | badge |
|---|---|---|---|---|---|---|
| N 返回 | 系統 back；無 back 才 .cancellationAction | 返回收藏／chevron.backward；搜尋來源為返回搜尋 | .automatic（自訂時） | 高 | 不主動收入 | — |
| M/L/F 關閉閱讀 | .cancellationAction | 關閉閱讀／xmark | .automatic | 高 | 不主動收入 | — |
| 分享 | .topBarPinnedTrailing | 分享／square.and.arrow.up | .automatic | 高 | 系統 | — |
| 單頁閱讀的清單入口 | .topBarTrailing | 收藏清單／list.bullet.rectangle | .automatic | 高 | 系統 | — |
| 字級 Menu | .bottomBar | 字級／textformat.size | .automatic | 自動 | 系統 | — |
| 管理標籤 | .bottomBar | 標籤／tag | .automatic | 自動 | 系統 | n>0 時 n |
| 開原文（URL 存在時） | .bottomBar | 開啟原文／arrow.up.right.square | .automatic | 低 | 系統 | — |
| 並排 → F／F → 原模式 | .bottomBar | 展開閱讀／arrow.up.left.and.arrow.down.right；返回並排或返回閱讀／arrow.down.right.and.arrow.up.left | .automatic | 自動；F 的返回高 | 系統 | — |
| 分類（M/L 未常駐且非 F） | ToolbarOverflowMenu 子項 | 分類／sidebar.leading | — | — | 固定 | — |
| 清單排序（M/L 且可操作清單） | ToolbarOverflowMenu 子項 | 排序／arrow.up.arrow.down | — | — | 固定 | — |
| 新增收藏（閱讀中） | ToolbarOverflowMenu 子項 | 新增收藏／plus | — | — | 固定 | — |
| 同步設定（閱讀中） | ToolbarOverflowMenu 子項 | 同步設定／同步狀態圖示 | — | — | 固定 | — |
| 內容已更新／重新載入 | 文章橫幅內 | 重新載入／arrow.clockwise | — | — | 否 | — |
| 內容下載重試 | 文章下載狀態內 | 重試／arrow.clockwise | — | — | 否 | — |

「分享」建議為閱讀的主動作；不是把「開原文」改成主動作。沒有原文 URL 時整項不產生，不留 disabled 空格。字級 Menu 保留小／標準／大／特大及目前選取；用 menu 取代 N 自訂底部字級 panel，但仍呼叫同一 ReaderSession 字級操作。標籤 sheet 沿用既有增減標籤功能。

單頁 M 的清單入口與常駐並排清單互斥；N 返回搜尋／收藏，不增設 M 的清單浮層。F 縮窄後仍提供「返回閱讀」，不要再出現先前已修正的退出缺口。清單浮層點目前文章也要關閉；切換分類保留文章與現有返回語意。

分享、標籤、原文與焦點切換每項獨立 ToolbarItem；不要把整個 ReaderFontMenu／ReaderChrome 的多按鈕 HStack 當單一 ToolbarItem。讀取、下載、更新狀態是文章內容，橫幅維持可見且不受 toolbar 壓縮影響。結果外提示可保留文字，但關閉閱讀已有系統入口時，不必再畫第二顆固定 bar 按鈕。

#### D. 標籤 sheet

| 項目 | placement | 標題／SF Symbol | axis | priority | overflow | badge |
|---|---|---|---|---|---|---|
| 完成（即時修改後離開） | .confirmationAction | 完成／checkmark | .automatic | 高 | 否 | — |
| 新增標籤 | 內容 List row | 新增標籤／plus | — | — | 否 | — |
| 各標籤切換 | 內容 List row | 標籤名稱／tag；選中另有checkmark | — | — | 否 | — |

此 sheet 只保留一顆 toolbar 完成鈕，因此建議 `.toolbarVerticalBehavior(.disabled)`，讓短表單使用較完整寬度；**不要**把即時儲存的「完成」改成暗示可回滾的「取消」。新增標籤 alert 的取消／新增交給系統 alert，不加 bar；標籤列名稱是資料內容，不硬塞圖示工具列。

#### E. 匯入 sheet

| 階段／項目 | placement | 標題／SF Symbol | axis | priority | overflow | badge |
|---|---|---|---|---|---|---|
| source：取消 | .cancellationAction | 取消匯入／xmark | .automatic | 高 | 否 | — |
| source：來源選項 | 內容 List／來源列 | 貼上連結／link；貼上 HTML 原始碼／chevron.left.forwardslash.chevron.right；從檔案匯入／folder | — | — | 否 | — |
| link／paste：回來源 | .cancellationAction（若改成push則系統back） | 返回來源／chevron.backward | .automatic | 高 | 否 | — |
| link：擷取並存入 | .topBarPinnedTrailing | 擷取並存入／square.and.arrow.down | .automatic | 高 | 系統 | — |
| paste：儲存 | .topBarPinnedTrailing | 存入 Keepbox／square.and.arrow.down | .automatic | 高 | 系統 | — |
| done：提早關閉（若成功畫面仍在） | .cancellationAction | 完成／checkmark | .automatic | 高 | 否 | — |

匯入全流程 `.automatic`，不因 source 只有一顆取消就切成 disabled，避免 source→link 時橫／直列反覆換位。link／paste 的提交改為系統主動作，移除內容底部重複大按鈕，保留相同 validation、isFetching、防重複與錯誤流程。擷取中不改成只有文字的 toolbar；保持 Label，使用 disabled 與 accessibilityValue「擷取中」，進度文字留表單。返回來源不暗中清空草稿。成功仍沿用既有約0.9秒自動關閉，手動完成與回呼必須去重。

#### F. 同步設定 sheet

| 項目 | placement | 標題／SF Symbol | axis | priority | overflow | badge |
|---|---|---|---|---|---|---|
| 取消 | .cancellationAction | 取消／xmark | .automatic | 高 | 否 | — |
| 儲存設定 | .topBarPinnedTrailing | 儲存／checkmark | .automatic | 高 | 系統 | — |
| 立即同步 | Form 內容按鈕 | 立即同步／arrow.triangle.2.circlepath | — | — | 否 | — |
| 狀態／上次同步／URL／憑證欄 | Form 內容 | 保留原文字標籤 | — | — | 否 | — |

同步 sheet `.automatic`；儲存與取消的位置由系統安排。立即同步維持先驗證／儲存再同步的既有語意，不因為改 bar 就更改資料保存行為。錯誤留表單，可捲動至錯誤欄；toolbar 不顯示 token，也不把錯誤內容寫進 badge。

### 13.4 由上到下線框與一般 iPhone 對照

以下是功能順序示意，**不是固定座標或保證每項都常駐**。分組間距、標題、溢出位置與隱藏由系統決定；以標題與圖示宣告同一份操作。右側僅示意目前回報的硬體邊，RTL 不自行鏡射側欄。

```text
Duo 外螢幕：瀏覽（全部）          Duo 外螢幕：閱讀
+--------------------+---------+  +--------------------+---------+
| Keepbox / 分類內容 | 狀態區  |  | 文章標題 / 內容    | 狀態區  |
|                    | + 新增  |  |                    | < 返回  |
| 清單/網格/圖文     | 搜尋    |  | WKWebView          | 分享    |
|                    | 同步    |  |                    |         |
|                    |         |  | 內容更新橫幅       | 字級    |
|                    | 排列    |  | （仍在內容區）     | 標籤 n  |
|                    | 排序    |  |                    | 原文*   |
|                    | …*      |  |                    | …       |
|                    |         |  |                    |         |
|                    | 全部    |  |                    |         |
|                    | 資料夾  |  |                    |         |
|                    | 標籤    |  |                    |         |
+--------------------+---------+  +--------------------+---------+
* 系統需要時才有 overflow；原文僅 URL 存在時顯示。
閱讀／搜尋隱藏 tab bar；不在內容左上再畫一個返回。

一般 iPhone 17–26：瀏覽            一般 iPhone：閱讀
+------------------------------+  +------------------------------+
| Keepbox   搜尋 同步   +      |  | < 返回   文章標題       分享 |
|                              |  |                              |
| 收藏內容                     |  | WKWebView                    |
|                              |  |                              |
| [排列]               [排序]  |  | [字級] [標籤] [原文*] […]    |
| 全部      資料夾      標籤    |  +------------------------------+
+------------------------------+   返回後才顯示三分頁
 系統 toolbar 與 tab bar，不畫自訂膠囊／浮動 +
```

搜尋的頂部主要導覽是返回，新增其次，輸入框＋scope 留內容；標籤 sheet 是例外，完成鈕維持水平頂列。匯入與同步 sheet 外螢幕預期取消／返回在直列最上、提交其次，內螢幕置中時採水平列。

M/L 展開時：瀏覽動作由 detail 容器提交；閱讀時改成關閉、分享、清單（僅單頁）、字級、標籤、原文、焦點，再由唯一 overflow 提供低頻操作。sidebar 標題與新增分類留 sidebar，不因為內螢幕有直列就全部挪到 detail。系統在內直回水平時，仍用同一套動作與 priority。

### 13.5 壓縮與退出直列策略

| 畫面 | verticalBehavior | compressionBehavior（27.1） | 壓縮順序／理由 |
|---|---|---|---|
| N 三個瀏覽分頁 | .automatic | .prefersTabBar | toolbar 先縮，保留分類導覽；排列／排序先 overflow，新增與錯誤同步較晚 |
| 搜尋目的頁 | .automatic | .prefersToolbarItems | 任務操作優先；本方案 tab 已隱藏，所以目前無 tab 競爭，鍵盤出現時仍保留返回與新增 |
| N/M/L/F 閱讀 | .automatic | .prefersToolbarItems | 閱讀動作優先；tab 隱藏時只在 toolbar 各項間壓縮，原文先、字級／標籤其次，分享與返回最後 |
| M/L 瀏覽 | .automatic | .prefersTabBar（無 tab 時無競爭效果） | 與瀏覽規則一致，sidebar 不等同 tab bar，不靠此 modifier 壓縮 sidebar |
| 標籤 sheet | **.disabled** | 不設 | 只有完成一顆 toolbar 控制項，內容新增列不算 bar；保留較寬列表 |
| 匯入各步驟 | .automatic | .prefersToolbarItems | 返回／取消及提交優先，不切換直列開關 |
| 同步設定 | .automatic | .prefersToolbarItems | 取消／儲存優先，立即同步與長錯誤留內容 |

**不要把 `.prefersToolbarItems` 誤解成 toolbar 先壓縮**：它是優先保留 toolbar；`.prefersTabBar` 優先保留 tabs。本章不用「低頻項目另開一顆 ellipsis Menu」的雙溢出做法。每一個作用中的 detail／目的頁至多一個 ToolbarOverflowMenu；瀏覽頁無固定低頻項目時不刻意建立空 overflow。

所有 toolbar 群組先保持 automatic priority，再依表格設單項優先權；不要整組都 high。回到一般 iPhone 時 low priority 不代表功能被刪除，須能由系統溢出或舊版等效 Menu 找到。原生 bar 空間不足不得將 Label 截成看不懂的文字或縮小到低於44pt命中範圍。

### 13.6 SDK 邊界與 iOS 17–26 退路

本次讀取題示 iOS27.2 的 SwiftUI swiftinterface，確認下列宣告。這是 API 宣告查核，尚未編譯本章實作。

| API | 本機宣告 | 本章使用條件／退路 |
|---|---|---|
| ToolbarContent.axisBehavior | anyAppleOS 27.1 | iOS 27.1 guard 內套用；17–27.0 不套 modifier |
| toolbarVerticalBehavior／toolbarVerticalCompressionBehavior | anyAppleOS 27.1；prefersToolbarItems／prefersTabBar 為 iOS 27.1 | iOS 27.1 guard；舊版自然水平列，不造假同名 extension |
| ToolbarContent.visibilityPriority | iOS 27.0 | iOS 27.0 guard；舊版使用較少常駐項目與等效 Menu |
| ToolbarOverflowMenu | iOS 27.0；macOS unavailable | 依本次需求統一在 iOS 27.1 guard 使用；17–27.0 單一 Menu 替代 |
| ToolbarItemPlacement.topBarPinnedTrailing | iOS 27.0；macOS unavailable | 依本次需求統一採27.1 guard；舊版新增／分享用 .topBarTrailing，儲存用 .confirmationAction |
| toolbarVerticalEdge | 題示未查得公開 SwiftUI 宣告，本章不採用 | 不用字串 KVC、私有 API 或猜硬體邊的替代法 |

新的直列適配元件限定非 Catalyst iOS 分支；Mac 共享 sheet／同步元件如需修改 Label，須維持 Mac 原控制項布局及語意。不能僅以 `#available(iOS 27.1, *)` 就把標示 macOS unavailable 的型別漏到 Mac 專屬碼；必要時以 `#if os(iOS) && !targetEnvironment(macCatalyst)` 隔離新 toolbar 宣告。基線 iOS 17 分支不直接引用新版型別作 stored property。

**17–26 的具體替代（27.0 也沿用此呈現，僅 priority 可另加27.0 guard）**：

- 同樣使用系統 TabView、NavigationStack、toolbar 與原生返回，保留資料／搜尋／三排列功能；不要退回原自訂列造成兩種導航狀態實作。
- 只有 topBarPinnedTrailing、axis／compression／priority 等新版宣告需隔離。原生返回與 cancellationAction、confirmationAction、topBarTrailing、bottomBar 沿用17基線。
- 原本固定放 ToolbarOverflowMenu 的項目，在17–26用唯一 `Menu { ... } label: { Label("更多", systemImage: "ellipsis") }`，放 `.bottomBar`。該 Menu 是溢出替代，因此可用 ellipsis；其餘排列／字級／排序仍用自己的符號。27.1以上路徑不可再並存此 Menu。
- toolbar 太擠時，17–26 閱讀保留返回／分享、底部字級／標籤與更多；原文與焦點切換改收該唯一更多。瀏覽的排列／排序可合併收更多，但選項必須完整；以最小支援 iPhone 的實際文字尺寸驗證，不以機型名稱切分。
- 同步按鈕在 bar 裡避免巢狀玻璃背景，命中至少44pt，狀態及 VoiceOver 保留。badge 僅在確認支援的27.1路徑加到標籤按鈕，舊版不用仿製小圓點擠壓圖示。

### 13.7 VoiceOver、Dynamic Type 與保留行為

- 每個入口的完整標題與圖示可用於 overflow 展開；VoiceOver 另外提供字級值、排列選取、同步狀態、已選標籤數，不把名稱改成純圖示代碼。等待狀態仍可理解「擷取並存入，擷取中，無法使用」。
- 原生 back 由系統處理方向與朗讀；自訂 fallback 用 chevron.backward，RTL 文字與返回符號順應語系，硬體工具列位置由系統決定。不要用左／右作為語音動作名稱。
- Dynamic Type 增大時允許 toolbar overflow，表單／分類內容增高或捲動；不強制 icon＋文字的固定寬 HStack。字級選項名稱、錯誤與匯入成功訊息不得被 bar 裁切。
- 內容更新橫幅「重新載入」保留可見且可朗讀；不要把文章更新提示換成只有 overflow 內一項。toast 留根 overlay、位於可用內容安全區內；移除舊 bar 後要重新檢查原本底部120pt偏移，改為隨內容安全區定位，不遮鍵盤／原生 bar，也不改通知時機。
- 長按整理、ActionMenu 與來源辨識不因系統 toolbar 消失；長按選單中的 ellipsis 不另當成一般動作符號。搜尋 scope、query 草稿、列表錨點、每篇文章位置及既有互動 gate 全部維持。
- Reduce Motion 下不額外旋轉／飛入工具列；Reduce Transparency 由系統 bar 表現，內容色彩與狀態不只靠透明度或顏色辨識。

### 13.8 Claude 後續實作切分（本次未改碼）

1. `AdaptiveLibraryView.swift`：N 換系統三分頁＋各自 stack，建立 state 導出的目的頁與唯一返回動作；移除 bottomBar。M/L 的 toolbar 由 detail 一處組合，保留現有欄寬 policy。不得新增裝置型號分支。
2. 新增 iOS 專用共用 ToolbarContent（建議 `Views/Library/LibraryToolbarContent.swift`、`Views/Reader/ReaderToolbarContent.swift`）：集中表格動作與17／27／27.1分支。資料操作仍呼叫現有 callback，不複製服務或另存 query。
3. `FileListView.swift`、`SearchView.swift`：移除搬進 bar 的重複入口，保持內容與搜尋錨點；`FolderGridView.swift`、`TagListView.swift` 接入各自導航標題，資料選擇維持現況。
4. `FileDetailView.swift`、`ReaderChrome.swift`：移除自訂頂／底工具 HStack，接共用 toolbar；ReaderContentView、ReaderSession、ResizeInteractionGate 不改。若原生 navigation resize 暴露問題，另列 bug 驗證，不在此遷移順便重寫閱讀演算法。
5. `ActionMenuView.swift` 中 TagManagementSheet、`ImportSheetView.swift`、`SyncSettingsView.swift`、`SyncStatusButton.swift`：按本章補 Label、呈現策略、等效入口，保護共用 Mac 路徑。原有匯入與同步功能不改。
6. `ContentView.swift`：保留根 sheet、toast與狀態，只有呈現需要的接線／toast避讓調整；不更動 SwiftData schema、SceneStorage 編碼、project.yml orientations 或多視窗設定。

### 13.9 驗收清單

以下均為實作後待驗收；本次僅完成設計與 SDK 查核。

| 環境／情境 | 驗收項目 | 通過標準 |
|---|---|---|
| Duo 外螢幕27.2三分頁 | 逐一檢查全部／資料夾／標籤，新增、搜尋、同步、三排列、排序、長按 | 系統側列有動作；沒有舊浮動＋或自訂底膠囊；分頁可選，返回不重置 filter |
| Duo 外螢幕閱讀 | 從收藏與搜尋各開文，系統back或fallback、分享、字級、標籤、原文有／無URL | 返回在直列主要導覽位置，只有一顆；無URL整項隱藏；讀文時不出現分頁列 |
| Duo 外螢幕壓縮 | 顯示鍵盤、最大字級、同步失敗、足量標籤badge | overflow只有一個，每項有正確標題／圖示；返回與主動作可達，不丟功能 |
| Duo 外螢幕 sheets | 標籤、匯入source/link/paste/done、同步設定 | 標籤完成水平；匯入／同步正常直排；提交有效性、取消／返回、草稿與成功去重正確 |
| Duo 內螢幕攤開 | M單頁＋清單、M並排、L可用容器、F，內直與內橫分別驗證 | detail動作單份；系統可回水平；其他欄不錯搬；原文／焦點／清單按鈕條件正確 |
| 開合與導航 | 搜尋深處開文、捲至中段、至少兩輪雙方向開合、返回、互動式pop | 同一文章與Session；不重載；原query／scope／來源位置保留；closeReader不執行兩次 |
| iPhone17 Pro 26.5 | 系統三分頁、搜尋、閱讀、所有sheets及更多Menu | 系統水平列／Liquid Glass；沒有27 API錯誤；三排列、同步、匯入、更新橫幅仍可用 |
| iOS17基線 | 舊版build／runtime（可用時），窄寬與大字體 | 無27型別洩漏；功能與入口完整；缺runtime時明示未驗，不以26.5代替17驗收 |
| iPad | 直橫、Split View兩側／窄幅、置中sheet、popover、分享 | M/L架構不多一組tabs；工具與文章不重複；系統sheet布局正確；縮窄退N仍有返回 |
| 輔助使用 | VoiceOver、最大字級、RTL、Reduce Motion／Transparency、深淺色 | 名稱／狀態完整、閱讀順序合理、命中≥44，RTL不手工搬硬體側列 |
| Mac回歸 | 建置與既有sidebar／toolbar／分享／同步sheet | 未套iOS側列新外觀，既有快捷鍵和流程維持 |

驗收紀錄需附 OS／SDK、作用中容器、size class、實際內容W/H、safe area及截圖；不要只以按鈕存在於 View tree 判定已進側邊bar。600／760／1100 的 policy 測試仍保留，但系統bar消耗空間後的真實幾何要重新記錄。未驗的項目不得沿用上一版 build20 截圖作為改版後通過證據。

### 13.10 需要大皓決定的問題

1. **一般 iPhone 也改用原生分頁列與工具列，接受與目前膠囊底列不同的外觀嗎？** 建議接受；保留紫色與內容風格，讓17–26走各自原生外觀，26採Liquid Glass。若不接受，需要另訂舊版外殼維護範圍，不能假裝目前設計沒有視覺變化。
2. **閱讀時最優先的動作是「分享」還是「字級」？** 建議分享放主要動作位置；字級留底部／直列工具組。若大皓更常調字級，可交換優先權與placement，其他分組不變。
3. **只有一顆完成鈕的標籤sheet是否保留水平列？** 建議是，使用disabled；匯入與同步維持automatic，兼顧列表寬度與提交操作一致性。

以上是建議，不阻止設計交付；需大皓確認後由 Claude 依定案實作，再交回審查。已決定的外螢幕不做橫式、多視窗Phase B、搜尋預設全部可切分類、Pencil註記不做，均不重新提問。

### 13.11 大皓決定（2026-11-04）

1. 一般 iPhone **一起改**用原生分頁列與工具列（接受外觀改變）。
2. 閱讀主動作：**分享**。
3. 標籤 sheet：**維持水平**（`.toolbarVerticalBehavior(.disabled)`）。
4. 一併修正：Duo 展開→折疊後外螢幕收藏列表／卡片格位置沒對齊（折疊→展開正常）。與本章外殼改寫一起做，並在 Duo 模擬器驗證雙向。
