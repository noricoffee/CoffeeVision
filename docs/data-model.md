# データモデル

CoffeeVision のドメインモデルを **Kotlin（ドメイン）/ SQLDelight（ローカル DB）/ Firestore（クラウド）** の 3 表現で定義します。

> **2026-06-19 大改訂**: 「カフェ訪問（`Visit`）主体」から「**コーヒー記録（`CoffeeRecord`）主体**」へ再設計。`Visit` / `CoffeeItem` / `FoodItem` を廃止し、1 杯のコーヒー記録 `CoffeeRecord` を集約ルートにした。カフェは任意（`cafe: Cafe?`、null = セルフ抽出）。クリーンブレイク（データ移行なし）。経緯は [`implementation_note.md`](./implementation_note.md) 2026-06-19 エントリ参照。

エンティティ一覧:

- `CoffeeRecord`（コーヒー記録。集約ルート）
- `Cafe`（カフェ情報。`CoffeeRecord` に埋め込み、任意）
- `Photo`（写真。`CoffeeRecord` の子）

---

## エンティティ関連図

```
User (Firebase Auth uid)
  │
  └── CoffeeRecord (1..N)
        ├── Cafe              (0..1, 埋め込み / null = セルフ抽出)
        └── Photo             (0..N)
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
    val rating: Double,                   // 0.5..5.0（0.5 刻み）。0.0 = 未評価（sentinel）
    val notes: String,                    // 自由メモ（旧 ambiance / フード等もここに吸収）
    val photos: List<Photo>,
    // --- コーヒー属性（旧 CoffeeItem から昇格）---
    val name: String,                     // コーヒー名（必須）
    val brewMethod: BrewMethod,
    val origin: String?,                  // 産地（国 / エリア）
    val variety: String?,                 // 品種
    val processing: ProcessingMethod?,    // 精製方法
    val roastLevel: RoastLevel?,          // 焙煎度
    val cup: String?,                     // カップの種類 / ブランドメモ
    val tasting: TastingScores?,          // テイスティング 5 要素。null = 未記入。記入する場合は 5 要素すべて必須
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
)
```

> `CoffeeRecord.cafe` が null の場合はカフェに紐づかないセルフ抽出を表す。`Cafe` 自体の定義は不変。

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
    val averageRating: Double?,           // 記録の平均評価（rating=0.0 の未評価は除外、全て未評価なら null）
)
```

> マップ表示・カフェ集計用。`ObserveVisitedCafesUseCase` が `CoffeeRecord` のうち **`cafe != null` のものだけ** を `cafe.placeId` でグループ化して生成する。セルフ抽出（cafe == null）は集計対象外（座標が無くマップに出せないため）。名前は互換性のため `VisitedCafe` を維持するが、意味は「コーヒー記録のあるカフェ」。

## 1.6 CoffeeStats（分析用 集計モデル）

`shared/domain/src/commonMain/kotlin/com/noricoffee/domain/model/CoffeeStats.kt`

分析タブ（[`requirements.md`](./requirements.md) §9）の **階層1（記述統計）+ 階層2（傾向抽出）** の結果。`CoffeeRecord` 群から `BuildCoffeeStatsUseCase` が決定論的に生成する。**永続化しない派生モデル**（DB / Firestore 表現は持たない）。この `CoffeeStats` が ① 統計 UI の入力であり、② 階層3（Foundation Models）に渡す**唯一の入力**でもある（生レコードは LLM に渡さない）。

```kotlin
data class CoffeeStats(
    val totalCount: Int,                       // 全記録件数
    val ratedCount: Int,                       // rating >= 0.5 の件数
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
    val dominantTastingAxis: TastingAxisCorrelation?,  // 評価と最も相関するテイスティング軸（|r| 閾値以上のみ）
    val minSampleSize: Int,                    // この件数未満の群は信号にしない（既定 3）
)

data class TastingAxisCorrelation(
    val axis: TastingAxis,                     // 相関が最大だった軸
    val correlation: Double,                   // ピアソン相関係数 r（-1.0..1.0、符号付き）
    val sampleSize: Int,                       // 相関の母数（rating>0 かつ tasting!=null の件数）
)

