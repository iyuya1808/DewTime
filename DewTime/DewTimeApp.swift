import SwiftUI

@main
struct DewTimeApp: App {
    @State private var dataStore = AppDataStore()
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
            ContentView()
                .environment(dataStore)
                .preferredColorScheme(colorScheme)
                .task {
                    NotificationScheduler.requestPermission()
                    _ = try? await AuthService.shared.ensureAuthenticated()
                    await dataStore.load()
                }
        }
    }
}
