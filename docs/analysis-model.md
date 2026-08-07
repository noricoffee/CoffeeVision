# 分析モデル（派生集計）

`CoffeeRecord` 群から**決定論的に算出する派生モデル**の正本。**いずれも永続化しない**（SQLDelight / Firestore 表現を持たない）ため、永続エンティティの正本である [`data-model.md`](./data-model.md) から分離している（2026-07-25。分離前は data-model.md §1.6 / §1.7 / §1.7a）。

対象:

- `CoffeeStats`（分析タブの階層1 記述統計 + 階層2 傾向抽出。階層3 = Foundation Models への唯一の入力）— §1
- `CoffeeInsightProvider` / `CoffeeRecordQuery`（階層3 の自然言語解釈インターフェースと生レコード照会）— §1 内
- `RecommendedCafe`（味覚プロファイル一致カフェ / 要件 9-5・9-6）— §2
- `UnexploredBeanSuggestion`（未経験の豆への探索提案 / 要件 9-8）— §3

> **この doc に書くこと / 書かないこと**は [`data-model.md`](./data-model.md) 前文と同じ基準に従う（ソースの逐語コピーと経緯・実測値は置かない）。統計定数の根拠や不採用案は [`implementation_note.md`](./implementation_note.md) が正本。
>
> 永続エンティティ（`CoffeeRecord` / `Cafe` / `Photo` / `BeanProfile` / `SavedCafe` / `CuratedCafe` / `AuthAccount`）と 4 表現のマッピング規則は [`data-model.md`](./data-model.md)。要件は [`requirements.md`](./requirements.md) §9。

---

## 1. CoffeeStats（分析の集計モデル）

`shared/domain/src/commonMain/kotlin/com/noricoffee/domain/model/CoffeeStats.kt`

分析タブ（[`requirements.md`](./requirements.md) §9）の **階層1（記述統計）+ 階層2（傾向抽出）** の結果。`CoffeeRecord` 群から `BuildCoffeeStatsUseCase` が決定論的に生成する。**永続化しない派生モデル**（DB / Firestore 表現は持たない）。この `CoffeeStats` が ① 統計 UI の入力であり、② 階層3（Foundation Models）に渡す**唯一の入力**でもある（生レコードは LLM に渡さない）。

```kotlin
data class CoffeeStats(
    val totalCount: Int,                       // 全記録件数
    val ratedCount: Int,                       // rating != null の件数
    val averageRating: Double?,                // 未評価(rating == null)除外の平均。全未評価なら null
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

```

構成要素（すべて `model/CoffeeStats.kt`。全 `averageRating` は「未評価除外・全未評価なら null」で共通）:

| 型 | フィールド |
|---|---|
| `RatingBucket` | `rating: Double` / `count: Int` |
| `CategoryStat` | `label: String`（enum 名 or 正規化済み産地）/ `count` / `averageRating: Double?` |
| `MonthlyStat` | `yearMonth: String`（"YYYY-MM"）/ `count` / `averageRating: Double?` |
| `CafeStat` | `placeId` / `name` / `count` / `averageRating: Double?` |
| `RecordDigest` | `name` / `rating: Double` / `cafeName: String?`（セルフ抽出は null）/ `visitedOn: LocalDate` |
| `TastingAverages` | 5 軸の平均 `Double?` + `ratedCount: Int`（all-or-nothing なので 5 軸共通の母数） |
| `TastingAxis` | enum `Sweetness` / `Body` / `Acidity` / `Flavor` / `Aftertaste` |
| `TastingAxisCorrelation` | `axis: TastingAxis` / `correlation: Double`（ピアソン r、符号付き）/ `sampleSize: Int` |
| `FavoriteSignals` | `bestBrewMethod` / `bestOrigin` / `bestRoastLevel` / `bestProcessing`（各 `CategoryStat?`。収縮平均で全体平均を上回った軸のみ）/ `dominantTastingAxis: TastingAxisCorrelation?` / `minSampleSize: Int`（既定 3） |
| `PreferredBeanTraits` | `matchedProfiles: List<BeanProfile>` / `dominantFlavorNotes`（flavorNotes 頻度 top-5）/ `originHint` / `roastLevelHint` / `dominantTastingAxis`（いずれも信号なしは null）。フェーズ 12-C。`model/PreferredBeanTraits.kt` |