enum class TastingAxis { Sweetness, Body, Acidity, Flavor, Aftertaste }
```

### 集計ルール（決定論）

- **平均評価**: `rating == 0.0`（未評価 sentinel）は常に母数から除外。対象が 0 件なら `null`。
- **`favoriteSignals`（階層2 / 好み判定）**: 「複数の評価から好みを統計的に抽出する」層。**生平均のランキングはサンプル数の罠に弱い**（n=1 の 5.0 が最上位に来る）ため、以下の補正を入れる。出力は常に **「弱い傾向」止まり**（断定しない。理由は交絡 = 下記）。
  - **カテゴリ好み（`bestBrewMethod` / `bestOrigin` / `bestRoastLevel`）= 収縮平均による選定**:
    1. 母数: `rating > 0.0` の評価済みレコード。全体平均 `globalMean` を算出（評価済み 0 件なら 3 つとも `null`）。
    2. 候補: 各軸で件数 `>= minSampleSize`（既定 3）かつ平均評価ありの label。
    3. **経験ベイズ収縮**: 各候補の評価を `shrunkMean = (n·mean + k·globalMean) / (n + k)` で全体平均へ寄せる（`k = SHRINKAGE_PRIOR_WEIGHT`、既定 5 ＝「全体平均を 5 杯ぶん事前に混ぜる」）。少数群の極端値を抑える。
    4. 選定: `shrunkMean` 最大の候補（n=1 外れ値に頑健な選定キー）。ただし信号化は **n 連動の信頼区間ゲート**で足切りする: `mean - globalMean > CATEGORY_Z · globalStd / sqrt(n)`（一標本 z 検定近似。`globalStd` = 全評価済 rating の母標準偏差、`n` = 候補群の件数、`mean` = 候補群の生平均）。これを満たす最良候補だけ信号にする。**固定オフセット δ（`shrunkMean - globalMean > δ`）は特異度を上げられない**（最良群の偶然の上振れ＝winner's curse がサンプリングばらつき σ/√n に比例して膨らみ、固定 δ では止まらない。B-1b 100% / B-1c 不均等でも 86.7% と実測）。よって**ばらつき連動（n 連動）の閾値**で足切りする。`CATEGORY_MIN_EFFECT = 0.20` は「統計的有意だが実用上は誤差レベル」を弾く小さな絶対下限として併用してよい（z ゲートと AND）。
    5. 返す `CategoryStat` は**生の `averageRating` と `count`**（収縮値・effect-size は選定/足切りの内部利用のみ。`count` が小さければ言語化で「但し書き」に使う）。タイ時は件数多 → label 昇順で決定論化。
  - **好みの軸（`dominantTastingAxis`）= テイスティング軸と評価の相関**:
    1. 母数: `tasting != null` かつ `rating > 0.0` の記録。`CORRELATION_MIN_SAMPLE`（既定 5）未満なら `null`。
    2. 5 軸それぞれと `rating` の**ピアソン相関係数 r**（符号付き）を計算。分散 0 の軸（全件同値）は相関定義不可のためスキップ。
    3. `|r|` 最大の軸を採用。ただし **`|r| >= CORRELATION_ABS_FLOOR`（サンプル数連動の下限。下記）のときだけ**信号にする（弱すぎる相関は出さない）。`r > 0`＝「その軸が高いほど高評価」、`r < 0`＝「低いほど高評価」として言語化に渡す。**5 軸の max|r| を採る多重比較で偽陽性が乗る**（B-1b 実測 40%）ため、固定 0.3 ではなくサンプル数に応じて締める。
  - **交絡（confounding）は計算しない（仕様）**: 「産地が好き」か「その産地を多く出す店が好き」かは個人の観測データでは分離不能。層別すると各層の n が枯れ、有意性検定も前提が崩れる。よって**多変量解析・検定は行わず**、上記の「件数ガード＋収縮＋相関閾値」というヒューリスティックで「弱い傾向」だけを出す。LLM へもこの但し書き付きで渡す（断定させない）。
  - **定数**（`BuildCoffeeStatsUseCase.companion` に公開、将来変更可）: `SHRINKAGE_PRIOR_WEIGHT = 5`（選定キー shrunkMean 用）/ `CORRELATION_MIN_SAMPLE = 5` / `CATEGORY_Z = 2.0`（カテゴリ z ゲート係数 ≈95% 信頼区間。B-1d sweep で確定。heavy-skew 偽陽性 9.3%・検出力 P2–P4 維持。`globalStd==0` は z ゲートをスキップしδ下限のみ）/ `CATEGORY_MIN_EFFECT = 0.20`（z ゲートと AND する絶対下限）/ テイスティング軸の |r| 下限 = `max(CORRELATION_MIN_ABS, CORRELATION_ABS_FLOOR_C / sqrt(n))`（`CORRELATION_MIN_ABS = 0.3` と `CORRELATION_ABS_FLOOR_C = 1.97` の併用。n=30 で実効 ≈0.36）。`minSampleSize` は `FavoriteSignals` 既定 3。値は `FavoriteSignalsPersonaTest` の sweep（150 シード）で検出力 P1–P4・P7 維持を確認して確定。
  - **既知の限界 / 経緯**: tasting 軸の偽陽性は 40%→22%（c 連動 floor、B-1c）。カテゴリ信号は固定 δ では下がらず（均等 100% / heavy-skew 86.7%、B-1d 前段実測）、**n 連動 z ゲートで根治**（B-1d 本体）。winner's curse は固定オフセットでなくばらつき連動の閾値で抑えるのが要点。詳細経緯は実装ノート 2026-06-22 B-1b〜B-1d。
- **産地（自由文字列）**: グループキーは `trim() + lowercase()` の正規化値、**表示ラベルはグループ内最初に出現したレコードの元表記（`trim()` のみ）** を採用（ユーザー入力の表記を尊重。表記ゆれの完全名寄せは将来課題）。
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
    val limit: Int = 10,
)

data class CoffeeRecordSummary(
    val name: String,
    val cafeName: String?,
    val origin: String?,
    val brewMethod: String,   // enum 名（iOS 側で日本語化）
    val roastLevel: String?,  // enum 名 or null
    val rating: Double,       // 0.0 = 未評価
    val visitedOn: String,    // "YYYY-MM-DD"
)
```

