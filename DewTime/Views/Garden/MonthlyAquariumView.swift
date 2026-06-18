import SwiftUI

struct MonthlyAquariumView: View {
    @State private var selectedRecord: FishCareRecord?

    var body: some View {
        ScrollView {
            DepartureRecordCalendarView(selectedRecord: $selectedRecord)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.teal)
                    Text(L10n.Aquarium.departureRecords)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(L10n.Aquarium.departureRecords)
            }
        }
        .dewAppBackground()
        .sheet(item: $selectedRecord) { record in
            FishCareDetailSheet(record: record)
                .presentationDetents([.fraction(0.68), .large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    NavigationStack {
        MonthlyAquariumView()
    }
    .environment(AppDataStore())
}
