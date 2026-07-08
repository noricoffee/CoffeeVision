import Foundation
import FirebaseFirestore
import SharedLogic

/// Kotlin の `CoffeeRecord` ドメインモデル ↔ Firestore ドキュメント `[String: Any]` を変換するヘルパ。
///
/// ## 設計判断
///
/// - Kotlin の `data class` は Swift から見ると参照型クラスになり、
///   Firestore Swift SDK の `Codable` には乗せにくいため、**手書きマッピング** を採用
/// - photos は埋め込み配列として 1 ドキュメントに格納（旧 visit サブコレクション方式を廃止）
/// - 日付: `LocalDate` (visitedOn) は ISO-8601 文字列、`Instant` (createdAt/updatedAt) は
///   Firestore `Timestamp` として保存（`docs/data-model.md` §6 準拠）
/// - enum（`BrewMethod` / `ProcessingMethod` / `RoastLevel`）は Kotlin の `name`
///   （例: `"HandDrip"`）を文字列として保存。decode 時は SKIE 生成 Swift enum の
///   `allCases` から逆引きする
/// - nullable フィールドは **キーごと省略**（Firestore の `null` 比較を避けるため）
/// - `sortOrder` はドメインモデルには存在しないため、photos upload 時に配列インデックスを採番。
///   decode 時は `sortOrder` でソート後に破棄してドメインモデルに戻す
/// - `Photo.localPath` / `Photo.remoteUrl` は Firestore には保存しない
///   (`localPath` は端末ごとの値、`remoteUrl` は Storage 採用見送り）
///
/// SKIE 生成型名:
/// - `CoffeeRecord` ドメイン → Swift 側で `CoffeeRecord`（SQLDelight 行型 `Coffee_record` と衝突しないためアンダースコアなし）
/// - `Photo` ドメイン → Swift 側で `Photo_`（SQLDelight 生成 `Photo` 行型との衝突回避）
/// - `LocalDate` → `Kotlinx_datetimeLocalDate`
/// - `Instant` → `Kotlinx_datetimeInstant`
enum CoffeeFirestoreMapper {

    // MARK: - CoffeeRecord

    /// `CoffeeRecord` を Firestore ドキュメント形式に変換する。
    ///
    /// - cafe が null の場合は `cafe` キーごと省略（セルフ抽出）
    /// - nullable なコーヒー属性（origin / variety / processing / roastLevel / cup / brewRecipe）は null 時キー省略
    /// - photos は埋め込み配列として書き出す
    static func toDocument(_ record: CoffeeRecord) -> [String: Any] {
        let createdAtDate = Date(
            timeIntervalSince1970: TimeInterval(record.createdAt.toEpochMilliseconds()) / 1000.0
        )
        let updatedAtDate = Date(
            timeIntervalSince1970: TimeInterval(record.updatedAt.toEpochMilliseconds()) / 1000.0
        )

        // photos を埋め込み配列に変換（localPath / remoteUrl は書かない）
        let photosArray: [[String: Any]] = record.photos
            .enumerated()
            .map { (index, photo) in
                toPhotoMap(photo, sortOrder: index)
            }

        var doc: [String: Any] = [
            "id": record.id,
            "userId": record.userId,
            "visitedOn": record.visitedOn.description(),
            "rating": record.rating,
            "notes": record.notes,
            "name": record.name,
            "brewMethod": record.brewMethod.name,
            "tags": record.tags,
            "photos": photosArray,
            "createdAt": Timestamp(date: createdAtDate),
            "updatedAt": Timestamp(date: updatedAtDate),
        ]

        // cafe は null 時キーごと省略
        if let cafe = record.cafe {
            doc["cafe"] = toCafeMap(cafe)
        }

        // nullable コーヒー属性は null 時キー省略
        if let origin = record.origin { doc["origin"] = origin }
        if let variety = record.variety { doc["variety"] = variety }
        if let processing = record.processing { doc["processing"] = processing.name }
        if let roastLevel = record.roastLevel { doc["roastLevel"] = roastLevel.name }
        if let cup = record.cup { doc["cup"] = cup }
        if let brewRecipe = record.brewRecipe { doc["brewRecipe"] = brewRecipe }

        // tasting: nil なら tasting キーを省略。非 nil なら 5 要素すべてのマップを書き出す
        if let tasting = record.tasting {
            doc["tasting"] = tastingToMap(tasting)
        }

        return doc
    }

