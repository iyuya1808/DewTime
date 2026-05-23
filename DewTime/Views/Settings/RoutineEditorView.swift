import SwiftUI
import SwiftData

struct RoutineEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSchedule.name) private var schedules: [UserSchedule]
    @Bindable var schedule: UserSchedule

    @State private var showAddSheet = false
    @State private var newName: String = ""
    @State private var newMinutes: Int = 5
    @State private var newColor: Color = Color.routinePalette[0]
    @State private var saveError: String?

    var body: some View {
        List {
            Section("基本情報") {
                TextField("名前", text: $schedule.name)
                DatePicker(
                    "出発予定時刻",
                    selection: $schedule.targetDepartureTime,
                    displayedComponents: .hourAndMinute
                )
                Toggle("このスケジュールを使用", isOn: activeBinding)
            }

            Section {
                ForEach(schedule.orderedItems) { item in
                    HStack {
                        Circle()
                            .fill(Color(hex: item.colorHex))
                            .frame(width: 14, height: 14)
                        Text(item.name)
                        Spacer()
                        Text("\(item.durationSeconds / 60)分")
                            .foregroundStyle(.secondary)
                    }
                }
                .onMove(perform: moveItems)
                .onDelete(perform: deleteItems)

                Button {
                    showAddSheet = true
                } label: {
                    Label("タスクを追加", systemImage: "plus")
                }
            } header: {
                HStack {
                    Text("タスク（合計 \(schedule.totalSeconds / 60) 分）")
                    Spacer()
                    EditButton()
                }
            }
        }
        .navigationTitle(schedule.name)
        .navigationBarTitleDisplayMode(.inline)
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

    private var addSheet: some View {
        NavigationStack {
            Form {
                TextField("タスク名", text: $newName)
                Stepper("所要時間: \(newMinutes) 分", value: $newMinutes, in: 1...60)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(Color.routinePalette.indices, id: \.self) { idx in
                        let c = Color.routinePalette[idx]
                        Circle()
                            .fill(c)
                            .frame(height: 36)
                            .overlay(
                                Circle().strokeBorder(.white, lineWidth: newColor == c ? 3 : 0)
                            )
                            .onTapGesture { newColor = c }
                    }
                }
            }
            .navigationTitle("新しいタスク")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { showAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        addItem()
                        showAddSheet = false
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var activeBinding: Binding<Bool> {
        Binding(
            get: { schedule.isActive },
            set: { isActive in
                if isActive {
                    UserSchedule.setActive(schedule, in: schedules)
                } else if schedules.filter(\.isActive).count > 1 {
                    schedule.isActive = false
                } else {
                    schedule.isActive = true
                }
                save()
            }
        )
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = schedule.orderedItems
        items.move(fromOffsets: source, toOffset: destination)
        for (idx, item) in items.enumerated() {
            item.orderIndex = idx
        }
        save()
    }

    private func deleteItems(at offsets: IndexSet) {
        let items = schedule.orderedItems
        for index in offsets {
            modelContext.delete(items[index])
        }
        save()
    }

    private func addItem() {
        let nextOrder = (schedule.orderedItems.last?.orderIndex ?? -1) + 1
        let item = RoutineItem(
            name: newName,
            durationSeconds: newMinutes * 60,
            colorHex: newColor.toHex(),
            orderIndex: nextOrder,
            schedule: schedule
        )
        modelContext.insert(item)
        save()
        newName = ""
        newMinutes = 5
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            saveError = "データの保存に失敗しました"
            print("[DewTime] RoutineEditorView の保存に失敗しました: \(error)")
        }
    }
}
