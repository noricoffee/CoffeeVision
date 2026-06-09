import Foundation
import FirebaseFirestore
import SharedLogic

/// Kotlin の `Visit` ドメインモデル ↔ Firestore ドキュメント `[String: Any]` を変換するヘルパ。
///
/// ## 設計判断
///
/// - Kotlin の `data class` は Swift から見ると参照型クラスになり、
///   Firestore Swift SDK の `Codable` には乗せにくいため、**手書きマッピング** を採用
/// - 子コレクション（coffeeItems / foodItems / photos）も本ファイルにマッパを集約。
///   親 Visit ドキュメントには子要素を埋め込まず、サブコレクション側で個別ドキュメントとして保存する
/// - 日付: `LocalDate` (visitedOn) は ISO-8601 文字列、`Instant` (createdAt/updatedAt) は
///   Firestore `Timestamp` として保存（[`docs/data-model.md`](../../../docs/data-model.md) §6 準拠）
/// - enum（`BrewMethod` / `ProcessingMethod` / `RoastLevel`）は Kotlin の `name`
///   （例: `"HandDrip"`）を文字列として保存。decode 時は SKIE 生成 Swift enum の
///   `allCases` から逆引きする
/// - nullable フィールドは **キーごと省略**（Firestore の `null` 比較を避けるため）
/// - `sortOrder` はドメインモデルには存在しないため、upload 時に配列インデックスを採番。
///   decode 時は `sortOrder` でソート後に破棄してドメインモデルに戻す
/// - `Photo.localPath` は端末ごとの値なので Firestore には保存しない
///
/// SKIE 生成型名:
/// - `Visit` ドメイン → Swift 側で `Visit_`（末尾 `_` は Foundation との衝突回避）
/// - `Photo` ドメイン → Swift 側で `Photo_`（SQLDelight 生成 `Photo` 行型との衝突回避）
/// - `LocalDate` → `Kotlinx_datetimeLocalDate`
/// - `Instant` → `Kotlinx_datetimeInstant`
enum VisitFirestoreMapper {

    // MARK: - Visit (親ドキュメント)

    /// Visit を Firestore 親ドキュメント形式に変換する。
    /// 子コレクション（coffees / foods / photos）は含めない（サブコレクションで別途保存）。
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

    /// Firestore 親ドキュメントを Visit に変換する。
    /// 子配列は呼び出し側でサブコレクションから取得して埋める前提で、ここでは空配列を返す。
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

    // MARK: - CoffeeItem

    /// `CoffeeItem` を `coffeeItems/{id}` 用の Firestore document に変換する。
    /// `sortOrder` は呼び出し側で採番した index を渡す（ドメインモデルには持たせない方針）。
    static func toDocument(_ item: CoffeeItem, sortOrder: Int) -> [String: Any] {
        var dict: [String: Any] = [
            "id": item.id,
            "name": item.name,
            "brewMethod": item.brewMethod.name,
            "rating": Int(item.rating),
            "sortOrder": sortOrder,
        ]
        if let origin = item.origin { dict["origin"] = origin }
        if let variety = item.variety { dict["variety"] = variety }
        if let processing = item.processing { dict["processing"] = processing.name }
        if let roastLevel = item.roastLevel { dict["roastLevel"] = roastLevel.name }
        if let cup = item.cup { dict["cup"] = cup }
        if let notes = item.notes { dict["notes"] = notes }
        return dict
    }

    /// Firestore document を `CoffeeItem` + `sortOrder` のペアに変換する。
    /// `sortOrder` は呼び出し側で並べ替えに使用したあと破棄する。
    /// パース失敗時は nil を返す。
    static func coffeeItemFromDocument(_ data: [String: Any]) -> (item: CoffeeItem, sortOrder: Int)? {
        guard
            let id = data["id"] as? String,
            let name = data["name"] as? String,
            let brewMethodName = data["brewMethod"] as? String,
            let brewMethod = BrewMethod.allCases.first(where: { $0.name == brewMethodName }),
            let rating = (data["rating"] as? NSNumber)?.int32Value
        else {
            return nil
        }

        let processing: ProcessingMethod? = (data["processing"] as? String).flatMap { name in
            ProcessingMethod.allCases.first { $0.name == name }
        }
        let roastLevel: RoastLevel? = (data["roastLevel"] as? String).flatMap { name in
            RoastLevel.allCases.first { $0.name == name }
        }

        let sortOrder = (data["sortOrder"] as? NSNumber)?.intValue ?? 0

        let item = CoffeeItem(
            id: id,
            name: name,
            brewMethod: brewMethod,
            origin: data["origin"] as? String,
            variety: data["variety"] as? String,
            processing: processing,
            roastLevel: roastLevel,
            cup: data["cup"] as? String,
            rating: rating,
            notes: data["notes"] as? String
        )
        return (item, sortOrder)
    }

