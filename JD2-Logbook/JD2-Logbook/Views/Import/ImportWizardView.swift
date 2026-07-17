// ImportWizardView.swift — JD2-Logbook/Views/Import/
// Week 9  — 3 步驟匯入嚮導
// Week 13 — 批次匯入（多選檔案 + 選資料夾）+ 逐檔進度顯示

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - 匯入精靈狀態機

enum ImportStep {
    case ready
    /// total == 0 → 掃描/準備階段（不確定進度）；total > 0 → 逐檔匯入
    case importing(current: Int, total: Int, fileName: String)
    case success(count: Int, skipped: Int)
    case failure(message: String)
}

// MARK: - Main View

struct ImportWizardView: View {
    @Environment(AppLanguageManager.self) private var languageManager
    @State private var step: ImportStep = .ready
    @State private var showFilePicker = false
    /// 顯示在 ready 頁的上次選擇摘要（"dive.uddf" 或 "3 files"）
    @State private var selectedFileLabel: String? = nil

    /// 匯入成功後回調：傳回最新一筆潛水的 PersistentIdentifier（用於 highlight）
    var onImportSuccess: ((PersistentIdentifier?) -> Void)? = nil

    /// 暫存最新匯入的潛水 ID，等用戶按「Done」時才觸發 tab 切換
    @State private var pendingHighlightID: PersistentIdentifier? = nil

    private let coordinator = ImportCoordinator(database: DiveLogDatabase.shared)

    var body: some View {
        // macOS：NavigationStack 由 MainTabView 容器層提供（避免雙層 nav bar 產生頂部空白）
        #if os(iOS)
        NavigationStack { importContent }
        #else
        importContent
        #endif
    }

