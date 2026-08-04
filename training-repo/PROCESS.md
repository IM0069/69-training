# MCP 設計筆記

## Resource(折扣規則) vs. 讓 agent 自己讀 OrderService.cs

`orderhub://discount-rules`(`OrderHubResources.cs`)和 `OrderService.GetDiscountRate`
(`src/OrderHub.Core/Services/OrderService.cs`)現在是同一條規則的兩份寫法:

```csharp
CustomerTier.Gold => 0.10m,
CustomerTier.Silver => 0.05m,
```

```markdown
- Silver:95 折
- Gold:9 折
```

**用 Resource 給:**
- agent 讀到的是「給人看的結論」,不用自己反推 C# 邏輯,也不會誤讀到不相關的實作細節(null 合併、四捨五入位數、方法命名)
- 不需要 agent 有原始碼存取權——換成透過 claude.ai 網頁版接這個 MCP server 的人,一樣讀得到
- 便宜:一次 resource read,不用 grep + 讀檔 + 推理
- 但這是**第二個真相來源**:改了 `GetDiscountRate` 卻忘記同步改 `OrderHubResources.cs`,agent 會很有自信地講出過期規則,而且沒有任何機制會提醒你兩邊不一致

**讓 agent 自己讀 OrderService.cs:**
- 永遠是活的、單一真相來源,不會有「兩份文件對不上」的問題
- 但耦合到程式碼結構:方法改名、邏輯搬到別的 service、邏輯拆成多個 helper,agent 都可能讀錯或找不到
- 需要原始碼存取權,且每次都要花 token 去讀檔 + 推理才能萃取出「現在的規則是什麼」
- 洩漏了不該給業務使用者看到的實作細節

**結論**:折扣規則這種「相對穩定、外部人也該看得懂」的知識適合用 Resource,但要有紀律——**改規則的 PR 必須同時改 `OrderService.cs` 和 `OrderHubResources.cs`**,否則 Resource 會變成一份會說謊的文件。目前沒有測試或 CI 檢查這兩邊是否一致,是這個設計的已知風險。

## Prompt 範本放 server vs. 每個人自己打一段話

`low_stock_report`(`OrderHubPrompts.cs`)把「該用哪些 tool、什麼順序、輸出成什麼格式」寫死成一個 slash command。

**放在 server(現在的做法):**
- 一份寫在 git 裡、經過 code review 的標準流程,採購同事每次執行 `/mcp__orderhub__low_stock_report` 拿到的都是同一套步驟
- 流程要改(例如之後想在步驟裡加一個「查近 30 天銷量」的 tool call),只要改這一個檔案,所有人下次執行就自動套用新流程
- 討論這個 prompt 寫得好不好,是在討論一份具體的程式碼,而不是在討論某人腦中的習慣

**每個人自己打:**
- N 個人會寫出 N 種版本,有人會漏掉「查近期訂單狀況」這步、有人輸出格式跟別人不一樣,後續彙整報告時格式對不上
- 「標準流程」只存在於某人的聊天記錄或記憶裡,那個人請假或離職,流程就跟著消失或失傳
- 流程要改,得逐一告訴每個人,實際上通常不會真的統一改到,文件(如果有)跟實際做法會慢慢分岔

**結論**:規則改版時要改幾個地方,是這兩個問題共通的判斷標準——
Resource 版的折扣規則,理想上該改 1 處,但現況要手動改 2 處(`OrderService.cs` + `OrderHubResources.cs`);
Prompt 放 server 版的採購流程,改版只要 1 處(`OrderHubPrompts.cs`);
Prompt 沒有 server 化的版本,改版理論上要通知 N 個人、實際上通常 0 處真的被改到,流程直接跟現實脫節。
