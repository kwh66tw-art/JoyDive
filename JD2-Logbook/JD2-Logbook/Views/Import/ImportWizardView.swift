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
        .navigationTitle("Import Dives")
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
                .folder
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

    private var stepLabels: [String] { ["Select", "Import", "Result"] }

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

            supportedFormatsSection

            Button {
                showFilePicker = true
            } label: {
                Label("Select Files or Folder", systemImage: "folder")
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

            Spacer(minLength: 40)
        }
        .padding(.bottom, 20)
    }

    private var supportedFormatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Supported Formats")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 24)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(supportedFormatCards, id: \.name) { card in
                    FormatCard(name: card.name, extensions: card.ext, icon: card.icon)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var supportedFormatCards: [(name: String, ext: String, icon: String)] {
        [
            ("UDDF",           ".uddf",        "doc.badge.gearshape"),
            ("Subsurface XML", ".ssrf / .xml", "doc.richtext"),
            ("Subsurface CSV", ".csv",         "tablecells"),
            ("Suunto JSON",    ".json",        "curlybraces"),
            ("Garmin Descent", ".fit",         "waveform.path.ecg"),
            ("Seabear CSV",    ".csv",         "tablecells.fill")
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

                    Text("Scanning files…")
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

            Text("Import Successful")
                .font(.title2.bold())

            VStack(spacing: 6) {
                Text("\(count) dive\(count == 1 ? "" : "s") imported")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if skipped > 0 {
                    Text("\(skipped) skipped (duplicates)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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
        let supported = Set(["uddf", "ssrf", "xml", "json", "csv", "fit"])
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

// MARK: - Format Card

private struct FormatCard: View {
    let name: String
    let extensions: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(extensions)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.platformSecondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ImportWizardView()
}
