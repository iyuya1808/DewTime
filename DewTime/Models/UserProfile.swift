import Foundation
import Observation

/// ユーザー本人のプロフィール。
///
/// 表示名・アバター絵文字・利用開始日を保持する。アプリ内で 1 レコードのみ存在する想定
/// （初回アクセス時に `AppDataStore.profile()` が lazy 生成する）。`Aquarium` と同じ単一
/// レコード方針で Firestore に永続化する。
@Observable
final class UserProfile: Identifiable {
    var id: UUID
    /// 表示名（ニックネーム）。
    var nickname: String
    /// アバターとして表示する絵文字。
    var avatarEmoji: String
    /// アプリを使い始めた日（「◯日目」の起点）。
    var createdAt: Date

    init(
        id: UUID = UUID(),
        nickname: String = "あなた",
        avatarEmoji: String = "🐟",
        createdAt: Date = .now
    ) {
        self.id = id
        self.nickname = nickname
        self.avatarEmoji = avatarEmoji
        self.createdAt = createdAt
    }

    /// 利用開始からの経過日数（1 始まり。初日を「1日目」とする）。
    var daysSinceStart: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: createdAt)
        let today = calendar.startOfDay(for: .now)
        let diff = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return max(1, diff + 1)
    }
}
