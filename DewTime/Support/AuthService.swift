import Foundation
import Observation
import Supabase
import CryptoKit

@Observable
@MainActor
final class AuthService {
    static let shared = AuthService()
    
    var currentUser: User?
    var isAnonymous = false
    var isProcessing = false
    var errorMessage: String?
    
    private let supabase = SupabaseManager.shared.client
    
    init() {
        // 現在のログインセッションを監視
        Task {
            for await state in supabase.auth.authStateChanges {
                self.currentUser = state.session?.user
                self.isAnonymous = state.session?.user.isAnonymous ?? false
            }
        }
    }
    
    /// ① アカウントなしで利用開始する（匿名サインイン）
    func signInAnonymously() async {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.signInAnonymously()
            self.currentUser = session.user
            self.isAnonymous = true
            print("Logged in anonymously: \(session.user.id)")
        } catch {
            self.errorMessage = "匿名ログインに失敗しました: \(error.localizedDescription)"
            print("Anonymous sign-in error: \(error)")
        }
        isProcessing = false
    }

    /// クラウドデータ同期前に、既存セッションまたは匿名ログイン済みユーザーを確保する。
    func ensureAuthenticated() async throws -> User {
        if let currentUser {
            return currentUser
        }

        if let session = supabase.auth.currentSession {
            self.currentUser = session.user
            self.isAnonymous = session.user.isAnonymous
            return session.user
        }

        return try await signInAnonymouslyForUser()
    }

    func ensureAuthenticatedUserId() async throws -> UUID {
        try await ensureAuthenticated().id
    }
    
    /// ② 匿名アカウントからメール・パスワードの正式アカウントにアップグレードする
    func signUpWithEmail(email: String, password: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        
        do {
            let attributes = UserAttributes(email: email, password: password)
            _ = try await supabase.auth.update(user: attributes)
            
            print("Successfully upgraded to permanent account")
        } catch {
            self.errorMessage = "アカウント登録に失敗しました: \(error.localizedDescription)"
            print("Account upgrade error: \(error)")
        }
        isProcessing = false
    }
    
    /// ③ 登録済みのメールアドレスとパスワードでサインインする
    func signInWithEmail(email: String, password: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            self.currentUser = session.user
            self.isAnonymous = false
            print("Successfully signed in with email: \(session.user.id)")
        } catch {
            self.errorMessage = "ログインに失敗しました: \(error.localizedDescription)"
            print("Email sign-in error: \(error)")
        }
        isProcessing = false
    }
    
    /// ③ Apple ID を使ってサインインまたは匿名アカウントをアップグレードする
    func signInWithApple(idToken: String, nonce: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        
        do {
            let credentials = OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                accessToken: nil,
                nonce: nonce
            )
            let session = try await supabase.auth.signInWithIdToken(credentials: credentials)
            self.currentUser = session.user
            self.isAnonymous = false
            print("Successfully signed in with Apple: \(session.user.id)")
        } catch {
            self.errorMessage = "Appleサインインに失敗しました: \(error.localizedDescription)"
            print("Apple sign-in error: \(error)")
        }
        isProcessing = false
    }
    
    /// ④ アカウントからサインアウトし、新しい匿名アカウントを作成する
    func signOut() async {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        
        do {
            try await supabase.auth.signOut()
            let session = try await supabase.auth.signInAnonymously()
            self.currentUser = session.user
            self.isAnonymous = true
            print("Successfully signed out and re-authenticated anonymously")
        } catch {
            self.errorMessage = "サインアウトに失敗しました: \(error.localizedDescription)"
            print("Sign out error: \(error)")
        }
        isProcessing = false
    }
    
    // MARK: - Nonce & SHA256 Helpers
    
    func generateNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let err = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if err != errSecSuccess {
            fatalError("Unable to generate input bytes: \(err)")
        }

        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._~")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }

    private func signInAnonymouslyForUser() async throws -> User {
        guard !isProcessing else {
            throw CloudDataError.unauthenticated
        }
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            let session = try await supabase.auth.signInAnonymously()
            self.currentUser = session.user
            self.isAnonymous = true
            print("Logged in anonymously: \(session.user.id)")
            return session.user
        } catch {
            self.errorMessage = "匿名ログインに失敗しました: \(error.localizedDescription)"
            print("Anonymous sign-in error: \(error)")
            throw error
        }
    }
}
