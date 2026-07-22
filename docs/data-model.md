# データモデル

CoffeeVision のドメインモデルを **Kotlin（ドメイン）/ SQLDelight（ローカル DB）/ Firestore（クラウド）** の 3 表現で定義します。

> **2026-06-19 大改訂**: 「カフェ訪問（`Visit`）主体」から「**コーヒー記録（`CoffeeRecord`）主体**」へ再設計。`Visit` / `CoffeeItem` / `FoodItem` を廃止し、1 杯のコーヒー記録 `CoffeeRecord` を集約ルートにした。カフェは任意（`cafe: Cafe?`、null = セルフ抽出）。クリーンブレイク（データ移行なし）。経緯は [`implementation_note.md`](./implementation_note.md) 2026-06-19 エントリ参照。

エンティティ一覧:

- `CoffeeRecord`（コーヒー記録。集約ルート）
- `Cafe`（カフェ情報。`CoffeeRecord` / `SavedCafe` に埋め込み）
- `Photo`（写真。`CoffeeRecord` の子）
- `BeanProfile`（豆ナレッジ。Firestore グローバルコレクション / サービス管理データ）
- `SavedCafe`（行きたい店。ウィッシュリスト / フェーズ 15-A）

---

## エンティティ関連図

```
User (Firebase Auth uid)
  │
  ├── CoffeeRecord (0..N)
  │     ├── Cafe              (0..1, 埋め込み / null = セルフ抽出)
  │     └── Photo             (0..N)
  │
  └── SavedCafe (0..N)         行きたい店（placeId ごとに最大 1 件）
        └── Cafe              (1, 埋め込みスナップショット)
```

---

# 1. Kotlin ドメインモデル

`shared/domain/src/commonMain/kotlin/com/noricoffee/domain/` 配下に配置します。

## 1.1 CoffeeRecord

```kotlin
package com.noricoffee.domain

import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

data class CoffeeRecord(
    val id: String,                       // UUID v4
    val userId: String,                   // Firebase Auth uid
    val cafe: Cafe?,                      // Places 由来のスナップショット。null = セルフ抽出（自宅等）
    val visitedOn: LocalDate,             // 飲んだ日
    val rating: Double?,                  // 0.5..5.0（0.5 刻み）。null = 未評価（2026-07-12 B-4 で 0.0 sentinel を廃止し nullable 化。0.0 は不正値）
    val notes: String,                    // 自由メモ（旧 ambiance / フード等もここに吸収）
    val photos: List<Photo>,
    // --- コーヒー属性（旧 CoffeeItem から昇格）---
    val name: String,                     // コーヒー名（必須）
    val brewMethod: BrewMethod,
    val origin: String?,                  // 産地（国名）。ドロップダウン選択（CoffeeOriginCatalog）。「ブレンド」/「その他で入力した国名」も可。null = 未選択。2026-07-22 に自由入力 → 国ドロップダウン化（§1.3a）
    val region: String?,                  // エリア / 農園（任意自由入力。例「イルガチェフェ」「ウエウエテナンゴ」）。origin から分離（2026-07-22 追加）。表示専用で分析には使わない（§1.6）
    val variety: String?,                 // 品種
    val processing: ProcessingMethod?,    // 精製方法
    val roastLevel: RoastLevel?,          // 焙煎度
    val cup: String?,                     // カップの種類 / ブランドメモ
    val brewRecipe: String?,              // 抽出レシピ（豆量 / 湯量 / 湯温 / 時間などの自由メモ）。フェーズ 15-E 追加。セルフ抽出向け
    val tasting: TastingScores?,          // テイスティング 5 要素。null = 未記入。記入する場合は 5 要素すべて必須
    val tags: List<String> = emptyList(), // ユーザー定義タグ（例: "ラテアート" "浅煎り"）。フェーズ 10-D 追加
    // --- メタ ---
    val createdAt: Instant,
    val updatedAt: Instant,
)
```

> **`tasting` の統合**: Blue Bottle「Elements of Coffee Tasting」に基づくテイスティング 5 要素（甘味 / ボディ / 酸味 / 風味 / 後味）を `TastingScores`（§1.1a）として持つ。各要素は **1〜10 の強度**。**テイスティングは任意だが、付ける場合は 5 要素すべて必須**（all-or-nothing）。「付けない」は `tasting = null`。総合評価 `rating`（0.5 刻みハーフスター）とは別軸の **強度スケール**であることに注意。

> **rating / notes の統合**: 旧モデルでは Visit と CoffeeItem の双方に rating / notes があったが、コーヒー主体では 1 杯につき 1 本に統一する。旧 `ambiance`（カフェの雰囲気）と `FoodItem`（フード）は構造化フィールドとして廃止し、必要なら自由メモ `notes` に書く方針。

## 1.1a TastingScores

```kotlin
data class TastingScores(
    val sweetness: Int,                    // 甘味     1..10
    val body: Int,                         // ボディ（コク）
    val acidity: Int,                      // 酸味
    val flavor: Int,                       // 風味
    val aftertaste: Int,                   // 後味
)
```

- 各要素は **1〜10 の整数**（強度スケール。UI はスライダー）。
- **5 要素は不可分（all-or-nothing）**: テイスティングを付ける場合は 5 要素すべて必須。「付けない」は `CoffeeRecord.tasting = null`（§1.1）で表す。**部分入力は型として表現不可能**（各フィールドが非 null）。
- 「良し悪し」ではなく**強度**を表す軸（酸味 10 = 酸が強い、であって優劣ではない）。総合評価 `rating` とは意味が異なる。
- バリデーション: 各値は `1..10`。UI は `+` でデフォルト値（5）の `TastingScores` を生成して 5 スライダーを一度に出し、削除で `null` に戻すため、部分状態は発生しない。

## 1.2 Cafe

```kotlin
data class Cafe(
    val placeId: String,                  // Google Places の place_id
    val name: String,
    val address: String?,
    val latitude: Double?,
    val longitude: Double?,
    val photoReferences: List<String>,    // Places の photo_reference
    val websiteUrl: String?,
    val mapsUrl: String?,
    // --- Places API 取得時のみ利用する表示用フィールド（フェーズ 10-B 追加。永続化しない）---
    val openNow: Boolean? = null,                        // 営業中か（currentOpeningHours.openNow）
    val weekdayDescriptions: List<String> = emptyList(), // 曜日別営業時間の表示文字列
    val phoneNumber: String? = null,                     // 電話番号（nationalPhoneNumber）
    val priceLevel: String? = null,                      // 価格帯（PRICE_LEVEL_* 文字列）
    val googleRating: Double? = null,                    // Google 上の評価
    val userRatingCount: Int? = null,                    // Google 上の評価件数（フェーズ 16 追加）
)
```

> `CoffeeRecord.cafe` が null の場合はカフェに紐づかないセルフ抽出を表す。

> **永続化されるのは先頭 8 フィールドのみ**: フェーズ 10-B で追加した 5 フィールド（`openNow`〜`googleRating`）とフェーズ 16 で追加した `userRatingCount` の計 6 フィールドは Places API（Text / Nearby / Details）のレスポンスから組み立てて**カフェ詳細画面・マップ下部カードの表示にのみ使う揮発値**。`CoffeeRecord.cafe` としてスナップショット保存する際は SQLDelight（§2.1 の `cafe_*` 列）にも Firestore（§3.2 の `cafe` マップ）にも書き出さず、読み戻した `Cafe` では既定値のままになる（営業時間等は鮮度が要るため都度取得が正）。

> **写真について**: Places API の写真は `photo_reference` をキーに **都度取得** する規約。
> ローカルに永続キャッシュしないこと（規約違反になる場合がある）。

## 1.3 enum

```kotlin
enum class BrewMethod {
    Espresso,
    HandDrip,
    NelDrip,
    FrenchPress,
    AeroPress,
    Syphon,
    ColdBrew,
    Other,
}

enum class ProcessingMethod {
    Natural,
    Washed,
    Honey,
    Anaerobic,
    Other,
}

enum class RoastLevel {
    Light,
    Cinnamon,
    Medium,
    High,
    City,
    FullCity,
    French,
    Italian,
}
```

## 1.3a CoffeeOriginCatalog（産地の国ドロップダウン / 2026-07-22）

`CoffeeRecord.origin` を自由入力から**国ドロップダウン選択**に変更するための、コーヒー生産国の**日本語国名カタログ**。記録入力の手間削減が目的（[`requirements.md`](./requirements.md) 2-1）。

**配置**: `shared/domain/src/commonMain/kotlin/com/noricoffee/domain/CoffeeOriginCatalog.kt`

```kotlin
object CoffeeOriginCatalog {
    // 表示順 = このリスト順 = コーヒー生豆の生産量の概算ランキング順（ICO / FAO ベース。
    // 上位は確度が高く、小規模産地の相対順は目安）。全て日本語表記。UI は先頭に「ブレンド」、
    // 末尾に「その他」を添えて出す（ブレンド → 生産量順 → その他）。
    val countries: List<String> = listOf(
        "ブラジル", "ベトナム", "コロンビア", "インドネシア", "エチオピア", "ウガンダ",
        "インド", "ホンジュラス", "ペルー", "メキシコ", "グアテマラ", "中国",
        "ニカラグア", "コートジボワール", "コスタリカ", "ケニア", "タンザニア", "エルサルバドル",
        "パプアニューギニア", "ラオス", "カメルーン", "タイ", "ベネズエラ", "コンゴ民主共和国",
        "ルワンダ", "ブルンジ", "ハイチ", "エクアドル", "ドミニカ共和国", "フィリピン",
        "ボリビア", "ミャンマー", "キューバ", "ザンビア", "イエメン", "マラウイ",
        "ネパール", "東ティモール", "パナマ", "台湾", "ジャマイカ", "プエルトリコ", "ハワイ",
    )

    const val BLEND: String = "ブレンド"   // 複数産地。単一国に落とし込めないコーヒー
    const val OTHER: String = "その他"     // リスト外の産地。UI は選択時に国名の自由入力欄を出す
}
```

### 設計上の決め事

