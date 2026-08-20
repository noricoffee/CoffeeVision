import Foundation
import FirebaseFirestore
import SharedLogic

/// Kotlin の `SavedCafe` ドメインモデル ↔ Firestore ドキュメント `[String: Any]` を変換するヘルパ。
///
/// ## 設計判断
///
/// - `CoffeeFirestoreMapper` と同じ手書きマッピング方針を踏襲する（`docs/data-model.md` §3.2 参照）
/// - `cafe` マップは `coffees.cafe` と同一のスナップショット（`docs/data-model.md` §1.2 の永続フィールドのみ）・直列化規則のため、
///   `CoffeeFirestoreMapper.toCafeMap` / `cafeFromMap` をそのまま再利用する（重複実装を避ける）
/// - ドキュメント ID = `cafe.placeId`（`userId` はドキュメント自体には保存しない。
///   親コレクションパス `users/{uid}/savedCafes/{placeId}` から復元する）
/// - `savedAt` は Firestore `Timestamp`（`docs/data-model.md` §6 準拠）
///
/// `nonisolated` である理由は `CoffeeFirestoreMapper` と同じ（SW6-2）。
nonisolated enum SavedCafeFirestoreMapper {

    // MARK: - SavedCafe

    /// `SavedCafe` を Firestore ドキュメント形式に変換する。
    static func toDocument(_ savedCafe: SavedCafe) -> [String: Any] {
        let savedAtDate = Date(
            timeIntervalSince1970: TimeInterval(savedCafe.savedAt.toEpochMilliseconds()) / 1000.0
        )
        return [
            "cafe": CoffeeFirestoreMapper.toCafeMap(savedCafe.cafe),
            "note": savedCafe.note,
            "savedAt": Timestamp(date: savedAtDate),
        ]
    }

    /// Firestore ドキュメントを `SavedCafe` に変換する。
    ///
    /// - Parameter userId: ドキュメント自体には保存されていないため、呼び出し元（購読中のコレクションパス）から渡す
    /// - パース失敗時は nil を返す（呼び出し側でスキップ）
    static func fromDocument(_ data: [String: Any], userId: String) -> SavedCafe? {
        guard
            let cafeDict = data["cafe"] as? [String: Any],
            let cafe = CoffeeFirestoreMapper.cafeFromMap(cafeDict),
            let note = data["note"] as? String,
            let savedAtTs = data["savedAt"] as? Timestamp
        else {
            return nil
        }

        let savedAt = Kotlinx_datetimeInstant.Companion.shared.fromEpochMilliseconds(
            epochMilliseconds: Int64(savedAtTs.dateValue().timeIntervalSince1970 * 1000)
        )

        return SavedCafe(
            userId: userId,
            cafe: cafe,
            note: note,
            savedAt: savedAt
        )
    }
}