### 集計ルール（決定論）

- **平均評価**: `rating == null`（未評価）は常に母数から除外。対象が 0 件なら `null`。
- **`favoriteSignals`（階層2 / 好み判定）**: 「複数の評価から好みを統計的に抽出する」層。**生平均のランキングはサンプル数の罠に弱い**（n=1 の 5.0 が最上位に来る）ため、以下の補正を入れる。出力は常に **「弱い傾向」止まり**（断定しない。理由は交絡 = 下記）。
  - **カテゴリ好み（`bestBrewMethod` / `bestOrigin` / `bestRoastLevel` / `bestProcessing`）= 収縮平均による選定**（4 軸すべて同一ロジック。`bestProcessing` は `processing != null` のレコードを enum 名でグループ化して選定）:
    1. 母数: `rating != null` の評価済みレコード。全体平均 `globalMean` を算出（評価済み 0 件なら 3 つとも `null`）。
    2. 候補: 各軸で件数 `>= minSampleSize`（既定 3）かつ平均評価ありの label。
    3. **経験ベイズ収縮**: 各候補の評価を `shrunkMean = (n·mean + k·globalMean) / (n + k)` で全体平均へ寄せる（`k = SHRINKAGE_PRIOR_WEIGHT`、既定 5 ＝「全体平均を 5 杯ぶん事前に混ぜる」）。少数群の極端値を抑える。
    4. 選定: `shrunkMean` 最大の候補（n=1 外れ値に頑健な選定キー）。ただし信号化は **n 連動の信頼区間ゲート**で足切りする: `mean - globalMean > CATEGORY_Z · globalStd / sqrt(n)`（一標本 z 検定近似。`globalStd` = 全評価済 rating の母標準偏差、`n` = 候補群の件数、`mean` = 候補群の生平均）。これを満たす最良候補だけ信号にする。**固定オフセット δ では特異度が上がらない**（winner's curse がばらつき σ/√n に比例して膨らむため）＝ **閾値はばらつき連動（n 連動）にするのが要点**。`CATEGORY_MIN_EFFECT = 0.20` は「統計的有意だが実用上は誤差レベル」を弾く絶対下限として z ゲートと AND で併用する。
    5. 返す `CategoryStat` は**生の `averageRating` と `count`**（収縮値・effect-size は選定/足切りの内部利用のみ。`count` が小さければ言語化で「但し書き」に使う）。タイ時は件数多 → label 昇順で決定論化。
  - **好みの軸（`dominantTastingAxis`）= テイスティング軸と評価の相関**:
    1. 母数: `tasting != null` かつ `rating != null` の記録。`CORRELATION_MIN_SAMPLE`（既定 5）未満なら `null`。
    2. 5 軸それぞれと `rating` の**ピアソン相関係数 r**（符号付き）を計算。分散 0 の軸（全件同値）は相関定義不可のためスキップ。
    3. `|r|` 最大の軸を採用。ただし **`|r|` が下限（サンプル数連動。下記の定数）以上のときだけ**信号にする（弱すぎる相関は出さない）。`r > 0`＝「その軸が高いほど高評価」、`r < 0`＝「低いほど高評価」として言語化に渡す。**5 軸の max|r| を採る多重比較で偽陽性が乗る**ため、固定 0.3 ではなくサンプル数に応じて締める。
  - **交絡（confounding）は計算しない（仕様）**: 「産地が好き」か「その産地を多く出す店が好き」かは個人の観測データでは分離不能。層別すると各層の n が枯れ、有意性検定も前提が崩れる。よって**多変量解析・検定は行わず**、上記の「件数ガード＋収縮＋相関閾値」というヒューリスティックで「弱い傾向」だけを出す。LLM へもこの但し書き付きで渡す（断定させない）。
  - **定数**（`BuildCoffeeStatsUseCase.companion` に公開、将来変更可）: `SHRINKAGE_PRIOR_WEIGHT = 5`（選定キー shrunkMean 用）/ `CORRELATION_MIN_SAMPLE = 5` / `CATEGORY_Z = 2.0`（z ゲート係数 ≈95% 信頼区間。`globalStd == 0` は z ゲートをスキップし δ 下限のみ）/ `CATEGORY_MIN_EFFECT = 0.20` / テイスティング軸の |r| 下限 = `max(CORRELATION_MIN_ABS, CORRELATION_ABS_FLOOR_C / sqrt(n))`（`0.3` と `1.97` の併用。n=30 で実効 ≈0.36）。`minSampleSize` は `FavoriteSignals` 既定 3。
  - **これらの値の根拠（偽陽性率の実測値・不採用案・sweep 条件）は [`implementation_note.md`](./implementation_note.md) 2026-06-22「好み判定の統計設計」が正本**。定数を動かすときは `FavoriteSignalsPersonaTest`（150 シード）で検出力 P1–P4・P7 の維持を確認する。
