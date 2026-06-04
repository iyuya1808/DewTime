import SwiftUI
import Supabase

struct ProfileEditView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var authService = AuthService.shared
    @State private var nickname = ""
    @State private var avatarEmoji = "🐟"
    @State private var showSignOutAlert = false
    
    @FocusState private var isNicknameFocused: Bool

    /// アバター候補。魚種の絵文字 + 一般的な顔・生き物を並べる。
    private let avatarOptions: [String] = {
        let fish = FishSpecies.allCases.map(\.emoji)
        let extras = ["😀", "🧑", "👧", "👦", "🌊", "💧", "🌱", "⭐️"]
        return fish + extras
    }()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. 未登録（匿名）の場合のロック警告・誘導カード
                    if authService.isAnonymous {
                        lockBannerCard
                            .padding(.top, 16)
                    }
                    
                    // 2. プロフィールカスタマイズセクション (カードで一体化)
                    VStack(spacing: 20) {
                        // ニックネーム入力
                        nicknameInputCard
                        
                        // アバター選択
                        avatarSelectionCard
                    }
                    .opacity(authService.isAnonymous ? 0.6 : 1.0)
                    .disabled(authService.isAnonymous)
                    
                    // 3. ログイン済みのときのアカウント情報・サインアウトカード
                    if !authService.isAnonymous {
                        accountStatusCard
                    }
                    
                    if let errorMessage = authService.errorMessage {
                        errorCard(message: errorMessage)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("アカウント")
            .navigationBarTitleDisplayMode(.inline)
            .dewAppBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await store.updateProfile(nickname: nickname, avatarEmoji: avatarEmoji) }
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(authService.isAnonymous ? Color.secondary : Color.teal)
                    .disabled(authService.isAnonymous)
                }
            }
            .onAppear {
                let profile = store.profile()
                nickname = profile.nickname
                avatarEmoji = profile.avatarEmoji
            }
            .alert("サインアウト", isPresented: $showSignOutAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("サインアウト", role: .destructive) {
                    performSignOut()
                }
            } message: {
                Text("サインアウトするとクラウドとのデータ同期が停止します。よろしいですか？（サインアウト後は新しい匿名アカウントが作成され、引き続きアプリをご利用いただけます）")
            }
        }
    }

    // MARK: - Subviews
    
    // 制限中のプレミアム警告・登録誘導カード
    private var lockBannerCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("プロフィール編集が制限されています")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text("ニックネームとアバターを変更するには、クラウド保存の有効化（アカウント登録）が必要です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                Spacer()
            }
            
            NavigationLink(destination: AccountRegistrationView()) {
                HStack {
                    Spacer()
                    Label("アカウント登録して編集する", systemImage: "icloud.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .frame(height: 48)
                .background(
                    LinearGradient(colors: [.dewBlue, .dewNavy], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .shadow(color: .dewBlue.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.dewSurface)
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1.2)
        )
    }
    
    // ニックネームの美しい入力カード
    private var nicknameInputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ニックネーム")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            
            TextField("例: みずやり名人", text: $nickname)
                .focused($isNicknameFocused)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.dewSurfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isNicknameFocused ? 
                            Color.teal.opacity(0.8) : 
                            Color.secondary.opacity(0.1), 
                            lineWidth: isNicknameFocused ? 1.5 : 1
                        )
                )
                .shadow(color: isNicknameFocused ? .teal.opacity(0.04) : .clear, radius: 4, x: 0, y: 2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.dewSurface)
                .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    // アバター選択の美しいカード
    private var avatarSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("アバター")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("水槽やプロフィールで表示されるアイコン")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                // 現在の選択を大きく浮かび上がらせる
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.12))
                        .frame(width: 54, height: 54)
                    
                    Text(avatarEmoji)
                        .font(.system(size: 32))
                }
                .shadow(color: .teal.opacity(0.15), radius: 8, x: 0, y: 3)
            }
            
            Divider()
                .padding(.vertical, 2)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(avatarOptions, id: \.self) { emoji in
                    Button {
                        avatarEmoji = emoji
                    } label: {
                        Text(emoji)
                            .font(.system(size: 26))
                            .frame(width: 44, height: 44)
                            .background(
                                ZStack {
                                    if avatarEmoji == emoji {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.teal.opacity(0.18))
                                            .shadow(color: .teal.opacity(0.1), radius: 4, x: 0, y: 2)
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                            .overlay {
                                if avatarEmoji == emoji {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.teal, lineWidth: 1.8)
                                }
                            }
                            .contentShape(Rectangle())
                            .background(Color.black.opacity(0.0001))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.dewSurface)
                .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    // ログイン中のアカウントステータスカード
    private var accountStatusCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.green)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("アカウント連携済み")
                        .font(.subheadline.weight(.semibold))
                    
                    if let user = authService.currentUser, let email = user.email {
                        Text(email)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            
            Divider()
            
            Button(role: .destructive) {
                showSignOutAlert = true
            } label: {
                HStack {
                    Spacer()
                    if authService.isProcessing {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Label("サインアウト", systemImage: "arrow.right.doc.on.clipboard")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    Spacer()
                }
                .frame(height: 48)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.red.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(authService.isProcessing)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.dewSurface)
                .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
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

    private func performSignOut() {
        Task {
            await authService.signOut()
            if authService.errorMessage == nil {
                await store.load()
                dismiss()
            }
        }
    }
}

#Preview {
    ProfileEditView()
        .environment(AppDataStore())
}
