import Foundation
import SharedLogic

// MARK: - PreviewSamples

/// Preview 用ダミーデータの集約。
///
/// - すべてのメンバは `static let` で定義し、Preview の外から呼び出しを禁止しない
///   （`#if DEBUG` で囲むと Preview Canvas では見えるが Xcode ビルドで dead-code strip される）
/// - `Visit_` / `Photo_` / `CoffeeItem` / `FoodItem` は KMP 側の Kotlin ドメインモデルから
///   Swift に橋渡しされた型。コンストラクタシグネチャは `VisitFirestoreMapper.swift` と同じパターン
/// - Kotlin の `Kotlinx_datetimeInstant` は `Kotlinx_datetimeInstant.Companion.shared
///   .fromEpochMilliseconds(epochMilliseconds:)` で生成する
/// - Kotlin の `Kotlinx_datetimeLocalDate` は `Kotlinx_datetimeLocalDate(year:monthNumber:dayOfMonth:)` で生成する
enum PreviewSamples {

    // MARK: - 日時ヘルパ

    /// 指定した日付から `Kotlinx_datetimeInstant` を生成する（時刻は 09:00 JST 固定）。
    static func instant(year: Int, month: Int, day: Int) -> Kotlinx_datetimeInstant {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 9
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let date = Calendar(identifier: .gregorian).date(from: components) ?? Date()
        let epochMillis = Int64(date.timeIntervalSince1970 * 1000)
        return Kotlinx_datetimeInstant.Companion.shared.fromEpochMilliseconds(
            epochMilliseconds: epochMillis
        )
    }

    /// 指定した日付から `Kotlinx_datetimeLocalDate` を生成する。
    static func localDate(year: Int, month: Int, day: Int) -> Kotlinx_datetimeLocalDate {
        Kotlinx_datetimeLocalDate(
            year: Int32(year),
            monthNumber: Int32(month),
            dayOfMonth: Int32(day)
        )
    }

    // MARK: - Photo

    static let samplePhotos: [Photo_] = [
        Photo_(
            id: "photo-001",
            fileName: "photo-001.jpg",
            localPath: "photos/photo-001.jpg",
            remoteUrl: nil,
            width: KotlinInt(value: 1920),
            height: KotlinInt(value: 1440),
            createdAt: instant(year: 2026, month: 6, day: 2)
        ),
        Photo_(
            id: "photo-002",
            fileName: "photo-002.jpg",
            localPath: "photos/photo-002.jpg",
            remoteUrl: nil,
            width: KotlinInt(value: 1280),
            height: KotlinInt(value: 960),
            createdAt: instant(year: 2026, month: 6, day: 2)
        ),
        Photo_(
            id: "photo-003",
            fileName: nil,
            localPath: nil,
            remoteUrl: nil,
            width: nil,
            height: nil,
            createdAt: instant(year: 2026, month: 6, day: 2)
        ),
    ]

    // MARK: - CoffeeItem

    static let sampleCoffeeItems: [CoffeeItem] = [
        CoffeeItem(
            id: "coffee-001",
            name: "本日のコーヒー（ケニア カグモイニ）",
            brewMethod: .handDrip,
            origin: "ケニア",
            variety: "SL28",
            processing: .washed,
            roastLevel: .medium,
            cup: "ノリタケ",
            rating: 5,
            notes: "ベリー系の華やかな酸味"
        ),
        CoffeeItem(
            id: "coffee-002",
            name: "エスプレッソ",
            brewMethod: .espresso,
            origin: "エチオピア",
            variety: nil,
            processing: .natural,
            roastLevel: .fullCity,
            cup: nil,
            rating: 4,
            notes: "チョコレートのような余韻"
        ),
        CoffeeItem(
            id: "coffee-003",
            name: "アイスコーヒー",
            brewMethod: .coldBrew,
            origin: nil,
            variety: nil,
            processing: nil,
            roastLevel: .city,
            cup: nil,
            rating: 3,
            notes: nil
        ),
    ]

    // MARK: - FoodItem

    static let sampleFoodItems: [FoodItem] = [
        FoodItem(
            id: "food-001",
            name: "バナナブレッド",
            rating: 4,
            notes: nil
        ),
        FoodItem(
            id: "food-002",
            name: "スコーン",
            rating: 5,
            notes: "クロテッドクリームとの相性が抜群"
        ),
        FoodItem(
            id: "food-003",
            name: "チョコレートクッキー",
            rating: 3,
            notes: nil
        ),
    ]

    // MARK: - Visit（フル）

    /// コーヒー・フード・写真をすべて持つサンプル訪問記録。
    static let sampleVisit: Visit_ = Visit_(
        id: "visit-001",
        userId: "preview-user",
        cafe: Cafe(
            placeId: "ChIJsampleBluBottle",
            name: "Blue Bottle 三軒茶屋",
            address: "東京都世田谷区太子堂4-1-22",
            latitude: KotlinDouble(value: 35.6448),
            longitude: KotlinDouble(value: 139.6694),
            photoReferences: [],
            websiteUrl: "https://bluebottlecoffee.jp/",
            mapsUrl: "https://maps.google.com/?cid=sample"
        ),
        visitedOn: localDate(year: 2026, month: 6, day: 2),
        ambiance: "落ち着いた木質の内装、奥に大きな焙煎機",
        rating: 4,
        notes: "店員さんが品種を丁寧に教えてくれた",
        photos: samplePhotos,
        coffees: sampleCoffeeItems,
        foods: sampleFoodItems,
        createdAt: instant(year: 2026, month: 6, day: 2),
        updatedAt: instant(year: 2026, month: 6, day: 2)
    )

    /// 写真なし・コーヒーのみのサンプル訪問記録。
    static let sampleVisitWithoutPhotos: Visit_ = Visit_(
        id: "visit-002",
        userId: "preview-user",
        cafe: Cafe(
            placeId: "ChIJsampleSteamers",
            name: "Streamer Coffee Company 原宿",
            address: "東京都渋谷区神宮前3-17-11",
            latitude: KotlinDouble(value: 35.6699),
            longitude: KotlinDouble(value: 139.7072),
            photoReferences: [],
            websiteUrl: nil,
            mapsUrl: nil
        ),
        visitedOn: localDate(year: 2026, month: 5, day: 28),
        ambiance: "カウンターがメインの開放的な空間",
        rating: 3,
        notes: "",
        photos: [],
        coffees: [sampleCoffeeItems[1]],
        foods: [],
        createdAt: instant(year: 2026, month: 5, day: 28),
        updatedAt: instant(year: 2026, month: 5, day: 28)
    )

    /// 最小構成（サブアイテムゼロ）のサンプル訪問記録。
    static let sampleVisitMinimal: Visit_ = Visit_(
        id: "visit-003",
        userId: "preview-user",
        cafe: Cafe(
            placeId: "ChIJsampleFuglen",
            name: "Fuglen Tokyo",
            address: "東京都渋谷区富ヶ谷1-16-11",
            latitude: nil,
            longitude: nil,
            photoReferences: [],
            websiteUrl: nil,
            mapsUrl: nil
        ),
        visitedOn: localDate(year: 2026, month: 5, day: 15),
        ambiance: "",
        rating: 5,
        notes: "",
        photos: [],
        coffees: [],
        foods: [],
        createdAt: instant(year: 2026, month: 5, day: 15),
        updatedAt: instant(year: 2026, month: 5, day: 15)
    )

    /// 複数 Visit の配列（一覧 Preview 用）。
    static let sampleVisits: [Visit_] = [
        sampleVisit,
        sampleVisitWithoutPhotos,
        sampleVisitMinimal,
    ]
}