- **産地**: 分析が見るのは `origin`（国名）**のみ**。`region`（エリア / 農園）は表示専用で集計に使わない（2026-07-22 分離）。origin は国ドロップダウン（`CoffeeOriginCatalog`。[`data-model.md`](./data-model.md) §1.3a）由来で概ね正規形に揃うが、`BeanProfile.origin` や legacy 自由文字列との名寄せのため引き続き `OriginNormalizer` を通す。グループキーは **`OriginNormalizer.normalize` の正規化値**（trim + lowercase → シノニム辞書の完全キー一致で正規形へ。「Ethiopia」「イルガチェフェ」→「エチオピア」。辞書外は素通し。辞書の正本は `shared/domain/.../OriginNormalizer.kt`、2026-07-08 導入）、**表示ラベルはグループ内最初に出現したレコードの元表記（`trim()` のみ）** を採用（ユーザー入力の表記を尊重）。複合文字列（「エチオピア イルガチェフェ」等）は辞書の完全キー一致にヒットせず独立グループのまま（突合側の contains で拾う。既知の限界）。
- **`recentHighlights`**: 階層3 の Q&A / 要約が具体名に言及できるよう、**`rating >= 4.0`** の高評価かつ直近の代表レコードを少数含める。
- **`tastingAverages`**: `tasting != null` の記録だけを母数に、5 要素それぞれの平均。tasting を持つ記録が 1 件も無ければ各要素 `null`。`ratedCount` = tasting を持つ記録件数（all-or-nothing なので 5 要素で共通。UI が「n 件の平均」を出せる）。
- **上位 N / 件数の定数**（`BuildCoffeeStatsUseCase.companion`。将来変更可）: `ORIGIN_RANKING_LIMIT = 10` / `TOP_CAFES_LIMIT = 10` / `RECENT_HIGHLIGHTS_LIMIT = 5` / `HIGHLIGHTS_MIN_RATING = 4.0`（**`HIGHLIGHTS_MIN_RATING` のみ `private`** = UseCase 内部専用。同じ 4.0 を使う §2 の推薦は別定数 `ObserveTasteMatchedCafesUseCase.RECOMMEND_MIN_RATING` を持つ）。

> `ObserveCoffeeStatsUseCase` が `CoffeeRepository.observeAll(userId)` を `map` して `Flow<CoffeeStats>` を返す。`favoriteSignals` は階層3（要約・Q&A）の `buildPrompt` にも「弱い傾向＋件数の但し書き」として渡し、LLM は断定させない。

