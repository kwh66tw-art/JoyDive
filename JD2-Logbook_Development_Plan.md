# JD2-Logbook 開發計劃書
**版本**: 2.0（已更新為 7 種格式 + 18 週計劃）
**日期**: 2026 年 5 月 17 日  
**狀態**: 📋 開發就緒  
**預期上線**: 18 週（2026 年 10 月底）- v1.0 完整 7 種格式支援

---

## 1. Executive Summary

### 1.1 專案目標

**JD2-Logbook** 是一款 iOS/macOS 潛水日誌應用，作為 JoyDive 生態系統的第一個商業化產品。核心價值：
- **快速匯入**：支持 UDDF、SHEARWATER、Peregrine 等主流潛水電腦檔案格式
- **簡潔視覺化**：深度曲線圖、潛水統計、位置記錄
- **輕量級**：無需實時運算，完全離線可用
- **轉換管道**：為 JD2-Immersion ($14.99 Watch 記錄器) 與 JD2-Ultra (正式潛水電腦) 建立用戶基礎

### 1.2 產品定位與亮點

**核心差異化：GPS 地圖潛點管理 + 無障礙遷移**

```
JD2-Logbook v1.0 (完整電腦支援版)
├─ 免費 + 廣告
├─ 無需帳號、無社群
├─ ✨ GPS 座標記錄 & 地圖顯示潛點（核心亮點）
├─ 7 種電腦檔案匯入（UDDF + SHEARWATER + Peregrine + Cressi + Garmin + Suunto + Oceanic）
├─ 簡潔 UI：一屏完成日誌記錄
└─ iCloud 同步（可選，不強制）

$1.99 IAP (移除廣告)
└─ 相同功能，無廣告界面

【異軍突起的理由】
├─ MacDive：有 150+ 支援但 UI 複雜
├─ Currents：現代 UI 但需帳號/訂閱
├─ 本地應用：無電腦匯入、無地圖
└─ JD2-Logbook：檔案匯入 + 地圖 + 簡潔 + 免費 = 無痛遷移
```

### 1.3 商業模型

**預期財務（Year 1，中等情景）**
- 下載量：20,000-50,000
- MAU：7,000-17,500 (35% 保留率)
- 廣告收入：$5,460-13,644/年（eCPM $6.50）
- IAP 收入：$3,348-8,352/年（2% 轉換率）
- **Year 1 預期收入**：$8,808-21,996 (~$15,000 保守預估)

### 1.4 無障礙遷移策略

**吸引其他應用用戶轉移的三層策略**

| 來源應用 | 痛點 | 我們的優勢 | 遷移助力 |
|---------|------|---------|--------|
| **MacDive** | 需付費、UI 複雜 | 免費 + 簡潔 | 一鍵匯入舊日誌 (UDDF 格式) |
| **Deepblu** | 已停服、社群失效 | 功能完整、本地可用 | 支援 Deepblu JSON 匯出 |
| **Subsurface** | UI 老舊、學習陡峭 | 現代 UI、上手快 | 支援 Subsurface XML 匯入 |
| **本地應用** | 無電腦匯入、無地圖 | 電腦檔案 + 地圖 + GPS | 自訂 CSV 批量匯入 |

**核心："零摩擦遷移"**
- ✅ 無需註冊帳號（直接使用）
- ✅ 一鍵匯入舊日誌（保留歷史記錄）
- ✅ 地圖功能開箱即用（GPS 自動定位）
- ✅ 簡潔 UI（第一次打開即會用）

### 1.5 目標受眾

| 客群 | 特徵 | 優先順序 |
|------|------|--------|
| **休閒潛水愛好者** | 度假潛水 3-10 次/年，需要簡單記錄 | 🔴 最高 |
| **認證潛水員** | 記錄認證進度，管理潛點筆記 | 🔴 最高 |
| **潛水教練** | 教學記錄、學生進度追蹤 | 🟠 中等 |
| **度假村** | 客戶日誌管理、統計分析 | 🟡 次要 |

**地域優先順序**：台灣/香港 (中文優先) > 東南亞 > 北美

### 1.6 成功指標 (KPI)

| 指標 | v1.0 目標 | Logbook+ 目標 |
|------|---------|---------|
| **App Store 評分** | 4.0+ stars | 4.3+ stars |
| **月活躍用戶 (MAU)** | 3,000-5,000 | 8,000-12,000 |
| **IAP 轉換率** | 2-3% | 3-5% |
| **匯入成功率** | 95% (7 種格式) | 98% (7+ 種格式) |
| **閃退率** | < 0.5% | < 0.2% |
| **平均會話時長** | 2-3 分鐘（簡潔）| 4-6 分鐘（照片） |
| **日誌新增速度** | < 30 秒 | 照片上傳 < 5 秒/張 |
| **地圖功能使用率** | > 60% MAU | > 80% MAU |
| **他應用遷移率** | > 30% 下載來自其他應用 | 無障礙遷移完成 |

---

## 2. 競品分析與差異化定位

**📋 本部分基於詳細競品對比文件 `DiveLog-Comparison.md`，涵蓋 20+ 款潛水日誌應用的功能、定價、優劣評估。**

### 2.0 市場概況

全球潛水日誌應用市場已相當成熟，主要分為 5 個陣營：
1. **開源/跨平台型**（Subsurface）- 技術潛水員優先
2. **iOS/Mac 專屬型**（MacDive、Dive Log）- 蘋果用戶首選
3. **社群導向型**（Deepblu、Dive+、Buddy）- 休閒潛水員首選
4. **品牌專屬型**（Garmin、TUSA、Oceanic）- 設備綁定生態
5. **台灣特化型**（Explore Diving）- 在地需求

### 2.1 直接競品分析

#### 【最接近的競爭對手】

| 應用 | 定位 | 優勢 | 劣勢 | 威脅度 |
|------|------|------|------|--------|
| **MacDive** | iOS/macOS 一體化日誌 | ✅ 150+ 電腦支援、Apple Watch、UI 精緻 | ❌ iOS 專屬、無社群、$9.99 一次性 | 🔴 高 |
| **Currents** | 現代化 UI + 雲端同步 | ✅ 新秀、UI 優美、$29.99 終身解鎖 | ❌ 僅 iOS、Android 未上線 | 🔴 高 |
| **Subsurface** | 開源、技術潛水優先 | ✅ 完全免費、支援最多電腦、跨平台 | ❌ UI 老舊、非官方支援 | 🟠 中 |
| **Deepblu** | 社群 + 日誌平衡型 | ✅ 免費、國際認證、社群活躍 | ❌ 技術記錄功能弱、2024 年關閉伺服器 | 🟡 低 |
| **潛水日誌 Diving x-Log** | 台灣輕量型日誌 | ✅ 中文 UI、自動天氣、照片整合 | ❌ 功能簡陋、無電腦匯入 | 🟠 中 |

#### 【次要競爭對手】

| 應用 | 特點 | 適用客群 |
|------|------|--------|
| Dive+ | 水下攝影色彩還原 | 潛水攝影師 |
| Buddy | 潛伴配對、教練認證 | 社交潛水員 |
| 潛水日誌 Dive Number | GPS 選點、社群潛點 | 入門潛水者 |
| Diving Log 6.0 | 技術檔案管理 | 進階用戶 |

### 2.2 JD2-Logbook 的差異化優勢

**VS MacDive**
```
MacDive 優勢：
├─ 更成熟的 iOS 生態整合（已有用戶基礎）
├─ Apple Watch 完整支援
└─ 150+ 電腦支援

JD2-Logbook 優勢：✅
├─ 免費基礎版（vs $9.99 一次性）
├─ 廣告 + IAP 靈活變現 (vs 單一付費)
├─ iCloud 同步原生支援
├─ 規劃接入 Watch 記錄器（JD2-Immersion $14.99）
└─ 與 JoyDive 生態銜接（潛水電腦認證之路）
```

**VS Currents**
```
Currents 優勢：
├─ UI 更現代化（2025 最新設計）
├─ 官方開發、持續更新
└─ 訂閱模式 ($4.99/月)

JD2-Logbook 優勢：✅
├─ 免費基礎版，低進入門檻
├─ iOS + macOS 原生支援（vs Currents 僅 iOS）
├─ 多檔案格式匯入焦點（UDDF/SHEARWATER/Peregrine）
├─ 臺灣本地化優先（中文界面、客服）
└─ 明確的商品升級路線（Logbook → Immersion → Ultra）
```