    // MARK: - FoodItem

    /// `FoodItem` を `foodItems/{id}` 用の Firestore document に変換する。
    static func toDocument(_ item: FoodItem, sortOrder: Int) -> [String: Any] {
        var dict: [String: Any] = [
            "id": item.id,
            "name": item.name,
            "rating": Int(item.rating),
            "sortOrder": sortOrder,
        ]
        if let notes = item.notes { dict["notes"] = notes }
        return dict
    }

    /// Firestore document を `FoodItem` + `sortOrder` のペアに変換する。
    static func foodItemFromDocument(_ data: [String: Any]) -> (item: FoodItem, sortOrder: Int)? {
        guard
            let id = data["id"] as? String,
            let name = data["name"] as? String,
            let rating = (data["rating"] as? NSNumber)?.int32Value
        else {
            return nil
        }
        let sortOrder = (data["sortOrder"] as? NSNumber)?.intValue ?? 0
        let item = FoodItem(
            id: id,
            name: name,
            rating: rating,
            notes: data["notes"] as? String
        )
        return (item, sortOrder)
    }

    // MARK: - Photo

    /// `Photo` を `photos/{id}` 用の Firestore document に変換する。
    /// `localPath` は端末固有値のため Firestore には保存しない。
    /// `fileName` は機種変・iCloud Backup 復元時に `localPath` を再構築できるよう Firestore にも保存する。
    /// Storage への写真本体 upload は採用見送りのため、`remoteUrl` は常に nil（フィールドは将来用に残置）。
    static func toDocument(_ photo: Photo_, sortOrder: Int) -> [String: Any] {
        let createdAtDate = Date(
            timeIntervalSince1970: TimeInterval(photo.createdAt.toEpochMilliseconds()) / 1000.0
        )
        var dict: [String: Any] = [
            "id": photo.id,
            "createdAt": Timestamp(date: createdAtDate),
            "sortOrder": sortOrder,
        ]
        if let fileName = photo.fileName { dict["fileName"] = fileName }
        if let remoteUrl = photo.remoteUrl { dict["remoteUrl"] = remoteUrl }
        if let width = photo.width { dict["width"] = width.intValue }
        if let height = photo.height { dict["height"] = height.intValue }
        return dict
    }

    /// Firestore document を `Photo` + `sortOrder` のペアに変換する。
    /// `localPath` は Firestore に存在しないので常に nil（端末側 DB のみが保持）。
    /// `fileName` は Firestore に保存されている場合に読み取る。
    static func photoFromDocument(_ data: [String: Any]) -> (photo: Photo_, sortOrder: Int)? {
        guard
            let id = data["id"] as? String,
            let createdAtTs = data["createdAt"] as? Timestamp
        else {
            return nil
        }

        let createdAt = Kotlinx_datetimeInstant.Companion.shared.fromEpochMilliseconds(
            epochMilliseconds: Int64(createdAtTs.dateValue().timeIntervalSince1970 * 1000)
        )

        let width = (data["width"] as? NSNumber).map { KotlinInt(value: $0.int32Value) }
        let height = (data["height"] as? NSNumber).map { KotlinInt(value: $0.int32Value) }

        let sortOrder = (data["sortOrder"] as? NSNumber)?.intValue ?? 0

        let photo = Photo_(
            id: id,
            fileName: data["fileName"] as? String,
            localPath: nil,
            remoteUrl: data["remoteUrl"] as? String,
            width: width,
            height: height,
            createdAt: createdAt
        )
        return (photo, sortOrder)
    }

    // MARK: - Helpers

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