- **origin は `String?` のまま（enum 化しない）**: 「ブレンド」「その他で入力した国名」「未選択（null）」「クリーンブレイク前の legacy 自由文字列」を型で表現でき、`OriginNormalizer` / `BeanProfile` 突合 / `originRanking`（すべて String ベース）を無改修で流用できる（Simplicity First）。カタログは選択肢の提示元であって格納型の制約ではない
- **正規形との一致（不変条件）**: `countries` の各要素は `OriginNormalizer.normalize` の**正規形（＝ normalize が自身を返す固定点）**であること。日本語表記はシノニム辞書のキー（英語綴り / サブ地域）に含まれず lowercase でも不変のため自然に成立する。**`OriginNormalizer` のシノニム値（RHS）は全て `countries` に含まれる**ことをテストで担保する（`OriginNormalizerTest` に catalog ⊇ synonymValues を追加）。新規追加国には英語綴りシノニム（`vietnam` → `ベトナム` 等）も `OriginNormalizer` へ追加し、カタログと正規化のカバレッジを揃える
- **「その他」で入力した国名の扱い**: literal「その他」を保存せず、ユーザーが入力した実際の国名文字列を `origin` に保存する（データ欠損回避）。「ブレンド」は literal「ブレンド」を保存する（実体が単一国でないため）
- **カタログの真実点は domain**: iOS ピッカーは SKIE ブリッジ経由で `CoffeeOriginCatalog` を読む（[`kmp-bridge.md`](./kmp-bridge.md)）。iOS 側でリストを二重管理しない。**表示順は生産量の概算ランキング順**（ICO/FAO ベース。よく飲まれる産地を上位に置き選択の手間を減らす）。ピッカーは先頭に「ブレンド」、`countries` を生産量順、末尾に「その他」を並べる（`未選択` は任意フィールドの空状態として最上段に残す。2026-07-22 並び替え）
- **`region`（エリア / 農園）は分析非対象**: サブ地域の粒度は交絡分離不能で統計に使えない（§1.6 の confounding 方針）ため、`region` は詳細表示・シェアカード等の**表示専用**。`originRanking` / `FavoriteSignals` は従来どおり `origin`（国）のみを見る

## 1.4 Photo

```kotlin
data class Photo(
    val id: String,
    val fileName: String?,                // Documents 配下の最終ファイル名（例: "{photoId}.jpg"）。Firestore にも保存し、機種変・iCloud Backup 復元時に `photos/{fileName}` で localPath を再構築できる
    val localPath: String?,               // Documents 配下からの相対パス（例: "photos/{photoId}.jpg"）。iOS Documents URL は起動ごとに変わるため絶対パス禁止
    val remoteUrl: String?,               // 将来 Firebase Storage 復活用フィールド。現状は常に null
    val width: Int?,
    val height: Int?,
    val createdAt: Instant,
)
```

> 現状は `localPath` / `fileName` が常に非 null（端末ローカル保存）、`remoteUrl` は常に null（将来 Storage 復活用にフィールドだけ残置）。写真ファイルは Documents 配下のフラットな `photos/` ディレクトリに置く（recordId 別ディレクトリにしない）。Create モードでも recordId 確定前に写真を保存できる + CoffeeRecord 削除時は `CoffeeRecord.photos` の id を順に物理削除する設計。`localPath` と `fileName` は冗長に見えるが、`localPath` は端末側 DB の即時読み込み用、`fileName` は Firestore メタデータの最小単位として両方持つ。

## 1.5 VisitedCafe（集計モデル）

`shared/domain/src/commonMain/kotlin/com/noricoffee/domain/model/VisitedCafe.kt`

```kotlin
data class VisitedCafe(
    val cafe: Cafe,                       // 最新記録時のカフェスナップショット
    val lastVisitedAt: Instant,           // そのカフェで最後にコーヒーを記録した日
    val visitCount: Int,                  // そのカフェでのコーヒー記録件数
    val averageRating: Double?,           // 記録の平均評価（rating=null の未評価は除外、全て未評価なら null）
)
```

> マップ表示・カフェ集計用。`ObserveVisitedCafesUseCase` が `CoffeeRecord` のうち **`cafe != null` のものだけ** を `cafe.placeId` でグループ化して生成する。セルフ抽出（cafe == null）は集計対象外（座標が無くマップに出せないため）。名前は互換性のため `VisitedCafe` を維持するが、意味は「コーヒー記録のあるカフェ」。

## 1.6 CoffeeStats（分析用 集計モデル）

`shared/domain/src/commonMain/kotlin/com/noricoffee/domain/model/CoffeeStats.kt`

分析タブ（[`requirements.md`](./requirements.md) §9）の **階層1（記述統計）+ 階層2（傾向抽出）** の結果。`CoffeeRecord` 群から `BuildCoffeeStatsUseCase` が決定論的に生成する。**永続化しない派生モデル**（DB / Firestore 表現は持たない）。この `CoffeeStats` が ① 統計 UI の入力であり、② 階層3（Foundation Models）に渡す**唯一の入力**でもある（生レコードは LLM に渡さない）。

```kotlin
data class CoffeeStats(
    val totalCount: Int,                       // 全記録件数
    val ratedCount: Int,                       // rating != null の件数
    val averageRating: Double?,                // 未評価(0.0)除外の平均。全未評価なら null
    val ratingHistogram: List<RatingBucket>,   // 0.5 刻みの度数（存在する刻みのみ、昇順）
    val byBrewMethod: List<CategoryStat>,      // 抽出方法別（label = enum.name）
    val byRoastLevel: List<CategoryStat>,      // 焙煎度別
    val byProcessing: List<CategoryStat>,      // 精製方法別
    val originRanking: List<CategoryStat>,     // 産地別（自由文字列を軽く正規化、件数降順 上位N）
    val monthlyTrend: List<MonthlyStat>,       // visitedOn の年月別（昇順）
    val topCafes: List<CafeStat>,              // cafe != null をグループ化（件数降順 上位N）
    val recentHighlights: List<RecordDigest>,  // Q&A 文脈用の代表レコード（高評価・直近）
    val favoriteSignals: FavoriteSignals,      // 階層2: 高評価群に共通する属性
    val tastingAverages: TastingAverages,      // テイスティング 5 要素の平均（設定済みのみ集計）
    val preferredBeanTraits: PreferredBeanTraits? = null, // 階層2+: 好みの産地 × BeanProfile 突合結果（フェーズ 12-C。BeanProfile 未提供時は null）
    val unexploredBeanSuggestions: List<UnexploredBeanSuggestion> = emptyList(), // 好み合致 × 未記録の BeanProfile 提案（フェーズ 15-E-3。BeanProfile 未提供 / 信号なしは空）
)

data class TastingAverages(
    val sweetness: Double?,                    // 甘味の平均（tasting ありの記録のみ、無ければ null）
    val body: Double?,
    val acidity: Double?,
    val flavor: Double?,
    val aftertaste: Double?,
    val ratedCount: Int,                       // tasting を持つ記録の件数（all-or-nothing なので 5 要素共通）
)

data class RatingBucket(val rating: Double, val count: Int)

data class CategoryStat(
    val label: String,                         // enum.name / 正規化済み産地など
    val count: Int,
    val averageRating: Double?,                // その群の平均（未評価除外、全未評価なら null）
)

data class MonthlyStat(
    val yearMonth: String,                     // "YYYY-MM"
    val count: Int,
    val averageRating: Double?,
)

data class CafeStat(
    val placeId: String,
    val name: String,
    val count: Int,
    val averageRating: Double?,
)

data class RecordDigest(
    val name: String,
    val rating: Double,
    val cafeName: String?,                     // セルフ抽出は null
    val visitedOn: LocalDate,
)

data class FavoriteSignals(
    val bestBrewMethod: CategoryStat?,         // 収縮平均で全体平均を最も上回る抽出方法（弱い好み信号。閾値・正方向のみ）
    val bestOrigin: CategoryStat?,
    val bestRoastLevel: CategoryStat?,
    val bestProcessing: CategoryStat? = null,  // 同上、精製方法（bestRoastLevel と対称。default null で加算的）
    val dominantTastingAxis: TastingAxisCorrelation?,  // 評価と最も相関するテイスティング軸（|r| 閾値以上のみ）
    val minSampleSize: Int,                    // この件数未満の群は信号にしない（既定 3）
)

data class TastingAxisCorrelation(
    val axis: TastingAxis,                     // 相関が最大だった軸
    val correlation: Double,                   // ピアソン相関係数 r（-1.0..1.0、符号付き）
    val sampleSize: Int,                       // 相関の母数（rating!=null かつ tasting!=null の件数）
)

enum class TastingAxis { Sweetness, Body, Acidity, Flavor, Aftertaste }

// フェーズ 12-C: FavoriteSignals と BeanProfile（§1.8）を突合した「好みやすい豆の特徴」。
// PreferredBeanTraitsUseCase が決定論的に生成し、ObserveCoffeeStatsUseCase に
// BeanProfileRepository? を注入したときだけ CoffeeStats.preferredBeanTraits に付加される（未注入 / 信号なしは null）。
data class PreferredBeanTraits(
    val matchedProfiles: List<BeanProfile>,   // bestOrigin ラベルと origin が部分一致するプロファイル
    val dominantFlavorNotes: List<String>,    // マッチしたプロファイルの flavorNotes 頻度集計 top-5
    val originHint: String?,                  // FavoriteSignals.bestOrigin のラベル（信号なしは null）
    val roastLevelHint: String?,              // FavoriteSignals.bestRoastLevel のラベル（同上）
    val dominantTastingAxis: TastingAxis?,    // FavoriteSignals.dominantTastingAxis の axis（同上）
)
```

### 集計ルール（決定論）

