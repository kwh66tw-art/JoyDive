import SwiftUI

struct GasIconPreview: View {
    var body: some View {
        NavigationStack {
            List {
                Section("潛水氣體 Icon 選項") {
                    HStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Image(systemName: "wind")
                                .font(.system(size: 40))
                                .foregroundStyle(.tint)
                            Text("wind")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 8) {
                            Image(systemName: "flask.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.orange)
                            Text("flask.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 8) {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.gray)
                            Text("cloud.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 8) {
                            Image(systemName: "cylinder.split.1x2")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                            Text("cylinder.split.1x2")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 12)
                }

                Section("Current (舊)") {
                    HStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.gray)
                            Text("bubble.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("× 不適合")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 12)
                }

                Section("推薦選擇") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            Image(systemName: "wind")
                                .font(.system(size: 36))
                                .foregroundStyle(.tint)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("wind")
                                    .font(.headline)
                                Text("最直覺代表氣體")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Gas Icon 預覽")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

#Preview {
    GasIconPreview()
}