設計上の決め事:

- **単一の柔軟な検索 tool**: 複数の専用 tool に分けず、`searchRecords` 1 本に絞り込み条件を optional で並べる。Foundation Models は引数説明が充実した単一 tool の方が安定し、KMP 照会 API も 1 メソッドで済む。
- **filter は全て String/Double/Int（enum を持ち込まない）**: LLM が生成する文字列を KMP 側で寛容にマッチする。`brewMethod`/`roastLevel` は enum `.name` を大小無視 + 部分一致、`rating=0.0`（未評価 sentinel）は評価範囲フィルタの対象外として扱う。これでブリッジが単純かつ LLM 出力に頑健になる。
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
        val axis: PreferenceMatchAxis,    // Origin / RoastLevel / BrewMethod
        val matchedLabel: String,         // "Ethiopia" / "Light" / "AeroPress"（表示用ラベル）
        val exampleRecordName: String,    // 代表記録のコーヒー名
        val exampleRating: Double,        // その記録の評価
    ) : RecommendationReason
    // 将来（9-6 協調フィルタ）: SimilarUsers(count, ...) 等をここに追加（UI/VM/FM は不変のまま種類追加）
}

enum class PreferenceMatchAxis { Origin, RoastLevel, BrewMethod }
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
2. かつ `FavoriteSignals` のカテゴリ好み（`bestOrigin` / `bestRoastLevel` / `bestBrewMethod` のうち **非 null のもの**）のいずれかに一致:
   - `origin`: `trim().lowercase()` 正規化で `bestOrigin.label` と一致（`buildOriginRanking` と同じ正規化）
   - `roastLevel`: enum 一致（`bestRoastLevel.label == record.roastLevel?.name`）
   - `brewMethod`: enum 一致（`bestBrewMethod.label == record.brewMethod.name`）

- **`matches` の構築**: 一致した軸ごとに 1 つの `TasteProfileMatch` を作る。同じ軸に複数の一致記録があれば**評価最高の記録**を代表（`exampleRecordName` / `exampleRating`）に採用。タイは `visitedOn` 新しい順 → コーヒー名昇順で決定論化。
- **`dominantTastingAxis`（相関軸）は v1 では一致条件に使わない**: 相関は per-record の categorical 一致に変換できず、理由表示も曖昧になるため。カテゴリ好み 3 軸に限定。
- **`FavoriteSignals` が全 null（データ不足）** なら一致 0 件 → 空リスト（マップは強調なし）。
- **並び順**: `matches` 件数降順 → 代表記録評価の最大降順 → placeId 昇順（決定論）。

### マップ連携（`MapViewModel` / iOS）

- `MapViewModel` は `CafeRecommendationProvider.observeRecommendedCafes(userId)` を購読し、`UIState` に `recommendedCafes: List<RecommendedCafe>` と一致 placeId 集合を加える（既存 `visitedCafes` 購読と同パターン）。公開 API 追加は加算的。
- iOS `MapTabView`: 一致カフェを**区別ピン**（アクセント色＋ハート/星）で強調し、タップで理由（`matches`）を表示。理由文言（「好みのエチオピアを高評価で記録（〇〇 ★4.5）」）は iOS でローカライズ生成。
- **Foundation Models 連携は将来 9-6 で「推薦理由の自然言語化」一点に限定**（v1 は構造化 reason を iOS が定型文で表示。LLM は使わない）。

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
    rating REAL NOT NULL,                  -- 0.5..5.0（0.5 刻み）。0.0 = 未評価
    notes TEXT NOT NULL,
    -- コーヒー属性
    name TEXT NOT NULL,
    brew_method TEXT NOT NULL,             -- enum 文字列
    origin TEXT,
    variety TEXT,
    processing TEXT,                       -- enum 文字列
    roast_level TEXT,                      -- enum 文字列
    cup TEXT,
    -- テイスティング 5 要素（各 1..10）。5 列は all-or-nothing（全列 NULL = tasting なし / 全列セット = tasting あり）
    sweetness INTEGER,
    body INTEGER,
    acidity INTEGER,
    flavor INTEGER,
    aftertaste INTEGER,
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
    name, brew_method, origin, variety, processing, roast_level, cup,
    sweetness, body, acidity, flavor, aftertaste,
    created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

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

