import SwiftUI
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        return true
    }
}

@main
struct DewTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var dataStore = AppDataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dataStore)
                .task {
                    NotificationScheduler.requestPermission()
                    await dataStore.load()
                }
        }
    }
}
