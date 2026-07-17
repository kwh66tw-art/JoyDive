// MinimalZipReader.swift — JD2Core/Importers/
// 純 Swift、跨平台（iOS + macOS）的最小 ZIP 讀取器（僅讀取單一具名條目）。
//
// 背景：UDDFParser 原本的 ZIP 解壓（extractXMLFromZIP）透過 Process 呼叫
// macOS 系統的 /usr/bin/unzip，iOS 沙盒無法執行任意可執行檔，故原本在 iOS
// 上完全不支援 .uddf 的 ZIP 包裝格式（僅拋 unsupportedFormat）。v1.1 新增
// Suunto SDE（同樣是 ZIP 包裝）也需要這個能力，趁機一併修正 iOS 缺口。
//
// ZIP 是 PKWARE 公開規格（APPNOTE.TXT），非猜測性逆向工程；僅支援讀取，
// 支援 stored（method 0）與 deflate（method 8，用 Apple Compression framework
// 的 COMPRESSION_ZLIB —— 該常數實際對應 raw DEFLATE bitstream，是 Apple API
// 命名上的已知慣例，並非真正的 zlib-wrapped 格式）。

import Foundation
import Compression

enum MinimalZipError: Error, LocalizedError {
    case notAZip
    case entryNotFound(String)
    case unsupportedCompressionMethod(Int)
    case decompressionFailed

    var errorDescription: String? {
        switch self {
        case .notAZip: return "不是有效的 ZIP 檔案"
        case .entryNotFound(let name): return "ZIP 內找不到符合條件的檔案（\(name)）"
        case .unsupportedCompressionMethod(let m): return "不支援的 ZIP 壓縮方法（\(m)）"
        case .decompressionFailed: return "ZIP 解壓縮失敗"
        }
    }
}

enum MinimalZipReader {

    /// 讀取 ZIP 內第一個檔名符合 predicate 的條目內容
    static func extractFirstEntry(from data: Data, matching predicate: (String) -> Bool) throws -> Data {
        let bytes = [UInt8](data)
        guard let eocd = findEndOfCentralDirectory(bytes) else { throw MinimalZipError.notAZip }

        var offset = eocd.centralDirectoryOffset
        for _ in 0..<eocd.entryCount {
            guard let entry = parseCentralDirectoryEntry(bytes, at: offset) else {
                throw MinimalZipError.notAZip
            }
            if predicate(entry.filename) {
                return try extractLocalFileData(bytes, entry: entry)
            }
            offset = entry.nextEntryOffset
        }
        throw MinimalZipError.entryNotFound("(predicate 無匹配項)")
    }

    // MARK: - End Of Central Directory（從檔尾往回找 signature，容許尾端 comment 欄位）

    private struct EOCD {
        let entryCount: Int
        let centralDirectoryOffset: Int
    }

    private static func findEndOfCentralDirectory(_ bytes: [UInt8]) -> EOCD? {
        let signature: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
        guard bytes.count >= 22 else { return nil }
        // comment 欄位最長 65535 bytes；由後往前掃描 signature
        let searchFloor = max(0, bytes.count - 22 - 65535)
        var i = bytes.count - 22
        while i >= searchFloor {
            if bytes[i] == signature[0], Array(bytes[i..<(i + 4)]) == signature {
                let entryCount = readUInt16LE(bytes, i + 10)
                let cdOffset = readUInt32LE(bytes, i + 16)
                return EOCD(entryCount: entryCount, centralDirectoryOffset: cdOffset)
            }
            i -= 1
        }
        return nil
    }

    // MARK: - Central Directory Entry

    private struct CDEntry {
        let filename: String
        let compressionMethod: Int
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
        let nextEntryOffset: Int
    }

    private static func parseCentralDirectoryEntry(_ bytes: [UInt8], at offset: Int) -> CDEntry? {
        let signature: [UInt8] = [0x50, 0x4B, 0x01, 0x02]
        guard offset + 46 <= bytes.count,
              Array(bytes[offset..<(offset + 4)]) == signature else { return nil }

        let method = readUInt16LE(bytes, offset + 10)
        let compressedSize = readUInt32LE(bytes, offset + 20)
        let uncompressedSize = readUInt32LE(bytes, offset + 24)
        let filenameLen = readUInt16LE(bytes, offset + 28)
        let extraLen = readUInt16LE(bytes, offset + 30)
        let commentLen = readUInt16LE(bytes, offset + 32)
        let localHeaderOffset = readUInt32LE(bytes, offset + 42)

        guard offset + 46 + filenameLen <= bytes.count else { return nil }
        let nameBytes = Array(bytes[(offset + 46)..<(offset + 46 + filenameLen)])
        let filename = String(decoding: nameBytes, as: UTF8.self)

        let nextOffset = offset + 46 + filenameLen + extraLen + commentLen
        return CDEntry(
            filename: filename,
            compressionMethod: method,
            compressedSize: compressedSize,
            uncompressedSize: uncompressedSize,
            localHeaderOffset: localHeaderOffset,
            nextEntryOffset: nextOffset
        )
    }

    // MARK: - Local File Header + 資料本體

    private static func extractLocalFileData(_ bytes: [UInt8], entry: CDEntry) throws -> Data {
        let signature: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
        let offset = entry.localHeaderOffset
        guard offset + 30 <= bytes.count,
              Array(bytes[offset..<(offset + 4)]) == signature else {
            throw MinimalZipError.notAZip
        }
        let filenameLen = readUInt16LE(bytes, offset + 26)
        let extraLen = readUInt16LE(bytes, offset + 28)
        let dataStart = offset + 30 + filenameLen + extraLen
        guard dataStart + entry.compressedSize <= bytes.count else { throw MinimalZipError.notAZip }
        let compressedData = Data(bytes[dataStart..<(dataStart + entry.compressedSize)])

        switch entry.compressionMethod {
        case 0:
            return compressedData
        case 8:
            return try inflate(compressedData, expectedSize: entry.uncompressedSize)
        default:
            throw MinimalZipError.unsupportedCompressionMethod(entry.compressionMethod)
        }
    }

    /// Raw DEFLATE 解壓縮（Apple Compression framework 的 COMPRESSION_ZLIB 常數
    /// 實際對應 raw deflate bitstream，非 zlib-wrapped，與 ZIP method 8 相容）
    private static func inflate(_ compressed: Data, expectedSize: Int) throws -> Data {
        guard expectedSize > 0 else { return Data() }
        var output = [UInt8](repeating: 0, count: expectedSize)
        let decodedCount = output.withUnsafeMutableBytes { outPtr -> Int in
            compressed.withUnsafeBytes { inPtr -> Int in
                guard let outBase = outPtr.bindMemory(to: UInt8.self).baseAddress,
                      let inBase = inPtr.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(
                    outBase, expectedSize,
                    inBase, compressed.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard decodedCount == expectedSize else { throw MinimalZipError.decompressionFailed }
        return Data(output)
    }

    // MARK: - Little-endian 讀取

    private static func readUInt16LE(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
    }

    private static func readUInt32LE(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(bytes[offset])
            | (Int(bytes[offset + 1]) << 8)
            | (Int(bytes[offset + 2]) << 16)
            | (Int(bytes[offset + 3]) << 24)
    }
}
