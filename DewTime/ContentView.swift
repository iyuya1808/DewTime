import SwiftUI
import SwiftData

enum AppTab: CaseIterable, Identifiable {
    case timer, collection, aquarium, profile

    var id: Self { self }

    var title: String {
        switch self {
        case .timer:      return "タイマー"
        case .collection: return "図鑑"
        case .aquarium:   return "水槽"
        case .profile:    return "プロフィール"
        }
    }

    var icon: String {
        switch self {
        case .timer:      return "drop.fill"
        case .collection: return "book.closed.fill"
        case .aquarium:   return "fish.fill"
        case .profile:    return "person.fill"
        }
    }

    @ViewBuilder var destination: some View {
        switch self {
        case .timer:      TimerView()
        case .collection: CollectionView()
        case .aquarium:   LiveAquariumView()
        case .profile:    ProfileView()
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
        .modelContainer(for: [UserSchedule.self, RoutineItem.self, CollectedFish.self, ActiveFish.self, FishCareRecord.self, Aquarium.self], inMemory: true)
}
