// DivesoftDLFParser.swift — JD2Core/Importers/
// v1.1 格式擴充：Divesoft Freedom/Liberty 專有二進位日誌格式（.dlf）。
//
// ⚠️ Divesoft 官方未公開規格書。本實作的欄位偏移與換算係數已對照開源
// divesoft-parser（MIT License，github.com/DiveWithDamian/divesoft-parser）
// 的實際 Python 原始碼逐位元校正，並用本專案 TestFiles/Divesoft/ 底下真實
// 二進位樣本 + Subsurface 對照解碼的 .dlf.xml 交叉驗證：
//   start_time / max_depth / min_temperature / dive_record_count 四個欄位
//   皆與地面真相（ground truth）精確吻合（dive_record_count 亦與檔案大小
//   (fileSize-32)/16 完全整除一致）。僅解析 Point 型別記錄（一般深度採樣
//   點）；Configuration/Event/Measurement 等記錄型別（韌體版本、氣體切換
//   事件等）目前略過，故氣體配置固定回退為 Air，日後如需精確氣體切換
//   歷史可再擴充 EventRecordParser 對應的位元配置。
//
// 檔案結構：
//   offset 0-31   ：32 bytes header（"DivE" 魔數 + start_time + duration +
//                   dive_record_count + min_temperature + max_depth 等）
//   offset 32...  ：dive_record_count 筆 × 16 bytes 記錄（型別由前 4 bits 決定，
//                   Point=0 為深度採樣點，其餘型別略過）

import Foundation

struct DivesoftDLFParser: DiveLogImporter {

    let format = DiveLogFormat.divesoft

    func canHandle(filePath: String) -> Bool {
        let ext = (filePath as NSString).pathExtension.lowercased()
        guard ext == "dlf" else { return false }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else { return false }
        return validateContent(data)
    }

    func validateContent(_ data: Data) -> Bool {
        guard data.count >= 32 else { return false }
        return data.prefix(4).elementsEqual(Array("DivE".utf8))
    }

    func parse(from filePath: String) throws -> [DiveLog] {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DiveLogImportError.fileNotFound(filePath)
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath),
                                   options: .mappedIfSafe) else {
            throw DiveLogImportError.corruptedData("無法讀取: \(filePath)")
        }
        guard !data.isEmpty else { throw DiveLogImportError.emptyFile }
        return try Self.parseBinaryData(data)
    }

    // MARK: - 靜態輔助（供單元測試直接呼叫）

    static func parseBinaryData(_ data: Data) throws -> [DiveLog] {
        let bytes = [UInt8](data)
        guard bytes.count >= 32, bytes.prefix(4).elementsEqual(Array("DivE".utf8)) else {
            throw DiveLogImportError.invalidFormat("非 Divesoft DLF 格式（缺少 DivE 標記）")
        }
        guard let header = DLFHeader(bytes: bytes) else {
            throw DiveLogImportError.parsingFailed("DLF header 解析失敗（檔案過短）")
        }
        guard header.durationSeconds > 0, header.maxDepth >= 0 else {
            throw DiveLogImportError.parsingFailed("DLF header 欄位無效")
        }

        var samples: [DiveProfileSample] = []
        var offset = 32
        var recordsRead = 0
        while recordsRead < header.diveRecordCount, offset + 16 <= bytes.count {
            let record = Array(bytes[offset..<(offset + 16)])
            if let point = DLFPointRecord(record) {
                samples.append(DiveProfileSample(
                    timeSeconds: Double(point.whenSeconds),
                    depthMeters: point.depthMeters,
                    waterTemp: point.temperature
                ))
            }
            offset += 16
            recordsRead += 1
        }

        let dive = DiveLog(
            dateTime: header.startTime,
            location: "",
            maxDepth: header.maxDepth,
            diveTimeSeconds: header.durationSeconds,
            gasMixJSON: "\"air\"",   // Point 記錄不含氣體百分比；Event 記錄的氣體切換暫未解析
            waterTemperature: header.minTemperature
        )
        dive.sourceFormat = "divesoft-dlf"

        if !samples.isEmpty {
            let sorted = samples.sorted { $0.timeSeconds < $1.timeSeconds }
            if let jsonData = try? JSONEncoder().encode(sorted),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                dive.profileSamplesJSON = jsonStr
            }
        }

        return [dive]
    }
}

