import SwiftUI

@main
struct DewTimeApp: App {
    @State private var dataStore = AppDataStore()
    @State private var deepLinkRouter = QuickTimerDeepLinkRouter()
    @State private var isBootstrapComplete = false
    @State private var showLaunchOverlay = true
    @AppStorage(AppPreferences.Key.appTheme.rawValue) private var appTheme = AppTheme.system.rawValue

    private var colorScheme: ColorScheme? {
        switch AppTheme(rawValue: appTheme) {
        case .light: return .light
        case .dark: return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(dataStore)
                    .environment(deepLinkRouter)
                    .preferredColorScheme(colorScheme)
                    .onOpenURL { url in
                        deepLinkRouter.handle(url)
                    }

                if showLaunchOverlay {
                    AppLaunchLoadingView(
                        bootstrapComplete: isBootstrapComplete,
                        onDismissed: { showLaunchOverlay = false }
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
        NotificationScheduler.requestPermission()
        await dataStore.loadLocalCache()
        isBootstrapComplete = true
        Task {
            await dataStore.syncFromCloud()
        }
    }
}
