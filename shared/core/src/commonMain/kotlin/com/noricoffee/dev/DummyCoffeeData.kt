package com.noricoffee.dev

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.TastingScores
import kotlinx.datetime.Clock
import kotlinx.datetime.DatePeriod
import kotlinx.datetime.TimeZone
import kotlinx.datetime.minus
import kotlinx.datetime.todayIn

/**
 * 開発・デバッグ用のダミー [CoffeeRecord] データ生成ユーティリティ。
 *
 * - **固定 ID**: `dummy-0001`..`dummy-0030`（ゼロ埋め 4 桁）
 * - **冪等**: `AppContainer.seedDummyData` が upsert で呼ぶため、何度実行しても 30 件のまま
 * - **LocalDB 限定**: Firestore には流さない（dev データで本番を汚染しない）
 * - **DEBUG 専用**: iOS 側 Scheme の環境変数 `SEED_DUMMY_DATA=1` で起動した場合のみ使用する
 *
 * ## データの幅（分析タブの全グラフが映えるよう分散）
 *
 * - 産地: Ethiopia / Kenya / Colombia / Guatemala / Brazil / Costa Rica / Panama /
 *         Indonesia / Rwanda / Honduras を複数回登場させる
 * - 抽出方法: [BrewMethod] 全 8 enum を分散
 * - 焙煎度: [RoastLevel] 全 8 enum + null 数件
 * - 精製方法: [ProcessingMethod] 全 5 enum + null 数件
 * - 評価: 3.0〜5.0 中心（0.5 刻み）+ 0.0（未評価）を 2 件混入
 * - 日付: 今日から逆算して直近 12 ヶ月に分散
 * - カフェ: 約 2/3 に固定ダミーカフェ（5 件）を割り当て / 約 1/3 は cafe = null（セルフ抽出）
 */
object DummyCoffeeData {

    /** ダミーレコードの全 ID リスト。[clearDummyData] で削除対象を列挙するために公開する。 */
    val ids: List<String> = (1..30).map { i -> "dummy-" + i.toString().padStart(4, '0') }

    /** [userId] を埋め込んだ 30 件のダミー [CoffeeRecord] を生成して返す。 */
    fun records(userId: String): List<CoffeeRecord> {
        val today = Clock.System.todayIn(TimeZone.currentSystemDefault())
        val now = Clock.System.now()

        return rawData.mapIndexed { index, raw ->
            val daysAgo = (index * 12) + (index % 7)  // 約 12 日ごと + 7 の剰余でずらし
            val visitedOn = today.minus(DatePeriod(days = daysAgo))
            CoffeeRecord(
                id = ids[index],
                userId = userId,
                cafe = raw.cafe,
                visitedOn = visitedOn,
                rating = raw.rating,
                notes = raw.notes,
                photos = emptyList(),
                name = raw.name,
                brewMethod = raw.brewMethod,
                origin = raw.origin,
                variety = raw.variety,
                processing = raw.processing,
                roastLevel = raw.roastLevel,
                cup = raw.cup,
                tasting = raw.tasting,
                createdAt = now,
                updatedAt = now,
            )
        }
    }

    // ---- ダミーカフェ（同一カフェを複数レコードに使い回し、topCafes が出るよう設計）----

    private val cafe1 = Cafe(
        placeId = "dummy-place-001",
        name = "ブルーボトルコーヒー 三軒茶屋",
        address = "東京都世田谷区三軒茶屋1-32-14",
        latitude = 35.6434,
        longitude = 139.6706,
        photoReferences = emptyList(),
        websiteUrl = null,
        mapsUrl = null,
    )
    private val cafe2 = Cafe(
        placeId = "dummy-place-002",
        name = "コーヒーファクトリー 渋谷",
        address = "東京都渋谷区道玄坂1-19-9",
        latitude = 35.6586,
        longitude = 139.7013,
        photoReferences = emptyList(),
        websiteUrl = null,
        mapsUrl = null,
    )
    private val cafe3 = Cafe(
        placeId = "dummy-place-003",
        name = "アラビカ 京都東山",
        address = "京都府京都市東山区星野町87-5",
        latitude = 34.9981,
        longitude = 135.7792,
        photoReferences = emptyList(),
        websiteUrl = null,
        mapsUrl = null,
    )
    private val cafe4 = Cafe(
        placeId = "dummy-place-004",
        name = "フグレン 東京",
        address = "東京都渋谷区富ヶ谷1-16-11",
        latitude = 35.6714,
        longitude = 139.6921,
        photoReferences = emptyList(),
        websiteUrl = null,
        mapsUrl = null,
    )
    private val cafe5 = Cafe(
        placeId = "dummy-place-005",
        name = "ナガラコーヒー 吉祥寺",
        address = "東京都武蔵野市吉祥寺南町2-19-3",
        latitude = 35.7021,
        longitude = 139.5792,
        photoReferences = emptyList(),
        websiteUrl = null,
        mapsUrl = null,
    )