**VS Subsurface (開源)**
```
Subsurface 優勢：
├─ 完全開源、免費
├─ 跨平台（Windows/Mac/Linux）
├─ 支援最多電腦型號
└─ 社群開發，不受商業限制

JD2-Logbook 優勢：✅
├─ 現代 UI/UX（vs 老舊介面）
├─ iOS/macOS 專業級設計
├─ 離線優先（Subsurface 需 Bluetooth 同步）
├─ 廣告補償免費使用成本
└─ 正式支援與快速反應（vs 開源社群延遲）
```

**VS 台灣本地應用（Diving x-Log、Dive Number）**
```
優勢：✅
├─ 電腦錶檔案匯入能力（他們只支援手動記錄）
├─ 專業級圖表與統計
├─ iCloud 同步（他們多無雲端）
├─ 國際化設計（中英文並行，為後續擴張準備）
├─ 與 JD2-Immersion/Ultra 的產品線整合

本地應用優勢：
└─ 更了解台灣潛點與使用習慣
  └─ 緩解策略：v1.1 加入台灣潛點資料庫 & 離線地圖
```

### 2.3 市場定位矩陣

```
            功能深度
              ▲
          500  │  ◆ Subsurface   ◆ Diving Log 6.0
              │ ◆ MacDive        ◆ Currents
          300  │    ◆ JD2-Logbook ✨
              │
          100  │        ◆ Deepblu  ◆ Dive+
              │     ◆ Diving x-Log
              └──────────────────────────────► 社群/社交程度
                 低          中高          高

JD2-Logbook 定位：
  ├─ 功能深度：中高 (300)
  │   - 完整日誌管理
  │   - 4+ 檔案格式匯入
  │   - 統計與視覺化
  │   - 但不涉及醫療/安全決策
  │
  └─ 社群導向：中低 (20-30%)
      - v1.0 焦點：個人日誌管理
      - v1.1 試驗：潛伴分享、潛點評論
      - 不競爭全球社群（Deepblu 已壟斷）
```

### 2.4 關鍵差異化要素

**1. 檔案匯入優先度**（核心差異）
```
JD2-Logbook v1.0：
├─ ✅ UDDF（ISO 標準，廣泛相容）
├─ ✅ SHEARWATER（Peregrine/Teric 最熱門）
├─ ✅ Peregrine（新品牌快速成長）
└─ ✅ Cressi/Mares（入門級覆蓋）

對手情況：
├─ MacDive：150+ 支援（但未列舉具體格式）
├─ Currents：4 個主流品牌（品牌導向）
├─ Subsurface：最多，但 UI 複雜
└─ 本地應用：手動記錄為主，無匯入能力

我們的優勢：
  └─ 完整格式支援 + 現代化 UI（結合兩方優勢）
```

**2. 定價模式靈活性**
```
JD2-Logbook：
├─ 免費基礎版 (with 廣告)
├─ $1.99 IAP (移除廣告)
└─ v1.1 試驗 $0.99/月 訂閱（進階功能）

對手：
├─ MacDive：$9.99 一次買斷（單一模式）
├─ Currents：$4.99/月 + $29.99 終身（高價）
├─ Subsurface：100% 免費（無獲利）
├─ Deepblu：100% 免費（已停服）
└─ 本地應用：免費 + 簡易 IAP

我們的靈活性：
  └─ 對不同用戶群體的包容策略（新手用免費版，活躍用戶升級）
```

**3. 生態系統銜接**
```
JD2-Logbook v1.0：
└─ 獨立應用

JD2-Logbook + Immersion (Year 2)：
├─ Logbook 用戶可升級至 Watch 記錄器 ($14.99)
├─ 同一帳戶 iCloud 同步
└─ 日誌無縫銜接

JD2-Logbook + Immersion + Ultra (Year 3)：
├─ 三層產品階梯
├─ 自然的用戶升級路徑
└─ 與業界潛水電腦認證整合

對手：孤立應用，無產品線延伸
  └─ MacDive、Currents、Subsurface 各自獨立
```

### 2.5 威脅評估與應對

**🔴 高威脅：MacDive & Currents**

```
威脅來源：
├─ 既有用戶基礎（MacDive）
├─ 近期融資與優化（Currents 2025 最受期待）
└─ 更成熟的付費轉換體驗

應對策略：
├─ 強調免費基礎版低進入門檻
├─ 突出檔案匯入完整性（7 種格式開箱即用，市場覆蓋 100%）
├─ 建立中文社群（他們無中文優先）
├─ 規劃與 Watch 生態銜接（Currents 尚無）
└─ 定位「入門到進階」的階梯化產品線
```

**🟠 中威脅：本地應用 + Subsurface**

```
威脅來源：
├─ 本地應用的地域優勢（Diving x-Log 有中文用戶）
├─ Subsurface 的技術信任（開源、Linus Torvalds）
└─ 免費策略的用戶習慣

應對策略：
├─ v1.1 納入台灣潛點資料庫（競爭本地應用）
├─ 維持免費基礎版（不與 Subsurface 價格戰）
├─ 強化台灣客服與中文社群
├─ 定位為「從日誌到潛水電腦」的完整生態（他們無此野心）
└─ 強調 UI 現代化與易用性
```

**🟡 低威脅：社群型應用（Deepblu、Buddy）**

```
威脅評估：
├─ Deepblu 已於 2024 年關閉伺服器（已不是威脅）
├─ Buddy 和 Dive+ 專注攝影/社交，不與日誌競爭
└─ 市場細分，不直接衝突

策略：合作大於競爭
└─ v1.1 可支援 Deepblu JSON 匯出（幫助用戶遷移）
```

### 2.6 市場進入時機評估

**時機分析**
```
2025 市場特點：
├─ ✅ Currents 剛進入 iOS（Android 未上線）
│   └─ iOS 市場仍有空缺
├─ ✅ Deepblu 停服（流離用戶轉向他處）
│   └─ 遷移時機成熟
├─ ✅ 本地應用未更新（≥ 1 年）
│   └─ 台灣市場有機會
└─ ❌ MacDive 仍佔 iOS 市場主導
    └─ 無法取代，但能細分

進入決策：✅ 時機良好
  ├─ 理由：市場分化，細分客群有空隙
  ├─ 策略：不正面碰撞 MacDive，而是差異化進入
  └─ 目標：Year 1 奪取 5-10% 的 iOS 潛水日誌市場
```

---

## 3. 功能規劃

### 3.1 v1.0 版本：完整電腦支援版（無帳號、無社群）

#### 核心功能模組 - "一次性完整，地圖為心"

| 模組 | 功能 | 優先級 | 工作量估計 |
|------|------|--------|---------|
| **日誌管理** | CRUD（新增/查看/編輯/刪除） | 🔴 P0 | 35 h |
| | 日誌列表視圖（日期排序） | 🔴 P0 | 18 h |
| | 簡潔日誌表單（一屏完成） | 🔴 P0 | 35 h |
| **✨ GPS & 地圖** | GPS 座標自動記錄 | 🔴 P0 | 25 h |
| | 地圖顯示潛點（MapKit） | 🔴 P0 | 35 h |
| | 潛點清單視圖 | 🟠 P1 | 15 h |
| **檔案匯入（核心 4 種）** | UDDF (.uddf) 解析 | 🔴 P0 | 50 h |
| | SHEARWATER 格式 | 🔴 P0 | 45 h |
| | Peregrine 格式 | 🔴 P0 | 40 h |
| | Cressi/Mares 格式 | 🔴 P0 | 35 h |
| | 匯入進度 UI + 錯誤處理 | 🔴 P0 | 20 h |
| **檔案匯入（擴展 3 種）** | Garmin Descent XML | 🔴 P0 | 55 h |
| | Suunto (SDE/XML/SDP) | 🔴 P0 | 64 h |
| | Oceanic (OCF/XML) | 🔴 P0 | 48 h |
| **數據視覺化** | 深度曲線圖表 | 🔴 P0 | 25 h |
| | 基礎統計（深度/時間） | 🟠 P1 | 18 h |
| **資料庫** | SwiftData 資料模型（含 GPS） | 🔴 P0 | 25 h |
| | 本地存儲 | 🔴 P0 | 15 h |
| | iCloud 同步（可選） | 🟡 P2 | 20 h |
| **廣告 & IAP** | AdMob/AppLovin 整合 | 🔴 P0 | 20 h |
| | $1.99 移除廣告 IAP | 🔴 P0 | 15 h |
| **設定 & 本地化** | 語言切換（中文/英文） | 🔴 P0 | 15 h |
| | 深度單位切換 (m/ft) | 🔴 P0 | 8 h |

**v1.0 總工作量**：~813 工作時數 (16-18 週，3 人團隊或 18-20 週，2 人團隊)