    /// Firestore ドキュメントを `CoffeeRecord` に変換する。
    /// パース失敗時は nil を返す（呼び出し側でスキップ）。
    static func fromDocument(_ data: [String: Any]) -> CoffeeRecord? {
        guard
            let id = data["id"] as? String,
            let userId = data["userId"] as? String,
            let visitedOnStr = data["visitedOn"] as? String,
            let visitedOn = parseIsoLocalDate(visitedOnStr),
            let notes = data["notes"] as? String,
            let name = data["name"] as? String,
            let brewMethodName = data["brewMethod"] as? String,
            let brewMethod = BrewMethod.allCases.first(where: { $0.name == brewMethodName }),
            let createdAtTs = data["createdAt"] as? Timestamp,
            let updatedAtTs = data["updatedAt"] as? Timestamp
        else {
            return nil
        }

        // rating: Double として読む。旧形式（Int）との互換のため NSNumber 経由でも解釈する
        let rating: Double = (data["rating"] as? Double)
            ?? (data["rating"] as? NSNumber)?.doubleValue
            ?? 0.0

        // cafe は null 時 nil（セルフ抽出）
        let cafe: Cafe?
        if let cafeDict = data["cafe"] as? [String: Any] {
            cafe = cafeFromMap(cafeDict)
        } else {
            cafe = nil
        }

        // nullable コーヒー属性
        let processing: ProcessingMethod? = (data["processing"] as? String).flatMap { name in
            ProcessingMethod.allCases.first { $0.name == name }
        }
        let roastLevel: RoastLevel? = (data["roastLevel"] as? String).flatMap { name in
            RoastLevel.allCases.first { $0.name == name }
        }

        // photos 埋め込み配列の decode
        let photos: [Photo_]
        if let photosArray = data["photos"] as? [[String: Any]] {
            photos = photosArray
                .compactMap { photoFromMap($0) }
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { $0.photo }
        } else {
            photos = []
        }

        let createdAt = Kotlinx_datetimeInstant.Companion.shared.fromEpochMilliseconds(
            epochMilliseconds: Int64(createdAtTs.dateValue().timeIntervalSince1970 * 1000)
        )
        let updatedAt = Kotlinx_datetimeInstant.Companion.shared.fromEpochMilliseconds(
            epochMilliseconds: Int64(updatedAtTs.dateValue().timeIntervalSince1970 * 1000)
        )

        // tasting: マップが存在し 5 要素揃っていれば TastingScores。欠如 or 不完全なら nil（防御的）
        let tasting: TastingScores?
        if let tastingDict = data["tasting"] as? [String: Any] {
            tasting = tastingFromMap(tastingDict)
        } else {
            tasting = nil
        }

        return CoffeeRecord(
            id: id,
            userId: userId,
            cafe: cafe,
            visitedOn: visitedOn,
            rating: rating,
            notes: notes,
            photos: photos,
            name: name,
            brewMethod: brewMethod,
            origin: data["origin"] as? String,
            variety: data["variety"] as? String,
            processing: processing,
            roastLevel: roastLevel,
            cup: data["cup"] as? String,
            brewRecipe: data["brewRecipe"] as? String,
            tasting: tasting,
            tags: (data["tags"] as? [String]) ?? [],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Cafe Map

    /// カフェスナップショット 8 フィールドを Firestore マップに変換する。
    ///
    /// `coffees.cafe` / `savedCafes.cafe`（`SavedCafeFirestoreMapper`）の両方から共有する
    /// （`docs/data-model.md` §3.2 / §1.9 で同一の直列化規則と規定されているため）。
    static func toCafeMap(_ cafe: Cafe) -> [String: Any] {
        var dict: [String: Any] = [
            "placeId": cafe.placeId,
            "name": cafe.name,
            "photoReferences": cafe.photoReferences,
        ]
        if let address = cafe.address { dict["address"] = address }
        if let latitude = cafe.latitude { dict["latitude"] = latitude.doubleValue }
        if let longitude = cafe.longitude { dict["longitude"] = longitude.doubleValue }
        if let websiteUrl = cafe.websiteUrl { dict["websiteUrl"] = websiteUrl }
        if let mapsUrl = cafe.mapsUrl { dict["mapsUrl"] = mapsUrl }
        return dict
    }

    /// カフェスナップショット 8 フィールドを Firestore マップから復元する。`toCafeMap` の逆変換。
    static func cafeFromMap(_ dict: [String: Any]) -> Cafe? {
        guard
            let placeId = dict["placeId"] as? String,
            let name = dict["name"] as? String
        else {
            return nil
        }

        let photoReferences = (dict["photoReferences"] as? [String]) ?? []
        let latitude = (dict["latitude"] as? NSNumber)
            .map { KotlinDouble(value: $0.doubleValue) }
        let longitude = (dict["longitude"] as? NSNumber)
            .map { KotlinDouble(value: $0.doubleValue) }

        return Cafe(
            placeId: placeId,
            name: name,
            address: dict["address"] as? String,
            latitude: latitude,
            longitude: longitude,
            photoReferences: photoReferences,
            websiteUrl: dict["websiteUrl"] as? String,
            mapsUrl: dict["mapsUrl"] as? String,
            openNow: nil,
            weekdayDescriptions: [],
            phoneNumber: nil,
            priceLevel: nil,
            googleRating: nil,
            userRatingCount: nil
        )
    }

    // MARK: - Photo Map

    /// `Photo_` を photos 埋め込み配列の要素に変換する。
    /// `localPath` / `remoteUrl` は端末固有値 or Storage 採用見送りのため Firestore には書かない。
    private static func toPhotoMap(_ photo: Photo_, sortOrder: Int) -> [String: Any] {
        let createdAtDate = Date(
            timeIntervalSince1970: TimeInterval(photo.createdAt.toEpochMilliseconds()) / 1000.0
        )
        var dict: [String: Any] = [
            "id": photo.id,
            "createdAt": Timestamp(date: createdAtDate),
            "sortOrder": sortOrder,
        ]
        if let fileName = photo.fileName { dict["fileName"] = fileName }
        if let width = photo.width { dict["width"] = width.intValue }
        if let height = photo.height { dict["height"] = height.intValue }
        return dict
    }

    /// photos 埋め込み配列の要素を `Photo_` + `sortOrder` のペアに変換する。
    /// `localPath` は Firestore に存在しないので常に nil（端末側 DB のみが保持）。
    private static func photoFromMap(_ data: [String: Any]) -> (photo: Photo_, sortOrder: Int)? {
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
            remoteUrl: nil,
            width: width,
            height: height,
            createdAt: createdAt
        )
        return (photo, sortOrder)
    }

    // MARK: - Tasting Map

    /// `TastingScores`（all-or-nothing、5 要素すべて非 null）を Firestore マップに変換する。
    ///
    /// 5 要素すべてを書き出す。呼び出し元は `tasting != nil` のときだけ呼ぶこと。
    private static func tastingToMap(_ tasting: TastingScores) -> [String: Any] {
        return [
            "sweetness": Int(tasting.sweetness),
            "body": Int(tasting.body),
            "acidity": Int(tasting.acidity),
            "flavor": Int(tasting.flavor),
            "aftertaste": Int(tasting.aftertaste),
        ]
    }

    /// Firestore の `tasting` マップを `TastingScores?` に変換する。
    ///
    /// 5 要素すべて揃っていれば `TastingScores`、いずれかが欠如していれば `nil`（防御的）。
    private static func tastingFromMap(_ dict: [String: Any]) -> TastingScores? {
        func parseInt(_ key: String) -> Int32? {
            guard let n = dict[key] as? NSNumber else { return nil }
            return n.int32Value
        }
        guard
            let sweetness = parseInt("sweetness"),
            let body = parseInt("body"),
            let acidity = parseInt("acidity"),
            let flavor = parseInt("flavor"),
            let aftertaste = parseInt("aftertaste")
        else {
            return nil
        }
        return TastingScores(
            sweetness: sweetness,
            body: body,
            acidity: acidity,
            flavor: flavor,
            aftertaste: aftertaste
        )
    }

    // MARK: - Helpers

    /// `YYYY-MM-DD` 形式の文字列を `Kotlinx_datetimeLocalDate` に変換する。
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