    private var importContent: some View {
        VStack(spacing: 0) {
            stepIndicator

            Divider()

            ScrollView {
                switch step {
                case .ready:
                    readyView
                case .importing(let current, let total, let fileName):
                    importingView(current: current, total: total, fileName: fileName)
                case .success(let count, let skipped):
                    successView(count: count, skipped: skipped)
                case .failure(let message):
                    failureView(message: message)
                }
            }

            PremiumAwareAdBanner(adUnitID: AdUnitID.importBanner)
        }
        .navigationTitle(Text(verbatim: languageManager.localized("Import Dives")))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "uddf") ?? .xml,
                UTType(filenameExtension: "ssrf") ?? .xml,
                UTType(filenameExtension: "fit")  ?? .data,
                .xml,
                .json,
                .commaSeparatedText,
                .folder,
                // v1.1 格式擴充（file_format_research 18 格式盤點）
                UTType(filenameExtension: "sml")  ?? .xml,     // Suunto SML
                UTType(filenameExtension: "sde")  ?? .zip,     // Suunto SDE（ZIP 包裝）
                UTType(filenameExtension: "dl7")  ?? .plainText,  // DAN DL7
                UTType(filenameExtension: "zxu")  ?? .plainText,
                UTType(filenameExtension: "zxl")  ?? .plainText,
                UTType(filenameExtension: "dlf")  ?? .data,    // Divesoft DLF
                UTType(filenameExtension: "dat")  ?? .plainText,  // Reefnet Sensus
                UTType(filenameExtension: "sql")  ?? .database,   // Diving Log 6.0
                UTType(filenameExtension: "sqlite") ?? .database,
                .plainText   // .txt（DAN DL7 / Cressi 等文字格式的相容副檔名）
            ],
            allowsMultipleSelection: true
        ) { result in
            handleFilePickerResult(result)
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(Array(stepLabels.enumerated()), id: \.offset) { index, label in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(stepCircleColor(index))
                            .frame(width: 26, height: 26)
                        if stepIsCompleted(index) {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(stepCircleTextColor(index))
                        }
                    }
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(stepLabelColor(index))
                }
                .frame(maxWidth: .infinity)

                if index < stepLabels.count - 1 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                        .frame(maxWidth: 24)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.platformGroupedBackground)
    }

    private var stepLabels: [String] {
        [String(localized: "Select"),
         String(localized: "Import"),
         String(localized: "Result")]
    }

    private var currentStepIndex: Int {
        switch step {
        case .ready:               return 0
        case .importing:           return 1
        case .success, .failure:   return 2
        }
    }

    private func stepCircleColor(_ index: Int) -> Color {
        if index <= currentStepIndex { return .accentColor }
        return Color.platformTertiaryFill
    }

    private func stepCircleTextColor(_ index: Int) -> Color {
        index <= currentStepIndex ? .white : .secondary
    }

    private func stepLabelColor(_ index: Int) -> Color {
        index == currentStepIndex ? .primary : .secondary
    }

    private func stepIsCompleted(_ index: Int) -> Bool {
        index < currentStepIndex
    }

    // MARK: - Step 1: Ready

    // 按鈕移到清單上方（原本排在 16 種格式清單之後，每次都要先捲到底才看得到，
    // 使用者回報體驗不佳）：header → 按鈕 → 上次選擇摘要 → 格式清單，常用操作
    // 一開頁就在畫面內，格式清單當作「參考資訊」自然排在後面即可捲動查閱。

    private var readyView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                    .padding(.top, 20)

                Text("Auto-detects format from file content")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showFilePicker = true
            } label: {
                Label(String(localized: "Select Files or Folder"), systemImage: "folder")
                    .font(.headline)
                    #if os(iOS)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    #endif
            }
            .buttonStyle(.borderedProminent)
            #if os(iOS)
            .controlSize(.large)
            .padding(.horizontal, 24)
            #else
            .controlSize(.regular)
            .padding(.horizontal, 16)
            #endif
            .accessibilityLabel(String(localized: "Select Files or Folder"))
            .accessibilityHint("Opens file picker to choose dive log files or a folder")

            if let label = selectedFileLabel {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.tint)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 24)
            }

            supportedFormatsSection

            Spacer(minLength: 40)
        }
        .padding(.bottom, 20)
    }

    // 16 種格式以品牌/來源分組＋單欄列表列呈現（取代舊版 2 欄卡片格線——格式數從
    // v1.1 前的 6 種增至 16 種後，無分類的 2 欄格線難以掃視）。列的視覺語彙
    // port 自 JD2-Ultra companion 的 ValueRow/NavRow 慣例（DiveComponents.swift）：
    // 圖示＋標題置左、次要資訊置右，同分組共用一個 grouped 卡片背景＋列間 Divider，
    // 對齊 iOS 原生 List(.insetGrouped) 的視覺語言。

    private var supportedFormatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Supported Formats"))
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 24)

            #if os(macOS)
            // macOS 視窗較寬，單欄清單得往下捲一大段才看完；拆兩欄並排（左：
            // Universal＋Suunto＝8 列，右：Garmin＋Other Brands＝8 列，剛好平衡），
            // 讓整份格式清單盡量在一頁內看完。
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    FormatGroupSection(title: supportedFormatGroups[0].title, formats: supportedFormatGroups[0].formats)
                    FormatGroupSection(title: supportedFormatGroups[1].title, formats: supportedFormatGroups[1].formats)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    FormatGroupSection(title: supportedFormatGroups[2].title, formats: supportedFormatGroups[2].formats)
                    FormatGroupSection(title: supportedFormatGroups[3].title, formats: supportedFormatGroups[3].formats)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            #else
            VStack(alignment: .leading, spacing: 14) {
                ForEach(supportedFormatGroups, id: \.title) { group in
                    FormatGroupSection(title: group.title, formats: group.formats)
                }
            }
            .padding(.horizontal, 16)
            #endif
        }
    }

    private var supportedFormatGroups: [(title: String, formats: [(name: String, ext: String, icon: String)])] {
        [
            (String(localized: "Universal"), [
                ("UDDF",                              ".uddf, .zip",  "doc.badge.gearshape"),
                (String(localized: "Subsurface XML"), ".ssrf / .xml", "doc.richtext"),
                (String(localized: "Subsurface CSV"), ".csv",         "tablecells"),
                (String(localized: "Seabear CSV"),    ".csv",         "tablecells.fill")
            ]),
            ("Suunto", [
                ("Suunto DM4/DM5",                    ".xml",         "applewatch.watchface"),
                ("Suunto SML",                        ".sml",         "applewatch.watchface"),
                ("Suunto SDE",                        ".sde",         "applewatch.watchface"),
                (String(localized: "Suunto JSON"),    ".json",        "curlybraces")
            ]),
            ("Garmin", [
                (String(localized: "Garmin Descent"), ".fit",         "waveform.path.ecg"),
                ("Garmin Connect",                    ".json",        "curlybraces")
            ]),
            (String(localized: "Other Brands"), [
                ("Shearwater Cloud",                  ".xml",         "gauge.with.dots.needle.67percent"),
                ("DAN DL7",                            ".dl7, .zxu, .zxl",   "doc.text"),
                ("Divesoft DLF",                       ".dlf",               "doc.text"),
                ("Reefnet Sensus",                     ".csv, .dat",         "tablecells.fill"),
                ("Diving Log 6.0",                     ".sql, .sqlite, .db", "cylinder.split.1x2"),
                ("Deepblu COSMIQ+",                    ".json",              "curlybraces")
            ])
        ]
    }

    // MARK: - Step 2: Importing（逐檔進度）

    private func importingView(current: Int, total: Int, fileName: String) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)

            if total > 0 {
                // 確定進度：線性進度條 + 檔案計數
                VStack(spacing: 16) {
                    ProgressView(value: Double(current - 1), total: Double(total))
                        .progressViewStyle(.linear)
                        .padding(.horizontal, 40)
                        .tint(.accentColor)

                    VStack(spacing: 6) {
                        Text("File \(current) of \(total)")
                            .font(.headline)
                            .monospacedDigit()

                        Text(fileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 40)
                    }
                }
            } else {
                // 掃描/準備階段：不確定轉圈
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.6)
                        .tint(.accentColor)

                    Text(String(localized: "Scanning files"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .frame(minHeight: 300)
        .accessibilityLabel(
            total > 0
                ? "Importing file \(current) of \(total): \(fileName)"
                : "Scanning files"
        )
    }

    // MARK: - Step 3: Success

    private func successView(count: Int, skipped: Int) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text(String(localized: "Import Successful"))
                .font(.title2.bold())

            VStack(spacing: 6) {
                Text("\(count) dive\(count == 1 ? "" : "s") imported")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if skipped > 0 {
                    Text("\(skipped) skipped (duplicates)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                resetToReady()
            } label: {
                Text("Done")
                    .font(.headline)
                    #if os(iOS)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    #endif
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            #if os(iOS)
            .padding(.horizontal, 40)
            #endif

            Spacer()
        }
        .frame(minHeight: 360)
    }

    // MARK: - Step 3: Failure

    private func failureView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Import Failed")
                .font(.title2.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                resetToReady()
            } label: {
                Text("Try Again")
                    .font(.headline)
                    #if os(iOS)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    #endif
            }
            .buttonStyle(.bordered)
            #if os(iOS)
            .padding(.horizontal, 40)
            #endif

            Spacer()
        }
        .frame(minHeight: 360)
    }

    // MARK: - Actions

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            // 進入掃描狀態，立即給用戶視覺反饋
            step = .importing(current: 0, total: 0, fileName: "")

            Task { @MainActor in
                let tempDir = FileManager.default.temporaryDirectory
                // (displayName, tempURL)：displayName 保留原始檔名供 UI 顯示
                var tempFiles: [(name: String, url: URL)] = []

                for pickerURL in urls {
                    let accessed = pickerURL.startAccessingSecurityScopedResource()

                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: pickerURL.path, isDirectory: &isDir)

                    if isDir.boolValue {
                        // 資料夾：在 security scope 有效期間枚舉並複製全部支援檔案
                        let found = enumerateSupportedFiles(in: pickerURL)
                        for fileURL in found {
                            let tempURL = tempDir.appendingPathComponent(
                                UUID().uuidString + "_" + fileURL.lastPathComponent
                            )
                            if (try? FileManager.default.copyItem(at: fileURL, to: tempURL)) != nil {
                                tempFiles.append((name: fileURL.lastPathComponent, url: tempURL))
                            }
                        }
                    } else {
                        // 單一檔案
                        let tempURL = tempDir.appendingPathComponent(
                            UUID().uuidString + "_" + pickerURL.lastPathComponent
                        )
                        if (try? FileManager.default.copyItem(at: pickerURL, to: tempURL)) != nil {
                            tempFiles.append((name: pickerURL.lastPathComponent, url: tempURL))
                        }
                    }

                    if accessed { pickerURL.stopAccessingSecurityScopedResource() }
                }

                guard !tempFiles.isEmpty else {
                    step = .failure(message: "No supported dive log files found.")
                    return
                }

                selectedFileLabel = tempFiles.count == 1
                    ? tempFiles[0].name
                    : "\(tempFiles.count) files"

                await runBatchImport(tempFiles: tempFiles)
            }

        case .failure(let error):
            step = .failure(message: error.localizedDescription)
        }
    }

    /// 遞迴枚舉資料夾內支援格式的潛水日誌檔案，依檔名排序
    private func enumerateSupportedFiles(in folderURL: URL) -> [URL] {
        let supported = Set([
            "uddf", "ssrf", "xml", "json", "csv", "fit", "zip",
            // v1.1 格式擴充（file_format_research 18 格式盤點）
            "sml", "sde", "dl7", "zxu", "zxl", "dlf", "dat",
            "sql", "sqlite", "db", "txt"
        ])
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
            else { continue }
            if supported.contains(fileURL.pathExtension.lowercased()) {
                files.append(fileURL)
            }
        }
        return files.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 批次匯入：逐檔處理，更新 step 進度；完成後切到 success / failure
    private func runBatchImport(tempFiles: [(name: String, url: URL)]) async {
        let total = tempFiles.count
        var allImported: [DiveLog] = []
        var firstError: String? = nil

        for (index, file) in tempFiles.enumerated() {
            step = .importing(current: index + 1, total: total, fileName: file.name)

            do {
                let imported = try await coordinator.importFile(file.url.path)
                allImported.append(contentsOf: imported)
            } catch DiveLogImportError.emptyFile {
                // 空檔案：跳過，不中斷批次
            } catch DiveLogImportError.fileNotFound(let path) {
                if firstError == nil { firstError = "File not found: \(path)" }
            } catch DiveLogImportError.unsupportedFormat(let fmt) {
                if firstError == nil { firstError = "\(file.name): unsupported format (\(fmt))" }
            } catch DiveLogImportError.parsingFailed(let msg, _) {
                if firstError == nil { firstError = "\(file.name): \(msg)" }
            } catch DiveLogImportError.invalidFormat(let fmt) {
                if firstError == nil { firstError = "\(file.name): invalid format (\(fmt))" }
            } catch DiveLogImportError.corruptedData(let detail) {
                if firstError == nil { firstError = "\(file.name): corrupted (\(detail))" }
            } catch {
                if firstError == nil { firstError = "\(file.name): \(error.localizedDescription)" }
            }

            // 清理 temp 檔案
            try? FileManager.default.removeItem(at: file.url)
        }

        // 決定最終狀態：只要有匯入成功就算成功，firstError 僅在全部失敗時顯示
        if allImported.isEmpty, let error = firstError {
            step = .failure(message: error)
        } else {
            // 暫存 ID，等用戶按 Done 再切換 Tab（讓用戶看到完成頁）
            pendingHighlightID = allImported
                .sorted { $0.dateTime > $1.dateTime }
                .first?.persistentModelID
            step = .success(count: allImported.count, skipped: 0)
        }
    }

    private func resetToReady() {
        // Done 按鈕觸發：先切換 Tab 再重設狀態
        onImportSuccess?(pendingHighlightID)
        pendingHighlightID = nil
        selectedFileLabel = nil
        step = .ready
    }
}

// MARK: - Format Group Section
// port 自 JD2-Ultra companion DiveComponents.swift 的 SectionHeader／ValueRow 慣例：
// 大寫小標籤分組標題＋單欄列，取代原本無分類、無法掃視的 2 欄卡片格線。

private struct FormatGroupSection: View {
    let title: String
    let formats: [(name: String, ext: String, icon: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            VStack(spacing: 0) {
                ForEach(Array(formats.enumerated()), id: \.offset) { index, format in
                    FormatRow(name: format.name, extensions: format.ext, icon: format.icon)
                    if index < formats.count - 1 {
                        Divider().padding(.leading, 40)
                    }
                }
            }
            .background(Color.platformSecondaryGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct FormatRow: View {
    let name: String
    let extensions: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.tint)
                .frame(minWidth: 20)
                .accessibilityHidden(true)

            Text(name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(extensions)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // WCAG: 合併為單一元素，並用格式名稱當 label（避免 VoiceOver 把 ".csv" 讀成「點 c s v」）
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }
}

#Preview {
    ImportWizardView()
}
