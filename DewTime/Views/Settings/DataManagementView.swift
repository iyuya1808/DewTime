import SwiftUI

struct DataManagementView: View {
    @Environment(AppDataStore.self) private var store

    @State private var showResetAllConfirm = false
    @State private var showResetAquariumConfirm = false
    @State private var saveError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsSectionHeader(
                            title: "保存状態",
                            caption: "水槽・図鑑・出発記録は端末内に保存されます",
                            systemImage: "externaldrive.fill",
                            tint: .teal
                        )

                        if store.isSaving || store.isLoading {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text(store.isLoading ? "データを読み込み中..." : "データを保存中...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("ローカルに保存されています")
                                    .font(.subheadline.weight(.medium))
                            }
                        }

                        if let message = store.errorMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsSectionHeader(
                            title: "部分的に初期化",
                            caption: "必要なデータだけを選んで削除できます",
                            systemImage: "arrow.counterclockwise",
                            tint: .orange
                        )

                        resetButton(
                            title: "水槽データを初期化",
                            subtitle: "魚・図鑑・出発記録・水槽を削除します",
                            systemImage: "fish.fill"
                        ) {
                            showResetAquariumConfirm = true
                        }
                    }
                }

                SettingsCard(borderColor: .red) {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsSectionHeader(
                            title: "危険な操作",
                            caption: "削除したデータは元に戻せません",
                            systemImage: "exclamationmark.triangle.fill",
                            tint: .red
                        )

                        Button {
                            showResetAllConfirm = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash.fill")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 40, height: 40)
                                    .background(Color.red.opacity(0.12), in: Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("すべてのデータを初期化")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("アプリのすべてのデータが削除されます")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle("データ管理")
        .navigationBarTitleDisplayMode(.inline)
        .dewAppBackground()
        .alert(
            "保存エラー",
            isPresented: Binding(get: { saveError != nil }, set: { _ in saveError = nil })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
        .confirmationDialog(
            "水槽データを初期化",
            isPresented: $showResetAquariumConfirm,
            titleVisibility: .visible
        ) {
            Button("初期化する", role: .destructive) { resetAquarium() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("図鑑・出発記録・水槽がすべて削除されます。旧データが残っている場合はここで初期化してください。")
        }
        .confirmationDialog(
            "すべてのデータを初期化",
            isPresented: $showResetAllConfirm,
            titleVisibility: .visible
        ) {
            Button("すべて初期化する", role: .destructive) { resetAll() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("魚・記録など、アプリのすべてのデータが削除されます。")
        }
    }

    private func resetButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SettingsNavigationRow(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                iconTint: .orange,
                showsChevron: false
            )
        }
        .buttonStyle(.plain)
    }

    private func resetAquarium() {
        Task { await store.resetAquarium() }
    }

    private func resetAll() {
        Task { await store.resetAll() }
    }
}

#Preview {
    NavigationStack {
        DataManagementView()
    }
    .environment(AppDataStore())
}
