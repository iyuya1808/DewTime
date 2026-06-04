import SwiftUI
import Supabase

struct SettingsView: View {
    @Environment(AppDataStore.self) private var store

    @AppStorage(AppPreferences.Key.notificationsEnabled.rawValue) private var notificationsEnabled = true
    @AppStorage(AppPreferences.Key.departureReminderEnabled.rawValue) private var departureReminderEnabled = true
    @AppStorage(AppPreferences.Key.departureReminderMinutes.rawValue) private var departureReminderMinutes = 5
    @AppStorage(AppPreferences.Key.hapticsEnabled.rawValue) private var hapticsEnabled = true
    @AppStorage(AppPreferences.Key.appTheme.rawValue) private var appTheme = AppTheme.system.rawValue
    @AppStorage(AppPreferences.Key.aquariumTheme.rawValue) private var aquariumTheme = AquariumTheme.dewBlue.rawValue
    @AppStorage(AppPreferences.Key.hasCompletedTutorial.rawValue) private var hasCompletedTutorial = false

    @State private var showAddSheet = false
    @State private var showProfileEditor = false
    @State private var newName = ""
    @State private var newTime = Date()
    @State private var saveError: String?

    @State private var authService = AuthService.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showProfileEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            let profile = store.profile()
                            Text(profile.avatarEmoji)
                                .font(.system(size: 28))
                                .frame(width: 44, height: 44)
                                .background(Color.dewSurfaceSoft, in: Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.nickname)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                if let user = authService.currentUser {
                                    if authService.isAnonymous {
                                        Text("クラウド保存: 未有効")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(user.email ?? "クラウド保存: 有効")
                                            .font(.caption2)
                                            .foregroundStyle(.teal)
                                    }
                                } else {
                                    Text("アカウント準備中...")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .background(Color.black.opacity(0.0001))
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("アカウント")
                } footer: {
                    if let user = authService.currentUser, authService.isAnonymous {
                        Text("現在はアカウント登録なしでご利用中です（データはローカルに保存されます）。プロフィールを編集するにはアカウント登録が必要です。")
                    } else if authService.currentUser != nil {
                        Text("クラウド保存が有効になっています。タップしてプロフィール変更やアカウント管理を行えます。")
                    }
                }
                .listRowBackground(Color.dewListRowBackground)

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
                .listRowBackground(Color.dewListRowBackground)

                Section {
                    Button {
                        newTime = defaultTime()
                        newName = ""
                        showAddSheet = true
                    } label: {
                        Label("スケジュールを追加", systemImage: "plus.circle.fill")
                    }
                }
                .listRowBackground(Color.dewListRowBackground)

                Section {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("通知と触覚", systemImage: "bell.badge")
                    }
                } header: {
                    Text("通知と触覚")
                } footer: {
                    Text(notificationSummary)
                }
                .listRowBackground(Color.dewListRowBackground)

                Section {
                    Button {
                        hasCompletedTutorial = false
                    } label: {
                        Label("チュートリアルを見る", systemImage: "questionmark.circle")
                    }
                } footer: {
                    Text("タイマー・図鑑・水槽・プロフィールの使い方をもう一度確認できます。")
                }
                .listRowBackground(Color.dewListRowBackground)

                Section {
                    HStack {
                        Label("外観モード", systemImage: "circle.lefthalf.filled")
                        Spacer()
                        Picker("", selection: $appTheme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.displayName).tag(theme.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                    }
                    HStack {
                        Label("水槽テーマ", systemImage: "paintpalette")
                        Spacer()
                        Picker("", selection: $aquariumTheme) {
                            ForEach(AquariumTheme.allCases) { theme in
                                Text(theme.displayName).tag(theme.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                    }
                } header: {
                    Text("表示")
                } footer: {
                    Text(themeFooterText)
                }
                .listRowBackground(Color.dewListRowBackground)

                Section {
                    NavigationLink(destination: DataManagementView()) {
                        Label("データ管理", systemImage: "externaldrive")
                    }
                }
                .listRowBackground(Color.dewListRowBackground)

                Section {
                    NavigationLink(destination: SupportDeveloperView()) {
                        Label("開発者を応援", systemImage: "heart.fill")
                    }
                } header: {
                    Text("サポート")
                }
                .listRowBackground(Color.dewListRowBackground)
            }
            .navigationTitle("設定")
            .scrollContentBackground(.hidden)
            .dewAppBackground()
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
            .sheet(isPresented: $showProfileEditor) {
                ProfileEditView()
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



    private var notificationSummary: String {
        guard notificationsEnabled else { return "通知はオフです。" }
        if departureReminderEnabled {
            return "出発時刻と\(departureReminderMinutes)分前に通知します。"
        }
        return "出発時刻のみ通知します。"
    }

    private var themeFooterText: String {
        switch AppTheme(rawValue: appTheme) {
        case .system:
            return "ライトモードとダークモードは端末の外観設定に合わせて切り替わります。"
        case .light:
            return "常にライトモードで表示します。"
        case .dark:
            return "常にダークモードで表示します。"
        default:
            return ""
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
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        UserSchedule.setActive(schedule, in: store.schedules)
        Task { await store.saveAll() }
    }

    private func delete(at offsets: IndexSet) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        let deleting = offsets.map { store.schedules[$0] }
        Task { await store.deleteSchedules(deleting) }
    }

    private func addSchedule() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
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
