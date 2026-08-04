# PROCESS.md — 我的練習心得

> 一個原則：**寫「具體發生的事」，不寫感想文。**
> 貼上當時真實的 prompt、真實的數字、真實的錯誤訊息——三個月後的你（和你的同事）才用得上。

問：這個專案的分層慣例是什麼？
答：
這個專案採三層分層：
OrderHub.Web：Controller、Razor View、ViewModel
OrderHub.Core：Domain、Services、Interfaces
OrderHub.Infrastructure：Repositories、EF Migrations
主要慣例是：
Controller 要保持薄，只負責接收請求、驗證、呼叫 service、轉接結果。
商業邏輯一律放在 Core 的 service。
只有 repository 可以碰 DbContext；Controller 和 Service 不可直接使用 EF Core。
Service 回傳 ServiceResult<T> 表達可預期失敗，不要用例外處理正常業務失敗。
View 綁定 ViewModel，不要直接把 domain model 丟給 View。
使用者輸入用 DataAnnotations 和 ModelState 驗證，輸入錯誤不能變成 500。
金額使用 decimal。
折扣計算集中在 OrderService.CalculateTotal，不要在其他地方重算。
參考寫法：Controller 看 ProductsController.cs，Service 看 ProductService.cs。

問：常用指令
答：
常用指令是：
dotnet build：建置專案
dotnet test：跑全部測試
dotnet run --project src/OrderHub.Web：啟動網站，預設在 http://localhost:5150

問：金額要用什麼型別？折扣在哪裡算？
答：
金額一律用 decimal。
折扣計算集中在 OrderService.CalculateTotal，不要在其他地方重算。

問：裝一個新 NuGet 套件
答：
依照這個專案的規範，不要未經同意就加新的 NuGet 套件。
你想裝哪一個 NuGet 套件、要加到哪個 project？我拿到套件名稱和目標專案後再幫你安裝。

#### 使用的 agent 與模型：Codex 5.5

---

## 通用四問

### 1. 我的任務拆解

（開工前你把任務拆成哪幾步？實際做的時候順序有變嗎？為什麼變？）

-沒有變，剛開始不太熟悉git 找不到題目 也花了時間了解如何用codex，之後選擇了之前用codex的方式（vscode） 
但是沒有注意到需要在每個題目都commit一次。 後面完成第三題后，才發現需要commit。 
那時候就一次過commit完 補上comment

### 2. AI 幫上大忙的地方

（哪件事 agent 做得又快又好？**貼上當時的提問原文**，說明為什麼這樣問有效。）

問：CreateOrderAsync中的validate 如果需要驗證更多欄位，會導致功能越來越長， 建議一個重構。 原有的測試維持全綠，先説明修改計劃。先只給實作計畫，我確認前不要修改任何檔案
答：
建議重構方向：把 CreateOrderAsync 拆成「流程 orchestration」和「建立訂單前驗證」兩段，先不引入新 NuGet、不改 Controller、不動 migration。
實作計畫
在 OrderService 內新增一個私有方法，例如：
private async Task<ServiceResult<Customer>> ValidateCreateOrderAsync(
    int customerId,
    IReadOnlyList<NewOrderLine>? lines)
它負責目前這些前置驗證：
客戶是否存在
lines 是否為 null / 空
數量是否大於 0
商品是否重複
回傳 ServiceResult<Customer>，成功時帶回已查到的 Customer，避免 CreateOrderAsync 再查一次。
把 CreateOrderAsync 開頭改成：
var validation = await ValidateCreateOrderAsync(customerId, lines);
if (!validation.Success)
    return ServiceResult<Order>.Fail(validation.Errors);

var customer = validation.Value!;
如此 CreateOrderAsync 主流程會只保留：
驗證
建立 Order
逐筆檢查商品狀態與庫存
扣庫存
儲存訂單
回傳結果
商品層級驗證先保留在建立訂單流程內，因為它目前同時牽涉到：查 product
判斷是否可賣
判斷庫存
扣庫存
建立 OrderItem

這段不是單純 validation，過早抽出去反而可能讓副作用變得不清楚。若之後欄位更多，可以再抽成 TryAddOrderItemAsync(...) 或 ValidateAndBuildOrderItemsAsync(...)。
測試不需要大改。先跑現有：
dotnet test
目標是維持現有測試全綠。
如果你希望驗證邏輯未來更容易單獨測，我會再加一層小型內部 helper，例如 CreateOrderValidationResult 或 OrderCreationValidator。但我建議第一步先用 OrderService private method，改動最小、符合目前專案風格，也不增加 DI 或類別數量。

問：實行1，2 排除3，4，5
答：
已依照你指定的範圍完成：
在 [OrderService.cs (line 85)](/mnt/d/AI Training/training-repo/src/OrderHub.Core/Services/OrderService.cs:85) 新增 ValidateCreateOrderAsync
在 CreateOrderAsync 開頭改成先呼叫 validation，失敗時轉回 ServiceResult<Order>.Fail(...)
商品驗證、測試執行、額外 helper/class 都沒有做
我沒有跑 dotnet test，因為你指定排除第 4 點。另：目前 shell 找不到 git，所以無法提供 git diff，只用檔案內容確認了修改區塊。

