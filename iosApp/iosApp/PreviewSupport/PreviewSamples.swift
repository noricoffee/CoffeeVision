import Foundation
import SharedLogic

// MARK: - PreviewSamples

/// Preview 用ダミーデータの集約。
///
/// - すべてのメンバは `static let` で定義し、Preview の外から呼び出しを禁止しない
///   （`#if DEBUG` で囲むと Preview Canvas では見えるが Xcode ビルドで dead-code strip される）
/// - `CoffeeRecord` / `Photo_` は KMP 側の Kotlin ドメインモデルから
///   Swift に橋渡しされた型。コンストラクタシグネチャは `CoffeeFirestoreMapper.swift` と同じパターン
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

    // MARK: - Cafe（カフェ検索 Preview 用）

    /// Places API 検索結果のサンプルカフェ一覧（CafeSearchView の Preview 用）。
    static let sampleCafes: [Cafe] = [
        Cafe(
            placeId: "ChIJsampleBluBottle",
            name: "Blue Bottle 三軒茶屋",
            address: "東京都世田谷区太子堂4-1-22",
            latitude: KotlinDouble(value: 35.6448),
            longitude: KotlinDouble(value: 139.6694),
            photoReferences: [],
            websiteUrl: "https://bluebottlecoffee.jp/",
            mapsUrl: "https://maps.google.com/?cid=sample1",
            openNow: nil,
            weekdayDescriptions: [],
            phoneNumber: nil,
            priceLevel: nil,
            googleRating: nil
        ),
        Cafe(
            placeId: "ChIJsampleSteamers",
            name: "Streamer Coffee Company 原宿",
            address: "東京都渋谷区神宮前3-17-11",
            latitude: KotlinDouble(value: 35.6699),
            longitude: KotlinDouble(value: 139.7072),
            photoReferences: [],
            websiteUrl: nil,
            mapsUrl: "https://maps.google.com/?cid=sample2",
            openNow: nil,
            weekdayDescriptions: [],
            phoneNumber: nil,
            priceLevel: nil,
            googleRating: nil
        ),
        Cafe(
            placeId: "ChIJsampleFuglen",
            name: "Fuglen Tokyo",
            address: "東京都渋谷区富ヶ谷1-16-11",
            latitude: nil,
            longitude: nil,
            photoReferences: [],
            websiteUrl: "https://fuglencoffee.jp/",
            mapsUrl: nil,
            openNow: nil,
            weekdayDescriptions: [],
            phoneNumber: nil,
            priceLevel: nil,
            googleRating: nil
        ),
    ]

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

    // MARK: - CoffeeRecord（カフェあり）

    /// カフェあり・写真ありのサンプルコーヒー記録。
    static let sampleCoffeeRecord: CoffeeRecord = CoffeeRecord(
        id: "coffee-001",
        userId: "preview-user",
        cafe: Cafe(
            placeId: "ChIJsampleBluBottle",
            name: "Blue Bottle 三軒茶屋",
            address: "東京都世田谷区太子堂4-1-22",
            latitude: KotlinDouble(value: 35.6448),
            longitude: KotlinDouble(value: 139.6694),
            photoReferences: [],
            websiteUrl: "https://bluebottlecoffee.jp/",
            mapsUrl: "https://maps.google.com/?cid=sample",
            openNow: nil,
            weekdayDescriptions: [],
            phoneNumber: nil,
            priceLevel: nil,
            googleRating: nil
        ),
        visitedOn: localDate(year: 2026, month: 6, day: 2),
        rating: 4.5,
        notes: "ベリー系の華やかな酸味。落ち着いた木質の内装。店員さんが品種を丁寧に教えてくれた",
        photos: samplePhotos,
        name: "本日のコーヒー（ケニア カグモイニ）",
        brewMethod: .handDrip,
        origin: "ケニア",
        variety: "SL28",
        processing: .washed,
        roastLevel: .medium,
        cup: "ノリタケ",
        brewRecipe: "豆 15g / 湯 240ml / 92℃ / 2:30",
        tasting: TastingScores(
            sweetness: 7,
            body: 5,
            acidity: 9,
            flavor: 7,
            aftertaste: 6
        ),
        tags: ["浅煎り", "フルーティー"],
        createdAt: instant(year: 2026, month: 6, day: 2),
        updatedAt: instant(year: 2026, month: 6, day: 2)
    )

    /// カフェあり・写真なしのサンプルコーヒー記録。
    static let sampleCoffeeRecordWithoutPhotos: CoffeeRecord = CoffeeRecord(
        id: "coffee-002",
        userId: "preview-user",
        cafe: Cafe(
            placeId: "ChIJsampleSteamers",
            name: "Streamer Coffee Company 原宿",
            address: "東京都渋谷区神宮前3-17-11",
            latitude: KotlinDouble(value: 35.6699),
            longitude: KotlinDouble(value: 139.7072),
            photoReferences: [],
            websiteUrl: nil,
            mapsUrl: nil,
            openNow: nil,
            weekdayDescriptions: [],
            phoneNumber: nil,
            priceLevel: nil,
            googleRating: nil
        ),
        visitedOn: localDate(year: 2026, month: 5, day: 28),
        rating: 3.0,
        notes: "",
        photos: [],
        name: "エスプレッソ",
        brewMethod: .espresso,
        origin: "エチオピア",
        variety: nil,
        processing: .natural,
        roastLevel: .fullCity,
        cup: nil,
        brewRecipe: nil,
        tasting: nil,
        tags: [],
        createdAt: instant(year: 2026, month: 5, day: 28),
        updatedAt: instant(year: 2026, month: 5, day: 28)
    )

    /// セルフ抽出（cafe = null）のサンプルコーヒー記録。
    static let sampleCoffeeRecordSelfBrew: CoffeeRecord = CoffeeRecord(
        id: "coffee-003",
        userId: "preview-user",
        cafe: nil,
        visitedOn: localDate(year: 2026, month: 6, day: 19),
        rating: 5.0,
        notes: "豆の挽き方を変えたら格段に旨くなった",
        photos: [],
        name: "エチオピア イルガチェフェ",
        brewMethod: .handDrip,
        origin: "エチオピア",
        variety: "ゲイシャ",
        processing: .washed,
        roastLevel: .light,
        cup: nil,
        brewRecipe: "豆 18g / 湯 300ml / 88℃ / 3:00",
        tasting: TastingScores(
            sweetness: 8,
            body: 4,
            acidity: 7,
            flavor: 9,
            aftertaste: 6
        ),
        tags: ["セルフ抽出"],
        createdAt: instant(year: 2026, month: 6, day: 19),
        updatedAt: instant(year: 2026, month: 6, day: 19)
    )

    /// 複数 CoffeeRecord の配列（一覧 Preview 用）。
    static let sampleCoffeeRecords: [CoffeeRecord] = [
        sampleCoffeeRecord,
        sampleCoffeeRecordWithoutPhotos,
        sampleCoffeeRecordSelfBrew,
    ]

    // MARK: - RecommendedCafe（マップ Preview 用）

    /// 好み一致カフェのサンプル（マップ強調ピン Preview 用）。
    static let sampleRecommendedCafes: [RecommendedCafe] = [
        RecommendedCafe(
            cafe: Cafe(
                placeId: "ChIJsampleBluBottle",
                name: "Blue Bottle 三軒茶屋",
                address: "東京都世田谷区太子堂4-1-22",
                latitude: KotlinDouble(value: 35.6448),
                longitude: KotlinDouble(value: 139.6694),
                photoReferences: [],
                websiteUrl: "https://bluebottlecoffee.jp/",
                mapsUrl: "https://maps.google.com/?cid=sample1",
                openNow: nil,
                weekdayDescriptions: [],
                phoneNumber: nil,
                priceLevel: nil,
                googleRating: nil
            ),
            matches: [
                RecommendationReasonTasteProfileMatch(
                    axis: .origin,
                    matchedLabel: "エチオピア",
                    exampleRecordName: "本日のコーヒー（エチオピア イルガチェフェ）",
                    exampleRating: 4.5
                ),
                RecommendationReasonTasteProfileMatch(
                    axis: .roastLevel,
                    matchedLabel: "Light",
                    exampleRecordName: "シングルオリジン",
                    exampleRating: 4.0
                ),
            ]
        ),
    ]

    // MARK: - CoffeeStats（分析 Preview 用）

    /// 分析ビュー Preview 用のサンプル統計データ。
    ///
    /// 各セクション（ヒストグラム / 産地 / 焙煎度 / 抽出方法 / 月次推移 / よく行く店）が
    /// 非空であることを確認できるよう、複数パターンのデータを含める。
    static let sampleCoffeeStats: CoffeeStats = CoffeeStats(
        totalCount: 12,
        ratedCount: 10,
        averageRating: 4.1,
        ratingHistogram: [
            RatingBucket(rating: 3.0, count: 1),
            RatingBucket(rating: 3.5, count: 1),
            RatingBucket(rating: 4.0, count: 4),
            RatingBucket(rating: 4.5, count: 3),
            RatingBucket(rating: 5.0, count: 1),
        ],
        byBrewMethod: [
            CategoryStat(label: "HandDrip", count: 7, averageRating: 4.3),
            CategoryStat(label: "Espresso", count: 3, averageRating: 3.8),
            CategoryStat(label: "FrenchPress", count: 2, averageRating: 4.0),
        ],
        byRoastLevel: [
            CategoryStat(label: "Light", count: 5, averageRating: 4.4),
            CategoryStat(label: "Medium", count: 4, averageRating: 4.0),
            CategoryStat(label: "FullCity", count: 3, averageRating: 3.8),
        ],
        byProcessing: [
            CategoryStat(label: "Washed", count: 7, averageRating: 4.2),
            CategoryStat(label: "Natural", count: 4, averageRating: 4.0),
            CategoryStat(label: "Honey", count: 1, averageRating: 4.5),
        ],
        originRanking: [
            CategoryStat(label: "エチオピア", count: 5, averageRating: 4.4),
            CategoryStat(label: "ケニア", count: 3, averageRating: 4.2),
            CategoryStat(label: "コロンビア", count: 2, averageRating: 3.9),
            CategoryStat(label: "グアテマラ", count: 2, averageRating: 4.0),
        ],
        monthlyTrend: [
            MonthlyStat(yearMonth: "2026-04", count: 3, averageRating: 4.0),
            MonthlyStat(yearMonth: "2026-05", count: 4, averageRating: 4.1),
            MonthlyStat(yearMonth: "2026-06", count: 5, averageRating: 4.2),
        ],
        topCafes: [
            CafeStat(placeId: "ChIJsampleBluBottle", name: "Blue Bottle 三軒茶屋", count: 5, averageRating: 4.4),
            CafeStat(placeId: "ChIJsampleSteamers", name: "Streamer Coffee Company 原宿", count: 4, averageRating: 3.8),
            CafeStat(placeId: "ChIJsampleFuglen", name: "Fuglen Tokyo", count: 3, averageRating: 4.3),
        ],
        recentHighlights: [
            RecordDigest(
                name: "本日のコーヒー（ケニア カグモイニ）",
                rating: 4.5,
                cafeName: "Blue Bottle 三軒茶屋",
                visitedOn: localDate(year: 2026, month: 6, day: 19)
            ),
        ],
        favoriteSignals: FavoriteSignals(
            bestBrewMethod: CategoryStat(label: "HandDrip", count: 7, averageRating: KotlinDouble(value: 4.3)),
            bestOrigin: CategoryStat(label: "エチオピア", count: 5, averageRating: KotlinDouble(value: 4.4)),
            bestRoastLevel: CategoryStat(label: "Light", count: 5, averageRating: KotlinDouble(value: 4.4)),
            dominantTastingAxis: TastingAxisCorrelation(
                axis: TastingAxis.acidity,
                correlation: 0.62,
                sampleSize: 8
            ),
            minSampleSize: 3
        ),
        tastingAverages: TastingAverages(
            sweetness: KotlinDouble(value: 7.2),
            body: KotlinDouble(value: 5.1),
            acidity: KotlinDouble(value: 8.0),
            flavor: KotlinDouble(value: 7.5),
            aftertaste: KotlinDouble(value: 6.3),
            ratedCount: 8
        ),
        preferredBeanTraits: PreferredBeanTraits(
            matchedProfiles: [],
            dominantFlavorNotes: ["ベリー系", "フルーティー", "シトラス"],
            originHint: "エチオピア",
            roastLevelHint: "Light",
            dominantTastingAxis: TastingAxis.acidity
        ),
        unexploredBeanSuggestions: [
            UnexploredBeanSuggestion(
                profile: BeanProfile(
                    beanId: "sample-bean-1",
                    name: "イルガチェフェ コチェレ",
                    origin: "エチオピア",
                    variety: "Heirloom",
                    processings: [.washed],
                    flavorNotes: ["ジャスミン", "ベルガモット", "ハチミツ"],
                    description: nil
                ),
                matchedOriginLabel: "エチオピア"
            ),
            UnexploredBeanSuggestion(
                profile: BeanProfile(
                    beanId: "sample-bean-2",
                    name: "グジ ウラガ",
                    origin: "エチオピア",
                    variety: nil,
                    processings: [.natural],
                    flavorNotes: ["ベリー", "ワイン"],
                    description: nil
                ),
                matchedOriginLabel: "エチオピア"
            ),
        ]
    )
}
