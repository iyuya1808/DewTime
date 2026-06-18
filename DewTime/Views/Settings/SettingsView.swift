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
            .navigationTitle("設定")
            .dewAppBackground()
            .task {
                await refreshAuthorizationStatus()
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

    // MARK: - Sections

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(title: "アカウント", systemImage: "person.crop.circle", tint: .teal)

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
                SettingsStatusBadge(text: "ローカルのみ", tint: .orange, systemImage: "iphone")
            } else {
                SettingsStatusBadge(text: "クラウド保存: 有効", tint: .teal, systemImage: "icloud.fill")
                if let email = user.email {
                    Text(email)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            SettingsStatusBadge(text: "準備中", tint: .secondary, systemImage: "hourglass")
        }
    }

    private var anonymousAccountBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("データはこの端末にのみ保存されています。アカウント登録でクラウド保存とプロフィール編集が使えます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink {
                AccountRegistrationView()
            } label: {
                HStack {
                    Spacer()
                    Label("アカウント登録する", systemImage: "icloud.and.arrow.up")
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
                title: "通知と触覚",
                caption: "出発時刻のお知らせと操作時の振動",
                systemImage: "bell.badge.fill",
                tint: .orange
            )

            NavigationLink {
                NotificationSettingsView()
            } label: {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsNavigationRow(
                            title: "通知と触覚の設定",
                            subtitle: notificationInlineSummary,
                            systemImage: "bell.badge",
                            iconTint: .orange,
                            showsChevron: false
                        )

                        if authorizationStatus == .denied {
                            SettingsStatusBadge(
                                text: "iOSで通知が拒否されています",
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
                title: "表示",
                caption: "アプリ全体と水槽の見た目",
                systemImage: "paintpalette.fill",
                tint: .purple
            )

            SettingsCard {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("外観モード")
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
                        Text("水槽テーマ")
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

                        Text("タイマーの水タンクと水槽画面の色合いが変わります。")
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
                title: "ヘルプ",
                systemImage: "questionmark.circle.fill",
                tint: .blue
            )

            SettingsCard {
                Button {
                    hasCompletedTutorial = false
                } label: {
                    SettingsNavigationRow(
                        title: "チュートリアルをもう一度見る",
                        subtitle: "タイマー・しずくと餌・水槽・図鑑・実績の使い方を確認できます",
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
            SettingsSectionHeader(title: "その他", systemImage: "ellipsis.circle", tint: .secondary)

            SettingsCard {
                VStack(spacing: 16) {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        SettingsNavigationRow(
                            title: "データ管理",
                            subtitle: "保存状態の確認やデータの初期化",
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
                            title: "開発者を応援",
                            subtitle: "アプリの開発をサポートする",
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
        Text("バージョン \(appVersionString)")
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
        parts.append(notificationsEnabled ? "通知 ON" : "通知 OFF")
        if notificationsEnabled {
            if departureReminderEnabled {
                parts.append("\(departureReminderMinutes)分前にリマインド")
            } else {
                parts.append("出発時刻のみ")
            }
        }
        parts.append(hapticsEnabled ? "触覚 ON" : "触覚 OFF")
        return parts.joined(separator: " · ")
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
