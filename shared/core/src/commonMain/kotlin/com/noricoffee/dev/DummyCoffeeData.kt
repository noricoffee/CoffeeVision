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
 * ## 人格設計（好み一致デモが機能する固定ペルソナ）
 *
 * 「王道の喫茶店ブレンド好き」という 1 人格を軸に構成する。分析タブの好み判定
 * （[com.noricoffee.domain.usecase.BuildCoffeeStatsUseCase.buildFavoriteSignals]、経験ベイズ収縮 + n連動 z ゲート）と
 * カフェ一致（[com.noricoffee.domain.usecase.ObserveTasteMatchedCafesUseCase]）が
 * **4 軸すべて（産地 / 焙煎度 / 抽出方法 / 精製方法）**で確実に信号化するよう、以下の 3 層で構成する:
 *
 * 1. **好みクラスタ（6 件、評価 4.5〜5.0）**: 産地=ブラジル・焙煎度=City・抽出=ネルドリップ・精製=ナチュラル
 *    を核レコード全件が同時に満たす。cafe1 / cafe2 / cafe3 に 2 件ずつ分散し、3 カフェすべてが
 *    4 軸すべての `PreferenceMatchAxis` で一致する「好み一致ピン」になる
 * 2. **二番手ケニア（4 件、評価 3.5〜4.0）**: 産地はケニアだが評価・件数ともブラジルに及ばず、
 *    産地の好み信号はブラジルが勝つ（好きだが二番手、という設計上の対比）
 * 3. **その他（20 件、評価 3.0〜3.5）**: 産地 9 種・焙煎度 7 種（+ null）・抽出方法 7 種・精製方法 4 種を
 *    分散させ、全体平均を約 3.6 まで下げつつ分析タブの各グラフ（産地ランキング・月次推移・カフェ別等）
 *    が退化しないだけの幅を残す。好みクラスタの 4 属性（ブラジル / City / ネルドリップ / ナチュラル）は
 *    信号のクリーンさを保つためこの層では使わない
 *
 * ## エッジケースの網羅
 *
 * - 未評価（`rating = null`）: 2 件
 * - 焙煎度 null: 4 件
 * - セルフ抽出（`cafe = null`）: 約 1/3（11/30）。ただし**好みクラスタの核レコードは全件カフェ付き**
 *   （セルフ抽出はカフェ一致の対象外のため）
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
                region = raw.region,
                variety = raw.variety,
                processing = raw.processing,
                roastLevel = raw.roastLevel,
                cup = raw.cup,
                brewRecipe = raw.brewRecipe,
                tasting = raw.tasting,
                createdAt = now,
                updatedAt = now,
            )
        }
    }

    // ---- ダミーカフェ（同一カフェを複数レコードに使い回し、topCafes / 好み一致ピンが出るよう設計）----

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
        val rating: Double?,
        val notes: String,
        val brewMethod: BrewMethod,
        val origin: String?,
        val region: String? = null,          // エリア / 農園（2026-07-22 追加。既存データに混在文字列は無いため既定 null）
        val variety: String?,
        val processing: ProcessingMethod?,
        val roastLevel: RoastLevel?,
        val cup: String?,
        val brewRecipe: String? = null,       // 抽出レシピ自由メモ（フェーズ 15-E 追加。セルフ抽出向け）
        val tasting: TastingScores? = null,  // all-or-nothing: 5 要素セット or null
    )

    private val rawData: List<RawData> = listOf(
        // ============================================================
        // 好みクラスタ（6件）: ブラジル × City × ネルドリップ × ナチュラル
        // 全 4 軸を同時に満たす核レコード。cafe1/cafe2/cafe3 に 2 件ずつ分散。
        // ============================================================
        // 001
        RawData(
            name = "ブラジル セラード ナチュラル ネルドリップ",
            cafe = cafe1,
            rating = 4.5,
            notes = "香ばしいナッツとカカオ。ネルの丸みでコクが引き立つ、まさに喫茶店の味。",
            brewMethod = BrewMethod.NelDrip,
            origin = "Brazil",
            variety = "Mundo Novo",
            processing = ProcessingMethod.Natural,
            roastLevel = RoastLevel.City,
            cup = "ネル生地",
            tasting = TastingScores(sweetness = 8, body = 8, acidity = 3, flavor = 7, aftertaste = 7),
        ),
        // 002
        RawData(
            name = "ブラジル モジアナ ナチュラル",
            cafe = cafe1,
            rating = 5.0,
            notes = "焦がしキャラメルのような甘香ばしさ。何杯でも飲める安心感のあるバランス。",
            brewMethod = BrewMethod.NelDrip,
            origin = "Brazil",
            variety = "Catuai",
            processing = ProcessingMethod.Natural,
            roastLevel = RoastLevel.City,
            cup = "ネル生地",
            tasting = TastingScores(sweetness = 9, body = 8, acidity = 3, flavor = 8, aftertaste = 8),
        ),
        // 003
        RawData(
            name = "ブラジル イパネマ ダイヤモンドマウンテン",
            cafe = cafe2,
            rating = 4.5,
            notes = "ミルクチョコとローストナッツ。ネルドリップの質感がしっとり心地よい。",
            brewMethod = BrewMethod.NelDrip,
            origin = "Brazil",
            variety = "Yellow Bourbon",
            processing = ProcessingMethod.Natural,
            roastLevel = RoastLevel.City,
            cup = "ネル生地",
        ),
        // 004
        RawData(
            name = "ブラジル カルモデミナス ナチュラル",
            cafe = cafe2,
            rating = 5.0,
            notes = "王道の喫茶店ブレンドそのもの。甘さと苦味のバランスが完璧で毎回頼みたくなる。",
            brewMethod = BrewMethod.NelDrip,
            origin = "Brazil",
            variety = "Icatu",
            processing = ProcessingMethod.Natural,
            roastLevel = RoastLevel.City,
            cup = "ネル生地",
            tasting = TastingScores(sweetness = 9, body = 9, acidity = 2, flavor = 8, aftertaste = 9),
        ),
        // 005
        RawData(
            name = "ブラジル スルデミナス ピーベリー",
            cafe = cafe3,
            rating = 4.5,
            notes = "ピーベリーらしい凝縮感。ネルの油脂感がコクを底上げしてくれる。",
            brewMethod = BrewMethod.NelDrip,
            origin = "Brazil",
            variety = "Peaberry",
            processing = ProcessingMethod.Natural,
            roastLevel = RoastLevel.City,
            cup = "ネル生地",
        ),
        // 006
        RawData(
            name = "ブラジル ショコラ農園 ナチュラル",
            cafe = cafe3,
            rating = 4.5,
            notes = "ダークチョコレートの余韻。中煎りらしい香ばしさが鼻に抜ける。",
            brewMethod = BrewMethod.NelDrip,
            origin = "Brazil",
            variety = "Acaia",
            processing = ProcessingMethod.Natural,
            roastLevel = RoastLevel.City,
            cup = "ネル生地",
            tasting = TastingScores(sweetness = 8, body = 7, acidity = 3, flavor = 7, aftertaste = 7),
        ),

        // ============================================================
        // 二番手ケニア（4件）: 好きだが評価・件数でブラジルに次ぐ
        // ============================================================
        // 007
        RawData(
            name = "ケニア キリニャガ ウォッシュド",
            cafe = cafe4,
            rating = 3.5,
            notes = "グレープフルーツのような明るい酸。ブラジルの丸さとはまた違う魅力。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Kenya",
            variety = "SL28",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = null,
        ),
        // 008
        RawData(
            name = "ケニア ニエリ AA",
            cafe = cafe4,
            rating = 4.0,
            notes = "ブラックカラントの凝縮感。酸が好きな日はこれを選びたくなる。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Kenya",
            variety = "SL34",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = null,
            tasting = TastingScores(sweetness = 5, body = 6, acidity = 8, flavor = 7, aftertaste = 6),
        ),
        // 009
        RawData(
            name = "ケニア カグモイニ AA",
            cafe = cafe5,
            rating = 3.5,
            notes = "力強い酸とベリー感。単体だと少し好みが分かれるかもしれない。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Kenya",
            variety = "SL28",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = null,
        ),
        // 010
        RawData(
            name = "ケニア ルイル11 ウォッシュド",
            cafe = null,
            rating = 4.0,
            notes = "自宅でハンドドリップ。トマトのような旨みのある珍しいロット。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Kenya",
            variety = "Ruiru 11",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = null,
            brewRecipe = "豆 16g / 湯 240ml / 92℃ / 2:30",
            tasting = TastingScores(sweetness = 6, body = 6, acidity = 7, flavor = 7, aftertaste = 6),
        ),

        // ============================================================
        // 未評価（2件）
        // ============================================================
        // 011
        RawData(
            name = "ベトナム ロブスタ ダークロースト",
            cafe = null,
            rating = null,
            notes = "サンプルでもらったロット。まだ淹れて評価できていない。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Vietnam",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = null,
        ),
        // 012
        RawData(
            name = "コロンビア ナリーニョ スプレモ",
            cafe = cafe2,
            rating = null,
            notes = "購入したばかり。今度ゆっくり淹れて記録する予定。",
            brewMethod = BrewMethod.Espresso,
            origin = "Colombia",
            variety = null,
            processing = null,
            roastLevel = null,
            cup = null,
        ),

        // ============================================================
        // その他（18件）: 評価 3.0〜3.5。産地・焙煎度・抽出・精製を分散し
        // 好みクラスタの 4 属性（ブラジル/City/ネルドリップ/ナチュラル）は使わない
        // ============================================================
        // 013
        RawData(
            name = "エチオピア イルガチェフェ G2 ウォッシュド",
            cafe = cafe4,
            rating = 3.5,
            notes = "レモンティーのような軽やかな酸。すっきりした後味。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Ethiopia",
            variety = "Heirloom",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Light,
            cup = null,
        ),
        // 014
        RawData(
            name = "エチオピア グジ ハニー",
            cafe = cafe1,
            rating = 3.0,
            notes = "エスプレッソにすると香りが強すぎて少し扱いにくかった。",
            brewMethod = BrewMethod.Espresso,
            origin = "Ethiopia",
            variety = null,
            processing = ProcessingMethod.Honey,
            roastLevel = RoastLevel.Cinnamon,
            cup = null,
        ),
        // 015
        RawData(
            name = "エチオピア シダモ アナエロビック",
            cafe = null,
            rating = 3.5,
            notes = "発酵感のあるトロピカルフレーバー。好みが分かれそうな個性派。",
            brewMethod = BrewMethod.AeroPress,
            origin = "Ethiopia",
            variety = null,
            processing = ProcessingMethod.Anaerobic,
            roastLevel = null,
            cup = null,
        ),
        // 016
        RawData(
            name = "コロンビア ウイラ ウォッシュド",
            cafe = cafe2,
            rating = 3.0,
            notes = "マイルドでクセがない。日常使いにはちょうど良い。",
            brewMethod = BrewMethod.FrenchPress,
            origin = "Colombia",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = null,
        ),
        // 017
        RawData(
            name = "コロンビア トリマ ハニー",
            cafe = null,
            rating = 3.5,
            notes = "サイフォンで淹れると甘みが少し立つ。まずまずの満足感。",
            brewMethod = BrewMethod.Syphon,
            origin = "Colombia",
            variety = null,
            processing = ProcessingMethod.Honey,
            roastLevel = RoastLevel.High,
            cup = null,
        ),
        // 018
        RawData(
            name = "グアテマラ アンティグア コールドブリュー",
            cafe = null,
            rating = 3.0,
            notes = "夏場に作った水出し。スモーキーさが冷えると少しぼやける。",
            brewMethod = BrewMethod.ColdBrew,
            origin = "Guatemala",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.FullCity,
            cup = null,
        ),
        // 019
        RawData(
            name = "グアテマラ フエゴ アナエロビック",
            cafe = cafe3,
            rating = 3.5,
            notes = "スパイシーで独特な発酵香。深煎りとの相性はまずまず。",
            brewMethod = BrewMethod.Other,
            origin = "Guatemala",
            variety = null,
            processing = ProcessingMethod.Anaerobic,
            roastLevel = RoastLevel.French,
            cup = null,
        ),
        // 020
        RawData(
            name = "コスタリカ タラス ホワイトハニー",
            cafe = null,
            rating = 3.0,
            notes = "上品な甘さだが自宅の抽出だと少し薄くなってしまった。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Costa Rica",
            variety = null,
            processing = ProcessingMethod.Honey,
            roastLevel = RoastLevel.Italian,
            cup = null,
            brewRecipe = "豆 14g / 湯 220ml / 90℃ / 2:15",
        ),
        // 021
        RawData(
            name = "コスタリカ ウエストバレー ウォッシュド",
            cafe = null,
            rating = 3.5,
            notes = "バランス型で飲みやすい。特筆すべき個性は少なめ。",
            brewMethod = BrewMethod.Espresso,
            origin = "Costa Rica",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = null,
            cup = null,
        ),
        // 022
        RawData(
            name = "パナマ ボケテ ウォッシュド",
            cafe = cafe5,
            rating = 3.0,
            notes = "ゲイシャではない通常品種。悪くはないが特別感はない。",
            brewMethod = BrewMethod.AeroPress,
            origin = "Panama",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Light,
            cup = null,
        ),
        // 023
        RawData(
            name = "パナマ ドンパチ ハニー",
            cafe = null,
            rating = 3.5,
            notes = "フレンチプレスでとろみのある口当たり。まあまあ好み。",
            brewMethod = BrewMethod.FrenchPress,
            origin = "Panama",
            variety = null,
            processing = ProcessingMethod.Honey,
            roastLevel = null,
            cup = null,
        ),
        // 024
        RawData(
            name = "インドネシア マンデリン G1",
            cafe = cafe4,
            rating = 3.0,
            notes = "アーシーなコクだが少し土っぽさが強すぎた。",
            brewMethod = BrewMethod.Syphon,
            origin = "Indonesia",
            variety = null,
            processing = ProcessingMethod.Other,
            roastLevel = RoastLevel.Medium,
            cup = null,
        ),
        // 025
        RawData(
            name = "インドネシア アチェ ウォッシュド",
            cafe = null,
            rating = 3.5,
            notes = "水出しでハーブ感が和らいで飲みやすくなった。",
            brewMethod = BrewMethod.ColdBrew,
            origin = "Indonesia",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.High,
            cup = null,
        ),
        // 026
        RawData(
            name = "ルワンダ ニャマシェケ ウォッシュド",
            cafe = cafe1,
            rating = 3.0,
            notes = "ストーンフルーツ感はあるがやや薄め。次はもう少し粉量を増やしたい。",
            brewMethod = BrewMethod.HandDrip,
            origin = "Rwanda",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Cinnamon,
            cup = null,
        ),
        // 027
        RawData(
            name = "ルワンダ カロンビ ハニー",
            cafe = null,
            rating = 3.5,
            notes = "ワイン的な発酵感。エスプレッソだと個性が少し強すぎるかもしれない。",
            brewMethod = BrewMethod.Espresso,
            origin = "Rwanda",
            variety = null,
            processing = ProcessingMethod.Honey,
            roastLevel = RoastLevel.FullCity,
            cup = null,
        ),
        // 028
        RawData(
            name = "ホンジュラス サンタバルバラ ウォッシュド",
            cafe = cafe2,
            rating = 3.0,
            notes = "クリーンでバランス型。悪くはないが記憶に残りにくい。",
            brewMethod = BrewMethod.AeroPress,
            origin = "Honduras",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.French,
            cup = null,
        ),
        // 029
        RawData(
            name = "ホンジュラス ラス ラハス アナエロビック",
            cafe = null,
            rating = 3.5,
            notes = "スパイシーで濃厚。深煎り好きにはもう少し評価が上がるかもしれない。",
            brewMethod = BrewMethod.Other,
            origin = "Honduras",
            variety = null,
            processing = ProcessingMethod.Anaerobic,
            roastLevel = RoastLevel.Italian,
            cup = null,
        ),
        // 030
        RawData(
            name = "ホンジュラス コパン ウォッシュド",
            cafe = cafe3,
            rating = 3.0,
            notes = "マイルドで飲みやすいが個性は控えめ。日常使いのローテーション候補。",
            brewMethod = BrewMethod.FrenchPress,
            origin = "Honduras",
            variety = null,
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = null,
        ),
    )
}