### 階層3（自然言語解釈）のインターフェース

iOS の Foundation Models 実装を `shared/domain` のインターフェースで抽象化し、プラットフォーム非対称を吸収する（Firebase の `RemoteCoffeeDataSource` と同じパターン）。

**`interface CoffeeInsightProvider`**（iOS = Foundation Models 実装 / Android = 注入しない = 分析タブ非表示。全メソッド `suspend` + `@Throws`）:

| メソッド | 用途 |
|---|---|
| `summarize(stats): CoffeeInsight` | 階層3 要約。`CoffeeStats` から headline / body を構造化生成 |
| `answer(question, stats): String` | 対話 Q&A v1。digest のみを文脈に 1 問 1 答。整形済み日本語プレーンテキスト（`@Generable` 不使用） |
| `summarizeBeanTraits(traits): CoffeeInsight?` | 好みの豆傾向の言語化（12-C）。**null 返却可**（不可時は UI がフレーバータグのみ表示にフォールバック） |

**`data class CoffeeInsight`**: `headline: String` / `body: String`。

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

`shared/domain` に 3 つ（`model/CoffeeRecordQuery.kt`。フィールドごとのマッチ仕様は同ファイルの KDoc が詳しい）:

- **`interface CoffeeRecordQuery`**: `suspend fun searchRecords(filter): List<CoffeeRecordSummary>` の 1 メソッドのみ（`@Throws`）
- **`data class CoffeeRecordFilter`**: `origin` / `brewMethod` / `roastLevel` / `cafeName` / `minRating` / `maxRating` / `fromYearMonth` / `toYearMonth`（"YYYY-MM"、両端含む）/ `tastingMin` / `tastingMax`（`TastingScores`）/ `limit`（既定 10・上限 100）。**全フィールド optional**（全 null = フィルタなし）
- **`data class CoffeeRecordSummary`**: `name` / `cafeName?` / `origin?` / `brewMethod`（enum 名）/ `roastLevel?`（enum 名）/ `rating`（**非 null `Double`。`0.0` = 未評価**）/ `visitedOn`（"YYYY-MM-DD"）

設計上の決め事:

- **単一の柔軟な検索 tool**: 複数の専用 tool に分けず、`searchRecords` 1 本に絞り込み条件を optional で並べる。Foundation Models は引数説明が充実した単一 tool の方が安定し、KMP 照会 API も 1 メソッドで済む。
- **filter は全て String/Double/Int（enum を持ち込まない）**: LLM が生成する文字列を KMP 側で寛容にマッチする。`brewMethod`/`roastLevel` は enum `.name` を大小無視 + 部分一致、未評価（domain の `rating == null`）は評価範囲フィルタの対象外として扱う。これでブリッジが単純かつ LLM 出力に頑健になる。**`CoffeeRecordSummary.rating` はこの境界の例外として `Double` のまま `0.0 = 未評価` を維持**（マッピングは `record.rating ?: 0.0`。domain の nullable 化 = 2026-07-12 B-4 後も、LLM ブリッジは primitive 主義を優先。iOS 側の `>= 0.5` 表示分岐はこの仕様に依存）。
- **`origin`/`cafeName` はフィールド横断の free-text term**（2026-06-21 横断化）: 各 term が `record.cafe?.name`（カフェ名）/ `record.origin`（産地）/ `record.name`（コーヒー名）/ `record.variety`（品種）のいずれかに部分一致（大小無視）すればマッチ。両方指定時は AND（各 term がそれぞれ union のいずれかにヒット）。どちらも null ならこのテキスト条件は無視。背景: Foundation Models が `cafeName` と `origin` を誤分類しても確実にヒットさせるため（例: "フグレン" を `origin` に入れても cafe 名にマッチ）。トレードオフとして、コーヒー名に地名が含まれる場合の偽陽性が増えるが個人アプリ規模では許容。
- **userId は実装（`CoffeeRecordQueryImpl`）が内部で解決**: Swift は filter だけ渡す。全件取得 → インメモリ filter → `visitedOn` 降順 → `limit` 件（個人アプリ規模の数十〜数百件では全件読みで十分）。`CoffeeRepository` + `AuthRepository` の**インターフェースのみに依存**させ（テスト容易）、`AppContainer` が組み立てて公開する。
- **digest はベース文脈として併用（ハイブリッド）**: tool は digest で足りないときだけ LLM が呼ぶ。プロンプトには引き続き `buildPrompt(stats)` の digest を含める。
- **既存インターフェース・VM・UI は不変**: `CoffeeInsightProvider.answer(question, stats)` のシグネチャは据え置き、iOS 実装が内部で tool を登録するだけ。`AnalysisViewModel` / Q&A UI は変更しない（変更は純粋に加算的）。ブリッジ方向（Swift→Kotlin calling direction）と配線は [`kmp-bridge.md`](./kmp-bridge.md) を参照。