**❌ 不包含的功能（保留至 Logbook+）**
- 社群分享、好友功能
- 帳號/登入系統
- 照片上傳與管理
- 潛點評論與打卡
- 背景雲端同步（iCloud 為可選項）

#### v1.0 技術要求

- ✅ iOS 16+ / macOS 13+ 支持
- ✅ 完全離線優先（無需網絡連接）
- ✅ 無帳號/登入系統
- ✅ 無社群功能
- ✅ **支援 7 種潛水電腦格式**（UDDF、SHEARWATER、Peregrine、Cressi、Garmin、Suunto、Oceanic）
- ✅ **匯入成功率 ≥ 95%**（包含所有支援的設備）
- ✅ App Store 標準審核流程通過
- ✅ 無健康/醫療聲稱（純日誌應用）
- ✅ 支援 150+ 潛水電腦型號（綜合覆蓋）

### 3.2 v1.1 版本：Logbook+（照片 & 進階功能）

**上線時機**：v1.0 (Oct 2026) 穩定後 2-3 個月開始開發 → 預期 Dec 2026  
**核心概念**：保持簡潔，逐步加入多媒體與統計（不再新增檔案格式）

| 功能 | 說明 | 設計原則 | 工作量 | 預期上線 |
|------|------|---------|--------|---------|
| **照片管理** | 上傳潛點照片（本地存儲，無雲端） | 無社群負擔 | 35 h | Dec 2026 (Month 2) |
| **潛點標籤** | 標記潛點名稱、難度、海況 | 地圖視覺化 | 20 h | Dec 2026 (Month 2) |
| **進階統計** | 總潛水時數、最深、統計圖表 | 數據駕駛艙 | 30 h | Dec 2026 (Month 2) |
| **HealthKit 整合** | 導入心率資料（Apple Watch） | 健康整合 | 20 h | Jan 2027 (Month 3) |
| **搜尋 & 篩選** | 按日期、位置、深度搜尋 | 快速查找 | 25 h | Jan 2027 (Month 3) |
| **導出報告** | 匯出 PDF/CSV | 資料可攜性 | 20 h | Jan 2027 (Month 3) |

**v1.1 (Logbook+) 設計原則**：
- ❌ 仍不包含社群分享、帳號系統
- ❌ 不新增檔案格式（v1.0 已完整 7 種）
- ✅ 包含本地媒體管理（照片）
- ✅ 包含進階統計與分析
- ✅ 保持簡潔 UI（不堆積功能）

**v1.1 總工作量**：~150 工作時數（2 人，約 8-10 週）

### 3.3 優先順序說明

```
🔴 P0 - v1.0 上線必需（Week 1-18 完成）
├─ 日誌 CRUD + 簡潔表單（一屏完成）
├─ GPS 地圖顯示潛點 ✨ （核心亮點）
├─ 7 種檔案匯入 + 解析（UDDF、SHEARWATER、Peregrine、Cressi、Garmin、Suunto、Oceanic）
├─ 深度圖表
├─ SwiftData 本地存儲
└─ 廣告 + IAP 框架

🟠 P1 - v1.0.1 穩定版（Week 19-20）
├─ 潛點清單視圖
├─ 基礎統計（深度/時間）
├─ iCloud 同步基礎框架
├─ Beta 反饋修復
└─ 效能優化

🟡 P2 - v1.1 Logbook+（Dec 2026 - Month 2-3）
├─ 照片上傳與管理
├─ 潛點標籤與分類
├─ 進階統計與報表
├─ HealthKit 整合
└─ 搜尋 & 篩選功能

🟣 P3 - v2.0+（2027 Q1+）
├─ 社群功能試驗（分享、評論）
├─ Apple Watch App
├─ 次要格式支援（PADI、SSI 整合）
└─ 國際化擴展
```

---

## 4. 技術架構

### 4.1 代碼復用計劃

**來自 JoyDiveCore 的復用部分（60% 總代碼）**

```
JoyDiveCore Framework
├─ Models/ → 100% 復用
│  ├─ GasMix.swift （氣體定義、MOD 計算）
│  ├─ DiveEnvironment.swift （壓力/深度轉換）
│  └─ AlgorithmConstants.swift （常數定義）
│
├─ Algorithm/ → 30% 復用（僅驗證，非即時計算）
│  └─ Buhlmann.swift （用於檢驗匯入資料的減壓狀態）
│
└─ Utilities/ → 100% 復用
   └─ Extensions.swift （日期格式化、深度顯示、濾波）
```

**新增開發部分（40% 總代碼）**

```
JD2-Logbook/
├─ Utilities/
│  ├─ DiveLogImporter.swift (~100 行)
│  │   └─ 統一的匯入協調器
│  │
│  ├─ Parsers/
│  │  ├─ UDDFParser.swift (~150 行)
│  │  ├─ SHEARWATERParser.swift (~120 行)
│  │  ├─ PeregrineParser.swift (~100 行)
│  │  └─ CreassiMaResParser.swift (~90 行)
│  │
│  └─ DiveLogDatabase.swift (~150 行)
│      └─ SwiftData 存儲層、iCloud 同步
│
├─ Views/
│  ├─ DiveLogListView.swift (~80 行)
│  ├─ DiveDetailView.swift (~120 行，來自 JoyDiveCore 改進)
│  ├─ ImportWizardView.swift (~150 行)
│  ├─ Charts/
│  │  ├─ DepthProfileChart.swift （100% 復用）
│  │  └─ StatisticsView.swift (~100 行)
│  └─ SettingsView.swift (~80 行)
│
└─ Models/
   ├─ DiveLog.swift (~80 行，擴展基礎模型)
   ├─ DataGap.swift （100% 復用）
   └─ ImportResult.swift (~50 行)
```

**總計新代碼**：~1,200 行  
**復用代碼**：~1,800 行  
**代碼復用率**：60%

### 4.2 技術決策點

#### A. 檔案格式支援優先順序

**v1.0 必須支持（7 種）- 完整市場覆蓋**

**核心 4 種（必須，訂定上線基線）**

1. ✅ **UDDF** (Universal Dive Data Format - ISO 標準)
   - 最廣泛支援的格式（Shearwater、Peregrine、Garmin 等）
   - 市場覆蓋：30%
   - 工作量：50h
   - 優先級：🔴 最高
   - 複雜度：⭐⭐⭐⭐

2. ✅ **SHEARWATER** (Shearwater Cloud XML)
   - 最熱門專業潛水電腦 (Teric、Peregrine)
   - 市場覆蓋：25%
   - 工作量：45h
   - 優先級：🔴 最高
   - 複雜度：⭐⭐⭐

3. ✅ **Peregrine** (Shearwater Peregrine XML)
   - 新型潛水電腦，市場占有率快速成長 (2023+)
   - 市場覆蓋：10%
   - 工作量：40h
   - 優先級：🔴 最高
   - 複雜度：⭐⭐⭐

4. ✅ **Cressi/Mares** (CSV/XML)
   - 入門級市場覆蓋
   - 市場覆蓋：5%
   - 工作量：35h
   - 優先級：🔴 重要
   - 複雜度：⭐⭐

**擴展 3 種（新增，對齐 DIVEROUT）**

5. ✅ **Garmin Descent** (XML / FIT 轉換)
   - Garmin 運動手錶生態（Descent、fenix、Enduro）
   - 市場覆蓋：15%
   - 工作量：55h
   - 優先級：🔴 高
   - 複雜度：⭐⭐⭐⭐
   - 理由：Garmin 用戶基數大，與 DIVEROUT 要求對齐

6. ✅ **Suunto** (SDE 二進位 + XML + SDP 文本)
   - Suunto Zoop/D4/EON 系列，傳統與高端市場
   - 市場覆蓋：12%
   - 工作量：64h
   - 優先級：🔴 高
   - 複雜度：⭐⭐⭐⭐⭐（最複雜）
   - 理由：歐洲與南美市場，無法繞過；與 DIVEROUT 要求對齐

7. ✅ **Oceanic** (OCF 二進位 + XML)
   - Oceanic Pro Plus、Geo、Oceanic+ 應用
   - 市場覆蓋：3%
   - 工作量：48h
   - 優先級：🔴 高
   - 複雜度：⭐⭐⭐⭐
   - 理由：傳統品牌用戶，與 DIVEROUT 要求對齐

**v1.1 擴展支持（4+ 種）**
- Garmin Descent XML
- Aqualung i750 CSV
- Deepblu JSON 匯出
- 自訂 CSV 上傳
- Suunto SDE/XML/SDP 格式 ⭐
- Oceanic OCF/XML 格式 ⭐

#### C. 為什麼 Suunto/Oceanic 納入 v1.0？（決策文檔 - 已更新）

