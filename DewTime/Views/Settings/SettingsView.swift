import SwiftUI
import Supabase
import UserNotifications

struct SettingsView: View {
    @Environment(AppDataStore.self) private var store

    @AppStorage(AppPreferences.Key.notificationsEnabled.rawValue) private var notificationsEnabled = true
    @AppStorage(AppPreferences.Key.departureReminderEnabled.rawValue) private var departureReminderEnabled = true
    @AppStorage(AppPreferences.Key.departureReminderMinutes.rawValue) private var departureReminderMinutes = 5
    @AppStorage(AppPreferences.Key.hapticsEnabled.rawValue) private var hapticsEnabled = true
    @AppStorage(AppPreferences.Key.appTheme.rawValue) private var appTheme = AppTheme.system.rawValue
    @AppStorage(AppPreferences.Key.aquariumTheme.rawValue) private var aquariumTheme = AquariumTheme.dewBlue.rawValue
    @AppStorage(AppPreferences.Key.hasCompletedTutorial.rawValue) private var hasCompletedTutorial = false
    @AppStorage(AppPreferences.Key.appLanguage.rawValue) private var appLanguageRaw = AppLanguage.system.rawValue

    @State private var showProfileEditor = false
    @State private var saveError: String?
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    @State private var authService = AuthService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    accountSection
                    notificationSection
                    displaySection
                    helpSection
                    linksSection
                    versionFooter
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .navigationTitle(L10n.Settings.title)
            .dewAppBackground()
            .task {
                await refreshAuthorizationStatus()
            }
            .sheet(isPresented: $showProfileEditor) {
                ProfileEditView()
            }
            .alert(
                L10n.Common.saveError,
                isPresented: Binding(get: { saveError != nil }, set: { _ in saveError = nil })
            ) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(title: L10n.Settings.account, systemImage: "person.crop.circle", tint: .teal)

            Button {
                showProfileEditor = true
            } label: {
                SettingsCard {
                    VStack(spacing: 16) {
                        HStack(spacing: 14) {
                            let profile = store.profile()
                            Text(profile.avatarEmoji)
                                .font(.system(size: 36))
                                .frame(width: 64, height: 64)
                                .background(Color.dewSurfaceSoft, in: Circle())

                            VStack(alignment: .leading, spacing: 6) {
                                Text(profile.nickname)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.primary)

                                accountStatusBadge
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }

                        if authService.isAnonymous {
                            anonymousAccountBanner
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var accountStatusBadge: some View {
        if let user = authService.currentUser {
            if authService.isAnonymous {
                SettingsStatusBadge(text: L10n.Settings.accountLocalOnly, tint: .orange, systemImage: "iphone")
            } else {
                SettingsStatusBadge(text: L10n.Settings.accountCloudEnabled, tint: .teal, systemImage: "icloud.fill")
                if let email = user.email {
                    Text(email)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            SettingsStatusBadge(text: L10n.Common.preparing, tint: .secondary, systemImage: "hourglass")
        }
    }

    private var anonymousAccountBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(L10n.Settings.accountAnonymousBanner)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink {
                AccountRegistrationView()
            } label: {
                HStack {
                    Spacer()
                    Label(L10n.Settings.accountRegister, systemImage: "icloud.and.arrow.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .frame(height: 40)
                .background(
                    LinearGradient(colors: [.dewBlue, .dewNavy], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(
                title: L10n.Settings.notificationsAndHaptics,
                caption: L10n.Settings.notificationsCaption,
                systemImage: "bell.badge.fill",
                tint: .orange
            )

            NavigationLink {
                NotificationSettingsView()
            } label: {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsNavigationRow(
                            title: L10n.Settings.notificationsSettings,
                            subtitle: notificationInlineSummary,
                            systemImage: "bell.badge",
                            iconTint: .orange,
                            showsChevron: false
                        )

                        if authorizationStatus == .denied {
                            SettingsStatusBadge(
                                text: L10n.Settings.notificationsDeniedIOS,
                                tint: .red,
                                systemImage: "exclamationmark.triangle.fill"
                            )
                        }

                        HStack {
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(
                title: L10n.Settings.display,
                caption: L10n.Settings.displayCaption,
                systemImage: "paintpalette.fill",
                tint: .purple
            )

            SettingsCard {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.Settings.language)
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 8) {
                            ForEach(AppLanguage.allCases) { language in
                                SettingsLanguageChip(
                                    language: language,
                                    isSelected: appLanguageRaw == language.rawValue
                                ) {
                                    appLanguageRaw = language.rawValue
                                }
                            }
                        }

                        Text(L10n.Settings.languageFooter)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.Settings.appearanceMode)
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 8) {
                            ForEach(AppTheme.allCases) { theme in
                                SettingsThemeChip(
                                    theme: theme,
                                    isSelected: appTheme == theme.rawValue
                                ) {
                                    appTheme = theme.rawValue
                                }
                            }
                        }

                        Text(themeFooterText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.Settings.aquariumTheme)
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 8) {
                            ForEach(AquariumTheme.allCases) { theme in
                                AquariumThemeSwatch(
                                    theme: theme,
                                    isSelected: aquariumTheme == theme.rawValue
                                ) {
                                    aquariumTheme = theme.rawValue
                                }
                            }
                        }

                        Text(L10n.Settings.aquariumThemeFooter)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(
                title: L10n.Settings.help,
                systemImage: "questionmark.circle.fill",
                tint: .blue
            )

            SettingsCard {
                Button {
                    hasCompletedTutorial = false
                } label: {
                    SettingsNavigationRow(
                        title: L10n.Settings.tutorialReplay,
                        subtitle: L10n.Settings.tutorialReplaySubtitle,
                        systemImage: "book.pages.fill",
                        iconTint: .blue
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(title: L10n.Settings.other, systemImage: "ellipsis.circle", tint: .secondary)

            SettingsCard {
                VStack(spacing: 16) {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        SettingsNavigationRow(
                            title: L10n.Settings.dataManagement,
                            subtitle: L10n.Settings.dataManagementSubtitle,
                            systemImage: "externaldrive.fill",
                            iconTint: .teal
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    NavigationLink {
                        SupportDeveloperView()
                    } label: {
                        SettingsNavigationRow(
                            title: L10n.Settings.supportDeveloper,
                            subtitle: L10n.Settings.supportDeveloperSubtitle,
                            systemImage: "heart.fill",
                            iconTint: .pink
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var versionFooter: some View {
        Text(L10n.Settings.version(appVersionString))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    // MARK: - Computed

    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var notificationInlineSummary: String {
        var parts: [String] = []
        parts.append(notificationsEnabled ? L10n.Settings.notificationOn : L10n.Settings.notificationOff)
        if notificationsEnabled {
            if departureReminderEnabled {
                parts.append(L10n.Settings.reminderBefore(departureReminderMinutes))
            } else {
                parts.append(L10n.Settings.departureOnly)
            }
        }
        parts.append(hapticsEnabled ? L10n.Settings.hapticsOn : L10n.Settings.hapticsOff)
        return parts.joined(separator: " · ")
    }

    private var themeFooterText: String {
        switch AppTheme(rawValue: appTheme) {
        case .system:
            return L10n.Settings.themeFooterSystem
        case .light:
            return L10n.Settings.themeFooterLight
        case .dark:
            return L10n.Settings.themeFooterDark
        default:
            return ""
        }
    }

    // MARK: - Actions

    private func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
}

#Preview {
    SettingsView()
        .environment(AppDataStore())
}
