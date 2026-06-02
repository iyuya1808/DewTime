import SwiftUI

struct DataManagementView: View {
    @Environment(AppDataStore.self) private var store

    @State private var showResetAllConfirm = false
    @State private var showResetSchedulesConfirm = false
    @State private var showResetAquariumConfirm = false
    @State private var saveError: String?

    var body: some View {
        List {
            Section {
                if store.isSaving || store.isLoading {
                    HStack {
                        ProgressView()
                        Text(store.isLoading ? "Firestoreから読み込み中..." : "Firestoreへ保存中...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Label("Firestore接続中", systemImage: "checkmark.icloud")
                        .foregroundStyle(.secondary)
                }

                if let message = store.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Firestore")
            } footer: {
                Text("このアプリのスケジュール・魚・図鑑・水やり履歴はFirestoreに保存されます。")
            }

            Section {
                Button {
                    showResetSchedulesConfirm = true
                } label: {
                    Label("スケジュールを初期化", systemImage: "calendar.badge.minus")
                }
                .tint(.primary)
                Button {
                    showResetAquariumConfirm = true
                } label: {
                    Label("水槽データを初期化", systemImage: "fish")
                }
                .tint(.primary)
            } footer: {
                Text("スケジュール・ルーティン、または魚・コレクション・水やり履歴のみを初期化します")
            }

            Section {
                Button {
                    showResetAllConfirm = true
                } label: {
                    Label("すべてのデータを初期化", systemImage: "trash")
                }
                .tint(.primary)
            } footer: {
                Text("アプリのすべてのデータを削除します。初期化後はサンプルデータに戻ります")
            }
        }
        .navigationTitle("データ管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "保存エラー",
            isPresented: Binding(get: { saveError != nil }, set: { _ in saveError = nil })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
        .confirmationDialog(
            "スケジュールを初期化",
            isPresented: $showResetSchedulesConfirm,
            titleVisibility: .visible
        ) {
            Button("初期化する", role: .destructive) { resetSchedules() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("すべてのスケジュールとルーティンが削除され、サンプルデータに戻ります。")
        }
        .confirmationDialog(
            "水槽データを初期化",
            isPresented: $showResetAquariumConfirm,
            titleVisibility: .visible
        ) {
            Button("初期化する", role: .destructive) { resetAquarium() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("育成中の魚・コレクション・水やり履歴・水槽がすべて削除されます。")
        }
        .confirmationDialog(
            "すべてのデータを初期化",
            isPresented: $showResetAllConfirm,
            titleVisibility: .visible
        ) {
            Button("すべて初期化する", role: .destructive) { resetAll() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("スケジュール・魚・記録など、アプリのすべてのデータが削除されます。")
        }
    }

    // MARK: - Actions

    private func resetSchedules() {
        Task { await store.resetSchedules() }
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