**問題背景**  
用戶問：「可以加入 Garmin + Suunto + Oceanic 嗎？」  
**決策**：✅ 確定納入 v1.0，實現完整 7 種格式支援。

**短答案**：可以加入，需要延期至 18 週，工作量 813h。推薦 3 人團隊。

**詳細技術分析**

參考文件：`FORMAT_TECHNICAL_ANALYSIS.md`（詳細的技術規範與工作量估計）

簡要總結：

| 格式 | 複雜度 | 工作量 | 難度 | 市場覆蓋 |
|------|--------|--------|------|--------|
| UDDF | 🔴 高 | 50h | ⭐⭐⭐⭐ | 30% |
| SHEARWATER | 🟠 中 | 45h | ⭐⭐⭐ | 25% |
| Peregrine | 🟠 中 | 40h | ⭐⭐⭐ | 10% |
| Cressi/Mares | 🟡 低 | 35h | ⭐⭐ | 5% |
| **Garmin** | 🔴 高 | 55h | ⭐⭐⭐⭐ | 15% |
| **Suunto** | 🔴 極高 | 64h | ⭐⭐⭐⭐⭐ | 12% |
| **Oceanic** | 🔴 高 | 48h | ⭐⭐⭐⭐ | 3% |

**決策理由**

✅ **v1.0 納入所有 7 種格式的原因**

1. **市場要求對齐**
   - DIVEROUT 應用支援 12+ 格式
   - JD2-Logbook 應至少相當於競品
   - 7 種格式覆蓋 100% 主流市場

2. **用戶無縫遷移**
   - 一次性完整匯入所有舊日誌
   - 不需多次升級應用
   - 用戶體驗最優

3. **競爭力差異化**
   - 完整性 > MacDive 150+ 格式（但實用性更高）
   - 速度 > Subsurface（現代 UI）
   - 簡潔性 > Currents（無需帳號）
   - 完整性 + 簡潔性 + 無帳號 = 獨特價值

4. **工期可控**
   - 3 人團隊 × 18 週可達成
   - 充足的測試時間 (4 週)
   - 風險可管理

**決定方案（已確定）- v1.0 包含 7 種格式**

```
v1.0：Week 18 (Oct 2026) ✅
總計：18 週一次完整發佈
優點：
  ├─ 完整市場覆蓋（100%）
  ├─ 用戶一次性遷移（無需多次升級）
  ├─ 品牌定位清晰（「業界最完整」）
  └─ 減少後續維護負擔（無格式升級壓力）

備註：相比舊計劃延期 2 個月（Aug → Oct），但一次性解決市場覆蓋問題
      是更優的商業決策。秋冬購物季仍可趕上。
```

**新的工作量與時間表**

```
Week 1-2：基礎搭建 (24h)
Week 3-8：7 種解析器 (380h)
  ├─ UDDF (50h)
  ├─ SHEARWATER (45h)
  ├─ Peregrine (40h)
  ├─ Cressi (35h)
  ├─ Garmin (55h) ⭐
  ├─ Suunto (64h) ⭐
  └─ Oceanic (48h) ⭐
Week 9-11：日誌管理 + GPS (163h)
Week 12-13：廣告 + IAP (96h)
Week 14-17：測試 + 品質控制 (150h)
───────────────────────────
總計：18 週，813h

推薦團隊配置：
├─ 3 人並行開發（每人負責 2-3 個解析器）
├─ 工作量均衡：Dev1 (270h), Dev2 (270h), Dev3 (273h)
└─ 每人週 40-45 小時，18 週內完成

備選：2 人團隊
├─ 週 45-50 小時，20-22 週完成
└─ 風險：延期到 11 月（Q4 購物季晚期）
```

**新版本規劃**

| 版本 | 格式數 | 上線時間 | 市場覆蓋 | 特點 |
|------|--------|--------|--------|------|
| **v1.0** | 7 種 | Oct 2026 (Week 18) | 100% | 完整一次性，無後續格式升級 |
| **v1.1** | 7+ 種 | Dec 2026+ | - | 照片管理、進階統計、次要格式 |
| **v2.0** | 10+ 種 | 2027 Q1+ | - | HealthKit 整合、社群功能探索 |

**風險評估與緩解**

| 風險 | 概率 | 影響 | 緩解 |
|------|------|------|------|
| Suunto 逆向工程困難 | 25% | 中 | 依賴 Subsurface 開源資源；若失敗降級為 XML+SDP only |
| Garmin XML 複雜性超期 | 20% | 中 | 預留彈性 1 週；使用第三方 XML 庫 |
| 測試檔案不足 | 40% | 低 | 聯繫社群、PADI 店家、GitHub 獲取範例 |
| 工期延期 > 1 週 | 35% | 中 | 週度 checkpoint；若超期，優先完成前 6 種 |

**最終建議**

✅ **v1.0 採用 7 種格式完整方案**

核心優勢：
- 市場覆蓋 100%（無競爭對手能比）
- 用戶一次性遷移（無需多次升級）
- 完整性 + 簡潔 UI + 無帳號 = 獨特賣點
- 3 人團隊 18 週可達成（可控風險）

時間表：
- v1.0 上線：2026 年 10 月底（Week 18）
- 與秋季/冬季市場同步
- 之後專注功能迭代 (v1.1+)，不再新增格式

商業影響：
- 延期 2 個月 (Aug → Oct)
- 但一次性解決市場覆蓋完整性問題
- 後續更新聚焦照片、統計、社群
- 品牌定位：「業界最完整的簡潔日誌應用」
```

#### B. 資料庫選型：SwiftData vs CoreData

| 因素 | SwiftData | CoreData |
|------|-----------|---------|
| 學習曲線 | ⭐⭐ (簡單) | ⭐⭐⭐⭐ (複雜) |
| iOS 版本 | iOS 17+ | iOS 5+ |
| iCloud 同步 | ✅ CloudKit 原生 | ⚠️ 需額外配置 |
| 效能 | ✅ 中等資料量優秀 | ✅ 大資料量優秀 |
| 社群 | ⭐ (新) | ⭐⭐⭐⭐ (成熟) |

**決策**：**SwiftData** ✅
- Logbook 資料量適中 (預估 50-500 次潛水)
- iCloud 同步開箱即用
- 代碼簡潔，維護成本低
- iOS 16 向後相容性可用 `CloudKit` 直接管理

#### C. 廣告框架選擇

| 框架 | 填充率 | eCPM | 支持格式 | 優先級 |
|------|--------|------|--------|--------|
| **AdMob** (Google) | 90%+ | $5-8 | 橫幅、插間、獎勵 | 🔴 首選 |
| **AppLovin** | 85% | $4-7 | 橫幅、獎勵 | 🟠 備選 |
| **Facebook Audience Network** | 75% | $3-6 | 原生、插間 | 🟡 第三 |

**決策**：**AdMob + AppLovin 瀑布流** ✅
- AdMob 為主（Google 廣告最多）
- AppLovin 為備選（AppLovin SDK 已優化）
- 工作量：15-20 小時整合

#### D. iCloud 同步方案

```
選項 A: CloudKit 直接同步 (推薦)
  ✅ SwiftData 內建支持
  ✅ 用戶無需額外設定
  ❌ 需要 iCloud 帳戶
  📊 成本：免費到 $0.15/GB/月

選項 B: 手動備份 + 還原
  ✅ 用戶控制權高
  ✅ 支持 v1.0 但無自動同步
  ❌ 使用體驗較差
  📊 成本：None

選項 C: 第三方後端 (Supabase/Firebase)
  ✅ 跨平台同步
  ❌ 工作量大 (40+ h)
  ❌ 隱私考量
  📊 成本：$10-30/月

決策：選項 A (CloudKit)
  ├─ v1.0：搭建基礎框架 (20h)
  ├─ v1.1：完整雙向同步 (30h)
  └─ 用戶無感知、無額外配置
```

### 4.3 新增模組詳細設計

#### DiveLogImporter 協調器

```swift
// 統一的匯入流程
protocol DiveLogImporter {
    func parse(fileURL: URL) throws -> [DiveLog]
    func validate(logs: [DiveLog]) -> ImportValidation
}

class DiveLogImportCoordinator {
    func importFromFile(_ url: URL) async throws -> (count: Int, errors: [ImportError]) {
        let fileExtension = url.pathExtension.lowercased()
        
        let parser: DiveLogImporter = switch fileExtension {
        case "uddf":
            UDDFParser()
        case "xml":
            // 檢測 XML 類型 (Shearwater/Peregrine)
            try detectXMLParser(url)
        case "csv":
            CreassiMaResParser()
        default:
            throw ImportError.unsupportedFormat
        }
        
        let logs = try parser.parse(fileURL: url)
        let validation = parser.validate(logs: logs)
        
        // 寫入資料庫
        return try await saveToDatabase(logs, validation: validation)
    }
}
```

#### SwiftData 儲存層

```swift
import SwiftData

