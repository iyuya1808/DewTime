import SwiftUI
import SwiftData

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSchedule.name) private var schedules: [UserSchedule]
    @Query private var activeFishes: [ActiveFish]
    @Query private var collectedFishes: [CollectedFish]
    @Query private var careRecords: [FishCareRecord]
    @Query private var aquariums: [Aquarium]

    @State private var showResetAllConfirm = false
    @State private var showResetSchedulesConfirm = false
    @State private var showResetAquariumConfirm = false
    @State private var saveError: String?

    var body: some View {
        List {
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
        schedules.forEach { modelContext.delete($0) }
        save()
        SampleData.seedIfNeeded(context: modelContext)
    }

    private func resetAquarium() {
        activeFishes.forEach { modelContext.delete($0) }
        collectedFishes.forEach { modelContext.delete($0) }
        careRecords.forEach { modelContext.delete($0) }
        aquariums.forEach { modelContext.delete($0) }
        save()
    }

    private func resetAll() {
        resetAquarium()
        schedules.forEach { modelContext.delete($0) }
        save()
        SampleData.seedIfNeeded(context: modelContext)
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            saveError = "データの保存に失敗しました"
            print("[DewTime] DataManagementView の保存に失敗しました: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        DataManagementView()
    }
    .modelContainer(for: [UserSchedule.self, RoutineItem.self, CollectedFish.self, ActiveFish.self, FishCareRecord.self, Aquarium.self], inMemory: true)
}