- **平均評価**: `rating == null`（未評価）は常に母数から除外。対象が 0 件なら `null`。
- **`favoriteSignals`（階層2 / 好み判定）**: 「複数の評価から好みを統計的に抽出する」層。**生平均のランキングはサンプル数の罠に弱い**（n=1 の 5.0 が最上位に来る）ため、以下の補正を入れる。出力は常に **「弱い傾向」止まり**（断定しない。理由は交絡 = 下記）。
  - **カテゴリ好み（`bestBrewMethod` / `bestOrigin` / `bestRoastLevel` / `bestProcessing`）= 収縮平均による選定**（4 軸すべて同一ロジック。`bestProcessing` は `processing != null` のレコードを enum 名でグループ化して選定）:
    1. 母数: `rating != null` の評価済みレコード。全体平均 `globalMean` を算出（評価済み 0 件なら 3 つとも `null`）。
    2. 候補: 各軸で件数 `>= minSampleSize`（既定 3）かつ平均評価ありの label。
    3. **経験ベイズ収縮**: 各候補の評価を `shrunkMean = (n·mean + k·globalMean) / (n + k)` で全体平均へ寄せる（`k = SHRINKAGE_PRIOR_WEIGHT`、既定 5 ＝「全体平均を 5 杯ぶん事前に混ぜる」）。少数群の極端値を抑える。
    4. 選定: `shrunkMean` 最大の候補（n=1 外れ値に頑健な選定キー）。ただし信号化は **n 連動の信頼区間ゲート**で足切りする: `mean - globalMean > CATEGORY_Z · globalStd / sqrt(n)`（一標本 z 検定近似。`globalStd` = 全評価済 rating の母標準偏差、`n` = 候補群の件数、`mean` = 候補群の生平均）。これを満たす最良候補だけ信号にする。**固定オフセット δ（`shrunkMean - globalMean > δ`）は特異度を上げられない**（最良群の偶然の上振れ＝winner's curse がサンプリングばらつき σ/√n に比例して膨らみ、固定 δ では止まらない。B-1b 100% / B-1c 不均等でも 86.7% と実測）。よって**ばらつき連動（n 連動）の閾値**で足切りする。`CATEGORY_MIN_EFFECT = 0.20` は「統計的有意だが実用上は誤差レベル」を弾く小さな絶対下限として併用してよい（z ゲートと AND）。
    5. 返す `CategoryStat` は**生の `averageRating` と `count`**（収縮値・effect-size は選定/足切りの内部利用のみ。`count` が小さければ言語化で「但し書き」に使う）。タイ時は件数多 → label 昇順で決定論化。
  - **好みの軸（`dominantTastingAxis`）= テイスティング軸と評価の相関**:
    1. 母数: `tasting != null` かつ `rating != null` の記録。`CORRELATION_MIN_SAMPLE`（既定 5）未満なら `null`。
    2. 5 軸それぞれと `rating` の**ピアソン相関係数 r**（符号付き）を計算。分散 0 の軸（全件同値）は相関定義不可のためスキップ。
    3. `|r|` 最大の軸を採用。ただし **`|r| >= CORRELATION_ABS_FLOOR`（サンプル数連動の下限。下記）のときだけ**信号にする（弱すぎる相関は出さない）。`r > 0`＝「その軸が高いほど高評価」、`r < 0`＝「低いほど高評価」として言語化に渡す。**5 軸の max|r| を採る多重比較で偽陽性が乗る**（B-1b 実測 40%）ため、固定 0.3 ではなくサンプル数に応じて締める。
  - **交絡（confounding）は計算しない（仕様）**: 「産地が好き」か「その産地を多く出す店が好き」かは個人の観測データでは分離不能。層別すると各層の n が枯れ、有意性検定も前提が崩れる。よって**多変量解析・検定は行わず**、上記の「件数ガード＋収縮＋相関閾値」というヒューリスティックで「弱い傾向」だけを出す。LLM へもこの但し書き付きで渡す（断定させない）。
  - **定数**（`BuildCoffeeStatsUseCase.companion` に公開、将来変更可）: `SHRINKAGE_PRIOR_WEIGHT = 5`（選定キー shrunkMean 用）/ `CORRELATION_MIN_SAMPLE = 5` / `CATEGORY_Z = 2.0`（カテゴリ z ゲート係数 ≈95% 信頼区間。B-1d sweep で確定。heavy-skew 偽陽性 9.3%・検出力 P2–P4 維持。`globalStd==0` は z ゲートをスキップしδ下限のみ）/ `CATEGORY_MIN_EFFECT = 0.20`（z ゲートと AND する絶対下限）/ テイスティング軸の |r| 下限 = `max(CORRELATION_MIN_ABS, CORRELATION_ABS_FLOOR_C / sqrt(n))`（`CORRELATION_MIN_ABS = 0.3` と `CORRELATION_ABS_FLOOR_C = 1.97` の併用。n=30 で実効 ≈0.36）。`minSampleSize` は `FavoriteSignals` 既定 3。値は `FavoriteSignalsPersonaTest` の sweep（150 シード）で検出力 P1–P4・P7 維持を確認して確定。
  - **既知の限界 / 経緯**: tasting 軸の偽陽性は 40%→22%（c 連動 floor、B-1c）。カテゴリ信号は固定 δ では下がらず（均等 100% / heavy-skew 86.7%、B-1d 前段実測）、**n 連動 z ゲートで根治**（B-1d 本体）。winner's curse は固定オフセットでなくばらつき連動の閾値で抑えるのが要点。詳細経緯は実装ノート 2026-06-22 B-1b〜B-1d。
- **産地**: 分析が見るのは `origin`（国名）**のみ**。`region`（エリア / 農園）は表示専用で集計に使わない（2026-07-22 分離）。origin は国ドロップダウン（`CoffeeOriginCatalog` §1.3a）由来で概ね正規形に揃うが、`BeanProfile.origin` や legacy 自由文字列との名寄せのため引き続き `OriginNormalizer` を通す。グループキーは **`OriginNormalizer.normalize` の正規化値**（trim + lowercase → シノニム辞書の完全キー一致で正規形へ。「Ethiopia」「イルガチェフェ」→「エチオピア」。辞書外は素通し。辞書の正本は `shared/domain/.../OriginNormalizer.kt`、2026-07-08 導入）、**表示ラベルはグループ内最初に出現したレコードの元表記（`trim()` のみ）** を採用（ユーザー入力の表記を尊重）。複合文字列（「エチオピア イルガチェフェ」等）は辞書の完全キー一致にヒットせず独立グループのまま（突合側の contains で拾う。既知の限界）。
- **`recentHighlights`**: 階層3 の Q&A / 要約が具体名に言及できるよう、**`rating >= 4.0`** の高評価かつ直近の代表レコードを少数含める。
- **`tastingAverages`**: `tasting != null` の記録だけを母数に、5 要素それぞれの平均。tasting を持つ記録が 1 件も無ければ各要素 `null`。`ratedCount` = tasting を持つ記録件数（all-or-nothing なので 5 要素で共通。UI が「n 件の平均」を出せる）。
- **上位 N / 件数の定数**（`BuildCoffeeStatsUseCase.companion` に公開。将来変更可）: `ORIGIN_RANKING_LIMIT = 10` / `TOP_CAFES_LIMIT = 10` / `RECENT_HIGHLIGHTS_LIMIT = 5` / `HIGHLIGHTS_MIN_RATING = 4.0`。

> Phase A では `byBrewMethod` / `byRoastLevel` / `originRanking` / `monthlyTrend` / `topCafes` / `ratingHistogram` までを実装し、`favoriteSignals` は **Phase B-1（好み判定）で上記仕様により実体化**する（収縮平均＋相関軸。それ以前は全フィールド null の空 `FavoriteSignals`）。`ObserveCoffeeStatsUseCase` で `CoffeeRepository.observeAll(userId)` を `map` して `Flow<CoffeeStats>` を返す形を基本とする。`favoriteSignals` は階層3（要約・Q&A）の `buildPrompt` にも「弱い傾向＋件数の但し書き」として渡し、LLM は断定せず言語化する。

### 階層3（自然言語解釈）のインターフェース

iOS の Foundation Models 実装を `shared/domain` のインターフェースで抽象化し、プラットフォーム非対称を吸収する（Firebase の `RemoteCoffeeDataSource` と同じパターン）。

```kotlin
// shared/domain — 階層3。iOS = Foundation Models 実装、Android = 注入しない（分析タブ非表示）
interface CoffeeInsightProvider {
    // 階層3 要約（Phase A-4 実装済）。CoffeeStats を入力に headline/body を構造化生成する。
    @Throws(Exception::class)
    suspend fun summarize(stats: CoffeeStats): CoffeeInsight

    // 対話 Q&A v1（Phase B-2）: 単発・ステートレス。digest（CoffeeStats）のみを文脈に質問へ回答する。
    // 戻り値は整形済みの日本語プレーンテキスト（@Generable 不使用）。tool / 会話履歴は持たない。
    @Throws(Exception::class)
    suspend fun answer(question: String, stats: CoffeeStats): String

    // 好みの豆傾向の言語化（フェーズ 12-C）: PreferredBeanTraits を入力に「あなたが好みやすい豆の特徴」を生成する。
    // iOS 実装は __summarizeBeanTraits(traits:completionHandler:) の protocol witness 形式。
    // null 返却を許可（Foundation Models 不可時は UI がフレーバータグのみ表示にフォールバック）。
    @Throws(Exception::class)
    suspend fun summarizeBeanTraits(traits: PreferredBeanTraits): CoffeeInsight?
}

data class CoffeeInsight(
    val headline: String,
    val body: String,
)
```

> `AnalysisViewModel` には `CoffeeInsightProvider?` を注入する（null = 階層3 非対応 = Android / Apple Intelligence 無効時）。**可否判定は iOS の注入時に行う**: `SystemLanguageModel` が `.available` のときだけ `CoffeeInsightProvider` の実装を注入し、不可なら null を渡す。`AnalysisViewModel` は `provider == null → InsightStatus.Unsupported` を既に実装済みのため、KMP 側を変更せず graceful degradation が成立する。iOS 実装は `summarize` 内で `LanguageModelSession` を用い、`@Generable` で `headline` / `body` を構造化生成する。`summarize` 自体の失敗（生成エラー等）は `Failed` 扱い。

#### 対話 Q&A v1（Phase B-2）の設計

`answer(question, stats)` は要約と同じく **`CoffeeStats` digest だけを唯一の入力**とする（生レコード・tool 無し / 計算は KMP 済み、LLM は解釈と整形のみ）。設計上の決め事:

- **単発・ステートレス**: 1 問 1 答。会話履歴・`LanguageModelSession` は質問ごとに新規生成し再利用しない。UI も「質問入力欄 + 直近の回答カード 1 枚」のみ保持する。
- **グラウンディング制約**: instructions で「与えられた統計の範囲でのみ答える / digest に無い情報は『記録からは分かりません』と返す / 数値の再計算はしない / 日本語で簡潔に」と縛り、ハルシネーションを防ぐ。
- **ストリーミングなし**: 逐次表示（`streamResponse` → `Flow`）は「Swift 側で Flow を作る」ハードパスになるため v1 では採用せず、suspend 一発で最終回答 `String` を返す。逐次表示は Phase 2 で別途検討。
- **可否判定は要約と共有**: 新たなゲートは設けない。`CoffeeInsightProvider != null`（= `summarize` が使える端末）なら Q&A も使える。`null` の端末は Q&A UI 自体を出さない。
- **tool calling（生レコード参照）は Phase 2（9-4b）**: digest で答えられない粒度の質問は将来 Foundation Models の `Tool` で KMP 照会を呼ぶ。v1 のインターフェースは tool を持ち込まない。

#### 対話 Q&A v2（Phase B-3 / 9-4b）の設計

digest で答えられない**個別レコード単位の問い**（「○○カフェで飲んだコーヒーは？」「先月飲んだのは？」「エチオピアの記録は？」）に対応するため、Foundation Models の `Tool`（function calling）から KMP の生レコード照会を呼べるようにする。**v1 と同じ "計算は KMP・LLM は解釈と整形のみ" 原則を踏襲**し、絞り込みは KMP 側で行う。

```kotlin
// shared/domain — 9-4b。iOS の Foundation Models Tool から呼ばれる生レコード照会
interface CoffeeRecordQuery {
    // 単一の柔軟な検索。userId は実装が内部で解決するため Swift は filter だけ渡す。
    @Throws(Exception::class)
    suspend fun searchRecords(filter: CoffeeRecordFilter): List<CoffeeRecordSummary>
}

data class CoffeeRecordFilter(
    val origin: String? = null,        // 産地（部分一致・大小無視）
    val brewMethod: String? = null,    // 抽出方法（enum 名/日本語ラベルに寛容マッチ）
    val roastLevel: String? = null,    // 焙煎度（同上）
    val cafeName: String? = null,      // カフェ名（部分一致）
    val minRating: Double? = null,
    val maxRating: Double? = null,
    val fromYearMonth: String? = null, // "YYYY-MM" 以降（含む）
    val toYearMonth: String? = null,   // "YYYY-MM" まで（含む）
    val tastingMin: TastingScores? = null,  // テイスティング各軸の下限（null = 条件なし）。指定時に tasting=null のレコードは除外
    val tastingMax: TastingScores? = null,  // テイスティング各軸の上限（null = 条件なし）。各軸は独立評価
    val limit: Int = 10,
)

data class CoffeeRecordSummary(
    val name: String,
    val cafeName: String?,
    val origin: String?,
    val brewMethod: String,   // enum 名（iOS 側で日本語化）
    val roastLevel: String?,  // enum 名 or null
    val rating: Double,       // 0.0 = 未評価（LLM ブリッジ境界の明示 sentinel。domain の null を 0.0 に写す。下記「filter は全て String/Double/Int」参照）
    val visitedOn: String,    // "YYYY-MM-DD"
)
```

