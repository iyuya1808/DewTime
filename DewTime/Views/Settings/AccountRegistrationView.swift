import SwiftUI
import Supabase
import AuthenticationServices

struct AccountRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppDataStore.self) private var store
    @State private var authService = AuthService.shared
    
    // メールログイン・登録用の状態
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isShowingSuccessAlert = false
    @State private var successAlertTitle = ""
    @State private var successAlertMessage = ""
    @State private var currentNonce = ""
    
    // アニメーション開閉用
    @State private var showEmailForm = false
    
    // 登録 or ログインの切り替え
    enum EmailMode {
        case signUp
        case signIn
    }
    @State private var emailMode: EmailMode = .signUp
    
    // フォーカス管理
    enum Field {
        case email, password, confirmPassword
    }
    @FocusState private var focusedField: Field?
    
    private var isFormValid: Bool {
        switch emailMode {
        case .signUp:
            return !email.isEmpty && 
                   email.contains("@") && 
                   password.count >= 6 && 
                   password == confirmPassword
        case .signIn:
            return !email.isEmpty && 
                   email.contains("@") && 
                   password.count >= 6
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // 1. ヘッダーセクション (高級感のあるアイコンとグラデーション)
                headerSection
                    .padding(.top, 24)
                
                // 2. メインアクション：Appleでサインイン (一押しの推奨カード)
                appleRegistrationCard
                    .padding(.horizontal)
                
                // 境界線（美しいグラデーションのラインとテキスト）
                orSeparator
                    .padding(.horizontal, 32)
                
                // 3. サブアクション：メールアドレスフォーム (折りたたみ式プレミアムアコーディオン)
                emailRegistrationAccordion
                    .padding(.horizontal)
                
                if let errorMessage = authService.errorMessage {
                    errorCard(message: errorMessage)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
        .dewAppBackground()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("クラウド保存の設定")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .alert(successAlertTitle, isPresented: $isShowingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(successAlertMessage)
        }
        .onChange(of: authService.errorMessage) { _, newValue in
            if newValue != nil {
                // エラー発生時にキーボードを閉じる
                focusedField = nil
            }
        }
    }
    
    // MARK: - Views
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // クラウドアイコンにグラデーションを適用
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.dewBlue.opacity(0.18), .dewNavy.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                
                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.dewBlue, .dewNavy],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: .dewBlue.opacity(0.25), radius: 12, x: 0, y: 6)
            
            Text("大切なデータをクラウドへ")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            
            Text("アカウントを連携すると、毎朝の水やりデータや水槽・図鑑の記録を安全に保存し、機種変更時にも引き継ぐことができます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineSpacing(5)
        }
    }
    
    private var appleRegistrationCard: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "apple.logo")
                        .font(.system(size: 22))
                        .foregroundStyle(.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Apple IDで連携")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        // 「推奨」バッジ
                        Text("推奨")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(colors: [.dewBlue, .dewNavy], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                    
                    Text("パスワード不要。最も安全で、1タップで瞬時にクラウド同期を開始できます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                Spacer()
            }
            
            if authService.isProcessing {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.primary)
                    Spacer()
                }
                .frame(height: 50)
            } else {
                SignInWithAppleButton(
                    .continue,
                    onRequest: { request in
                        let nonce = authService.generateNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = authService.sha256(nonce)
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                               let tokenData = appleIDCredential.identityToken,
                               let tokenString = String(data: tokenData, encoding: .utf8) {
                                Task {
                                    await authService.signInWithApple(idToken: tokenString, nonce: currentNonce)
                                    if authService.errorMessage == nil {
                                        await store.load()
                                        successAlertTitle = "連携完了"
                                        successAlertMessage = "Apple IDとの連携が完了しました！これで大事な育成データを安全にバックアップ・同期できます。"
                                        isShowingSuccessAlert = true
                                    }
                                }
                            }
                        case .failure(let error):
                            print("Apple Auth Failed: \(error.localizedDescription)")
                            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                                // ユーザーがキャンセルした場合は何もしない
                            } else {
                                authService.errorMessage = "Appleサインインに失敗しました。設定やネットワーク状況を確認してください。"
                            }
                        }
                    }
                )
                .frame(height: 50)
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.dewSurface)
                .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .clear, .black.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
    
    private var orSeparator: some View {
        HStack(spacing: 16) {
            VStack { Divider().background(Color.secondary.opacity(0.2)) }
            Text("または")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            VStack { Divider().background(Color.secondary.opacity(0.2)) }
        }
    }
    
    private var emailRegistrationAccordion: some View {
        VStack(spacing: 0) {
            // アコーディオンのヘッダーボタン
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showEmailForm.toggle()
                }
            } label: {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.08))
                            .frame(width: 36, height: 36)
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("メールアドレスを使用する")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showEmailForm ? 90 : 0))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .contentShape(Rectangle())
                .background(Color.black.opacity(0.0001))
            }
            .buttonStyle(.plain)
            
            // 開閉するフォーム部分
            if showEmailForm {
                VStack(spacing: 20) {
                    Divider()
                        .padding(.horizontal, 18)
                        .padding(.bottom, 4)
                    
                    // プレミアムカスタムセグメンテッドコントロール
                    customSegmentedControl
                    
                    VStack(spacing: 16) {
                        customTextField(
                            title: "メールアドレス",
                            placeholder: "example@email.com",
                            text: $email,
                            fieldType: .email,
                            keyboardType: .emailAddress
                        )
                        
                        customSecureField(
                            title: "パスワード (6文字以上)",
                            text: $password,
                            fieldType: .password
                        )
                        
                        if emailMode == .signUp {
                            customSecureField(
                                title: "パスワードの確認",
                                text: $confirmPassword,
                                fieldType: .confirmPassword
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, 18)
                    
                    // 送信ボタン
                    if authService.isProcessing {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.dewBlue)
                            Spacer()
                        }
                        .frame(height: 48)
                        .padding(.bottom, 20)
                    } else {
                        Button {
                            focusedField = nil
                            handleEmailAction()
                        } label: {
                            Text(emailMode == .signUp ? "登録してクラウド保存を開始" : "ログインしてクラウド保存を開始")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(isFormValid ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    isFormValid ?
                                    LinearGradient(colors: [.dewBlue, .dewNavy], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(colors: [Color.dewSurfaceSoft], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: isFormValid ? .dewBlue.opacity(0.25) : .clear, radius: 8, x: 0, y: 4)
                        }
                        .disabled(!isFormValid)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 22)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.dewSurface.opacity(0.85))
                .shadow(color: .black.opacity(0.03), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    // スムーズなアニメーション付きカスタムセグメンテッドコントロール
    private var customSegmentedControl: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    emailMode = .signUp
                }
            } label: {
                Text("新規作成")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(emailMode == .signUp ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        ZStack {
                            if emailMode == .signUp {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(LinearGradient(colors: [.dewBlue, .dewNavy], startPoint: .leading, endPoint: .trailing))
                                    .matchedGeometryEffect(id: "activeTab", in: tabAnimation)
                                    .shadow(color: .dewBlue.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                    .background(Color.black.opacity(0.0001))
            }
            .buttonStyle(.plain)
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    emailMode = .signIn
                }
            } label: {
                Text("ログイン")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(emailMode == .signIn ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        ZStack {
                            if emailMode == .signIn {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(LinearGradient(colors: [.dewBlue, .dewNavy], startPoint: .leading, endPoint: .trailing))
                                    .matchedGeometryEffect(id: "activeTab", in: tabAnimation)
                                    .shadow(color: .dewBlue.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                    .background(Color.black.opacity(0.0001))
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(Color.dewSurfaceSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 18)
    }
    
    @Namespace private var tabAnimation
    
    // カスタムの美しいテキスト入力フィールド
    private func customTextField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        fieldType: Field,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($focusedField, equals: fieldType)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.dewSurfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            focusedField == fieldType ? 
                            Color.dewBlue.opacity(0.8) : 
                            Color.secondary.opacity(0.1), 
                            lineWidth: focusedField == fieldType ? 1.5 : 1
                        )
                )
                .shadow(color: focusedField == fieldType ? .dewBlue.opacity(0.04) : .clear, radius: 4, x: 0, y: 2)
        }
    }
    
    // カスタムの美しいセキュア入力フィールド
    private func customSecureField(
        title: String,
        text: Binding<String>,
        fieldType: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            SecureField("••••••••", text: text)
                .focused($focusedField, equals: fieldType)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.dewSurfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            focusedField == fieldType ? 
                            Color.dewBlue.opacity(0.8) : 
                            Color.secondary.opacity(0.1), 
                            lineWidth: focusedField == fieldType ? 1.5 : 1
                        )
                )
                .shadow(color: focusedField == fieldType ? .dewBlue.opacity(0.04) : .clear, radius: 4, x: 0, y: 2)
        }
    }
    
    private func errorCard(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(nil)
            
            Spacer()
            
            Button {
                authService.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Actions
    
    private func registerAccount() {
        Task {
            await authService.signUpWithEmail(email: email, password: password)
            if authService.errorMessage == nil {
                await store.load()
                successAlertTitle = "アカウント作成完了"
                successAlertMessage = "メールアドレスでのアカウント登録が完了しました！これで大事な育成データを安全に同期できます。"
                isShowingSuccessAlert = true
            }
        }
    }
    
    private func loginAccount() {
        Task {
            await authService.signInWithEmail(email: email, password: password)
            if authService.errorMessage == nil {
                await store.load()
                successAlertTitle = "ログイン完了"
                successAlertMessage = "ログインに成功し、クラウドのデータ同期が有効になりました。"
                isShowingSuccessAlert = true
            }
        }
    }
    
    private func handleEmailAction() {
        switch emailMode {
        case .signUp:
            registerAccount()
        case .signIn:
            loginAccount()
        }
    }
}

#Preview {
    NavigationStack {
        AccountRegistrationView()
            .environment(AppDataStore())
    }
}