- 問題有提供了參考部分和注明了完成需求
AI了解后提供了5個調整步驟， 後面分析后只執行了前兩項。 AI也有跟著執行

### 3. AI 誤導我的地方，與我如何發現

（agent 說錯／改錯／過度自信的時刻。你靠什麼抓到——對照程式碼？頁面實測？跑測試？）

-對照程式碼

### 4. 我會帶回日常工作的一招

（一個具體、可複製的做法，不要寫「要多驗證」這種口號——寫出**操作步驟**。）

- 還沒有

## 自我驗證（做到哪個階段答哪題）

### 第一階段 — Agentic Coding

練習 1

1. 我能不看筆記說出三個專案（Web/Core/Infrastructure）各自的職責
2. 我核對過 agent 描述的建單流程，且**至少找出一處不精確或過度簡化的說法**
3. 我知道商業邏輯應該放在哪一層、新增頁面要動哪些地方

練習 2

1. 三個 bug 我都先在頁面上重現過，才開始找程式
	- 是
2. 我給 agent 的資訊包含具體觀察（頁碼／金額數字／庫存數字），而不是只貼客訴原文
	- 是
3. 每個修復都回到頁面驗證過症狀消失
	- 是
4. 每個 bug 都補了一個回歸測試，`dotnet test` 全綠
	- 是
5. 三個獨立 commit，message 說明症狀與根因
6. （思考題）為什麼原本的測試沒抓到這三個 bug？
	- 沒有對這種情況做出測試（頁面）

練習 3

1. `/Products/LowStock` 不帶參數 → 門檻 10 的結果；帶 `?threshold=3` → 結果隨之改變
	- 不帶參數會顯示錯誤（必填）
2. `?threshold=0`、`?threshold=-1` → 頁面顯示驗證錯誤，不是 500
	- viewmodel有設置了需要大於0
3. 售出數量欄位排除了 Cancelled 訂單（可用一筆已取消的訂單驗證）
	- 可以用GetLowStock_SoldQuantityLast30Days_ExcludesCancelledOrders 驗證
4. 停售（已停售 badge）商品不出現在列表
	-  StockQuantity < threshold && IsActive = 1
5. 程式分層與命名跟既有的 Products 功能一致（請 agent 自我 review 一次，並自己確認）
	- 沒有跑到
6. 至少 3 個新測試，`dotnet test` 全綠
	- 是

練習 4

1. 重構後 `dotnet test` 全綠
	- AI沒有跑，我自己跑
2. 我能說出這次重構「改善了什麼、沒有改變什麼」
	- 改善了代碼編排，容易看 容易讀
3. 我有在 code review 的角度看過 diff（不是 agent 說好就好）
	- 有

### 第二階段 — MCP Server
練習0 - AI 能夠自行控制頁面達到測試效果，并且能完成截圖

已建立新訂單並截圖結果頁。
訂單資訊：
訂單：#213
客戶：陳志明（金卡會員）
商品：SKU-1002 極光 機械鍵盤
數量：1
小計：NT$ 2,320.00
會員折扣 10%：-NT$ 232.00
應付總額：NT$ 2,088.00
截圖：[`order-213-details.png`](./order-213-details.png)

練習1 - 建立 OrderHub MCP Server

PS D:\AI Training\training-repo> dotnet build src/OrderHub.Mcp
还原完成(1.7)
  OrderHub.Core net8.0 已成功 (4.0 秒) → src\OrderHub.Core\bin\Debug\net8.0\OrderHub.Core.dll
  OrderHub.Infrastructure net8.0 已成功 (1.5 秒) → src\OrderHub.Infrastructure\bin\Debug\net8.0\OrderHub.Infrastructure.dll
  OrderHub.Mcp net10.0 已成功 (1.9 秒) → src\OrderHub.Mcp\bin\Debug\net10.0\OrderHub.Mcp.dll

在 9.9 秒内生成 已成功

新增的 MCP 工具有 3 個：
GetOrder(id)
用訂單 Id 查詢訂單詳細資料。
回傳客戶、商品明細、單價快照、小計、會員折扣率、應付總額等 JSON。

LowStock(threshold = 10)
查詢低於庫存門檻、且仍在販售中的商品。
依庫存量由低到高排序。
預設門檻是 10。

CustomerOrders(customerId)
查詢指定客戶的全部訂單摘要。
回傳訂單編號、建立時間、狀態、總額

練習 2 — 用 MCP Inspector 除錯
彈出一個MCP Inspector頁面， 可以從List Tools 中選擇工具來進行驗證數據。
這個可以方便後續的測試和撈取數據進行驗證

練習 3 — 註冊給 agent,做 before/after 對照
在把.mcp.json更名后， claude無法讀取到工具而回復說沒有工具， 需要從代碼上去尋找 》 目前 orderhub 連線已中斷,無法重新查詢。請重新連接 orderhub 後,我再重新查詢一次。
I don't have any orderhub MCP tools available in this conversation — this is the "no tools" side of your comparison
my only way to answer "which products have stock below 5" is to go dig through the repo's data/code manually.

恢復.mcp.json后，AI很快就把數據顯示出來了 》 Called orderhub 


## 附錄：值得留下的對話片段

（貼 1–2 段最有代表性的 prompt 與回應**摘要**——不用貼全文，重點是「我怎麼問」和「它怎麼答」。）