設計上の決め事:

- **単一の柔軟な検索 tool**: 複数の専用 tool に分けず、`searchRecords` 1 本に絞り込み条件を optional で並べる。Foundation Models は引数説明が充実した単一 tool の方が安定し、KMP 照会 API も 1 メソッドで済む。
- **filter は全て String/Double/Int（enum を持ち込まない）**: LLM が生成する文字列を KMP 側で寛容にマッチする。`brewMethod`/`roastLevel` は enum `.name` を大小無視 + 部分一致、未評価（domain の `rating == null`）は評価範囲フィルタの対象外として扱う。これでブリッジが単純かつ LLM 出力に頑健になる。**`CoffeeRecordSummary.rating` はこの境界の例外として `Double` のまま `0.0 = 未評価` を維持**（マッピングは `record.rating ?: 0.0`。domain の nullable 化 = 2026-07-12 B-4 後も、LLM ブリッジは primitive 主義を優先。iOS 側の `>= 0.5` 表示分岐はこの仕様に依存）。
- **`origin`/`cafeName` はフィールド横断の free-text term**（2026-06-21 横断化）: 各 term が `record.cafe?.name`（カフェ名）/ `record.origin`（産地）/ `record.name`（コーヒー名）/ `record.variety`（品種）のいずれかに部分一致（大小無視）すればマッチ。両方指定時は AND（各 term がそれぞれ union のいずれかにヒット）。どちらも null ならこのテキスト条件は無視。背景: Foundation Models が `cafeName` と `origin` を誤分類しても確実にヒットさせるため（例: "フグレン" を `origin` に入れても cafe 名にマッチ）。トレードオフとして、コーヒー名に地名が含まれる場合の偽陽性が増えるが個人アプリ規模では許容。
- **userId は実装が内部で解決**: `CoffeeRecordQueryImpl` は `authRepository.signInAnonymouslyIfNeeded()` で現在 uid を取得し、`coffeeRepository.observeAll(uid).first()` で全件取得 → Kotlin で filter 適用 → `visitedOn` 降順 → `limit` 件に切って `CoffeeRecordSummary` 化する。個人アプリ規模（数十〜数百件）のため全件読みで十分。`shared/domain` 内に置き、`CoffeeRepository` + `AuthRepository` インターフェースのみに依存させる（テスト容易）。`AppContainer` が組み立てて `val coffeeRecordQuery` で公開する。
- **digest はベース文脈として併用（ハイブリッド）**: tool は digest で足りないときだけ LLM が呼ぶ。プロンプトには引き続き `buildPrompt(stats)` の digest を含める。
- **既存インターフェース・VM・UI は不変**: `CoffeeInsightProvider.answer(question, stats)` のシグネチャは据え置き、iOS 実装が内部で tool を登録するだけ。`AnalysisViewModel` / Q&A UI は変更しない（変更は純粋に加算的）。ブリッジ方向（Swift→Kotlin calling direction）と配線は [`kmp-bridge.md`](./kmp-bridge.md) を参照。

---

## 1.7 RecommendedCafe（味覚プロファイル一致カフェ / 要件 9-5）

マップ上で「あなた好みの一杯があった店」を強調するための**派生集計モデル**（永続化しない）。`CoffeeRecord` 群と `FavoriteSignals` から決定論的に算出する。

### モデル（`shared/domain`）

```kotlin
// 推薦カフェ 1 件。matches は非空（理由が 1 つ以上あるカフェだけを返す）。
data class RecommendedCafe(
    val cafe: Cafe,                       // placeId / 座標を持つ（マップピン用）。最新記録時スナップショット
    val matches: List<RecommendationReason>, // なぜ推薦されたか（非空）
)

// 推薦理由。将来の協調フィルタリングでも種類を増やして再利用できるよう sealed で表現する。
sealed interface RecommendationReason {
    // v1（コンテンツベース）: 自分の好み属性に一致する高評価記録があった
    data class TasteProfileMatch(
        val axis: PreferenceMatchAxis,    // Origin / RoastLevel / BrewMethod / Processing
        val matchedLabel: String,         // "Ethiopia" / "Light" / "AeroPress" / "Natural"（表示用ラベル）
        val exampleRecordName: String,    // 代表記録のコーヒー名
        val exampleRating: Double,        // その記録の評価
    ) : RecommendationReason
    // 9-6（協調フィルタ / リモート・設計確定 2026-07-21・未実装）: 味覚が近いユーザーが高評価した未訪問店
    data class SimilarUsers(
        val similarUserCount: Int,        // 似ているユーザー数（最小 K 未満は推薦を出さない = 個人特定回避）
    ) : RecommendationReason
}

enum class PreferenceMatchAxis { Origin, RoastLevel, BrewMethod, Processing }
```

### 推薦ソースの抽象化（将来の差し替えポイント）

```kotlin
// 推薦の供給元。v1 はローカル決定論実装、将来はサーバ（GCP 等）リモート実装に差し替える。
// MapViewModel はこの interface にだけ依存し、中身（ローカル集計 / 横断ベクトル類似）を知らない。
interface CafeRecommendationProvider {
    fun observeRecommendedCafes(userId: String): Flow<List<RecommendedCafe>>
}
```

- **v1 実装 = `ObserveTasteMatchedCafesUseCase`**（`CafeRecommendationProvider` のローカル実装）。`CoffeeRepository.observeAll(userId)` ＋ `BuildCoffeeStatsUseCase` の `FavoriteSignals` から算出。
- **将来 9-6** はこの interface のリモート実装（横断ベクトル類似はサーバ側）を `AppContainer` で差し替えるだけ。`MapViewModel` / iOS UI / Foundation Models 言語化層は不変。

### 一致ルール（決定論 / v1 コンテンツベース）

あるカフェ（`cafe.placeId` でグループ化、`cafe == null` のセルフ抽出は座標が無いため対象外）に、次を**両方**満たす `CoffeeRecord` が 1 件以上あれば `RecommendedCafe` として返す:

1. `rating >= HIGHLIGHTS_MIN_RATING`（= 4.0。`recentHighlights` と統一）
2. かつ `FavoriteSignals` のカテゴリ好み（`bestOrigin` / `bestRoastLevel` / `bestBrewMethod` / `bestProcessing` のうち **非 null のもの**）のいずれかに一致:
   - `origin`: `OriginNormalizer.normalize`（trim + lowercase + シノニム辞書）で `bestOrigin.label` と一致（`buildOriginRanking` と同じ正規化）
   - `roastLevel`: enum 一致（`bestRoastLevel.label == record.roastLevel?.name`）
   - `brewMethod`: enum 一致（`bestBrewMethod.label == record.brewMethod.name`）
   - `processing`: enum 一致（`bestProcessing.label == record.processing?.name`）

- **`matches` の構築**: 一致した軸ごとに 1 つの `TasteProfileMatch` を作る。同じ軸に複数の一致記録があれば**評価最高の記録**を代表（`exampleRecordName` / `exampleRating`）に採用。タイは `visitedOn` 新しい順 → コーヒー名昇順で決定論化。
- **`dominantTastingAxis`（相関軸）は一致条件に使わない**: 相関は per-record の categorical 一致に変換できず、理由表示も曖昧になるため。カテゴリ好み 4 軸（産地 / 焙煎度 / 抽出方法 / 精製方法）に限定。
- **`FavoriteSignals` が全 null（データ不足）** なら一致 0 件 → 空リスト（マップは強調なし）。
- **並び順**: `matches` 件数降順 → 代表記録評価の最大降順 → placeId 昇順（決定論）。

### マップ連携（`MapViewModel` / iOS）

- `MapViewModel` は `CafeRecommendationProvider.observeRecommendedCafes(userId)` を購読し、`UIState` に `recommendedCafes: List<RecommendedCafe>` と一致 placeId 集合を加える（既存 `visitedCafes` 購読と同パターン）。公開 API 追加は加算的。
- iOS `MapTabView`: 一致カフェを**区別ピン**（アクセント色＋ハート/星）で強調し、タップで理由（`matches`）を表示。理由文言（「好みのエチオピアを高評価で記録（〇〇 ★4.5）」）は iOS でローカライズ生成。
- **Foundation Models 連携は将来 9-6 で「推薦理由の自然言語化」一点に限定**（v1 は構造化 reason を iOS が定型文で表示。LLM は使わない）。

### 9-6 協調フィルタリング（リモート実装 / 設計確定 2026-07-21・未実装）

9-5（ローカル・既訪問の再訪）に**追加**で載る新規開拓推薦。`CafeRecommendationProvider` のリモート実装として差し替える（`MapViewModel` / iOS UI / 理由表示層は不変）。**実装はインフラ選定から段階着手**（tasks 12-D）。

- **同意**: 新規 `recommendationConsent`（§3.2 `users/{uid}`。`analyticsConsent` とは目的別・オプトイン・既定 false）。ON かつ記録変更時に自プロファイルを再計算し `sharedTasteProfiles/{uid}` へ upsert、OFF で削除（共有撤回）。
- **共有プロファイル `sharedTasteProfiles/{uid}`**（`beanProfiles` / `curatedCafes` と同型のグローバルコレクション。§3.2 / §3.3 参照）: 特徴ベクトルのみを持ち、生メモ・タグ・記録本文・カフェ名は含めない（プライバシー最小化）。
  - `tastingVector`: `tastingAverages` 5 軸（`Double?`。null 軸は cosine で欠損扱い）
  - `categoryPrefs`: `bestOrigin` / `bestRoastLevel` / `bestBrewMethod` / `bestProcessing` のラベル（null 可）
  - `highRatedCafes`: 高評価（rating ≥ 4.0）カフェの `[{placeId, lat, lng, rating}]`（地理制約に座標が要るため座標を持つ。店名は placeId から詳細解決）
  - `updatedAt`
