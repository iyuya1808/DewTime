import Foundation
import StoreKit
import Observation

@Observable
@MainActor
class StoreManager {
    static let shared = StoreManager()
    
    private let productIDs = [
        "com.technophere.dewtime.tip.snack",
        "com.technophere.dewtime.tip.coffee",
        "com.technophere.dewtime.tip.pizza"
    ]
    
    var products: [Product] = []
    var isPurchasing = false
    var purchaseSuccessMessage: String?
    var errorMessage: String?
    
    private var transactionListener: Task<Void, Error>?
    
    init() {
        transactionListener = listenForTransactions()
    }
    
    deinit {}
    
    /// プロダクト情報を読み込む
    func loadProducts() async {
        do {
            let loadedProducts = try await Product.products(for: productIDs)
            // 価格の安い順にソートして保持
            self.products = loadedProducts.sorted(by: { $0.price < $1.price })
        } catch {
            print("Failed to load products: \(error)")
            self.errorMessage = "商品の情報を取得できませんでした。"
        }
    }
    
    /// 購入処理を実行
    func purchase(_ product: Product) async {
        isPurchasing = true
        errorMessage = nil
        purchaseSuccessMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                
                // トランザクションの完了
                await transaction.finish()
                
                // 応援へのお礼メッセージを設定
                self.purchaseSuccessMessage = "「\(product.displayName)」での応援、ありがとうございます！温かいお気持ちに感謝いたします。"
                
            case .userCancelled:
                // ユーザーによるキャンセル
                break
                
            case .pending:
                self.errorMessage = "購入処理が保留中です。承認されるまでお待ちください。"
                
            @unknown default:
                break
            }
        } catch {
            print("Purchase failed: \(error)")
            self.errorMessage = "購入処理中にエラーが発生しました。"
        }
        
        isPurchasing = false
    }
    
    /// トランザクションの検証
    private nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    /// トランザクションアップデートの監視
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached(priority: .background) {
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await transaction.finish()
                } catch {
                    print("Transaction update failed verification: \(error)")
                }
            }
        }
    }
}