---

## 2. RecommendedCafe（味覚プロファイル一致カフェ / 要件 9-5）

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

**`interface CafeRecommendationProvider`**: `fun observeRecommendedCafes(userId): Flow<List<RecommendedCafe>>` の 1 メソッドのみ。`MapViewModel` はこの interface にだけ依存し、中身（ローカル集計 / 横断ベクトル類似）を知らない。

- **v1 実装 = `ObserveTasteMatchedCafesUseCase`**（ローカル決定論）。`CoffeeRepository.observeAll(userId)` ＋ `BuildCoffeeStatsUseCase` の `FavoriteSignals` から算出。
- **将来 9-6** はこの interface のリモート実装（横断ベクトル類似はサーバ側）を `AppContainer` で差し替えるだけ。`MapViewModel` / iOS UI / Foundation Models 言語化層は不変。

### 一致ルール（決定論 / v1 コンテンツベース）

あるカフェ（`cafe.placeId` でグループ化、`cafe == null` のセルフ抽出は座標が無いため対象外）に、次を**両方**満たす `CoffeeRecord` が 1 件以上あれば `RecommendedCafe` として返す:

1. `rating >= ObserveTasteMatchedCafesUseCase.RECOMMEND_MIN_RATING`（= 4.0。`recentHighlights` の `HIGHLIGHTS_MIN_RATING` と同値だが、あちらは `private` のため別定数として持つ）
2. かつ `FavoriteSignals` のカテゴリ好み（`bestOrigin` / `bestRoastLevel` / `bestBrewMethod` / `bestProcessing` のうち **非 null のもの**）のいずれかに一致:
   - `origin`: `OriginNormalizer.normalize`（trim + lowercase + シノニム辞書）で `bestOrigin.label` と一致（`buildOriginRanking` と同じ正規化）
   - `roastLevel`: enum 一致（`bestRoastLevel.label == record.roastLevel?.name`）
   - `brewMethod`: enum 一致（`bestBrewMethod.label == record.brewMethod.name`）
   - `processing`: enum 一致（`bestProcessing.label == record.processing?.name`）

- **`matches` の構築**: 一致した軸ごとに 1 つの `TasteProfileMatch` を作る。同じ軸に複数の一致記録があれば**評価最高の記録**を代表（`exampleRecordName` / `exampleRating`）に採用。タイは `visitedOn` 新しい順 → コーヒー名昇順で決定論化。
- **`dominantTastingAxis`（相関軸）は一致条件に使わない**: 相関は per-record の categorical 一致に変換できず、理由表示も曖昧になるため。カテゴリ好み 4 軸（産地 / 焙煎度 / 抽出方法 / 精製方法）に限定。
- **`FavoriteSignals` が全 null（データ不足）** なら一致 0 件 → 空リスト（マップは強調なし）。
- **並び順**: `matches` 件数降順 → 代表記録評価の最大降順 → placeId 昇順（決定論）。