- **類似度**: `tastingVector` 5 軸 cosine を主軸に、`categoryPrefs` 4 軸の一致をスコア加味（tasting 未入力ユーザーはカテゴリで fallback して母集団が痩せない）。
- **計算（Cloud Function / callable）**: クライアントが `{center, radiusMeters}` で呼ぶ → Function が Admin 特権で自プロファイル + 全 `sharedTasteProfiles` を read → 近傍上位 K 人選定 → K 人の `highRatedCafes` のうち「呼び出しユーザー未訪問」かつ「半径内」を placeId で集約（複数人が高評価した placeId ほど上位 = 票数）→ `[{placeId, lat, lng, similarUserCount}]` を返す（他人の uid・生データは返さない）。**横断 read はサーバ特権に閉じ、クライアントは他人のプロファイルを一切見ない**。
- **コールドスタート**: 近傍 K・自己記録 N 未満は推薦 0（空 = ピンが出ないだけ・専用空状態 UI なし）。最小 K で「N 人が高評価」表示の個人特定を回避。閾値は定数化し実装時 sweep（9-5 の `FavoriteSignals` 定数運用に倣う）。
- **理由表示**: `RecommendationReason.SimilarUsers(count)`。9-5（既訪問・ハートピン）と視覚区別。文言「あなたと味覚が近い人のおすすめ」は KMP でテンプレ生成（両 OS）。Foundation Models 言語化は iOS の任意上乗せ（必須でない）。
- **未決**: 閾値定数（近傍 K / 自己記録 N / 半径 R）/ Function 内の類似計算（総当たり cosine vs Firestore ネイティブベクトル KNN。初期は総当たりで十分の想定）/ サーバーインフラ選定（Cloud Functions ランタイム・デプロイ・CI）/ FM 言語化を v1 に含めるか。

---

## 1.7a UnexploredBeanSuggestion（未経験の豆への探索提案 / 要件 9-8・フェーズ 15-E-3）

好み信号に合致するが**ユーザーがまだ飲んでいない** `BeanProfile` を提案する派生集計（永続化しない）。9-5（既訪問店の**再訪**推薦）に対する**新規開拓**のナッジ。決定論（FM 不要）。

```kotlin
data class UnexploredBeanSuggestion(
    val profile: BeanProfile,             // 提案する豆
    val matchedOriginLabel: String,       // マッチ理由の表示用ラベル（FavoriteSignals.bestOrigin 由来）
)
```

**`SuggestUnexploredBeansUseCase`**（`shared/domain/.../usecase/`、決定論）:

```kotlin
class SuggestUnexploredBeansUseCase(
    private val beanProfileMatchUseCase: BeanProfileMatchUseCase = BeanProfileMatchUseCase(),
) {
    operator fun invoke(
        records: List<CoffeeRecord>,
        profiles: List<BeanProfile>,
        signals: FavoriteSignals,
    ): List<UnexploredBeanSuggestion>   // 上位 SUGGESTED_BEANS_LIMIT 件
    companion object { const val SUGGESTED_BEANS_LIMIT = 5 }
}
```

- **好み合致**: `signals.bestOrigin`（非 null のとき）に対し、既存 `BeanProfileMatchUseCase`（§1.8 の origin ファジーマッチ・スコアリング）を再利用して候補を選定・並べる（DRY）。`bestRoastLevel` / `bestBrewMethod` は `BeanProfile` に対応フィールドが無いため使わない（origin 主軸）
- **「未経験」判定 = (origin, variety) ペア**: `BeanProfile.variety != null` の候補は `(origin正規化, variety正規化)` ペアがユーザーの記録に無ければ未経験（同産地でも品種違いは別体験として提案）。`variety == null` の候補は origin のみで判定（その産地を一度でも記録済みなら経験済み扱い）。正規化は origin が `OriginNormalizer.normalize`（`buildOriginRanking` と同じ）、variety が `trim().lowercase()`（品種シノニムは対象外の非対称）
- **空になる条件**: `signals.bestOrigin == null`（好み未確定）/ `profiles` 空（BeanProfile 未投入）
- **配線**: `BuildCoffeeStatsUseCase.invoke(records, beanProfiles)` 内で `beanProfiles.isNotEmpty()` のときだけ計算し `CoffeeStats.unexploredBeanSuggestions` に格納（`preferredBeanTraits` = 12-C と同じ流儀。`ObserveCoffeeStatsUseCase` に `BeanProfileRepository?` を注入した端末でのみ非空）。`readiness`（UI メタ）と違い**ドメイン実質のある派生値**なので `CoffeeStats` 内に置く
- **LLM 非混入**: iOS の `buildPrompt(from: stats)` はフィールドを選択的に読む実装のため、本フィールドを buildPrompt に足さない限り Foundation Models の digest には入らない（分析タブ UI 表示専用）

---

## 1.8 BeanProfile（豆ナレッジ / フェーズ 12-B）

> サービス管理のコーヒー豆知識データ。ユーザーの `CoffeeRecord` と `beanProfileId` では**紐付けしない**。`origin`（trim/lowercase）+ `processings`（enum 名）でファジーマッチし、記録入力時のサジェストや将来の分析強化（12-C）に活用する。

**配置**: `shared/domain/src/commonMain/kotlin/com/noricoffee/domain/BeanProfile.kt`（パッケージ `com.noricoffee.domain`）

```kotlin
data class BeanProfile(
    val beanId: String,                        // Firestore ドキュメント ID（ASCII kebab-case）
    val name: String,                          // 豆名（表示用。「エチオピア ゲイシャ ナチュラル」等）
    val origin: String,                        // 産地（「エチオピア」「コロンビア」等。日本語表記 = §3.2 表記規約）
    val variety: String?,                      // 品種（「ゲイシャ」「ブルボン」等）
    val processings: List<ProcessingMethod>,   // 精製方法（複数可）
    val flavorNotes: List<String>,             // フレーバーノート（「チョコレート」「シトラス」等。統一語彙 = §3.2）
    val description: String?,                  // 12-C LLM インプット用説明
)
```

**ファジーマッチロジック**（`BeanProfileMatchUseCase`）:

| フィールド | マッチ方式 | スコア |
|---|---|---|
| `origin` | `OriginNormalizer.normalize`（trim + lowercase + シノニム辞書）後の完全一致 | +2 |
| `origin` | 同正規化後の双方向 contains | +1 |
| `processings` | `ProcessingMethod.name` 完全一致 | +1 |

- score > 0 のもののみ、降順でソートして返す
- `roastLevel` はロースター次第なので除外

**Repository インターフェース**（`com.noricoffee.repository.BeanProfileRepository`）:

```kotlin
interface BeanProfileRepository {
    suspend fun getAll(): List<BeanProfile>
    suspend fun getByOrigin(origin: String): List<BeanProfile>
}
```

`getAll()` はメモリキャッシュ前提（Firestore への one-shot get、snapshotListener 不要）。

---

## 1.9 SavedCafe（行きたい店 / フェーズ 15-A）

> 「探す → 保存 → 訪問 → 記録」のループを閉じるウィッシュリスト（[`requirements.md`](./requirements.md) §10）。記録（訪問済み）とは独立した「これから行く店」の管理。

**配置**: `shared/domain/src/commonMain/kotlin/com/noricoffee/domain/model/SavedCafe.kt`

```kotlin
data class SavedCafe(
    val userId: String,                   // Firebase Auth uid
    val cafe: Cafe,                       // Places 由来のスナップショット（保存時点。永続化は 8 フィールドのみ = §1.2 と同じ）
    val note: String,                     // 任意メモ（「◯◯さんおすすめ」等）。空文字可
    val savedAt: Instant,                 // 保存日時（一覧の並び順キー、降順）
)
```

### 設計上の決め事

- **キーは `cafe.placeId`（自然キー。UUID を持たない）**: 同じカフェを二重に「行きたい」登録する意味がないため、`(userId, placeId)` で一意とする。§5 の「ID は UUID v4」ルールの**意図的な例外**（保存/解除がトグルとして冪等になり、二重登録の防御ロジックが不要になる）。Places の place_id は英数字 + `-`/`_` で構成され `/` を含まないため、Firestore ドキュメント ID にそのまま使える
- **記録作成時の自動解除はしない（データは独立）**: 記録保存フローに `SavedCafeRepository` への書き込みを結合させない（Simplicity First / ユーザーの意図しないデータ消失を避ける。「また行きたい」用途でリストに残す使い方も許容）。重複感は**表示側で解決**する:
  - マップのピンは同一 placeId が競合したら **訪問済み（+ 好み一致）> 行きたい > 検索結果** の優先順位で 1 本だけ出す
  - 行きたい一覧では、記録が既にある店に「記録あり」バッジを表示し、手動解除を促す
- **一覧の導線はマップ画面内**: マップのツールバー（またはフィルタチップ列）のブックマークボタン → ハーフシートで `SavedCafe` 一覧（`savedAt` 降順、タップでカフェ詳細 push、スワイプで解除）。**新規 feature モジュールは作らない**（シートはマップ画面の一部。状態は `MapViewModel` に持たせ、1 画面 = 1 モジュール原則のカウント外とする）
- **カフェ詳細のトグル状態**: `CafeDetailViewModel` が `observeByPlaceId` を購読して「行きたい」ボタンの ON/OFF を表示。保存時は表示中の `Cafe`（Places Details 取得済み）からスナップショットを作る
- **スナップショットの鮮度**: 保存時点の 8 フィールドを固定保存。営業時間等の揮発情報はカフェ詳細画面が都度 Places Details を取得する既存挙動（§1.2）に委ねる

---

## 1.10 CuratedCafe（都道府県別おすすめカフェ / フェーズ 19）

> サービス管理のキュレーション済みおすすめカフェ。マップに専用ピン（通常カフェピンと同アイコンの拡大 + `Color.orange` 高彩度 = Google Maps 風 POI 強調。ズームイン時のみ表示、トグルなし）で強調する。既存の `RecommendedCafe`（§1.7 = ユーザーの味覚プロファイル好み一致）とは**別概念**なので命名を curated で分離。

**配置**: `shared/domain/src/commonMain/kotlin/com/noricoffee/domain/model/CuratedCafe.kt`

```kotlin
data class CuratedCafe(
    val placeId: String,        // Google Places ID（ピンタップ時の詳細解決キー）
    val name: String,           // 表示名
    val latitude: Double,       // 非 null（座標なし候補はシード時に弾く）
    val longitude: Double,
    val prefectureCode: String, // JIS X 0401 の 2 桁ゼロ埋め文字列（"01".."47"）
)
```

### 設計上の決め事

- **保持は最小 5 フィールドのみ（Places 規約対応）**: 評価・営業時間等の揮発データは保存せず、ピンタップ時にカフェ詳細画面が既存の `CafeRepository.getDetails` で解決する。placeId 以外の Places 由来データには 30 日キャッシュ規定があるため、シード再実行による定期リフレッシュを運用で担保する（`scripts/seed/README.md`）
- **都道府県コードは JIS X 0401**: 標準規格でローマ字ゆれ（hyogo/hyougo 等）がなく、文字列ソート = 北から南の自然順、Firestore ドキュメント ID にそのまま使える。47 値の Kotlin enum は作らない（クライアントは全件一括ロードのみで県別ロジックを持たない）。コード → 県名対応はシードスクリプトの定数表と Firestore ドキュメントの `prefectureName` が持つ
- **件数は県ごとの上限 + 人気枠**: 基準上位（評価 4.4 / レビュー 100 件以上）は東京 100 / 他県 30 を上限とし、加えて人気枠（評価 3.7 / レビュー 500 件以上）を上限の枠外で全件採用（2026-07-18 追加。初期スコープは東京のみ）
- **SQLDelight には持たない**: Firestore one-shot get + メモリキャッシュで足りる。オフラインは Firestore 永続化キャッシュに委ねる（アーキテクチャ不変条件どおり独自同期は書かない）

