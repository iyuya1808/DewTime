import SwiftUI

@main
struct DewTimeApp: App {
    @State private var dataStore = AppDataStore()
    @State private var deepLinkRouter = QuickTimerDeepLinkRouter()
    @State private var isDataReady = false
    @State private var isShellReady = false
    @State private var showLaunchOverlay = true
    @AppStorage(AppPreferences.Key.appTheme.rawValue) private var appTheme = AppTheme.system.rawValue
    @AppStorage(AppPreferences.Key.appLanguage.rawValue) private var appLanguageRaw = AppLanguage.system.rawValue

    private var isLaunchReady: Bool {
        isDataReady && isShellReady
    }

    private var colorScheme: ColorScheme? {
        switch AppTheme(rawValue: appTheme) {
        case .light: return .light
        case .dark: return .dark
        default: return nil
        }
    }

    private var activeLocale: Locale {
        LocalizationManager.shared.locale
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isDataReady {
                    ContentView()
                        .environment(dataStore)
                        .environment(deepLinkRouter)
                        .preferredColorScheme(colorScheme)
                        .environment(\.locale, activeLocale)
                        .id(appLanguageRaw)
                        .onOpenURL { url in
                            deepLinkRouter.handle(url)
                        }
                        .onAppear {
                            LocalizationManager.shared.language = AppLanguage(rawValue: appLanguageRaw) ?? .system
                        }
                        .task {
                            await Task.yield()
                            isShellReady = true
                        }
                }

                if showLaunchOverlay {
                    AppLaunchLoadingView(
                        bootstrapComplete: isLaunchReady,
                        onDismissed: {
                            showLaunchOverlay = false
                            NotificationScheduler.requestPermission()
                        }
                    )
                    .zIndex(1)
                }
            }
            .task {
                await runBootstrap()
            }
        }
    }

    @MainActor
    private func runBootstrap() async {
        await dataStore.loadLocalCache()
        isDataReady = true
        Task {
            await dataStore.syncFromCloud()
        }
    }
}
