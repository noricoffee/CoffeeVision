import Foundation
import FirebaseFirestore
import SharedLogic

/// Kotlin の `Visit` ドメインモデル ↔ Firestore ドキュメント `[String: Any]` を変換するヘルパ。
///
/// ## 設計判断
///
/// - Kotlin の `data class` は Swift から見ると参照型クラスになり、
///   Firestore Swift SDK の `Codable` には乗せにくいため、**手書きマッピング** を採用
/// - 子コレクション（coffeeItems / foodItems / photos）の同期は本フェーズ外
///   （Phase 2 後半で別途実装）
/// - 日付: `LocalDate` (visitedOn) は ISO-8601 文字列、`Instant` (createdAt/updatedAt) は
///   Firestore `Timestamp` として保存（[`docs/data-model.md`](../../../docs/data-model.md) §6 準拠）
///
/// SKIE 生成型名:
/// - `Visit` ドメイン → Swift 側で `Visit_`（末尾 `_` は Foundation との衝突回避）
/// - `LocalDate` → `Kotlinx_datetimeLocalDate`
/// - `Instant` → `Kotlinx_datetimeInstant`
enum VisitFirestoreMapper {

    /// Visit を Firestore ドキュメント形式に変換する。
    /// 子コレクション（coffees / foods / photos）は含めない（別途サブコレクションで同期）。
    static func toDocument(_ visit: Visit_) -> [String: Any] {
        let cafe = visit.cafe
        var cafeDict: [String: Any] = [
            "placeId": cafe.placeId,
            "name": cafe.name,
            "photoReferences": cafe.photoReferences,
        ]
        if let address = cafe.address { cafeDict["address"] = address }
        if let latitude = cafe.latitude { cafeDict["latitude"] = latitude.doubleValue }
        if let longitude = cafe.longitude { cafeDict["longitude"] = longitude.doubleValue }
        if let websiteUrl = cafe.websiteUrl { cafeDict["websiteUrl"] = websiteUrl }
        if let mapsUrl = cafe.mapsUrl { cafeDict["mapsUrl"] = mapsUrl }

        let createdAtDate = Date(
            timeIntervalSince1970: TimeInterval(visit.createdAt.toEpochMilliseconds()) / 1000.0
        )
        let updatedAtDate = Date(
            timeIntervalSince1970: TimeInterval(visit.updatedAt.toEpochMilliseconds()) / 1000.0
        )

        return [
            "id": visit.id,
            "userId": visit.userId,
            "cafe": cafeDict,
            "visitedOn": visit.visitedOn.description(),
            "ambiance": visit.ambiance,
            "rating": Int(visit.rating),
            "notes": visit.notes,
            "createdAt": Timestamp(date: createdAtDate),
            "updatedAt": Timestamp(date: updatedAtDate),
        ]
    }

    /// Firestore ドキュメントを Visit に変換する。
    /// 子コレクションはこの時点では空配列。Phase 2 後半で別途同期。
    /// パース失敗時は nil を返す（呼び出し側でスキップ）。
    static func fromDocument(_ data: [String: Any]) -> Visit_? {
        guard
            let id = data["id"] as? String,
            let userId = data["userId"] as? String,
            let cafeDict = data["cafe"] as? [String: Any],
            let placeId = cafeDict["placeId"] as? String,
            let name = cafeDict["name"] as? String,
            let visitedOnStr = data["visitedOn"] as? String,
            let visitedOn = parseIsoLocalDate(visitedOnStr),
            let ambiance = data["ambiance"] as? String,
            let rating = (data["rating"] as? NSNumber)?.int32Value,
            let notes = data["notes"] as? String,
            let createdAtTs = data["createdAt"] as? Timestamp,
            let updatedAtTs = data["updatedAt"] as? Timestamp
        else {
            return nil
        }

        let photoReferences = (cafeDict["photoReferences"] as? [String]) ?? []

        let latitude = (cafeDict["latitude"] as? NSNumber)
            .map { KotlinDouble(value: $0.doubleValue) }
        let longitude = (cafeDict["longitude"] as? NSNumber)
            .map { KotlinDouble(value: $0.doubleValue) }

        let cafe = Cafe(
            placeId: placeId,
            name: name,
            address: cafeDict["address"] as? String,
            latitude: latitude,
            longitude: longitude,
            photoReferences: photoReferences,
            websiteUrl: cafeDict["websiteUrl"] as? String,
            mapsUrl: cafeDict["mapsUrl"] as? String
        )

        let createdAt = Kotlinx_datetimeInstant.Companion.shared.fromEpochMilliseconds(
            epochMilliseconds: Int64(createdAtTs.dateValue().timeIntervalSince1970 * 1000)
        )
        let updatedAt = Kotlinx_datetimeInstant.Companion.shared.fromEpochMilliseconds(
            epochMilliseconds: Int64(updatedAtTs.dateValue().timeIntervalSince1970 * 1000)
        )

        return Visit_(
            id: id,
            userId: userId,
            cafe: cafe,
            visitedOn: visitedOn,
            ambiance: ambiance,
            rating: rating,
            notes: notes,
            photos: [],
            coffees: [],
            foods: [],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// `YYYY-MM-DD` 形式の文字列を `Kotlinx_datetimeLocalDate` に変換する。
    /// LocalDate.Companion.parse は format 引数必須で扱いづらいため、手書きで分解する。
    private static func parseIsoLocalDate(_ str: String) -> Kotlinx_datetimeLocalDate? {
        let parts = str.split(separator: "-")
        guard parts.count == 3,
              let year = Int32(parts[0]),
              let month = Int32(parts[1]),
              let day = Int32(parts[2])
        else {
            return nil
        }
        return Kotlinx_datetimeLocalDate(year: year, monthNumber: month, dayOfMonth: day)
    }
}