**Repository インターフェース**（`com.noricoffee.repository.CuratedCafeRepository`）:

```kotlin
interface CuratedCafeRepository {
    suspend fun getAll(): List<CuratedCafe>
}
```

`getAll()` はメモリキャッシュ前提（Firestore への one-shot get、snapshotListener 不要 = BeanProfile と同じパターン）。全県分を flatten した 1 本のリストを返す。`MapViewModel` が init で一括ロードし、失敗時はサイレントに空のまま（おすすめは付加情報でありマップ本体を阻害しない）。

> **将来課題**: 47 県フル展開時（約 1,400 件）は iOS 側 Annotation の可視領域フィルタ導入を検討する。

---

# 2. SQLDelight スキーマ

ローカル DB は **検索・オフライン参照の高速化** が目的。Firestore のキャッシュとは別途に持つ。
配置: `shared/data-local/src/commonMain/sqldelight/com/noricoffee/db/`

> **クリーンブレイク**: 旧 `Visit.sq` / `CoffeeItem.sq` / `FoodItem.sq` を削除し、`CoffeeRecord.sq` を新設。`Photo.sq` の FK を `coffee_record` に変更。マイグレーションは書かない（未リリースのため、テスト端末はアプリ削除→再インストール）。

## 2.1 CoffeeRecord.sq

```sql
CREATE TABLE coffee_record (
    id TEXT NOT NULL PRIMARY KEY,
    user_id TEXT NOT NULL,
    -- cafe は任意（全 cafe_* が null = セルフ抽出）
    cafe_place_id TEXT,
    cafe_name TEXT,
    cafe_address TEXT,
    cafe_latitude REAL,
    cafe_longitude REAL,
    cafe_photo_references TEXT,            -- JSON 配列（cafe null のとき null）
    cafe_website_url TEXT,
    cafe_maps_url TEXT,
    -- 記録本体
    visited_on TEXT NOT NULL,              -- ISO-8601 (YYYY-MM-DD)
    rating REAL,                           -- 0.5..5.0（0.5 刻み）。NULL = 未評価（migration 5.sqm で NOT NULL 撤廃 + 既存 0.0 → NULL 変換）
    notes TEXT NOT NULL,
    -- コーヒー属性
    name TEXT NOT NULL,
    brew_method TEXT NOT NULL,             -- enum 文字列
    origin TEXT,                           -- 国名（CoffeeOriginCatalog 選択値 / 「ブレンド」/ legacy 自由文字列）
    region TEXT,                           -- エリア / 農園（自由入力。migration 6.sqm で ALTER TABLE ADD COLUMN。2026-07-22 追加）
    variety TEXT,
    processing TEXT,                       -- enum 文字列
    roast_level TEXT,                      -- enum 文字列
    cup TEXT,
    brew_recipe TEXT,                      -- 抽出レシピ自由メモ（フェーズ 15-E 追加、migration 4.sqm で ALTER TABLE ADD COLUMN）
    -- テイスティング 5 要素（各 1..10）。5 列は all-or-nothing（全列 NULL = tasting なし / 全列セット = tasting あり）
    sweetness INTEGER,
    body INTEGER,
    acidity INTEGER,
    flavor INTEGER,
    aftertaste INTEGER,
    -- ユーザー定義タグ（JSON 配列文字列。空リストは "[]"、マイグレーション前の行は ""）
    tags TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,           -- epoch millis
    updated_at INTEGER NOT NULL
);

CREATE INDEX coffee_record_by_user_visited ON coffee_record (user_id, visited_on DESC);
CREATE INDEX coffee_record_by_cafe ON coffee_record (cafe_place_id);

selectAll:
SELECT * FROM coffee_record WHERE user_id = ? ORDER BY visited_on DESC, created_at DESC;

selectById:
SELECT * FROM coffee_record WHERE id = ?;

selectByCafe:
SELECT * FROM coffee_record WHERE user_id = ? AND cafe_place_id = ? ORDER BY visited_on DESC;

upsert:
INSERT OR REPLACE INTO coffee_record (
    id, user_id, cafe_place_id, cafe_name, cafe_address,
    cafe_latitude, cafe_longitude, cafe_photo_references,
    cafe_website_url, cafe_maps_url,
    visited_on, rating, notes,
    name, brew_method, origin, region, variety, processing, roast_level, cup,
    sweetness, body, acidity, flavor, aftertaste,
    tags,
    created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

deleteById:
DELETE FROM coffee_record WHERE id = ?;
```

> `selectByCafe` は `cafe_place_id = ?` の等値マッチのため、cafe null（セルフ抽出）は自然に除外される（意図通り）。

## 2.2 Photo.sq

```sql
CREATE TABLE photo (
    id TEXT NOT NULL PRIMARY KEY,
    record_id TEXT NOT NULL,
    file_name TEXT,
    local_path TEXT,
    remote_url TEXT,
    width INTEGER,
    height INTEGER,
    created_at INTEGER NOT NULL,
    sort_order INTEGER NOT NULL,
    FOREIGN KEY (record_id) REFERENCES coffee_record(id) ON DELETE CASCADE
);

CREATE INDEX photo_by_record ON photo (record_id, sort_order);

selectByRecord:
SELECT * FROM photo WHERE record_id = ? ORDER BY sort_order ASC;

upsert:
INSERT OR REPLACE INTO photo (
    id, record_id, file_name, local_path, remote_url, width, height, created_at, sort_order
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);

deleteByRecord:
DELETE FROM photo WHERE record_id = ?;

deleteById:
DELETE FROM photo WHERE id = ?;
```

> **FOREIGN KEY は接続ごとの opt-in（2026-07-03 確定）**: SQLite の外部キー制約は既定で OFF のため、`ON DELETE CASCADE` を機能させるには**本番ドライバ側で明示的に有効化する**必要がある。
> - Android: `AndroidSqliteDriver` の `Callback.onConfigure` で `db.setForeignKeyConstraintsEnabled(true)`（onConfigure に置くことで migration 実行中は framework 側が自動で制約を外す挙動に乗る）
> - iOS: `NativeSqliteDriver` の `onConfiguration` で `extendedConfig.foreignKeyConstraints = true`（sqliter の既定は false）
> - テストドライバ（`TestSqlDriver.*`）も同じ設定に揃える（JVM は `PRAGMA foreign_keys = ON` 済み、iOS は要追随）
>
> 有効化以前に記録削除で発生した孤児 photo 行（`record_id` が `coffee_record` に存在しない行）は migration `2.sqm` で一括削除して掃除する。

## 2.3 マッピング方針

- DB 行 ↔ ドメインモデル変換は `db/Mapper.kt` に集約する
- 子テーブル（photo）は別クエリで取得し、Repository でまとめる（JOIN は使わず、`Flow.combine` で結合）
- 写真の参照配列やタグ（`tags`）など複数値は **JSON 文字列**（`kotlinx.serialization`）で 1 列に格納する。`tags` は空文字（旧行）も空リストとして読む
- `cafe_place_id` が null の行は `cafe = null` で組み立てる。非 null の行のみ `Cafe(...)` を構築する
- **`brew_recipe`（フェーズ 15-E）**: migration `4.sqm` で `ALTER TABLE coffee_record ADD COLUMN brew_recipe TEXT;`（既存行は NULL）。`upsert` の列リスト・VALUES にも `brew_recipe` を追加する。Mapper は他の nullable TEXT 列と同じ扱い
- **`region`（産地の国ドロップダウン化、2026-07-22）**: migration `6.sqm` で `ALTER TABLE coffee_record ADD COLUMN region TEXT;`（既存行は NULL）。`upsert` の列リスト・VALUES にも `region` を追加する（`brew_recipe` と同じ nullable TEXT 扱い）。Mapper は他の nullable TEXT 列と同様に read/write する
- **`rating` nullable 化（B-4、2026-07-12）**: migration `5.sqm`。SQLite は NOT NULL 撤廃の ALTER をサポートしないため**テーブル再作成方式**（新テーブル CREATE → `NULLIF(rating, 0.0)` で INSERT SELECT → 旧テーブル DROP → RENAME → インデックス再作成）。photo テーブルの FK（`record_id` → `coffee_record.id`、2026-07-03 本番有効化）をトランザクション内で壊さない手順にすること

## 2.4 SavedCafe.sq（フェーズ 15-A）

```sql
CREATE TABLE saved_cafe (
    place_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    -- Cafe スナップショット（place_id 以外の 7 フィールド。coffee_record の cafe_* と同じ直列化規則）
    cafe_name TEXT NOT NULL,
    cafe_address TEXT,
    cafe_latitude REAL,
    cafe_longitude REAL,
    cafe_photo_references TEXT,            -- JSON 配列
    cafe_website_url TEXT,
    cafe_maps_url TEXT,
    note TEXT NOT NULL DEFAULT '',
    saved_at INTEGER NOT NULL,             -- epoch millis
    PRIMARY KEY (place_id, user_id)
);

CREATE INDEX saved_cafe_by_user ON saved_cafe (user_id, saved_at DESC);

selectAll:
SELECT * FROM saved_cafe WHERE user_id = ? ORDER BY saved_at DESC;

selectByPlaceId:
SELECT * FROM saved_cafe WHERE user_id = ? AND place_id = ?;

upsert:
INSERT OR REPLACE INTO saved_cafe (
    place_id, user_id, cafe_name, cafe_address,
    cafe_latitude, cafe_longitude, cafe_photo_references,
    cafe_website_url, cafe_maps_url,
    note, saved_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

deleteByPlaceId:
DELETE FROM saved_cafe WHERE user_id = ? AND place_id = ?;
```

> - **migration**: 既存インストールへのテーブル追加のため `migrations/3.sqm`（`CREATE TABLE` + `CREATE INDEX`）を書く（フェーズ 7 のクリーンブレイク以後はリリース前でも migration を書く運用）
> - 行 ↔ ドメイン変換は `db/Mapper.kt` に追加。`cafe_*` 列の直列化規則（photo_references の JSON 化等）は `coffee_record` と共通化する

---

# 3. Firestore スキーマ

## 3.1 コレクション構造

```
users/{uid}                               # ユーザープロフィール（analyticsConsent フラグ等）
  coffees/{coffeeId}                      # CoffeeRecord 本体（Cafe 埋め込み / 評価 / メモ / photos 配列）
  savedCafes/{placeId}                    # 行きたい店（フェーズ 15-A。ドキュメント ID = Places の place_id）

beanProfiles/{beanId}                     # 豆ナレッジベース（サービス管理 / 全認証ユーザーが read-only）
curatedCafes/{prefectureCode}             # 都道府県別おすすめカフェ（サービス管理 / 全認証ユーザーが read-only。フェーズ 19）
```

> **2026-06-19 改訂**: 旧 `visits` コレクション + サブコレクション（`coffeeItems` / `foodItems` / `photos`）を廃止。`coffees` コレクションの 1 ドキュメントに `cafe`（任意）と `photos`（埋め込み配列）を含める。子サブコレクションは持たない。

