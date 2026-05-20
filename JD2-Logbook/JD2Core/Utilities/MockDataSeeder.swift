// MockDataSeeder.swift — JD2Core/Utilities/MockDataSeeder.swift
// v1.0
//
// 大量 Mock 數據注入工具類別，用於性能與渲染測試

import Foundation
import SwiftData

/// 大量 Mock 數據注入工具，協助測試 Map 渲染、日誌列表效能與 SwiftData 大數據加載
final class MockDataSeeder {
    
    /// 知名潛點與正確的 GPS 坐標對應表，用來產生具備真實地理資訊的潛水日誌
    private static let mockSites: [(name: String, lat: Double, lon: Double, env: String)] = [
        // 台灣東北角 & 北部
        ("龍洞三號", 25.1189, 121.9213, "seawater"),
        ("鼻頭角公園", 25.1278, 121.9189, "seawater"),
        ("潮境公園", 25.1438, 121.8021, "seawater"),
        ("野柳潛點", 25.2078, 121.6912, "seawater"),
        
        // 台灣南部 & 離島
        ("墾丁後壁湖出水口", 21.9392, 120.7441, "seawater"),
        ("墾丁合界", 21.9567, 120.7188, "seawater"),
        ("小琉球花瓶岩", 22.3564, 120.3821, "seawater"),
        ("小琉球衫福沉船", 22.3421, 120.3589, "seawater"),
        ("綠島大香菇", 22.6489, 121.4723, "seawater"),
        ("蘭嶼八代灣沉船", 22.0298, 121.5342, "seawater"),
        
        // 印尼科莫多 (Komodo)
        ("Castle Rock, Komodo", -8.4419, 119.5719, "seawater"),
        ("Crystal Rock, Komodo", -8.4462, 119.5694, "seawater"),
        ("Batu Bolong, Komodo", -8.5634, 119.5742, "seawater"),
        ("Manta Point, Komodo", -8.5912, 119.5938, "seawater"),
        
        // 馬爾地夫 (Maldives)
        ("Maaya Thila, Maldives", 3.9934, 72.8874, "seawater"),
        ("Fish Head, Maldives", 3.9482, 72.8421, "seawater"),
        ("Banana Reef, Maldives", 4.2234, 73.5312, "seawater"),
        
        // 日本沖繩 (Okinawa)
        ("萬座毛真榮田岬 (青之洞窟)", 26.4442, 127.7719, "seawater"),
        ("石垣島川平灣 (Manta Scramble)", 24.4612, 124.1489, "seawater"),
        
        // 淡水及高海拔環境
        ("日月潭", 23.8616, 120.9158, "freshwater"),
        ("翠峰湖", 24.5121, 121.6143, "altitude"),
        ("Lake Tahoe, USA", 39.0968, -120.0324, "altitude")
    ]
    
    private static let mockBuddies = [
        "Alex Chen", "Emily Wong", "Michael Tanaka", "Jessica Miller", "David Smith",
        "Sarah Jenkins", "Kenji Sato", "Sophia Carter", "Liam Davies", "Olivia Taylor"
    ]
    
    private static let mockNotes = [
        "看見了三隻綠蠵龜和一整群的梭魚，水下能見度非常棒，約有 20 米。",
        "流很強，下潛時要緊抓頂流繩。在斷崖邊看到灰真鯊在巡邏，十分震撼！",
        "輕鬆的放流潛水，沿著珊瑚牆漂流。看到很多微距生物，包括海蛞蝓和豆丁海馬。",
        "夜潛。看到很多寄居蟹、夜行性魚類和一隻正在捕食的章魚。浮游生物會發光，很美！",
        "沉船潛水。內部結構完整，有許多玻璃魚聚集。導航需要特別注意，避免迷失方向。",
        "水溫偏冷，穿 5mm 濕式防寒衣剛好。練習了浮力控制和打浮力袋，進步很多。",
        "高海拔淡水潛水。需要特別注意 Buhlmann 減壓算法的高海拔修正，組織分壓上升較快。",
        "能見度普通（約 8 米），主要是沙地地形。看到幾隻魟魚半埋在沙子裡休息。"
    ]
    
