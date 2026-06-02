import SwiftUI

struct ProfileEditView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var avatarEmoji = "🐟"

    /// アバター候補。魚種の絵文字 + 一般的な顔・生き物を並べる。
    private let avatarOptions: [String] = {
        let fish = FishSpecies.allCases.map(\.emoji)
        let extras = ["😀", "🧑", "👧", "👦", "🌊", "💧", "🌱", "⭐️"]
        return fish + extras
    }()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        NavigationStack {
            Form {
                Section("ニックネーム") {
                    TextField("例: みずやり名人", text: $nickname)
                }

                Section("アバター") {
                    HStack {
                        Text("現在の選択")
                        Spacer()
                        Text(avatarEmoji).font(.system(size: 36))
                    }

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(avatarOptions, id: \.self) { emoji in
                            Button {
                                avatarEmoji = emoji
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 26))
                                    .frame(width: 42, height: 42)
                                    .background(
                                        avatarEmoji == emoji ? Color.teal.opacity(0.22) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .overlay {
                                        if avatarEmoji == emoji {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(Color.teal, lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await store.updateProfile(nickname: nickname, avatarEmoji: avatarEmoji) }
                        dismiss()
                    }
                }
            }
            .onAppear {
                let profile = store.profile()
                nickname = profile.nickname
                avatarEmoji = profile.avatarEmoji
            }
        }
    }
}

#Preview {
    ProfileEditView()
        .environment(AppDataStore())
}