> **2026-06-30 追記（フェーズ 12-A）**: `users/{uid}` ルートドキュメント（`coffees` の親）にユーザープロフィールフィールドを追加。現在は `analyticsConsent: Boolean` のみ。ドキュメントが存在しない（新規ユーザー）場合は `analyticsConsent = false` と同義に扱う。

写真本体は Firestore / Storage に同期せず、端末の Documents 配下にのみ保存します（[`requirements.md`](./requirements.md) §7-2）。

### なぜ photos を埋め込み配列にしたか

- `CoffeeRecord` は 1 杯単位なので photos は数枚程度。Firestore の 1MB ドキュメント上限に十分収まる（photo はメタデータのみ、画像本体は端末ローカル）
- 子取得の N+1（record ごとに `getDocuments` を並列発行）と WriteBatch の差分 delete が不要になり、Android / iOS のリモート実装が大幅に簡素化される
- 子要素単位のリッスンは不要（1 杯のコーヒーをまとめて読み書きするため）

---

## 3.2 ドキュメント定義

### `users/{uid}`（ユーザープロフィール）

```json
{
  "analyticsConsent": false,
  "recommendationConsent": false
}
```

- **analyticsConsent**: ユーザーが記録データをサービス改善目的での集計に同意したか否か。初回起動オンボーディングで取得。後から設定画面のトグルで変更可能。ドキュメント自体が存在しない場合（未オンボーディングユーザー）は `false` として扱う。
- **recommendationConsent**（フェーズ 12-D / 9-6・設計確定 2026-07-21・未実装）: 味覚プロファイルを協調フィルタ推薦の材料として共有することへの同意。`analyticsConsent`（Firebase Analytics 集計）とは**目的が別**の独立フラグ。オプトイン・既定 false（未設定は false 扱い）。ON のとき自プロファイルを `sharedTasteProfiles/{uid}` へ upsert、OFF で削除。
- フィールドは今後増える可能性がある。

### `beanProfiles/{beanId}`（豆ナレッジ）

```json
{
  "beanId": "ethiopia-geisha-natural",
  "name": "エチオピア ゲイシャ ナチュラル",
  "origin": "エチオピア",
  "variety": "ゲイシャ",
  "processings": ["Natural"],
  "flavorNotes": ["ジャスミン", "ライチ", "ピーチ", "ローズ"],
  "description": "ゲイシャ種発祥の地エチオピアのナチュラル精製。華やかな香りとライチのようなみずみずしい甘さが際立つ。"
}
```

**表記規約（2026-07-08 確定）**:

- **日本語表記に統一**: `name` / `origin`（「エチオピア」）/ `variety`（「ゲイシャ」）/ `flavorNotes`（「ジャスミン」）/ `description` は日本語。好み突合（12-C）はユーザーが記録に入力した産地文字列との trim + lowercase 部分一致のため、日本語 UI の手入力・サジェスト表示と表記を揃える
- **`processings` は `ProcessingMethod.name`（`"Washed"` / `"Natural"` / `"Honey"` / `"Anaerobic"` / `"Other"`）の配列**: 表示文字列ではなく enum 識別子。Mapper が enum 名で逆引きするため日本語化しない
- **`beanId` は ASCII kebab-case**（例: `ethiopia-geisha-natural`）: Firestore ドキュメント ID として安全な形を維持
- **`flavorNotes` は下記の統一語彙から選ぶ（自由記述禁止）**: `PreferredBeanTraitsUseCase` の頻度集計（top-5）が表記ゆれで割れるのを防ぐ。語彙は SCA フレーバーホイール + SCAJ カッピング評価語彙由来の日本語 42 語。機械検証は seed スクリプトのバリデーションが行う

  > ジャスミン / ローズ / フローラル / シトラス / ベルガモット / レモン / オレンジ / グレープフルーツ / アップル / 洋梨 / ピーチ / アプリコット / チェリー / ストロベリー / ブルーベリー / ラズベリー / カシス / ライチ / マンゴー / パッションフルーツ / パイナップル / トロピカルフルーツ / レーズン / プルーン / ハチミツ / キャラメル / ブラウンシュガー / 黒糖 / バニラ / メープルシロップ / チョコレート / ダークチョコレート / アーモンド / ヘーゼルナッツ / ナッツ / シナモン / スパイス / 紅茶 / ワイン / ハーブ / アーシー / スモーキー

- **`description` は自作テキスト**（ロースター各社サイトからの転載禁止）。SCAJ カッピングの評価観点（酸の質 / 甘さ / 質感 / クリーンカップ / 余韻 / 調和）を記述観点に使う
- サービス管理データのため、ユーザーは read-only。write は Admin SDK または Firebase Console から
- **初期データ**: `scripts/seed/bean-profiles.json`（主要産地網羅 38 件）を `scripts/seed/seed-bean-profiles.mjs`（Admin SDK / ドキュメント ID = beanId の冪等 upsert / 投入前バリデーション）で投入する。手順は `scripts/seed/README.md`。実行はユーザー作業（サービスアカウント鍵が必要、鍵は非コミット）

### `users/{uid}/coffees/{coffeeId}`

```json
{
  "id": "uuid-v4",
  "userId": "firebase-auth-uid",
  "cafe": {
    "placeId": "ChIJ...",
    "name": "Blue Bottle 三軒茶屋",
    "address": "東京都世田谷区...",
    "latitude": 35.6448,
    "longitude": 139.6694,
    "photoReferences": ["AcJnMu..."],
    "websiteUrl": "https://bluebottlecoffee.jp/",
    "mapsUrl": "https://maps.google.com/?cid=..."
  },
  "visitedOn": "2026-06-02",
  "rating": 4.5,
  "notes": "ベリー系の華やかな酸味。落ち着いた木質の内装",
  "name": "本日のコーヒー（ケニア カグモイニ）",
  "brewMethod": "HandDrip",
  "origin": "ケニア",
  "region": "ニエリ",
  "variety": "SL28",
  "processing": "Washed",
  "roastLevel": "Medium",
  "cup": "ノリタケ",
  "brewRecipe": "豆 15g / 湯 240ml / 92℃ / 2:30",
  "tasting": {
    "sweetness": 7,
    "body": 5,
    "acidity": 9,
    "flavor": 7,
    "aftertaste": 6
  },
  "tags": ["ラテアート", "浅煎り"],
  "photos": [
    {
      "id": "uuid-v4",
      "fileName": "550e8400-e29b-41d4-a716-446655440000.jpg",
      "width": 1920,
      "height": 1080,
      "createdAt": "<Timestamp>",
      "sortOrder": 0
    }
  ],
  "createdAt": "<Timestamp>",
  "updatedAt": "<Timestamp>"
}
```

- **cafe**: セルフ抽出（`cafe == null`）の場合は `cafe` キーごと省略する。decode 時にキーが欠如していたら `cafe = null`
- **rating**（2026-07-12 B-4 で nullable 化）: `rating == null`（未評価）なら他の nullable フィールドと同じく**キーごと省略**。decode 時は **キー欠如 / null / `0.0`（nullable 化以前の legacy sentinel）をすべて `null` に正規化**する（iOS / Android 対称。リモートの既存 0.0 ドキュメントは migration せず読み側で吸収）
- **nullable なコーヒー属性**（origin / region / variety / processing / roastLevel / cup / brewRecipe）: null の場合はキーごと省略。`brewRecipe` はフェーズ 15-E 追加、`region` は 2026-07-22 追加（いずれも decode 時にキー欠如は null 扱い）
- **tasting**: `tasting != null` のとき 5 要素すべてを持つマップを書き出す。`tasting == null`（未記入）なら `tasting` マップごと省略。decode 時、`tasting` マップが存在し 5 要素揃っていれば `TastingScores`、欠如していれば `null`（防御的に、いずれかキー欠如も `null` 扱い）。SQLDelight も同様に **5 列全セット → `TastingScores` / それ以外 → `null`**
- **tags**: 文字列配列。空でも配列として書き出す。decode 時にキーが欠如している（フェーズ 10-D 以前の）ドキュメントは空リスト扱い
- **cafe** に書くのはスナップショット 8 フィールドのみ（§1.2 の注記参照。`openNow` 等の表示用フィールドは書かない）
- **photos**: 埋め込み配列。`localPath` は端末固有値のため Firestore には書かない。`remoteUrl` も書かない（Storage 採用見送り）。`sortOrder` は配列 index を upload 時に採番、decode 時はソート用途で破棄
- `visitedOn` は `"YYYY-MM-DD"` 文字列、`createdAt` / `updatedAt` は Firestore `Timestamp`

### `users/{uid}/savedCafes/{placeId}`（行きたい店 / フェーズ 15-A）

```json
{
  "cafe": {
    "placeId": "ChIJ...",
    "name": "Blue Bottle 三軒茶屋",
    "address": "東京都世田谷区...",
    "latitude": 35.6448,
    "longitude": 139.6694,
    "photoReferences": ["AcJnMu..."],
    "websiteUrl": "https://bluebottlecoffee.jp/",
    "mapsUrl": "https://maps.google.com/?cid=..."
  },
  "note": "",
  "savedAt": "<Timestamp>"
}
```

- ドキュメント ID = `cafe.placeId`（§1.9 の自然キー方針）。保存 = `set`（上書き）、解除 = `delete` の冪等トグル
- `cafe` マップは `coffees` と同じスナップショット 8 フィールドのみ（揮発フィールドは書かない）。nullable フィールドは null 時にキー省略（`coffees` と同じ直列化規則）
- Security Rules は既存の `users/{uid}` 配下ワイルドカード（`match /{document=**}`）でカバーされるため**変更不要**

### `curatedCafes/{prefectureCode}`（都道府県別おすすめカフェ / フェーズ 19）

```json
{
  "prefectureCode": "13",
  "prefectureName": "東京都",
  "cafes": [
    {
      "placeId": "ChIJ...",
      "name": "コーヒー清澄白河",
      "latitude": 35.681,
      "longitude": 139.799
    }
  ],
  "updatedAt": "<Timestamp>"
}
```

- **1 都道府県 = 1 ドキュメント + カフェ埋め込み配列**: 全県読んでも最大 47 reads / 起動 1 回（メモリキャッシュ）。東京 100 件でも約 15KB で 1MB 上限に余裕
- ドキュメント ID = `prefectureCode`（JIS X 0401、§1.10）
- `cafes` 要素は placeId / name / latitude / longitude の 4 フィールドのみ（評価等の揮発データは書かない = Places 規約対応、§1.10）。必須フィールド欠落要素は decode 時に skip
- `updatedAt` は最終シード日時（Places 規約のリフレッシュ判断用）
- サービス管理データのため、ユーザーは read-only。write は Admin SDK のみ
- **初期データ**: `scripts/seed/generate-curated-cafes.mjs`（Places Text Search で候補生成）→ 人手レビュー → `seed-curated-cafes.mjs`（ドキュメント ID = prefectureCode の冪等 upsert / 投入前バリデーション）の 2 段構成。手順は `scripts/seed/README.md`。実行はユーザー作業

