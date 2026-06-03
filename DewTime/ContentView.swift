import SwiftUI

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
    @AppStorage(AppPreferences.Key.hasCompletedTutorial.rawValue) private var hasCompletedTutorial = false
    @State private var selectedTab: AppTab = .timer

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                tab.destination
                    .tag(tab)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
            }
        }
        .overlay {
            if !hasCompletedTutorial {
                TutorialOverlayView(
                    selectedTab: $selectedTab,
                    onFinish: { hasCompletedTutorial = true }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasCompletedTutorial)
        .onChange(of: selectedTab) { _, _ in
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppDataStore())
}