@Model
final class DiveLog {
    // 基礎欄位（來自 JoyDiveCore）
    @Attribute(.unique) var id: UUID
    var diveNumber: Int
    var diveDate: Date
    var location: String?
    var gasMix: GasMix
    var environment: DiveEnvironment
    
    // 擴展欄位（Logbook 特定）
    var maxDepth: Double
    var diveTime: TimeInterval
    var waterTemp: Double?
    var notes: String?
    var photo: Data?  // 潛點圖片 (JPEG, max 5MB)
    var buddyName: String?
    var certificationLevel: String?
    
    // 狀態管理
    var isManualEntry: Bool = false
    var importSource: String?  // "UDDF", "SHEARWATER" 等
    var lastModified: Date
    
    // 計算欄位
    var formattedDate: String {
        DateFormatter.localizedString(from: diveDate, dateStyle: .medium, timeStyle: .none)
    }
    
    var avgDepth: Double {
        maxDepth * 0.65  // 粗估，基於統計
    }
}

@Model
final class DiveLogDatabase {
    @ModelContext var modelContext
    
    func saveDiveLog(_ log: DiveLog) throws {
        modelContext.insert(log)
        try modelContext.save()
    }
    
    func fetchAllDives(sortBy: SortDescriptor<DiveLog> = SortDescriptor(\.diveDate, order: .reverse)) -> [DiveLog] {
        let descriptor = [sortBy]
        return try? modelContext.fetch(FetchDescriptor(sortBy: descriptor))
    }
    
    func iCloudSync() throws {
        // CloudKit 同步邏輯
        try modelContext.save()
    }
}
```

### 4.4 整合計畫

**與 JoyDiveCore 的整合點**

```
Phase 1: 代碼複製 (Week 1-2)
├─ Copy Models/, Constants/, Utilities/ 到 JD2-Logbook
├─ 調整 import 路徑
└─ 驗證編譯無誤

Phase 2: 檔案解析 (Week 3-8)
├─ 實作 4 個 Parser
├─ 單元測試（10+ 測試檔案）
└─ 與 DiveLog 模型對應

Phase 3: UI 整合 (Week 9-12)
├─ SwiftData 儲存層
├─ 視圖層與資料綁定
├─ 廣告 & IAP 框架
└─ 全面 Beta 測試

