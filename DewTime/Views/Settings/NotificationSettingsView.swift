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
                            title: L10n.NotificationSettings.sectionTitle,
                            caption: L10n.NotificationSettings.sectionCaption,
                            systemImage: "bell.fill",
                            tint: .orange
                        )

                        SettingsToggleRow(
                            title: L10n.NotificationSettings.enable,
                            subtitle: L10n.NotificationSettings.enableSubtitle,
                            isOn: $notificationsEnabled
                        )

                        Divider()

                        SettingsToggleRow(
                            title: L10n.NotificationSettings.reminder,
                            subtitle: L10n.NotificationSettings.reminderSubtitle,
                            isOn: $departureReminderEnabled,
                            isDisabled: !notificationsEnabled
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.NotificationSettings.reminderTiming)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Picker(L10n.NotificationSettings.reminder, selection: $departureReminderMinutes) {
                                ForEach(AppPreferences.reminderMinuteOptions, id: \.self) { minutes in
                                    Text(L10n.NotificationSettings.minutesBefore(minutes)).tag(minutes)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(!notificationsEnabled || !departureReminderEnabled)
                        }

                        SettingsPrimaryButton(
                            title: L10n.NotificationSettings.checkPermission,
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
                            title: L10n.NotificationSettings.hapticsSection,
                            caption: L10n.NotificationSettings.hapticsCaption,
                            systemImage: "hand.tap.fill",
                            tint: .teal
                        )

                        SettingsToggleRow(
                            title: L10n.NotificationSettings.hapticsEnable,
                            isOn: $hapticsEnabled
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle(L10n.NotificationSettings.title)
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
