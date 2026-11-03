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
