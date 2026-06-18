import SwiftUI
import StoreKit

struct SupportDeveloperView: View {
    @State private var storeManager = StoreManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showSuccessAlert = false
    @State private var successAlertMessage = ""

    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.dewWaterHigh1, .dewWaterHigh2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .dewBlue.opacity(0.3), radius: 8, x: 0, y: 4)

                    Text(L10n.Support.header)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(L10n.Support.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .padding(.horizontal, 8)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dewSurface)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                )
                .padding(.horizontal)
                .padding(.top, 16)

                if storeManager.products.isEmpty {
                    if storeManager.isPurchasing {
                        ProgressView(L10n.Support.loading)
                            .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 16) {
                            Text(L10n.Support.loadFailed)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button(action: {
                                Task {
                                    await storeManager.loadProducts()
                                }
                            }) {
                                Text(L10n.Support.reload)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.dewBlue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(20)
                            }
                        }
                        .padding(.vertical, 40)
                    }
                } else {
                    VStack(spacing: 16) {
                        ForEach(storeManager.products) { product in
                            productCard(for: product)
                        }
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Support.disclaimerTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(L10n.Support.disclaimer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(L10n.Support.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .dewAppBackground()
        .disabled(storeManager.isPurchasing)
        .overlay {
            if storeManager.isPurchasing {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(L10n.Support.processing)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(Color(white: 0.15, opacity: 0.85))
                    .cornerRadius(16)
                }
            }
        }
        .task {
            if storeManager.products.isEmpty {
                await storeManager.loadProducts()
            }
        }
        .onChange(of: storeManager.purchaseSuccessMessage) { _, newValue in
            if let message = newValue {
                successAlertMessage = message
                showSuccessAlert = true
                storeManager.purchaseSuccessMessage = nil
            }
        }
        .onChange(of: storeManager.errorMessage) { _, newValue in
            if let message = newValue {
                errorAlertMessage = message
                showErrorAlert = true
                storeManager.errorMessage = nil
            }
        }
        .alert(L10n.Support.thankYou, isPresented: $showSuccessAlert) {
            Button(L10n.Common.close, role: .cancel) { }
        } message: {
            Text(successAlertMessage)
        }
        .alert(L10n.Support.errorTitle, isPresented: $showErrorAlert) {
            Button(L10n.Support.confirm, role: .cancel) { }
        } message: {
            Text(errorAlertMessage)
        }
    }

    @ViewBuilder
    private func productCard(for product: Product) -> some View {
        let style = cardStyle(for: product)

        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(style.gradient)
                    .frame(width: 56, height: 56)

                Image(systemName: style.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .shadow(color: style.shadowColor.opacity(0.3), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                    .fontWeight(.bold)

                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: {
                Task {
                    await storeManager.purchase(product)
                }
            }) {
                Text(product.displayPrice)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(style.gradient)
                    .foregroundStyle(.white)
                    .cornerRadius(18)
                    .shadow(color: style.shadowColor.opacity(0.2), radius: 4, x: 0, y: 2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dewSurface)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
    }

    private struct CardStyleInfo {
        let icon: String
        let gradient: LinearGradient
        let shadowColor: Color
    }

    private func cardStyle(for product: Product) -> CardStyleInfo {
        let id = product.id.lowercased()

        if id.contains("tip.snack") {
            return CardStyleInfo(
                icon: "gift.fill",
                gradient: LinearGradient(
                    colors: [Color(hex: "#4FC3F7"), Color(hex: "#0EC5FF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                shadowColor: Color(hex: "#0EC5FF")
            )
        } else if id.contains("tip.coffee") {
            return CardStyleInfo(
                icon: "cup.and.saucer.fill",
                gradient: LinearGradient(
                    colors: [Color(hex: "#FFB74D"), Color(hex: "#ffd200")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                shadowColor: Color(hex: "#FFB74D")
            )
        } else if id.contains("tip.pizza") {
            return CardStyleInfo(
                icon: "flame.fill",
                gradient: LinearGradient(
                    colors: [Color(hex: "#f953c6"), Color(hex: "#b91d73")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                shadowColor: Color(hex: "#b91d73")
            )
        } else {
            return CardStyleInfo(
                icon: "heart.fill",
                gradient: LinearGradient(
                    colors: [Color(hex: "#f953c6"), Color(hex: "#b91d73")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                shadowColor: Color(hex: "#b91d73")
            )
        }
    }
}

#Preview {
    NavigationStack {
        SupportDeveloperView()
    }
}
