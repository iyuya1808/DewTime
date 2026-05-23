import SwiftUI
import SwiftData

@main
struct DewTimeApp: App {
    let container: ModelContainer

    init() {
        do {
            let container = try ModelContainer(
                for: UserSchedule.self, RoutineItem.self, PlantFlower.self, ActivePlant.self, PlantWateringRecord.self
            )
            SampleData.seedIfNeeded(context: container.mainContext)
            self.container = container
        } catch {
            fatalError("ModelContainer initialization failed: \(error)")
        }
        NotificationScheduler.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
