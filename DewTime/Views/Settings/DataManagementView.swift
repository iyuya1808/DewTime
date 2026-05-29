import SwiftUI
import SwiftData

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSchedule.name) private var schedules: [UserSchedule]
    @Query private var activePlants: [ActivePlant]
    @Query private var plantFlowers: [PlantFlower]
    @Query private var wateringRecords: [PlantWateringRecord]

    @State private var showResetAllConfirm = false
    @State private var showResetSchedulesConfirm = false
    @State private var showResetGardenConfirm = false
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
                    showResetGardenConfirm = true
                } label: {
                    Label("植物データを初期化", systemImage: "leaf.arrow.circlepath")
                }
                .tint(.primary)
            } footer: {
                Text("スケジュール・ルーティン、または植物・開花記録・水やり履歴のみを初期化します")
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
            "植物データを初期化",
            isPresented: $showResetGardenConfirm,
            titleVisibility: .visible
        ) {
            Button("初期化する", role: .destructive) { resetGarden() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("育成中の植物・開花記録・水やり履歴がすべて削除されます。")
        }
        .confirmationDialog(
            "すべてのデータを初期化",
            isPresented: $showResetAllConfirm,
            titleVisibility: .visible
        ) {
            Button("すべて初期化する", role: .destructive) { resetAll() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("スケジュール・植物・記録など、アプリのすべてのデータが削除されます。")
        }
    }

    // MARK: - Actions

    private func resetSchedules() {
        schedules.forEach { modelContext.delete($0) }
        save()
        SampleData.seedIfNeeded(context: modelContext)
    }

    private func resetGarden() {
        activePlants.forEach { modelContext.delete($0) }
        plantFlowers.forEach { modelContext.delete($0) }
        wateringRecords.forEach { modelContext.delete($0) }
        save()
    }

    private func resetAll() {
        resetGarden()
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
    .modelContainer(for: [UserSchedule.self, RoutineItem.self, PlantFlower.self, ActivePlant.self, PlantWateringRecord.self], inMemory: true)
}