Phase 4: 上線準備 (Week 13-16)
├─ App Store 提審
├─ 社群反饋修復
└─ v1.0 發佈
```

---

## 5. 開發里程碑

### 5.1 週層級開發計畫（16-18 週 - 完整版）

**更新說明**：納入 7 種格式支援後，調整為 18 週完整計劃（3 人並行開發）  
**備註**：若 2 人團隊，預估需 20-22 週（工期延期風險）

#### **Week 1-2: 基礎搭建**

| 任務 | 負責人 | 時數 | 交付物 |
|------|--------|------|--------|
| Xcode 工作區設置 | Lead | 4 | xcworkspace + SPM 配置 |
| JoyDiveCore 集成 | Dev 1 | 6 | 代碼複製、編譯驗證 |
| SwiftData 模型定義 | Dev 2 | 8 | DiveLog.swift + database 層 |
| 多格式解析器架構設計 | Dev 3 | 6 | 統一的 parser protocol + 協調器架構 |
| UI 框架搭建 | Design | 6 | Figma 設計稿（列表、詳情、匯入） |
| **小計** | | **30 h** | **可編譯的 MVP 骨架 + 解析器基礎** |

**里程碑檢查**：✅ 應用能否編譯運行？✅ Parser protocol 是否支援多種格式？

---

#### **Week 3-6: 核心 4 種解析器實作**

| 任務 | 負責人 | 時數 | 交付物 |
|------|--------|------|--------|
| UDDF 解析器實作 | Dev 1 | 50 | UDDFParser.swift + 10 測試檔案 |
| SHEARWATER 解析器 | Dev 1 | 45 | SHEARWATERParser.swift + 5 測試檔案 |
| Peregrine 解析器 | Dev 2 | 40 | PeregrineParser.swift + 5 測試檔案 |
| Cressi/Mares 解析器 | Dev 2 | 35 | CreassiMaResParser.swift + 10 測試檔案 |
| ImportCoordinator 設計與整合 | Lead | 10 | 統一匯入流程、錯誤處理 |
| **小計** | | **180 h** | **4 種格式 100% 支持，驗證完備** |

**里程碑檢查**：✅ 每種格式能否正確解析測試檔案？✅ 單元測試覆蓋率 > 80%？

---

#### **Week 7-8: 擴展 3 種解析器實作**

| 任務 | 負責人 | 時數 | 交付物 |
|------|--------|------|--------|
| Garmin Descent XML 解析器 | Dev 3 | 55 | GarminParser.swift + 8 測試檔案 |
| Suunto (SDE/XML/SDP) 解析器 | Dev 1 | 64 | SuuntoParser.swift (多格式支援) + 15 測試檔案 |
| Oceanic (OCF/XML) 解析器 | Dev 2 | 48 | OceanicParser.swift (二進位 + XML) + 12 測試檔案 |
| 跨格式相容性測試 | QA | 15 | 混合檔案批量匯入驗證 |
| **小計** | | **182 h** | **7 種格式 100% 支持** |

**里程碑檢查**：✅ Garmin、Suunto、Oceanic 各能解析多版本檔案？✅ 批量匯入成功率 > 95%？

---

#### **Week 9-10: 日誌管理與 GPS 地圖核心**

| 任務 | 負責人 | 時數 | 交付物 |
|------|--------|------|--------|
| DiveLogListView （簡潔版） | Dev 2 | 18 | 列表視圖、日期排序、快速篩選 |
| 簡潔日誌表單 UI | Dev 1 | 35 | 一屏完成日誌記錄、表單驗證 |
| GPS 座標記錄 | Dev 3 | 25 | 自動地理位置擷取、精度驗證 |
| 地圖顯示潛點 (MapKit) | Dev 3 | 35 | 地圖視圖、潛點標籤、縮放互動 ✨ |
| ImportWizardView 流程 | Dev 1 | 20 | 檔案選擇 → 預覽 → 確認 → 進度顯示 |
| DepthProfileChart 整合 | Dev 2 | 20 | 深度曲線圖（來自 JoyDiveCore） |
| 本地存儲 + GPS 測試 | QA | 15 | SwiftData CRUD + 地理位置驗證 |
| **小計** | | **168 h** | **日誌管理 + GPS 地圖核心完成** |

**里程碑檢查**：✅ 日誌 CRUD 完整？✅ GPS 座標能否記錄？✅ 地圖能否顯示 100+ 潛點？

---

#### **Week 11-12: 廣告、IAP、設定與本地化**

| 任務 | 負責人 | 時數 | 交付物 |
|------|--------|------|--------|
| AdMob + AppLovin 整合 | Dev 2 | 20 | 橫幅 + 插間廣告、瀑布流 |
| IAP 框架 ($1.99 移除廣告) | Dev 1 | 18 | 購買流程、收據驗證、恢復購買 |
| 語言切換 (中文/英文) | Dev 3 | 12 | Localizable.strings 完整化 |
| 單位設定 (m/ft) | Dev 3 | 8 | UserDefaults 持久化 |
| SettingsView 簡潔版 | Dev 2 | 8 | 語言、單位、關於設定 |
| iCloud 同步（可選框架） | Dev 1 | 15 | CloudKit 基礎框架建立 |
| 潛點清單視圖 | Dev 3 | 15 | 按位置聚類的潛點列表、統計 |
| **小計** | | **96 h** | **貨幣化 + 本地化 + 潛點視圖完成** |

**里程碑檢查**：✅ IAP 能否正常購買？✅ 廣告能否顯示？✅ 語言切換有效？

---

#### **Week 13-17: 整合測試、優化與上線準備**

| 任務 | 負責人 | 時數 | 交付物 |
|------|--------|------|--------|
| 單元測試編寫（7 種解析器） | QA | 30 | 各 3+ 單元測試，覆蓋率 > 85% |
| 集成測試 (全流程) | QA | 25 | 匯入 → 視覺化 → IAP → 導出全流程 |
| 相容性測試（多設備） | QA | 15 | iPhone 12/13/14/15，iPad 相容性驗證 |
| 性能優化 | Dev 1 | 20 | 地圖 < 200ms、列表滑動 60fps |
| UI/UX 簡潔化 & 修正 | Design + Dev 2 | 20 | 按鈕可點性、字體層級、間距調整 |
| Beta 測試招募與反饋 | Product | 15 | TestFlight 100+ 測試者，收集反饋 |
| Bug 修復與回歸測試 | Dev 1-3 | 50 | 優先順序修復、防止 regression |
| 地圖性能優化（100+ 潛點） | Dev 3 | 15 | 聚類算法、記憶體最佳化 |
| 網絡安全檢查（iCloud） | Lead | 10 | 資料加密驗證、隱私政策審核 |
| App Store 提審準備 | Product | 15 | 截圖、描述、隱私政策、功能描述、分級 |
| 上線前檢查清單 | Lead | 10 | 最終審查、備災計劃 |
| **小計** | | **225 h** | **v1.0 正式發佈準備完成** |

**里程碑檢查**：✅ 閃退率 < 0.5%？✅ GPS 功能穩定？✅ App Store 審批通過？✅ 所有 7 種格式 > 95% 成功率？

---

#### **Week 6-8: 日誌管理與地圖核心**

| 任務 | 負責人 | 時數 | 交付物 |
|------|--------|------|--------|
| DiveLogListView （簡潔版） | Dev 2 | 18 | 列表視圖、日期排序 |
| 簡潔日誌表單 UI | Dev 1 | 35 | 一屏完成日誌記錄 |
| GPS 座標記錄 | Dev 2 | 25 | 自動地理位置擷取 |
| 地圖顯示潛點 (MapKit) | Dev 1 | 35 | 地圖視圖、潛點標籤 ✨ |
| ImportWizardView （流程） | Dev 2 | 20 | 檔案選擇 → 預覽 → 確認 |
| DepthProfileChart 整合 | Dev 1 | 20 | 深度曲線圖（來自 JoyDiveCore） |
| 本地存儲 + GPS 測試 | Dev 1 | 10 | SwiftData CRUD + 地理位置驗證 |
| **小計** | | **163 h** | **日誌管理 + GPS 地圖核心完成** |

**里程碑檢查**：✅ 日誌能否新增、查看、編輯、刪除？ ✅ GPS 座標能否記錄？ ✅ 地圖能否顯示潛點？

---

#### **Week 9-10: 廣告、IAP、設定與本地化**

| 任務 | 負責人 | 時數 | 交付物 |
|------|--------|------|--------|
| AdMob + AppLovin 整合 | Dev 2 | 20 | 橫幅 + 插間廣告、瀑布流 |
| IAP 框架 ($1.99 移除廣告) | Dev 1 | 18 | 購買流程、收據驗證 |
| 語言切換 (中文/英文) | Dev 2 | 12 | Localizable.strings 完整化 |
| 單位設定 (m/ft) | Dev 2 | 8 | UserDefaults 持久化 |
| SettingsView 簡潔版 | Dev 2 | 8 | 語言、單位設定 |
| iCloud 同步（可選，v1.0.1） | Dev 1 | 15 | CloudKit 基礎框架 |
| 潛點清單視圖 | Dev 1 | 15 | 按位置聚類的潛點列表 |
| **小計** | | **96 h** | **貨幣化 + 本地化 + 潛點視圖完成** |

**里程碑檢查**：✅ IAP 能否正常購買? ✅ 語言切換有效? ✅ 廣告能否顯示? ✅ 潛點清單能否正確聚類?

---

#### **Week 11-13: 測試、優化、上線**

| 任務 | 負責人 | 時數 | 交付物 |
|------|--------|------|--------|
| 單元測試編寫 | QA | 20 | 解析器 8+、GPS 3+、資料庫 3+ 測試 |
| 集成測試 | QA | 18 | 匯入全流程、GPS 地圖、IAP |
| 性能優化 (地圖 < 200ms) | Dev 1 | 15 | 地圖渲染最佳化、記憶體優化 |
| UI/UX 簡潔化 | Design | 15 | 一屏表單、地圖交互、易用性 |
| Beta 測試招募與反饋 | Product | 12 | TestFlight 測試者 50-100 人 |
| Bug 修復與回歸 | Dev 1+2 | 35 | 優先順序修復清單 |
| App Store 提審準備 | Product | 10 | 截圖、描述、隱私政策、功能描述 |
| 上線前檢查清單 | Lead | 8 | 最終審查 (見 7.3 節) |
| **小計** | | **133 h** | **v1.0 正式發佈** |

**里程碑檢查**：✅ 閃退率 < 0.5%？ ✅ GPS 功能穩定？ ✅ App Store 審批通過？

---

### 5.2 關鍵決策點與風險

| 週次 | 決策點 | 影響 | 緩解方案 |
|------|--------|------|--------|
| Week 3-4 | UDDF + SHEARWATER 解析複雜度評估 | 若超時會延遲整個解析器週期 | ① 每個解析器獨立 unit test，立即發現問題 ② 若超期 >3 天，停止 Peregrine 開發，聯繫 Subsurface 社群尋求幫助 |
| Week 7-8 | **Suunto SDE 逆向工程可行性** | 🔴 高風險，直接影響時程 | ① 優先依賴 Subsurface 開源資源（已成熟） ② 若資源不足，降級為僅支援 XML+SDP（跳過 SDE）③ 預留 1 週彈性 |
| Week 7-8 | Garmin XML 複雜度超期 | 可能延遲 GPS 地圖開發 | ① 使用 Swift XMLDecoder（官方庫） ② 預留 1 週補時 ③ 考慮外部 XML 庫（Alomofire） |
| Week 9 | 地圖性能（100+ 潛點） | 若卡頓，使用體驗降級 | ① 早期性能測試（Week 7） ② 採用聚類演算法而非全量繪製 ③ 若需要，改用 Canvas 而非 MapKit overlay |
| Week 11-12 | App Store IAP 審核 | 可能拒審（廣告或定價議題） | ① 提前模擬審核，調整描述文案 ② 若被拒，改為 $2.99 或訂閱制 ③ 預留 2 週重審窗口 |
| Week 13 | Beta 反饋質量不足（< 50 人） | 發佈品質風險 | ① 主動招募 PADI dive shop、潛水社團 ② 擴大 TestFlight 群體至 150+ ③ 若仍不足，延遲 1-2 週 |
| Week 15-16 | 測試發現重大 bug（> 5 個 P0） | 延期上線 | ① 週度 regression testing ② 優先修復 P0（致命）③ P1 降至 v1.0.1 ④ 最遲延期 1 週 |
| Week 18 | 上線後崩潰率 > 0.5% | 緊急回滾或熱修復 | ① 預留上線後 48h 監控窗口 ② 準備 1-2 個熱修復版本 ③ 若無法控制，立即召集 3 人應急修復 |
| 持續 | 測試檔案不足（獲取困難） | 某個格式驗證不完整 | ① Week 0 就開始聯繫社群、GitHub、PADI ② 尋求 Subsurface、MacDive 用戶捐贈 ③ 若確實缺乏，標註「X 型號未驗證」於 Release Notes |

---

## 6. 商業與變現

### 6.1 廣告策略

**投放位置**

```
主列表 (每 5 個潛水):
├─ 中間插入 300×50 橫幅廣告
└─ 位置：在 FlatList 的第 5、10、15 項

詳情頁 (底部粘性):
├─ 320×50 粘性橫幅
└─ IAP 購買後自動隱藏

匯入成功後:
├─ 全屏插間廣告 (30 秒後自動關閉)
└─ "升級移除廣告" CTA 按鈕
```

**廣告聯播網配置**

```
Primary: Google AdMob
├─ 廣告單元 ID（待配置）
├─ 預期填充率：90%+
└─ eCPM 預估：$6.50 (健身類應用)

Secondary: AppLovin
├─ 作為備選源
├─ 預期填充率：85%
└─ 瀑布流設置優先級

禁止設定:
├─ 不展示成人/賭博廣告
├─ 不展示醫療申請
└─ 不展示投資/加密廣告 (品牌保護)
```

**預期收入計算**

```
假設：20,000 下載 × 35% 保留率 = 7,000 MAU
假設：日活 (DAU) = 1,000 (14% 的 MAU)

月廣告展示次數估計：
├─ 日均會話：1,000 user × 1.5 session/day = 1,500 session/day
├─ 每會話展示：2-3 廣告 = 3,000-4,500 展示/day
├─ 月展示：90,000-135,000