### UI 連携（`MapViewModel` / `CafeDetailViewModel` / iOS）

**`CafeRecommendationProvider` は 2 つの ViewModel が購読する**。マップは「どの店が一致しているか」（一覧）、カフェ詳細は「この店がなぜ一致しているか」（理由）を担い、役割で分かれている。

- `MapViewModel` は `observeRecommendedCafes(userId)` を購読し、`UIState` に `recommendedCafes: List<RecommendedCafe>` と一致 placeId 集合を加える（既存 `visitedCafes` 購読と同パターン）。用途は**ピンの区別と一覧シート**。
- `CafeDetailViewModel` も同じ provider を購読し、自 `placeId` に一致するエントリの理由を `UIState.matches: List<RecommendationReason>` として公開する（一致なし = 空リスト。nullable にしない）。2026-08-07 に追加。
- iOS `MapTabView`: 一致カフェを**区別ピン**（pink + ハートバッジ）で示す。**タップは他の概念ピンと同じくカフェ詳細へ直行**する（2026-08-07 に変更。旧実装はピンタップで推薦理由のモーダルシートを挟んでいた）。
- iOS `CafeDetailView`: `matches` が非空なら店名直下に「好み一致」セクションを出し、軸ごとの理由を並べる。理由文言（「好みの産地: Ethiopia」+ 代表記録 ★4.5）は iOS でローカライズ生成。**マップ以外の経路（コーヒー記録一覧など）で開いても表示される**のが移設の主目的。
- **Foundation Models 連携は将来 9-6 で「推薦理由の自然言語化」一点に限定**（v1 は構造化 reason を iOS が定型文で表示。LLM は使わない）。

> **再計算コストの注記**: `ObserveTasteMatchedCafesUseCase` は全記録を毎回集計する。provider は `AppContainer` のファクトリで**都度生成**するため、マップと詳細が同時にアクティブな間は集計が二重に走る。カフェ詳細は push / pop ごとの生成・破棄で常駐しないこと、個人アプリの記録件数規模から、現状は許容と判断（2026-08-07）。共有化するなら `AppContainer` 側で `shareIn` する設計変更になる。

### 9-6 協調フィルタリング（リモート実装 / 設計確定 2026-07-21・未実装）

9-5（ローカル・既訪問の再訪）に**追加**で載る新規開拓推薦。`CafeRecommendationProvider` のリモート実装として差し替える（`MapViewModel` / iOS UI / 理由表示層は不変）。**実装はインフラ選定から段階着手**（tasks 12-D）。

- **同意**: 新規 `recommendationConsent`（[`data-model.md`](./data-model.md) §3.2 の `users/{uid}`。`analyticsConsent` とは目的別・オプトイン・既定 false）。ON かつ記録変更時に自プロファイルを再計算し `sharedTasteProfiles/{uid}` へ upsert、OFF で削除（共有撤回）。
- **共有プロファイル `sharedTasteProfiles/{uid}`**（`beanProfiles` / `curatedCafes` と同型のグローバルコレクション。[`data-model.md`](./data-model.md) §3.2 / §3.3 参照）: 特徴ベクトルのみを持ち、生メモ・タグ・記録本文・カフェ名は含めない（プライバシー最小化）。
  - `tastingVector`: `tastingAverages` 5 軸（`Double?`。null 軸は cosine で欠損扱い）
  - `categoryPrefs`: `bestOrigin` / `bestRoastLevel` / `bestBrewMethod` / `bestProcessing` のラベル（null 可）
  - `highRatedCafes`: 高評価（rating ≥ 4.0）カフェの `[{placeId, lat, lng, rating}]`（地理制約に座標が要るため座標を持つ。店名は placeId から詳細解決）
  - `updatedAt`