---

## 3.3 Security Rules（概略）

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      // users/{uid} ルートドキュメント（analyticsConsent フラグ保存用）
      allow read, write: if request.auth != null && request.auth.uid == uid;

      match /{document=**} {
        // coffees サブコレクション等
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }

    match /beanProfiles/{beanId} {
      // 豆ナレッジベース：認証済みユーザーは read-only。write は Admin SDK のみ
      allow read: if request.auth != null;
      allow write: if false;
    }

    match /curatedCafes/{prefectureCode} {
      // 都道府県別おすすめカフェ：認証済みユーザーは read-only。write は Admin SDK のみ
      allow read: if request.auth != null;
      allow write: if false;
    }

    match /sharedTasteProfiles/{uid} {
      // 協調フィルタ用の共有味覚プロファイル（9-6・設計確定 2026-07-21・未実装）。
      // 本人のみ read/write。他ユーザー横断 read は Cloud Function（Admin SDK）が Rules バイパスで行う。
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

> **フェーズ 12-A 更新**: `users/{uid}` ルートドキュメントへのアクセスを明示的に追加。**フェーズ 12-B 更新**: `beanProfiles` グローバルコレクションを追加（認証済みユーザー read-only）。**フェーズ 19 更新**: `curatedCafes` グローバルコレクションを追加（同型）。**9-6 設計確定（2026-07-21・未実装）**: `sharedTasteProfiles/{uid}` を追加（本人のみ read/write、横断 read は Cloud Function 特権のみ）。`firebase deploy --only firestore:rules` はユーザー作業。

---

# 4. Repository 設計

`commonMain` から Firestore SDK は直接呼べない（公式 SDK はプラットフォーム別 = iOS Swift / Android Kotlin）。そこで **2 段構成** にして、合成ロジックを共通層に 1 度だけ書く（詳細は [`kmp-bridge.md`](./kmp-bridge.md) §Repository 合成パターン）。

- `CoffeeRepository`（interface, `shared/domain`） — UI から見える唯一の API
- `RemoteCoffeeDataSource`（interface, `shared/domain`） — Firestore リスナを `Flow` で公開し、`upload(record)` / `remove(userId, id)` を持つ**薄いアダプタ**。実装はプラットフォーム別（Android = `shared/data-firebase/androidMain`、iOS = `iosApp` 側 Swift）
- `LocalCoffeeRepository`（class, `shared/data-local`） — SQLDelight のみの単体実装
- `CoffeeRepositoryImpl`（class, `shared/core`） — `LocalCoffeeRepository` と `RemoteCoffeeDataSource` を合成し、`CoffeeRepository` を満たす

各プラットフォームが書くのは `RemoteCoffeeDataSource` の実装のみ。書き込み順序（ローカル → リモート）や `startSync` はこの合成クラスに集約される。

## 4.1 インターフェース例

```kotlin
// shared/domain — UI から見える API
interface CoffeeRepository {
    fun observeAll(userId: String): Flow<List<CoffeeRecord>>
    fun observeById(id: String): Flow<CoffeeRecord?>
    fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>>

    suspend fun save(record: CoffeeRecord)         // 新規・更新 共通
    suspend fun delete(userId: String, id: String)
}

// shared/domain — プラットフォーム別に実装する薄いリモートアダプタ
interface RemoteCoffeeDataSource {
    fun observeChanges(userId: String): Flow<List<CoffeeRecord>>
    suspend fun upload(record: CoffeeRecord)
    suspend fun remove(userId: String, id: String)
}
```

## 4.2 実装方針

- **読み取り** は **SQLDelight の Flow を Single Source として返す**
  - Firestore の更新は `RemoteCoffeeDataSource.observeChanges` を `startSync` で購読し、SQLDelight に書き戻す
  - UI からは SQLDelight のみを見る（書き戻しが完了次第、Flow が emit する）
  - **スナップショット reconciliation（2026-07-03 確定）**: `observeChanges` は指定 userId の**全件スナップショット**を返す契約のため、`startSync` は upsert だけでなく「スナップショットに存在しない id のローカル行の削除」も行う。これが無いと他端末での削除がローカル DB に永久に伝播しない
    - **除外**: dev ダミーデータ（`DummyCoffeeData.ids`）はローカル DB 限定で Firestore に流さない設計のため、reconciliation の削除対象から除外する
    - **既知の許容トレードオフ**: `save`（ローカル書き込み）から `upload` 完了までの間に「新規レコードを含まないスナップショット」が届くと、そのレコードが一瞬ローカルから消えて upload 後のリスナ echo で復活しうる。Firestore リスナは pending writes を含むため窓は極小であり、MVP では許容する（競合解決の本格化は backlog B-1）
- **書き込み** は **ローカル（SQLDelight）→ リモート（Firestore）の順** で実施
  - ローカル書き込み完了で即座に UI 更新
  - リモート書き込みの失敗扱いは `WritePolicy` で切り替え可能（既定 `PropagateRemoteFailure` = 呼び出し元に伝播 / `IgnoreRemoteFailure` = SDK のオフライン永続化の再送に委ねる）
- **写真** は端末ローカル（Documents 配下）にのみ保存する。Firestore の `coffees/{id}.photos` 配列には `fileName` / `width` / `height` / `createdAt` などメタデータのみを書き出し、`remoteUrl` は常に null（Storage 採用見送りのため）

```kotlin
// shared/core — local + remote を合成（commonMain。Firestore SDK は呼ばない）
class CoffeeRepositoryImpl(
    private val local: CoffeeRepository,            // SQLDelight（shared/data-local の LocalCoffeeRepository）
    private val remote: RemoteCoffeeDataSource,      // プラットフォーム別実装を注入
    private val writePolicy: WritePolicy = WritePolicy.PropagateRemoteFailure,
) : CoffeeRepository {

    override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = local.observeAll(userId)

    override suspend fun save(record: CoffeeRecord) {
        local.save(record)                           // 1) まずローカル（UI 即時更新）
        runRemote { remote.upload(record) }          // 2) 並行でリモート（WritePolicy に従う）
    }

    override suspend fun delete(userId: String, id: String) {
        local.delete(userId, id)
        runRemote { remote.remove(userId, id) }
    }

    fun startSync(userId: String, scope: CoroutineScope) {
        scope.launch {
            remote.observeChanges(userId).collect { records ->
                // reconciliation: スナップショットに無い id は他端末で削除済みとみなしローカルからも削除
                // （dev ダミーデータ DummyCoffeeData.ids はローカル専用のため除外）
                val remoteIds = records.map { it.id }.toSet()
                local.observeAll(userId).first()
                    .filter { it.id !in remoteIds && it.id !in DummyCoffeeData.ids }
                    .forEach { local.delete(userId, it.id) }
                records.forEach { local.save(it) }
            }
        }
    }

    private suspend fun runRemote(block: suspend () -> Unit) =
        when (writePolicy) {
            WritePolicy.PropagateRemoteFailure -> block()
            WritePolicy.IgnoreRemoteFailure -> runCatching { block() }.let { }
        }
}
```

> iOS / Android が実装するのは `RemoteCoffeeDataSource`（Firestore SDK 直叩き）だけ。photos を埋め込み配列にしたため、observe は `coffees` リスナ 1 本で完結（子の都度取得は不要）、upload は単一ドキュメント `set`、remove は単一ドキュメント `delete` で済む。

## 4.3 SavedCafeRepository（フェーズ 15-A）

`CoffeeRepository` と同じ 2 段構成をそのまま踏襲する（新パターンは持ち込まない）。

```kotlin
// shared/domain — UI から見える API
interface SavedCafeRepository {
    fun observeAll(userId: String): Flow<List<SavedCafe>>                       // マップピン / 一覧シート用
    fun observeByPlaceId(userId: String, placeId: String): Flow<SavedCafe?>     // カフェ詳細のトグル状態用
    suspend fun save(savedCafe: SavedCafe)                                      // 保存（同一 placeId は上書き）
    suspend fun delete(userId: String, placeId: String)                         // 解除
}

// shared/domain — プラットフォーム別に実装する薄いリモートアダプタ
interface RemoteSavedCafeDataSource {
    fun observeChanges(userId: String): Flow<List<SavedCafe>>
    suspend fun upload(savedCafe: SavedCafe)
    suspend fun remove(userId: String, placeId: String)
}
```

- 合成クラス `SavedCafeRepositoryImpl`（`shared/core`）: 読み取りは SQLDelight を Single Source、書き込みはローカル → リモート順、`WritePolicy` 共用、`startSync` は **coffees と同じスナップショット reconciliation**（スナップショットに無い place_id のローカル行を削除。dev ダミーデータのような除外対象は無し）
- 実装先: Android = `shared/data-firebase/androidMain`、iOS = `iosApp` 側 Swift（`FirebaseRepositories/` の既存 `RemoteCoffeeDataSource` 実装と同居）
- ViewModel 配線（公開 API は加算的変更のみ）: `MapViewModel` に `savedCafes` の購読 + ピン用状態 + 一覧シート状態、`CafeDetailViewModel` に `isSaved` トグル状態と save/delete アクション

---

# 5. ID 採番

- すべてのエンティティ ID は **クライアント側で UUID v4 を採番** する
- Firestore のドキュメント ID もこの UUID を使う（auto-id は使わない）
- 端末オフラインでも採番できる、複数端末間で衝突しない、SQLDelight と Firestore で同じ ID を使えるメリットがある
- **例外: `SavedCafe` は `cafe.placeId` を自然キーにする**（§1.9。同一カフェの二重登録を型レベルで防ぎ、保存 / 解除を冪等トグルにするため。UUID は持たない）

---

# 6. 日時の扱い

- `kotlinx-datetime` を使う
- `visitedOn`: `LocalDate`（タイムゾーン非依存。ユーザーが「いつ飲んだか」を表現）
- `createdAt` / `updatedAt`: `Instant`（UTC エポック millis）
- Firestore では `Timestamp` 型として保存し、ドメインモデルに戻す時に `Instant` へ変換

---

# 7. バリデーション

- `rating` は null（未評価）または 0.5..5.0 の範囲（0.5 刻み）。**未評価のままの保存を許可する**（2026-07-12 B-4。「まず記録、あとで評価」を可能に）。非 null 時のみ 0.5..5.0 かつ 0.5 刻みをバリデーション
- `name`（コーヒー名）は必須・最大 200 文字（SQLite の現実的な上限）
- `notes` は最大 2000 文字
- `cafe` は任意（未選択でもセルフ抽出として保存可能）
- バリデーションは **ViewModel 層で行う**（ドメインモデル自体は値を信用する）

---

## 参考リンク

- [SQLDelight](https://sqldelight.github.io/sqldelight/)
- [Firestore — データモデル](https://firebase.google.com/docs/firestore/data-model)
- [Firestore — オフライン永続化](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
- [Google Places API](https://developers.google.com/maps/documentation/places/web-service)
- [アーキテクチャ方針](./architecture.md)
