import SwiftUI
import WidgetKit

enum AppTab: CaseIterable, Identifiable {
    case timer, collection, aquarium, profile

    var id: Self { self }

    var title: String {
        switch self {
        case .timer:      return L10n.Tab.timer
        case .collection: return L10n.Tab.collection
        case .aquarium:   return L10n.Tab.aquarium
        case .profile:    return L10n.Tab.profile
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
    @AppStorage(AppPreferences.Key.appLanguage.rawValue) private var appLanguageRaw = AppLanguage.system.rawValue
    @State private var selectedTab: AppTab = .timer

    private var activeLocale: Locale {
        LocalizationManager.shared.locale
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                tab.destination
                    .tag(tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
            }
        }
        .environment(\.appTabSelection, $selectedTab)
        .environment(\.locale, activeLocale)
        .onAppear {
            LocalizationManager.shared.language = AppLanguage(rawValue: appLanguageRaw) ?? .system
        }
        .onChange(of: appLanguageRaw) { _, newValue in
            LocalizationManager.shared.language = AppLanguage(rawValue: newValue) ?? .system
            WidgetCenter.shared.reloadTimelines(ofKind: SharedTimerWidgetState.widgetKind)
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
        .environment(QuickTimerDeepLinkRouter())
}