- **類似度**: `tastingVector` 5 軸 cosine を主軸に、`categoryPrefs` 4 軸の一致をスコア加味（tasting 未入力ユーザーはカテゴリで fallback して母集団が痩せない）。
- **計算は Cloud Function（callable）に閉じる**: クライアントは `{center, radiusMeters}` を渡し、`[{placeId, lat, lng, similarUserCount}]` だけ受け取る。**横断 read はサーバ特権のみで、クライアントは他人のプロファイル・uid・生データを一切見ない**（プライバシー設計の核）。
- **理由表示**: `RecommendationReason.SimilarUsers(count)`。9-5（既訪問・ハートピン）と視覚区別。最小 K 未満は推薦を出さない（個人特定回避 + コールドスタート時は空 = ピンが出ないだけ）。

> **意思決定 6 点の理由（同意フラグを分離した根拠 / クライアント直 KNN 案の不採用理由 / 役割分担 など）と未決事項（閾値 K・N・R / Function 内の類似計算方式 / インフラ選定 / FM 言語化の範囲）は [`implementation_note.md`](./implementation_note.md) 2026-07-21 が正本**。

---

## 3. UnexploredBeanSuggestion（未経験の豆への探索提案 / 要件 9-8・フェーズ 15-E-3）

好み信号に合致するが**ユーザーがまだ飲んでいない** `BeanProfile` を提案する派生集計（永続化しない）。9-5（既訪問店の**再訪**推薦）に対する**新規開拓**のナッジ。決定論（FM 不要）。

**`data class UnexploredBeanSuggestion`**: `profile: BeanProfile`（提案する豆）/ `matchedOriginLabel: String`（マッチ理由の表示用ラベル。`FavoriteSignals.bestOrigin` 由来）。

**`SuggestUnexploredBeansUseCase`**（`shared/domain/.../usecase/`、決定論）: `invoke(records, profiles, signals)` → 上位 `SUGGESTED_BEANS_LIMIT`（= 5）件。

- **好み合致**: `signals.bestOrigin`（非 null のとき）に対し、既存 `BeanProfileMatchUseCase`（[`data-model.md`](./data-model.md) §1.8 の origin ファジーマッチ・スコアリング）を再利用して候補を選定・並べる（DRY）。`bestRoastLevel` / `bestBrewMethod` は `BeanProfile` に対応フィールドが無いため使わない（origin 主軸）
- **「未経験」判定 = (origin, variety) ペア**: `BeanProfile.variety != null` の候補は `(origin正規化, variety正規化)` ペアがユーザーの記録に無ければ未経験（同産地でも品種違いは別体験として提案）。`variety == null` の候補は origin のみで判定（その産地を一度でも記録済みなら経験済み扱い）。正規化は origin が `OriginNormalizer.normalize`（`buildOriginRanking` と同じ）、variety が `trim().lowercase()`（品種シノニムは対象外の非対称）
- **空になる条件**: `signals.bestOrigin == null`（好み未確定）/ `profiles` 空（BeanProfile 未投入）
- **配線**: `BuildCoffeeStatsUseCase.invoke(records, beanProfiles)` 内で `beanProfiles.isNotEmpty()` のときだけ計算し `CoffeeStats.unexploredBeanSuggestions` に格納（`preferredBeanTraits` = 12-C と同じ流儀。`ObserveCoffeeStatsUseCase` に `BeanProfileRepository?` を注入した端末でのみ非空）。`readiness`（UI メタ）と違い**ドメイン実質のある派生値**なので `CoffeeStats` 内に置く
- **LLM 非混入**: iOS の `buildPrompt(from: stats)` はフィールドを選択的に読む実装のため、本フィールドを buildPrompt に足さない限り Foundation Models の digest には入らない（分析タブ UI 表示専用）

---

## 参考リンク

- [データモデル（永続エンティティ）](./data-model.md)
- [要件定義 §9 分析タブ](./requirements.md)
- [実装ノート（統計設計の経緯・実測値）](./implementation_note.md)
- [KMP ブリッジ（Foundation Models 連携の配線）](./kmp-bridge.md)

