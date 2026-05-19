// ImportWizardView.swift — JD2-Logbook/Views/Import/
// Week 9 — 3 步驟匯入嚮導
//
// Step 1: 格式總覽 + 選擇檔案
// Step 2: 解析中（自動跳轉）
// Step 3: 匯入結果

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 匯入精靈狀態機

enum ImportStep {
    case ready          // Step 1: 待選檔案
    case importing      // Step 2: 解析 + 匯入中
    case success(count: Int, skipped: Int)   // Step 3: 成功
    case failure(message: String)            // Step 3: 失敗
}

// MARK: - Main View

struct ImportWizardView: View {
    @State private var step: ImportStep = .ready
    @State private var showFilePicker = false
    @State private var selectedFileName: String? = nil

    // ImportCoordinator 是 @MainActor，在 MainActor 視圖中直接使用
    private let coordinator = ImportCoordinator(database: DiveLogDatabase.shared)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 步驟指示器
                stepIndicator

                Divider()

                // 主要內容
                ScrollView {
                    switch step {
                    case .ready:
                        readyView
                    case .importing:
                        importingView
                    case .success(let count, let skipped):
                        successView(count: count, skipped: skipped)
                    case .failure(let message):
                        failureView(message: message)
                    }
                }
            }
            .navigationTitle("Import Dives")
            .navigationBarTitleDisplayMode(.large)
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "uddf") ?? .xml,
                    UTType(filenameExtension: "ssrf") ?? .xml,
                    UTType(filenameExtension: "fit")  ?? .data,
                    .xml,
                    .json,
                    .commaSeparatedText
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFilePickerResult(result)
            }
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
        .background(Color(.systemGroupedBackground))
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
        if index < currentStepIndex { return .accentColor }
        if index == currentStepIndex { return .accentColor }
        return Color(.tertiarySystemFill)
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
            // 說明
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

            // 支援格式列表
            supportedFormatsSection

            // 選擇檔案按鈕
            Button {
                showFilePicker = true
            } label: {
                Label("Select File", systemImage: "folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .accessibilityLabel(String(localized: "Select File"))
            .accessibilityHint("Opens file picker to choose a dive log file")

            // 已選擇的檔案名稱
            if let name = selectedFileName {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.tint)
                    Text(name)
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
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
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
            ("UDDF",          ".uddf",       "doc.badge.gearshape"),
            ("Subsurface XML",".ssrf / .xml","doc.richtext"),
            ("Subsurface CSV",".csv",        "tablecells"),
            ("Suunto JSON",   ".json",       "curlybraces"),
            ("Garmin Descent",".fit",        "waveform.path.ecg"),
            ("Seabear CSV",   ".csv",        "tablecells.fill")
        ]
    }

    // MARK: - Step 2: Importing

    private var importingView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)

            ProgressView()
                .scaleEffect(1.6)
                .tint(.accentColor)

            VStack(spacing: 6) {
                Text("Importing…")
                    .font(.headline)

                if let name = selectedFileName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .frame(minHeight: 300)
        .accessibilityLabel(String(localized: "Importing…"))
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .padding(.top, 8)

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
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(minHeight: 360)
    }

    // MARK: - Actions

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFileName = url.lastPathComponent
            runImport(url: url)

        case .failure(let error):
            step = .failure(message: error.localizedDescription)
        }
    }

    private func runImport(url: URL) {
        step = .importing

        Task { @MainActor in
            // Security-scoped resource access
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            do {
                // 複製到 temp 目錄，避免 security scope 過期
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)

                // 執行匯入
                let imported = try await coordinator.importFile(tempURL.path)

                // 計算跳過數（dedup 已在 coordinator 內處理，這裡無法直接取得）
                step = .success(count: imported.count, skipped: 0)

            } catch DiveLogImportError.fileNotFound(let path) {
                step = .failure(message: "File not found: \(path)")
            } catch DiveLogImportError.unsupportedFormat(let fmt) {
                step = .failure(message: "Unsupported format: \(fmt)")
            } catch DiveLogImportError.emptyFile {
                step = .failure(message: "No dives found in this file.")
            } catch DiveLogImportError.parsingFailed(let msg, _) {
                step = .failure(message: "Parse error: \(msg)")
            } catch DiveLogImportError.invalidFormat(let fmt) {
                step = .failure(message: "Invalid format: \(fmt)")
            } catch DiveLogImportError.corruptedData(let detail) {
                step = .failure(message: "Corrupted data: \(detail)")
            } catch {
                step = .failure(message: error.localizedDescription)
            }

            // 清理 temp
            try? FileManager.default.removeItem(
                at: FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
            )
        }
    }

    private func resetToReady() {
        selectedFileName = nil
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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ImportWizardView()
}
