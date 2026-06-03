import SwiftUI
import StoreKit

struct SupportDeveloperView: View {
    @State private var storeManager = StoreManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // 購入成功メッセージのアラート表示制御
    @State private var showSuccessAlert = false
    @State private var successAlertMessage = ""
    
    // エラーメッセージのアラート表示制御
    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ヘッダーカード
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
                    
                    Text("開発者を応援する")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("DewTimeは個人で開発・運営を行っています。もしこのアプリを気に入っていただけましたら、開発をサポートしていただけると大変励みになります。いただいた応援金は、アプリのサーバー維持費や、今後の新機能開発の活動費（コーヒー代やピザ代など）として大切に活用させていただきます。")
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
                
                // アイテムリスト
                if storeManager.products.isEmpty {
                    if storeManager.isPurchasing {
                        ProgressView("読み込み中...")
                            .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 16) {
                            Text("応援プランを読み込めませんでした。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Button(action: {
                                Task {
                                    await storeManager.loadProducts()
                                }
                            }) {
                                Text("再読み込み")
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
                
                // 注意事項
                VStack(alignment: .leading, spacing: 8) {
                    Text("注意事項")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text("・本機能は開発者への「寄付・チップ」としての応援機能であり、アプリ内の追加機能がアンロックされるものではありません。\n・お支払いにはApp Storeに登録された決済方法が適用されます。\n・一度購入された応援のキャンセルや返金はいたしかねますのでご了承ください。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("開発者応援")
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
                        Text("決済処理中...")
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
                storeManager.purchaseSuccessMessage = nil // リセット
            }
        }
        .onChange(of: storeManager.errorMessage) { _, newValue in
            if let message = newValue {
                errorAlertMessage = message
                showErrorAlert = true
                storeManager.errorMessage = nil // リセット
            }
        }
        .alert("ありがとうございます！", isPresented: $showSuccessAlert) {
            Button("閉じる", role: .cancel) { }
        } message: {
            Text(successAlertMessage)
        }
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("確認", role: .cancel) { }
        } message: {
            Text(errorAlertMessage)
        }
    }
    
    // MARK: - Views
    
    @ViewBuilder
    private func productCard(for product: Product) -> some View {
        let style = cardStyle(for: product)
        
        HStack(spacing: 16) {
            // アイコン
            ZStack {
                Circle()
                    .fill(style.gradient)
                    .frame(width: 56, height: 56)
                
                Image(systemName: style.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .shadow(color: style.shadowColor.opacity(0.3), radius: 6, x: 0, y: 3)
            
            // テキスト
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
            
            // 購入ボタン
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
    
    // MARK: - Style Helpers
    
    private struct CardStyleInfo {
        let icon: String
        let gradient: LinearGradient
        let shadowColor: Color
    }
    
    private func cardStyle(for product: Product) -> CardStyleInfo {
        let id = product.id.lowercased()
        let name = product.displayName
        
        // 1. お菓子判定 (IDか表示名に snack/cookie/お菓子/クッキー が含まれる)
        if id.contains("snack") || id.contains("cookie") || id.contains("tip1") || id.contains("small") || id.contains("tier1") ||
           name.contains("お菓子") || name.contains("スナック") || name.contains("クッキー") {
            return CardStyleInfo(
                icon: "cookie",
                gradient: LinearGradient(
                    colors: [Color(hex: "#4FC3F7"), Color(hex: "#0EC5FF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                shadowColor: Color(hex: "#0EC5FF")
            )
        } 
        // 2. コーヒー判定 (IDか表示名に coffee/drink/コーヒー/珈琲 が含まれる)
        else if id.contains("coffee") || id.contains("drink") || id.contains("tip2") || id.contains("medium") || id.contains("tier2") ||
                name.contains("コーヒー") || name.contains("珈琲") || name.contains("カフェ") {
            return CardStyleInfo(
                icon: "cup.and.saucer.fill",
                gradient: LinearGradient(
                    colors: [Color(hex: "#FFB74D"), Color(hex: "#ffd200")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                shadowColor: Color(hex: "#FFB74D")
            )
        } 
        // 3. ピザ判定 (IDか表示名に pizza/meal/ピザ/夜食 が含まれる)
        else if id.contains("pizza") || id.contains("meal") || id.contains("tip3") || id.contains("large") || id.contains("tier3") ||
                name.contains("ピザ") || name.contains("食事") || name.contains("夜食") {
            return CardStyleInfo(
                icon: "pizza",
                gradient: LinearGradient(
                    colors: [Color(hex: "#f953c6"), Color(hex: "#b91d73")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                shadowColor: Color(hex: "#b91d73")
            )
        }
        // 4. デフォルト (判定不能な場合は汎用的なハートマーク)
        else {
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