## 2.3 マッピング方針

- DB 行 ↔ ドメインモデル変換は `db/Mapper.kt` に集約する
- 子テーブル（photo）は別クエリで取得し、Repository でまとめる（JOIN は使わず、`Flow.combine` で結合）
- 写真の参照配列など複数値は **JSON 文字列**（`kotlinx.serialization`）で 1 列に格納する
- `cafe_place_id` が null の行は `cafe = null` で組み立てる。非 null の行のみ `Cafe(...)` を構築する

---

# 3. Firestore スキーマ

## 3.1 コレクション構造

```
users/{uid}
  coffees/{coffeeId}                      # CoffeeRecord 本体（Cafe 埋め込み / 評価 / メモ / photos 配列）
```

> **2026-06-19 改訂**: 旧 `visits` コレクション + サブコレクション（`coffeeItems` / `foodItems` / `photos`）を廃止。`coffees` コレクションの 1 ドキュメントに `cafe`（任意）と `photos`（埋め込み配列）を含める。子サブコレクションは持たない。

写真本体は Firestore / Storage に同期せず、端末の Documents 配下にのみ保存します（[`requirements.md`](./requirements.md) §7-2）。

### なぜ photos を埋め込み配列にしたか

- `CoffeeRecord` は 1 杯単位なので photos は数枚程度。Firestore の 1MB ドキュメント上限に十分収まる（photo はメタデータのみ、画像本体は端末ローカル）
- 子取得の N+1（record ごとに `getDocuments` を並列発行）と WriteBatch の差分 delete が不要になり、Android / iOS のリモート実装が大幅に簡素化される
- 子要素単位のリッスンは不要（1 杯のコーヒーをまとめて読み書きするため）

---

## 3.2 ドキュメント定義

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
  "variety": "SL28",
  "processing": "Washed",
  "roastLevel": "Medium",
  "cup": "ノリタケ",
  "tasting": {
    "sweetness": 7,
    "body": 5,
    "acidity": 9,
    "flavor": 7,
    "aftertaste": 6
  },
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
- **nullable なコーヒー属性**（origin / variety / processing / roastLevel / cup）: null の場合はキーごと省略
- **tasting**: `tasting != null` のとき 5 要素すべてを持つマップを書き出す。`tasting == null`（未記入）なら `tasting` マップごと省略。decode 時、`tasting` マップが存在し 5 要素揃っていれば `TastingScores`、欠如していれば `null`（防御的に、いずれかキー欠如も `null` 扱い）。SQLDelight も同様に **5 列全セット → `TastingScores` / それ以外 → `null`**
- **photos**: 埋め込み配列。`localPath` は端末固有値のため Firestore には書かない。`remoteUrl` も書かない（Storage 採用見送り）。`sortOrder` は配列 index を upload 時に採番、decode 時はソート用途で破棄
- `visitedOn` は `"YYYY-MM-DD"` 文字列、`createdAt` / `updatedAt` は Firestore `Timestamp`

---

## 3.3 Security Rules（概略）

```
service cloud.firestore {
  match /databases/{db}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == uid;
    }
  }
}
```

> path uid のみ検証する現行ルールで `coffees` もカバーされる（`{document=**}` ワイルドカード）。ルール本体の変更は不要。旧 `visits` の残置データは無視されるだけ（クリーンに保つなら手動削除）。

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

---

# 5. ID 採番

- すべてのエンティティ ID は **クライアント側で UUID v4 を採番** する
- Firestore のドキュメント ID もこの UUID を使う（auto-id は使わない）
- 端末オフラインでも採番できる、複数端末間で衝突しない、SQLDelight と Firestore で同じ ID を使えるメリットがある

---

# 6. 日時の扱い

- `kotlinx-datetime` を使う
- `visitedOn`: `LocalDate`（タイムゾーン非依存。ユーザーが「いつ飲んだか」を表現）
- `createdAt` / `updatedAt`: `Instant`（UTC エポック millis）
- Firestore では `Timestamp` 型として保存し、ドメインモデルに戻す時に `Instant` へ変換

---

# 7. バリデーション

- `rating` は 0.5..5.0 の範囲（0.5 刻み）。0.0 は未評価扱い（保存時はバリデーションで 0.5 以上を要求）
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