    // ---- 生データ（visitedOn / userId / photos / id は records() で動的設定）----

    private data class RawData(
        val name: String,
        val cafe: Cafe?,
        val rating: Double,
        val notes: String,
        val brewMethod: BrewMethod,
        val origin: String?,
        val variety: String?,
        val processing: ProcessingMethod?,
        val roastLevel: RoastLevel?,
        val cup: String?,
        val tasting: TastingScores? = null,  // all-or-nothing: 5 要素セット or null
    )

    private val rawData: List<RawData> = listOf(
        // 001: Ethiopia / HandDrip / Light / cafe1 — 全要素設定
        RawData(
            name = "エチオピア イルガチェフェ G1",
            cafe = cafe1,
            rating = 4.5,
            notes = "ジャスミンのような花の香りと明るいベリー系の酸味。余韻が長い。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Ethiopia",
            variety = "Heirloom",
            processing = ProcessingMethod.Natural,
            roastLevel = RoastLevel.Light,
            cup = null,
            tasting = TastingScores(sweetness = 8, body = 4, acidity = 9, flavor = 9, aftertaste = 8),
        ),
        // 002: Kenya / Espresso / Medium / cafe2 — 全要素設定
        RawData(
            name = "ケニア カグモイニ AA",
            cafe = cafe2,
            rating = 4.0,
            notes = "ブラックカラントの凝縮感と力強い酸。エスプレッソでも個性が際立つ。",
            brewMethod = BrewMethod.Espresso,
            origin = "Kenya",
            variety = "SL28",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = null,
            tasting = TastingScores(sweetness = 5, body = 7, acidity = 8, flavor = 7, aftertaste = 6),
        ),
        // 003: Colombia / HandDrip / City / null(セルフ抽出) — tasting あり（5 要素）
        RawData(
            name = "コロンビア ウイラ ウォッシュド",
            cafe = null,
            rating = 3.5,
            notes = "マイルドなチョコレート感。ガトーショコラを思わせる丸さ。自宅抽出。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Colombia",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.City,
            cup = null,
            tasting = TastingScores(sweetness = 7, body = 8, acidity = 4, flavor = 6, aftertaste = 5),
        ),
        // 004: Guatemala / FrenchPress / FullCity / cafe3 — 全要素設定
        RawData(
            name = "グアテマラ アンティグア SHB",
            cafe = cafe3,
            rating = 4.5,
            notes = "ブラウンシュガーとスモーキーなコク。フレンチプレスの油脂感と相性抜群。",
            brewMethod = BrewMethod.FrenchPress,
            origin = "Guatemala",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.FullCity,
            cup = "波佐見焼",
            tasting = TastingScores(sweetness = 6, body = 9, acidity = 4, flavor = 7, aftertaste = 7),
        ),
        // 005: Brazil / Espresso / French / cafe4 — tasting 未設定（全 null）
        RawData(
            name = "ブラジル セラード ナチュラル",
            cafe = cafe4,
            rating = 3.0,
            notes = "ナッツとチョコレートの王道ブラジル。エスプレッソのベースに最適。",
            brewMethod = BrewMethod.Espresso,
            origin = "Brazil",
            variety = "Yellow Bourbon",
            processing = ProcessingMethod.Natural,
            roastLevel = RoastLevel.French,
            cup = null,
        ),
        // 006: Ethiopia / AeroPress / Cinnamon / cafe1 — 全要素設定（高評価）
        RawData(
            name = "エチオピア グジ ハニー",
            cafe = cafe1,
            rating = 5.0,
            notes = "ピーチとアプリコットの甘い香り。シナモンローストでフルーツ感が全開。これは最高傑作。",
            brewMethod = BrewMethod.AeroPress,
            origin = "Ethiopia",
            variety = "Heirloom",
            processing = ProcessingMethod.Honey,
            roastLevel = RoastLevel.Cinnamon,
            cup = null,
            tasting = TastingScores(sweetness = 9, body = 5, acidity = 7, flavor = 10, aftertaste = 9),
        ),
        // 007: Costa Rica / NelDrip / Light / cafe5 — tasting あり（5 要素）
        RawData(
            name = "コスタリカ タラス ホワイトハニー",
            cafe = cafe5,
            rating = 4.0,
            notes = "柔らかな甘さとシルキーな口当たり。ネルドリップの丸みと好相性。",
            brewMethod = BrewMethod.NelDrip,
            origin = "Costa Rica",
            variety = null,
            processing = ProcessingMethod.Honey,
            roastLevel = RoastLevel.Light,
            cup = null,
            tasting = TastingScores(sweetness = 7, body = 5, acidity = 5, flavor = 8, aftertaste = 7),
        ),
        // 008: Panama / HandDrip / Light / null(セルフ抽出) — 全要素設定（高評価）
        RawData(
            name = "パナマ ゲイシャ ボケテ",
            cafe = null,
            rating = 5.0,
            notes = "ベルガモットとジャスミンの芳香。まるでティーのように繊細。自宅抽出だが最高品質。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Panama",
            variety = "Geisha",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Light,
            cup = "ノリタケ",
            tasting = TastingScores(sweetness = 7, body = 3, acidity = 6, flavor = 10, aftertaste = 9),
        ),
        // 009: Indonesia / Syphon / High / cafe2 — tasting 未設定（全 null）
        RawData(
            name = "インドネシア マンデリン G1",
            cafe = cafe2,
            rating = 3.5,
            notes = "アーシーなコクと独特のハーブ感。ゆっくり飲むほど深みが増す。",
            brewMethod = BrewMethod.Syphon,
            origin = "Indonesia",
            variety = null,
            processing = ProcessingMethod.Other,
            roastLevel = RoastLevel.High,
            cup = null,
        ),
        // 010: Rwanda / ColdBrew / Medium / cafe3 — 全要素設定
        RawData(
            name = "ルワンダ ニャマシェケ ウォッシュド",
            cafe = cafe3,
            rating = 4.0,
            notes = "ストーンフルーツとブラックティー。コールドブリューで甘さが際立つ。",
            brewMethod = BrewMethod.ColdBrew,
            origin = "Rwanda",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = null,
            tasting = TastingScores(sweetness = 8, body = 6, acidity = 5, flavor = 7, aftertaste = 6),
        ),
        // 011: Honduras / HandDrip / City / cafe4 — tasting null
        RawData(
            name = "ホンジュラス サンタバルバラ SHG",
            cafe = cafe4,
            rating = 3.5,
            notes = "バランスよくマイルド。初めてコーヒーを飲む人にも勧めやすい味わい。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Honduras",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.City,
            cup = null,
        ),
        // 012: Kenya / HandDrip / Light / cafe5 — 全要素設定
        RawData(
            name = "ケニア キリニャガ ウォッシュド",
            cafe = cafe5,
            rating = 4.5,
            notes = "グレープフルーツとレッドカラント。ケニアらしい明快な酸が気持ちいい。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Kenya",
            variety = "Batian",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Light,
            cup = null,
            tasting = TastingScores(sweetness = 6, body = 5, acidity = 9, flavor = 8, aftertaste = 7),
        ),
        // 013: Ethiopia / Espresso / Medium / cafe1 — 未評価（sentinel 0.0）、tasting 未設定
        RawData(
            name = "エチオピア シダマ ナチュラル",
            cafe = cafe1,
            rating = 0.0,
            notes = "まだメモが書けていない。いつか振り返ろう。",
            brewMethod = BrewMethod.Espresso,
            origin = "Ethiopia",
            variety = null,
            processing = ProcessingMethod.Natural,
            roastLevel = RoastLevel.Medium,
            cup = null,
        ),
        // 014: Colombia / AeroPress / Cinnamon / null(セルフ抽出) — 全要素設定
        RawData(
            name = "コロンビア エルパライソ アナエロビック",
            cafe = null,
            rating = 4.5,
            notes = "アナエロビック特有の濃密なトロピカルフレーバー。桃とパイナップル。",
            brewMethod = BrewMethod.AeroPress,
            origin = "Colombia",
            variety = "Castillo",
            processing = ProcessingMethod.Anaerobic,
            roastLevel = RoastLevel.Cinnamon,
            cup = null,
            tasting = TastingScores(sweetness = 9, body = 6, acidity = 6, flavor = 9, aftertaste = 8),
        ),
        // 015: Brazil / HandDrip / FullCity / cafe2 — tasting 未設定（全 null）
        RawData(
            name = "ブラジル カーモデミナス ボルボン",
            cafe = cafe2,
            rating = 3.0,
            notes = "ヘーゼルナッツとダークチョコ。あと味にほのかな苦味が残る。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Brazil",
            variety = "Bourbon",
            processing = ProcessingMethod.Natural,
            roastLevel = RoastLevel.FullCity,
            cup = null,
        ),
        // 016: Guatemala / NelDrip / High / cafe3 — 全要素設定
        RawData(
            name = "グアテマラ フエゴ ブラックハニー",
            cafe = cafe3,
            rating = 4.0,
            notes = "ドライフルーツとバタースコッチ。ネルドリップの甘みが引き立てる。",
            brewMethod = BrewMethod.NelDrip,
            origin = "Guatemala",
            variety = null,
            processing = ProcessingMethod.Honey,
            roastLevel = RoastLevel.High,
            cup = "有田焼",
            tasting = TastingScores(sweetness = 7, body = 8, acidity = 4, flavor = 7, aftertaste = 6),
        ),
        // 017: Costa Rica / FrenchPress / Italian / cafe1 — tasting あり（5 要素）
        RawData(
            name = "コスタリカ ブルマス デル スルコ",
            cafe = cafe1,
            rating = 3.5,
            notes = "フレンチローストの強い苦味とロースト感。深煎り好きには満足。",
            brewMethod = BrewMethod.FrenchPress,
            origin = "Costa Rica",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Italian,
            cup = null,
            tasting = TastingScores(sweetness = 4, body = 9, acidity = 3, flavor = 5, aftertaste = 4),
        ),
        // 018: Rwanda / HandDrip / null(roast) / null(cafe=セルフ) — tasting 未設定（全 null）
        RawData(
            name = "ルワンダ カロンビ ナチュラル",
            cafe = null,
            rating = 4.0,
            notes = "ワイン的な発酵感とダークベリー。焙煎度表示なしのロット。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Rwanda",
            variety = null,
            processing = ProcessingMethod.Natural,
            roastLevel = null,
            cup = null,
        ),
        // 019: Indonesia / HandDrip / City / cafe4 — 全要素設定
        RawData(
            name = "インドネシア アチェ ゲイシャ",
            cafe = cafe4,
            rating = 4.5,
            notes = "インドネシアのテロワールにゲイシャの繊細さが融合。甘さと余韻が長い。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Indonesia",
            variety = "Geisha",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.City,
            cup = null,
            tasting = TastingScores(sweetness = 7, body = 7, acidity = 5, flavor = 8, aftertaste = 9),
        ),
        // 020: Kenya / ColdBrew / Medium / null(cafe=セルフ) — tasting null
        RawData(
            name = "ケニア ルイル11 コールドブリュー",
            cafe = null,
            rating = 3.5,
            notes = "12時間水出し。ブラックカラントが冷えると甘みとして広がる。",
            brewMethod = BrewMethod.ColdBrew,
            origin = "Kenya",
            variety = "Ruiru 11",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = null,
        ),
        // 021: Panama / Syphon / Light / cafe5 — 全要素設定（最高評価）
        RawData(
            name = "パナマ エスメラルダ ゲイシャ",
            cafe = cafe5,
            rating = 5.0,
            notes = "ティーライクでフローラル。サイフォンでの昇華が絶妙。記録に残しておくべき一杯。",
            brewMethod = BrewMethod.Syphon,
            origin = "Panama",
            variety = "Geisha",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Light,
            cup = "ウェッジウッド",
            tasting = TastingScores(sweetness = 8, body = 4, acidity = 6, flavor = 10, aftertaste = 10),
        ),
        // 022: Ethiopia / HandDrip / null(roast) / cafe2 — 全要素設定
        RawData(
            name = "エチオピア コンガ ナチュラル",
            cafe = cafe2,
            rating = 4.0,
            notes = "ブルーベリーとシトラス。焙煎度不明ロットだが口当たりは浅煎り系。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Ethiopia",
            variety = null,
            processing = ProcessingMethod.Natural,
            roastLevel = null,
            cup = null,
            tasting = TastingScores(sweetness = 7, body = 4, acidity = 8, flavor = 8, aftertaste = 7),
        ),
        // 023: Honduras / Espresso / FullCity / cafe3 — tasting 未設定（全 null）
        RawData(
            name = "ホンジュラス ラス ラハス",
            cafe = cafe3,
            rating = 3.0,
            notes = "クリーンでバランス型。エスプレッソのアフターテイストが心地よい。",
            brewMethod = BrewMethod.Espresso,
            origin = "Honduras",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.FullCity,
            cup = null,
        ),
        // 024: Colombia / HandDrip / Medium / null(cafe=セルフ) — 未評価（sentinel 0.0）、tasting 未設定
        RawData(
            name = "コロンビア ナリーニョ スプレモ",
            cafe = null,
            rating = 0.0,
            notes = "サンプルとして購入。評価は後日。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Colombia",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = null,
        ),
        // 025: Guatemala / AeroPress / City / cafe4 — 全要素設定
        RawData(
            name = "グアテマラ エル インヘルト ウォッシュド",
            cafe = cafe4,
            rating = 4.0,
            notes = "ミルクチョコとキャラメル。アエロプレスで甘さの輪郭がはっきりする。",
            brewMethod = BrewMethod.AeroPress,
            origin = "Guatemala",
            variety = "Bourbon",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.City,
            cup = null,
            tasting = TastingScores(sweetness = 8, body = 7, acidity = 4, flavor = 7, aftertaste = 6),
        ),
        // 026: Brazil / HandDrip / null(roast) / cafe1 — tasting あり（5 要素）
        RawData(
            name = "ブラジル イパネマ ディアモンド",
            cafe = cafe1,
            rating = 3.5,
            notes = "焙煎度表記なし。ナッツとバター感、飲みやすいブラジル。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Brazil",
            variety = null,
            processing = ProcessingMethod.Natural,
            roastLevel = null,
            cup = null,
            tasting = TastingScores(sweetness = 6, body = 7, acidity = 3, flavor = 6, aftertaste = 5),
        ),
        // 027: Indonesia / HandDrip / Italian / null(cafe=セルフ) — tasting 未設定（全 null）
        RawData(
            name = "インドネシア スラウェシ トラジャ",
            cafe = null,
            rating = 3.5,
            notes = "深煎りのダークチョコとスパイシーな余韻。ブラックで楽しむ一杯。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Indonesia",
            variety = null,
            processing = ProcessingMethod.Other,
            roastLevel = RoastLevel.Italian,
            cup = null,
        ),
        // 028: Costa Rica / ColdBrew / Light / cafe5 — 全要素設定
        RawData(
            name = "コスタリカ ロス アルチリョス ゲイシャ",
            cafe = cafe5,
            rating = 4.5,
            notes = "コールドブリューでもゲイシャの花感が残る。甘くて冷たくて最高。",
            brewMethod = BrewMethod.ColdBrew,
            origin = "Costa Rica",
            variety = "Geisha",
            processing = ProcessingMethod.Honey,
            roastLevel = RoastLevel.Light,
            cup = null,
            tasting = TastingScores(sweetness = 8, body = 5, acidity = 5, flavor = 9, aftertaste = 8),
        ),
        // 029: Kenya / Other / Cinnamon / cafe2 — 全要素設定
        RawData(
            name = "ケニア チェボリット ナチュラル",
            cafe = cafe2,
            rating = 4.0,
            notes = "ケニアナチュラルの珍しいロット。ストロベリーとブルーベリーが全開。",
            brewMethod = BrewMethod.Other,
            origin = "Kenya",
            variety = null,
            processing = ProcessingMethod.Natural,
            roastLevel = RoastLevel.Cinnamon,
            cup = null,
            tasting = TastingScores(sweetness = 7, body = 5, acidity = 7, flavor = 8, aftertaste = 7),
        ),
        // 030: Ethiopia / HandDrip / High / cafe3 — 全要素設定（高評価）
        RawData(
            name = "エチオピア ウォルカ コチェレ",
            cafe = cafe3,
            rating = 4.5,
            notes = "ストーンフルーツとフラワー。中深煎りで甘みと酸のバランスが絶妙。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Ethiopia",
            variety = "Heirloom",
            processing = ProcessingMethod.Natural,
            roastLevel = RoastLevel.High,
            cup = null,
            tasting = TastingScores(sweetness = 8, body = 6, acidity = 7, flavor = 9, aftertaste = 8),
        ),
    )
}