年度廣告收入：
├─ CPM $6.50（健身類應用溢價）
├─ 月收入 = (90,000-135,000) × $6.50 / 1000 = $585-877
├─ 年度 = $7,020-10,524
│
└─ 保守估計 (60% 填充率) = $4,200-6,300/年
```

### 6.2 IAP 定價與轉換

**$1.99 移除廣告 IAP**

```
購買流程:
1. 使用者看到廣告 → "移除廣告?" 按鈕
2. 彈窗顯示價格 $1.99 + App Store 交易費用說明
3. 點擊確認 → App Store 認證 & 購買
4. 成功後：廣告全部隱藏，本地標籤記錄

轉換率目標：
├─ 保守：1.5% (3 人 / 200 DAU)
├─ 中等：2.5% (10 人 / 400 DAU)
└─ 樂觀：4% (16 人 / 400 DAU)

年度 IAP 收入估計：
├─ MAU 7,000 × 30% 轉換率 = 2,100 users/month
├─ 每月新購：2,100 × 2% = 42 購買/月
├─ 月收入：42 × $1.99 × 0.7 (Apple 分成) = $58
├─ 年度 = $696
│
備註：上述為保守估計。最優化應用：
├─ 針對重活躍用戶的推薦 (存在 3+ 月)
├─ 限時折扣 ($.99 首次購買)
└─ 預期年度可達 $2,000-3,500
```

**v1.1 訂閱模式試驗** (Optional)

```
結構：免費版 (with 廣告) + $0.99/月訂閱（自動續訂）

訂閱內容：
├─ 移除廣告 (同 IAP)
├─ 月份報告 (PDF 生成)
└─ 優先客服支援

預期轉換：1% MAU = 70 訂閱用戶 × $0.99 × 0.7 = $48/月
年度訂閱收入：$576

評估指標 (Week 24)：
├─ 如果訂閱轉換 < 0.5% → 棄用
├─ 如果訂閱轉換 > 1.5% → 升級為 $1.99/月
└─ 如果介於中間 → 保持測試
```

### 6.3 商業風險與機遇

**潛在風險**

| 風險 | 概率 | 影響 | 緩解策略 |
|------|------|------|--------|
| App Store 廣告政策變更 | 20% | 中 | 預留季度收入應急金 |
| 新競品進入市場 | 30% | 中 | 強化中文社群、品牌建設 |
| 用戶隱私訴訟 (iCloud 同步) | 5% | 高 | 聘用法律顧問、完善隱私政策 |
| 潛水電腦廠商封鎖檔案存取 | 10% | 低 | 支援多格式備選、開源替代 |

**增長機遇**

```
1. 潛水度假村 B2B 合作 (Week 16+)
   └─ 白標版本、客戶日誌管理
   └─ 預期月度收入：$500-2,000/度假村

2. 潛水教練認證課程集成 (Week 24+)
   └─ PADI/SSI 課程進度追蹤
   └─ 預期月度收入：$200-500/教練

3. 東南亞本地化擴展 (Week 20+)
   └─ 泰文、越南文、印尼文支援
   └─ 預期擴展用戶 +30%

4. 應用內導購到 JD2-Immersion (Year 2)
   └─ 當用戶使用 Watch 時，應用推送「升級至 Immersion」
   └─ 預期轉換 5-10% (在 Logbook 活躍用戶中)
```

---

## 7. 檢查清單

### 7.1 開發前準備項目 (Week 0)

**技術準備**
- [ ] Xcode 15.3+ 安裝並驗證
- [ ] iOS 16 SDK + macOS 13 SDK 已下載
- [ ] GitHub 倉庫已建立 (private，含 .gitignore)
- [ ] CI/CD 流程配置 (GitHub Actions 或 Xcode Cloud)
- [ ] CocoaPods / SPM 依賴清單確認
- [ ] JoyDiveCore 代碼審計完成 (13 項修復已應用)

**商業與法律**
- [ ] Apple Developer 帳戶建立 (3 個 Bundle ID)
  - `com.jd2.logbook.ios`
  - `com.jd2.logbook.macos`
  - `com.jd2.logbook.watchos` (v1.1)
- [ ] AdMob 帳戶申請 + App ID 配置
- [ ] AppLovin 帳戶申請 + SDK 金鑰
- [ ] 隱私政策草稿完成 (含 iCloud 同步說明)
- [ ] 免責聲明初稿 (App Store 適用)
- [ ] 法律顧問審查隱私政策

**設計與內容**
- [ ] UI/UX 設計稿完成 (Figma)
- [ ] 應用圖標 (1024×1024 + 各尺寸)
- [ ] App Store 截圖 5 張 (中文、英文各版本)
- [ ] 應用描述文案 (中文、英文)
- [ ] 關鍵詞清單 (20-30 個相關詞)

**團隊與溝通**
- [ ] 開發團隊角色分配
  - Lead (架構、Code Review)
  - Dev 1 (演算法、解析)
  - Dev 2 (UI、資料庫)
  - QA (測試、文件)
  - Product (需求、行銷)
- [ ] 每週迴圈開會時程確認 (Standup、Review)
- [ ] Slack / GitHub 通知規則設置

---

### 7.2 每週完成檢查 (Sprint Planning)

**Week 開始**
```
Monday 早晨：
☐ Sprint 規劃會議 (1 小時)
  ├─ 確認該週目標與交付物
  ├─ 識別阻礙與依賴
  └─ 調整優先順序

☐ 代碼檢查
  ├─ 檢視上週 Merge 的 PR
  ├─ 驗證沒有引入 regression
  └─ 檢查測試覆蓋率 (目標 > 70%)
```

**週中進行**
```
Wednesday：
☐ 中期同步
  ├─ 檢查進度是否在軌
  ├─ 識別風險並調整計劃
  └─ Demo 可運行的功能

Friday：
☐ Sprint 完成檢查
  ├─ 確認所有 PR 已 Merge
  ├─ 更新 GitHub Issues
  └─ 文件更新（README、注釋）
```

---

### 7.3 上線前檢查清單 (Week 15)

**功能完整性**
- [ ] **所有 7 個檔案格式能完整匯入** ⭐
  - [ ] UDDF (.uddf) - 包含 zip 處理、XML 解析
  - [ ] SHEARWATER (XML) - 多版本相容性
  - [ ] Peregrine (XML) - ppO2/減壓資訊
  - [ ] Cressi/Mares (CSV) - 編碼/格式變體
  - [ ] Garmin Descent (XML) - namespace 正確解析
  - [ ] Suunto (SDE + XML + SDP) - 三種格式併行
  - [ ] Oceanic (OCF + XML) - 二進位與 XML 混合
- [ ] 匯入成功率 ≥ 95% (7 種格式各 10+ 測試檔案)
- [ ] 日誌列表、詳情、編輯全部可用
- [ ] 深度圖表正確顯示（無數據丟失、採樣率正確）
- [ ] GPS 地圖正確顯示潛點（支援 100+ 潛點聚類）
- [ ] 廣告在所有頁面正確顯示
- [ ] IAP 購買流程完整（成功 + 失敗 + 恢復購買場景）
- [ ] iCloud 同步基礎可用 (可選但推薦)
- [ ] 支援中文、英文介面切換
- [ ] 深度單位轉換 (m/ft) 正確

**技術品質**
- [ ] 單元測試覆蓋率 > 85% (特別是 7 個解析器)
- [ ] 集成測試涵蓋關鍵流程
  - [ ] 匯入全流程（檔案選擇 → 預覽 → 確認 → 儲存）
  - [ ] CRUD（新增 → 查看 → 編輯 → 刪除）
  - [ ] GPS 記錄與地圖顯示
  - [ ] IAP 購買與廣告隱藏
- [ ] **格式相容性驗證** ⭐
  - [ ] UDDF 各 10+ 測試檔案（不同潛水電腦輸出）
  - [ ] SHEARWATER 各 5+ 版本檔案
  - [ ] Peregrine 各 5+ Nitrox/Trimix 檔案
  - [ ] Cressi/Mares CSV 各 10+ （不同編碼）
  - [ ] Garmin 各 8+ (Descent Mk1/Mk2/Mk3)
  - [ ] Suunto 各 15+ (SDE v1-v4, XML, SDP)
  - [ ] Oceanic 各 12+ (OCF + XML)
- [ ] Memory leak 檢查 (Xcode Instruments) - 無 significant leaks
- [ ] **閃退率 < 0.5%** (Beta 100+ 用戶 × 1 週測試) ⭐
- [ ] 啟動時間 < 3 秒 (iPhone 12 以上)
- [ ] UI 回應時間 < 100ms (列表滑動 60fps，地圖縮放 < 200ms)
- [ ] 批量匯入效能（1000+ 筆日誌 < 5 秒）

**安全與隱私**
- [ ] 敏感資料 (HealthKit 授權) 已加密儲存
- [ ] iCloud 同步資料已加密 (CloudKit 預設)
- [ ] 隱私政策已發佈至應用描述
- [ ] 無硬編碼的密鑰或 Token
- [ ] 網路請求已使用 HTTPS (若有)

**本地化**
- [ ] 所有字符串已進 Localizable.strings
- [ ] 中文與英文翻譯完整
- [ ] RTL 語言無障礙 (基礎檢查)
- [ ] 日期格式化符合地區偏好
- [ ] 數字格式 (小數點、千位分隔) 正確

**App Store 準備**
- [ ] 應用圖標 (1024×1024) 已提交
- [ ] 截圖已製作 (5 張，至少中文、英文各版本)
- [ ] 應用描述已撰寫 (100-170 字)
- [ ] 關鍵詞已設定 (20-30 個)
- [ ] 首頁類別已選擇 (健康健身)
- [ ] 分級問卷已完成
- [ ] 聯絡支援郵件已配置
- [ ] 隱私政策 URL 已設置
- [ ] TestFlight Beta 已驗證 (50+ 內測用戶，無重大 issue)

**外部整合**
- [ ] AdMob App ID 已配置 + 廣告單元測試成功
- [ ] AppLovin SDK 已整合 + 測試成功
- [ ] Firebase Analytics (可選) 已配置
- [ ] Sentry / Bugsnag (可選) 已配置用於崩潰報告

**文件與知識轉移**
- [ ] README.md 已更新 (安裝、開發步驟、架構概述)
- [ ] CONTRIBUTING.md 已撰寫 (開發指南)
- [ ] API 文件已完成 (主要類別和方法)
- [ ] 已編寫上線後支援手冊
- [ ] 已準備客服常見問題 (FAQ)

---

### 7.4 上線後監控指標 (Week 16+)

**Day 1 - 48h**
- [ ] 崩潰率監控 < 0.5%
- [ ] 廣告填充率 > 85%
- [ ] IAP 轉換率 > 0.5%
- [ ] 無法啟動的使用者佔比 < 1%
- 若任何指標異常，準備熱修復

**Week 1 - 7**
- [ ] DAU 達成目標 (500+ 是 green)
- [ ] IAP 轉換率趨勢 (目標 1.5-2.5%)
- [ ] App Store 評分 > 3.5 stars (中等)
- [ ] 常見崩潰原因已識別並修復

**Month 1**
- [ ] 用戶保留率分析
  - Day 1 保留：40-50%
  - Day 7 保留：20-30%
  - Day 30 保留：10-15%
- [ ] 檔案匯入成功率 (目標 95%+)
- [ ] 社群反饋收集 (Reddit、Facebook 潛水社團)
- [ ] v1.0.1 熱修復發佈 (若需要)

---

## 8. 技術棧總結

### 依賴與框架

```
核心框架：
├─ SwiftUI (UI 開發，iOS 16+)
├─ SwiftData (本地存儲)
├─ CloudKit (iCloud 同步)
└─ Combine (事件驅動)

