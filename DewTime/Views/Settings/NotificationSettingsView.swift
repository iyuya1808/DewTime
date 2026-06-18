import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @AppStorage(AppPreferences.Key.notificationsEnabled.rawValue) private var notificationsEnabled = true
    @AppStorage(AppPreferences.Key.departureReminderEnabled.rawValue) private var departureReminderEnabled = true
    @AppStorage(AppPreferences.Key.departureReminderMinutes.rawValue) private var departureReminderMinutes = 5
    @AppStorage(AppPreferences.Key.hapticsEnabled.rawValue) private var hapticsEnabled = true

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                NotificationAuthorizationBanner(status: authorizationStatus)

                SettingsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsSectionHeader(
                            title: "通知",
                            caption: "タイマー開始時に出発通知を予約します",
                            systemImage: "bell.fill",
                            tint: .orange
                        )

                        SettingsToggleRow(
                            title: "通知を使う",
                            subtitle: "オフにすると出発通知を送りません",
                            isOn: $notificationsEnabled
                        )

                        Divider()

                        SettingsToggleRow(
                            title: "出発前にリマインド",
                            subtitle: "出発時刻の前にもう一度お知らせします",
                            isOn: $departureReminderEnabled,
                            isDisabled: !notificationsEnabled
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("リマインドのタイミング")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Picker("リマインド", selection: $departureReminderMinutes) {
                                ForEach(AppPreferences.reminderMinuteOptions, id: \.self) { minutes in
                                    Text("\(minutes)分前").tag(minutes)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(!notificationsEnabled || !departureReminderEnabled)
                        }

                        SettingsPrimaryButton(
                            title: "通知許可を確認",
                            systemImage: "bell.badge.fill",
                            tint: .orange
                        ) {
                            requestNotificationPermission()
                        }
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsSectionHeader(
                            title: "触覚（ハプティクス）",
                            caption: "タスク切り替えや操作時の振動フィードバック",
                            systemImage: "hand.tap.fill",
                            tint: .teal
                        )

                        SettingsToggleRow(
                            title: "ハプティクスを使う",
                            isOn: $hapticsEnabled
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle("通知と触覚")
        .navigationBarTitleDisplayMode(.inline)
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
