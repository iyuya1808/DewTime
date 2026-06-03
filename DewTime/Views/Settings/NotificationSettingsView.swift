import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @AppStorage(AppPreferences.Key.notificationsEnabled.rawValue) private var notificationsEnabled = true
    @AppStorage(AppPreferences.Key.departureReminderEnabled.rawValue) private var departureReminderEnabled = true
    @AppStorage(AppPreferences.Key.departureReminderMinutes.rawValue) private var departureReminderMinutes = 5
    @AppStorage(AppPreferences.Key.hapticsEnabled.rawValue) private var hapticsEnabled = true

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        List {
            Section {
                Toggle("通知を使う", isOn: $notificationsEnabled)

                Toggle("出発前にリマインド", isOn: $departureReminderEnabled)
                    .disabled(!notificationsEnabled)

                Picker("リマインド", selection: $departureReminderMinutes) {
                    ForEach(AppPreferences.reminderMinuteOptions, id: \.self) { minutes in
                        Text("\(minutes)分前").tag(minutes)
                    }
                }
                .disabled(!notificationsEnabled || !departureReminderEnabled)

                Button {
                    requestNotificationPermission()
                } label: {
                    Label("通知許可を確認", systemImage: "bell.badge")
                }
            } header: {
                Text("通知")
            } footer: {
                Text(notificationFooterText)
            }
            .listRowBackground(Color.dewListRowBackground)

            Section {
                Toggle("ハプティクス", isOn: $hapticsEnabled)
            } footer: {
                Text("タスク切り替えや遅延時の触覚フィードバックを切り替えます。")
            }
            .listRowBackground(Color.dewListRowBackground)
        }
        .navigationTitle("通知と触覚")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .dewAppBackground()
        .task {
            await refreshAuthorizationStatus()
        }
        .onChange(of: departureReminderMinutes) { _, newValue in
            if !AppPreferences.reminderMinuteOptions.contains(newValue) {
                departureReminderMinutes = 5
            }
        }
    }

    private var notificationFooterText: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return notificationsEnabled ? "タイマー開始時に出発通知を予約します。" : "アプリ内設定で通知がオフです。"
        case .denied:
            return "iOSの設定で通知が許可されていません。必要な場合は設定アプリから許可してください。"
        case .notDetermined:
            return "通知許可を確認すると、出発時刻の通知を使えるようになります。"
        @unknown default:
            return "通知状態を確認できませんでした。"
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            Task { @MainActor in
                await refreshAuthorizationStatus()
            }
        }
    }

    private func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
