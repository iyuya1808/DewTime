import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSchedule.name) private var schedules: [UserSchedule]

    @State private var showAddSheet = false
    @State private var newName = ""
    @State private var newTime = Date()
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(schedules) { schedule in
                        NavigationLink(destination: RoutineEditorView(schedule: schedule)) {
                            ScheduleRow(schedule: schedule)
                        }
                        .swipeActions(edge: .leading) {
                            Button("有効化") { activate(schedule) }
                                .tint(.green)
                        }
                    }
                    .onDelete(perform: delete)
                } header: {
                    Text("出発スケジュール")
                } footer: {
                    Text("有効化したスケジュールがタイマーに使われます")
                }

                Section {
                    Button {
                        newTime = defaultTime()
                        newName = ""
                        showAddSheet = true
                    } label: {
                        Label("スケジュールを追加", systemImage: "plus.circle.fill")
                    }
                }

                Section {
                    NavigationLink(destination: DataManagementView()) {
                        Label("データ管理", systemImage: "externaldrive")
                    }
                }
            }
            .navigationTitle("設定")
            .onAppear {
                let activeCount = schedules.filter(\.isActive).count
                if !schedules.isEmpty, activeCount != 1 {
                    UserSchedule.ensureSingleActive(in: schedules)
                    save()
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addSheet
                    .presentationDetents([.medium])
            }
            .alert(
                "保存エラー",
                isPresented: Binding(get: { saveError != nil }, set: { _ in saveError = nil })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    // MARK: - Add sheet

    private var addSheet: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("例: 平日・休日", text: $newName)
                }
                Section("出発時刻") {
                    DatePicker("出発時刻", selection: $newTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
            .navigationTitle("新しいスケジュール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { showAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        addSchedule()
                        showAddSheet = false
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func activate(_ schedule: UserSchedule) {
        UserSchedule.setActive(schedule, in: schedules)
        save()
    }

    private func delete(at offsets: IndexSet) {
        let deleting = offsets.map { schedules[$0] }
        let deletingIDs = Set(deleting.map(\.id))
        let shouldPickNextActive = deleting.contains(where: \.isActive)
        deleting.forEach { modelContext.delete($0) }

        if shouldPickNextActive, let next = schedules.first(where: { !deletingIDs.contains($0.id) }) {
            UserSchedule.setActive(next, in: schedules)
        }
        save()
    }

    private func addSchedule() {
        let s = UserSchedule(
            name: newName,
            targetDepartureTime: newTime,
            isActive: schedules.isEmpty
        )
        modelContext.insert(s)
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            saveError = "データの保存に失敗しました"
            print("[DewTime] SettingsView の保存に失敗しました: \(error)")
        }
    }

    private func defaultTime() -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        c.hour = 8; c.minute = 0
        return Calendar.current.date(from: c) ?? .now
    }
}

// MARK: - Row

private struct ScheduleRow: View {
    let schedule: UserSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(schedule.name)
                    .font(.headline)
                Spacer()
                if schedule.isActive {
                    Label("使用中", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                }
            }
            Text(schedule.targetDepartureTime, format: .dateTime.hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserSchedule.self, RoutineItem.self, PlantFlower.self, ActivePlant.self, PlantWateringRecord.self], inMemory: true)
}