整合框架：
├─ HealthKit (心率資料，可選 v1.1)
├─ WatchConnectivity (Watch 同步，v1.1)
└─ AdMob + AppLovin (廣告)

測試框架：
├─ XCTest (單元測試)
├─ XCUITest (UI 自動化測試)
└─ 第三方：Quick + Nimble (可選，改善可讀性)

圖表庫：
├─ Charts for iOS (推薦，穩定)
└─ 備選：iOS Native Canvas (更輕量)

版本控制：
├─ Git + GitHub (含 Actions CI/CD)
└─ 分支策略：main + develop + feature/*
```

### 支援版本

```
iOS：16.0+ (主要)
   ├─ 85% 的用戶使用 iOS 16+（Apple 2025 數據）
   └─ 不支援 iOS 15 及以下

macOS：13.0+ (次要，使用 Catalyst)
   ├─ 與 iOS 版本共享 90% 代碼
   └─ 不支援 macOS 12 及以下

watchOS：不在 v1.0 範圍內 (v1.1 計劃)
```

---

## 9. 風險管理

### 高優先級風險

| 風險 | 概率 | 影響 | 緩解策略 |
|------|------|------|--------|
| **檔案格式解析失敗** | 30% | 高 | 早期單元測試 (Week 3)，與潛水電腦用戶社群合作取得測試檔案 |
| **App Store IAP 審核拒絕** | 15% | 高 | 預先申請預審，與蘋果開發者關係團隊溝通 |
| **iCloud 同步隱私問題** | 10% | 中高 | 法律顧問審查，隱私政策清晰說明資料處理 |
| **廣告填充率低** | 20% | 中 | 多廣告網絡瀑布流，A/B 測試廣告位置 |
| **用戶保留率低 (< 10%)** | 25% | 中 | 使用 Logbook 獲客為 funnel 上層，預期保留率偏低 |

### 中優先級風險

| 風險 | 概率 | 影響 | 緩解策略 |
|------|------|------|--------|
| 開發進度延遲 1-2 週 | 40% | 中 | 每週 Sprint 同步、優先推遲 P2 功能 |
| 新 iOS 版本發佈 (compatibility) | 80% | 低 | 每季度檢查新 SDK，使用 @available 條件編譯 |
| 團隊成員離職 | 10% | 高 | 知識文件化、code review 兩人檢查 |

---

## 10. 後續計劃與願景

### v1.1 (Month 6-8)

```
功能增強：
├─ 好友分享 (深潛日誌分享連結)
├─ 潛點評論與照片 (社群)
├─ Apple Watch 摘要視圖 (不含計算)
└─ 8+ 檔案格式支援

商業化：
├─ 訂閱模式試驗 ($0.99/月 測試)
├─ 度假村白標版本 (B2B)
└─ 預期 MAU 增長至 15,000-25,000
```

### v2.0 方向 (Year 2)

```
大型功能：
├─ HealthKit 深度整合 (心率、步數)
├─ 社群平台 (潛水夥伴、挑戰)
├─ AI 推薦 (根據經驗推薦潛點)
└─ 多語言支援 (泰文、越南文、日文)

商業轉換：
└─ Logbook 用戶升級至 JD2-Immersion (Watch) 的自然管道
```

---

## 11. 成功標準

### v1.0 發佈成功標準

✅ **必須達成**
- 上線 App Store (審批通過)
- MAU > 2,000
- 閃退率 < 0.5%
- IAP 首月轉換 > 1%
- 檔案匯入成功率 > 95%

⚠️ **需改進但不阻擋上線**
- 廣告填充率 < 80%（預期 90%）
- 用戶評分 < 4 stars (目標 4+)
- iCloud 同步不穩定 (延遲至 v1.0.1)

❌ **必須修復後上線**
- 任何編譯警告
- 任何數據丟失相關的 bug
- App Store 審核拒絕
- 隱私政策不合規

---

## 附錄 A: 參考文檔與資訊來源

```
📚 已有的 JoyDive 文件：
├─ JoyDive_三專案策略評估.md （總體策略）
├─ QUICK_REFERENCE.md （技術快速參考）
├─ CODE_AUDIT_AND_FIXES.md （13 項修復詳解）
├─ XCODE_IMPORT_GUIDE.md （Xcode 設置）
├─ IMPLEMENTATION_GUIDE.md （5 階段開發藍圖）
└─ DiveLog-Comparison.md （竞品功能對比分析 - Section 2 的數據來源）

📋 需新建的文件 (此計劃後)：
├─ API_DOCUMENTATION.md （SwiftData、Parser API）
├─ TESTING_GUIDE.md （單元測試、集成測試）
├─ DEPLOYMENT_GUIDE.md （上線與監控）
├─ USER_MANUAL.md （應用說明書）
└─ FAQ.md （常見問題解答）
```

---

## 附錄 B: 命令列快速參考

```bash
# 代碼檢查
swiftlint

# 單元測試
xcodebuild test -scheme JD2-Logbook -configuration Debug

# 代碼覆蓋率
xcodebuild test -scheme JD2-Logbook -derivedDataPath ~/DerivedData \
  -enableCodeCoverage YES

# 建置 Release
xcodebuild build -scheme JD2-Logbook -configuration Release -arch arm64

# 啟動模擬器
xcrun simctl launch booted com.jd2.logbook.ios
```

---

**文檔版本**：1.0  
**最後更新**：2026-05-17  
**維護者**：Kevin (Product Lead)  
**審批者**：待定

---

**📌 立即行動項目**

1. ✅ 本計劃已審閱無誤
2. ⏳ 團隊角色分配 (本週完成)
3. ⏳ GitHub 倉庫初始化 (本週完成)
4. ⏳ UI/UX 設計稿定版 (Week 1 完成)
5. ⏳ Week 1 Sprint 開始日期確認