// MARK: - 位元陣列（LSB-first、逐 byte 排列；對照 divesoft-parser BitArray 驗證過）

/// bit index 0 = 第一個 byte 的最低位元；bit index 8 = 第二個 byte 的最低位元，依此類推。
/// getInt(start, end) 回傳以 bit[start] 為結果最低位元、往上疊加至 bit[end-1] 的整數。
private struct DLFBitArray {
    let bytes: [UInt8]

    func getInt(_ start: Int, _ end: Int) -> Int {
        var result = 0
        for i in start..<end {
            let byteIndex = i / 8
            let bitIndex = i % 8
            guard byteIndex < bytes.count else { continue }
            if (bytes[byteIndex] & (1 << bitIndex)) != 0 {
                result |= (1 << (i - start))
            }
        }
        return result
    }
}

private func dlfReadUInt16LE(_ bytes: [UInt8], _ offset: Int) -> Int {
    Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
}

private func dlfReadUInt32LE(_ bytes: [UInt8], _ offset: Int) -> Int {
    Int(bytes[offset])
        | (Int(bytes[offset + 1]) << 8)
        | (Int(bytes[offset + 2]) << 16)
        | (Int(bytes[offset + 3]) << 24)
}

// MARK: - Header（32 bytes）

private struct DLFHeader {
    let startTime: Date
    let durationSeconds: Int
    let maxDepth: Double
    let minTemperature: Double
    let diveRecordCount: Int

    /// 2000-01-01T00:00:00Z 的 Unix epoch 秒數（Divesoft 韌體自訂基準時間）
    private static let dlfEpochOffset: TimeInterval = 946_684_800

    init?(bytes: [UInt8]) {
        guard bytes.count >= 24 else { return nil }
        // offset 0-3   : "DivE" 魔數（呼叫端已驗證）
        // offset 4-5   : 未知欄位（原始 SDK 亦未解讀，略過）
        // offset 6-7   : log_number（不影響 DiveLog 欄位，略過）
        // offset 8-11  : start_time = dlfEpochOffset + uint32 秒數
        let epochDelta = dlfReadUInt32LE(bytes, 8)
        startTime = Date(timeIntervalSince1970: Self.dlfEpochOffset + TimeInterval(epochDelta))

        // offset 12-15 : bit_array_1 → duration(17bit) / no_deco(1bit) / dive_mode(3bit) / test(1bit)
        let bitArray1 = DLFBitArray(bytes: Array(bytes[12..<16]))
        durationSeconds = bitArray1.getInt(0, 17)

        // offset 16-19 : bit_array_2 → dive_record_count(18bit) / min_temperature×10(10bit) / dive_day_number(4bit)
        let bitArray2 = DLFBitArray(bytes: Array(bytes[16..<20]))
        diveRecordCount = bitArray2.getInt(0, 18)
        minTemperature = Double(bitArray2.getInt(18, 28)) / 10.0

        // offset 20-21 : max_depth（公尺 ×100，uint16 LE）
        maxDepth = Double(dlfReadUInt16LE(bytes, 20)) / 100.0
    }
}

// MARK: - Point Record（16 bytes：4 bytes 型別+when，12 bytes 內容）

private struct DLFPointRecord {
    let whenSeconds: Int
    let depthMeters: Double
    let temperature: Double

    init?(_ record: [UInt8]) {
        guard record.count == 16 else { return nil }
        let typeBits = DLFBitArray(bytes: Array(record[0..<4]))
        guard typeBits.getInt(0, 4) == 0 else { return nil }   // DiveRecordType.Point = 0

        whenSeconds = typeBits.getInt(4, 21)

        let data = Array(record[4..<16])   // 12 bytes 內容
        depthMeters = Double(dlfReadUInt16LE(data, 0)) / 100.0
        // ppo2 = dlfReadUInt16LE(data, 2) / 10000.0 — 暫不使用，保留供未來擴充

        let bitArray2 = DLFBitArray(bytes: Array(data[4..<8]))
        // no_deco_time = bitArray2.getInt(0,10)*60 秒、ascent_time = bitArray2.getInt(10,20)*60 秒 — 暫不使用
        temperature = Double(bitArray2.getInt(20, 30)) / 10.0
    }
}