    private static let mockGases = [
        "\"air\"",
        "{\"o2Percent\":32,\"heliumPercent\":0}", // Nitrox 32%
        "{\"o2Percent\":36,\"heliumPercent\":0}", // Nitrox 36%
        "{\"o2Percent\":21,\"heliumPercent\":35}" // Trimix 21/35 (用於深潛測試)
    ]

    /// 注入大量 Mock 數據
    /// - Parameters:
    ///   - database: 潛水日誌資料庫實例
    ///   - count: 要產生的日誌筆數 (預設為 105 筆)
    /// - Returns: 成功產生的潛水日誌陣列
    @MainActor
    @discardableResult
    static func seed(database: DiveLogDatabase, count: Int = 105) throws -> [DiveLog] {
        var dives: [DiveLog] = []
        let calendar = Calendar.current
        let now = Date()
        
        for i in 0..<count {
            // 隨機選取潛點資訊
            let site = mockSites[i % mockSites.count]
            
            // 計算日期 (從現在往回推隨機天數，分佈在過去兩年內)
            let randomDaysAgo = Int.random(in: 1..<(365 * 2))
            let randomMinutes = Int.random(in: 0..<1440)
            guard let baseDate = calendar.date(byAdding: .day, value: -randomDaysAgo, to: now),
                  let diveDate = calendar.date(byAdding: .minute, value: randomMinutes, to: baseDate) else {
                continue
            }
            
            // 根據潛點決定最大深度與潛水時長
            let isDeep = (i % 7 == 0) // 每 7 筆注入一筆深潛
            let maxDepth = isDeep ? Double.random(in: 30.0...42.0) : Double.random(in: 12.0...25.0)
            let diveTimeSeconds = isDeep ? Int.random(in: 1800...2400) : Int.random(in: 2400...3600) // 30-40分 或 40-60分
            
            // 氣體
            let gasMixJSON = isDeep ? mockGases[3] : (i % 3 == 0 ? mockGases[1] : mockGases[0])
            
            // 隨機水溫 (根據是否深潛或高海拔/淡水做調整)
            var temp = Double.random(in: 23.0...28.0)
            if site.env == "freshwater" || site.env == "altitude" {
                temp = Double.random(in: 15.0...20.0)
            } else if isDeep {
                temp = Double.random(in: 18.0...22.0)
            }
            
            // 建立 DiveLog 實例
            let log = DiveLog(
                dateTime: diveDate,
                location: site.name,
                maxDepth: maxDepth,
                diveTimeSeconds: diveTimeSeconds,
                gasMixJSON: gasMixJSON,
                waterTemperature: temp
            )
            
            // 設定 GPS 座標
            // 微調坐標避免完全重疊在同一個點 (抖動 0.0005 以內，約 50 米)
            let latJitter = Double.random(in: -0.0005...0.0005)
            let lonJitter = Double.random(in: -0.0005...0.0005)
            log.setLocation(latitude: site.lat + latJitter, longitude: site.lon + lonJitter)
            
            // 設定環境類型
            log.setEnvironment(
                type: site.env,
                surfacePressure: site.env == "altitude" ? 0.85 : 1.0,
                metersPerBar: site.env == "freshwater" ? 10.3 : 10.0
            )
            
            // 其他細節
            log.buddy = i % 4 == 0 ? nil : mockBuddies.randomElement()
            log.notes = mockNotes.randomElement() ?? ""
            log.sourceFormat = i % 5 == 0 ? "UDDF" : (i % 8 == 0 ? "FIT" : "manual")
            
            dives.append(log)
        }
        
        // 批次寫入資料庫
        try database.addBatch(dives)
        
        print("MockDataSeeder: 成功注入 \(dives.count) 筆測試數據！")
        return dives
    }
}
