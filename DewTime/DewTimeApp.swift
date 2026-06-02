import SwiftUI

@main
struct DewTimeApp: App {
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
