import SwiftUI

struct SettingsView: View {
    @Environment(AppDataStore.self) private var store

    @State private var showAddSheet = false
    @State private var newName = ""
    @State private var newTime = Date()
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.schedules) { schedule in
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
                let activeCount = store.schedules.filter(\.isActive).count
                if !store.schedules.isEmpty, activeCount != 1 {
                    UserSchedule.ensureSingleActive(in: store.schedules)
                    Task { await store.saveAll() }
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
        UserSchedule.setActive(schedule, in: store.schedules)
        Task { await store.saveAll() }
    }

    private func delete(at offsets: IndexSet) {
        let deleting = offsets.map { store.schedules[$0] }
        Task { await store.deleteSchedules(deleting) }
    }

    private func addSchedule() {
        Task { await store.addSchedule(name: newName, targetDepartureTime: newTime) }
    }

    private func defaultTime() -> Date {
        DepartureTimeDefaults.fifteenMinutesFromNow()
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
        .environment(AppDataStore())
}
