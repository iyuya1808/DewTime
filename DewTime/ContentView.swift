import SwiftUI
import SwiftData

enum AppTab: CaseIterable, Identifiable {
    case timer, garden, collection, settings

    var id: Self { self }

    var title: String {
        switch self {
        case .timer:    return "タイマー"
        case .garden:   return "お庭"
        case .collection: return "図鑑"
        case .settings: return "設定"
        }
    }

    var icon: String {
        switch self {
        case .timer:    return "drop.fill"
        case .garden:   return "leaf.fill"
        case .collection: return "book.closed.fill"
        case .settings: return "gear"
        }
    }

    @ViewBuilder var destination: some View {
        switch self {
        case .timer:    TimerView()
        case .garden:   GardenView()
        case .collection: CollectionView()
        case .settings: SettingsView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            ForEach(AppTab.allCases) { tab in
                tab.destination
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserSchedule.self, RoutineItem.self, PlantFlower.self, ActivePlant.self, PlantWateringRecord.self], inMemory: true)
}
