package com.noricoffee.domain.model

import kotlinx.datetime.LocalDate

/**
 * 分析タブ（[requirements.md] §9）の **階層1（記述統計）+ 階層2（傾向抽出）** の結果をまとめた集計モデル。
 *
 * [com.noricoffee.domain.CoffeeRecord] 群から [com.noricoffee.domain.usecase.BuildCoffeeStatsUseCase] が
 * 決定論的に生成する。**永続化しない派生モデル**（DB / Firestore 表現は持たない）。
 *
 * この `CoffeeStats` が:
 * 1. 統計 UI の入力
 * 2. 階層3（Foundation Models）に渡す**唯一の入力**（生レコードは LLM に渡さない）
 *
 * @see [data-model.md] §1.6
 */
data class CoffeeStats(
    val totalCount: Int,                       // 全記録件数
    val ratedCount: Int,                       // rating != null の件数
    val averageRating: Double?,                // 未評価(null)除外の平均。全未評価なら null
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
    val preferredBeanTraits: PreferredBeanTraits? = null, // 階層2+: 好みの産地 × BeanProfile 突合結果（Phase 12-C）
    val unexploredBeanSuggestions: List<UnexploredBeanSuggestion> = emptyList(), // 好みに合致するが未経験の BeanProfile 提案（フェーズ 15-E-3 / 要件 9-8）
)

/**
 * 0.5 刻みの評価 1 バケットの度数。
 *
 * [rating] は 0.5..5.0 の値（0.5 刻み）。未評価（null）のレコードは含まない。
 */
data class RatingBucket(val rating: Double, val count: Int)

/**
 * カテゴリ軸の統計情報（抽出方法 / 焙煎度 / 精製方法 / 産地 など）。
 *
 * @param label enum.name または正規化済み産地文字列
 * @param count このカテゴリに属するレコード件数
 * @param averageRating このカテゴリ内の平均評価（未評価(null)除外、全未評価なら null）
 */
data class CategoryStat(
    val label: String,
    val count: Int,
    val averageRating: Double?,
)

/**
 * 月次推移の 1 エントリ。
 *
 * @param yearMonth "YYYY-MM" 形式
 * @param count その月の記録件数
 * @param averageRating その月の平均評価（未評価(null)除外、全未評価なら null）
 */
data class MonthlyStat(
    val yearMonth: String,
    val count: Int,
    val averageRating: Double?,
)

/**
 * よく行くカフェの統計情報。
 *
 * cafe が null のレコード（セルフ抽出）は集計対象外。
 *
 * @param placeId Google Places の place_id
 * @param name 最新記録時のカフェ名スナップショット
 * @param count このカフェでのコーヒー記録件数
 * @param averageRating このカフェでの平均評価（未評価(null)除外、全未評価なら null）
 */
data class CafeStat(
    val placeId: String,
    val name: String,
    val count: Int,
    val averageRating: Double?,
)

/**
 * Q&A 文脈向けの代表レコードの要約。
 *
 * [com.noricoffee.domain.CoffeeStats.recentHighlights] に格納され、
 * 階層3（Foundation Models）が具体名に言及できるよう高評価かつ直近のレコードを少数含める。
 *
 * @param name コーヒー名
 * @param rating 評価値（0.5..5.0。recentHighlights は高評価済みレコードのみ対象のため常に非 null）
 * @param cafeName カフェ名（セルフ抽出は null）
 * @param visitedOn 飲んだ日
 */
data class RecordDigest(
    val name: String,
    val rating: Double,
    val cafeName: String?,
    val visitedOn: LocalDate,
)

/**
 * テイスティング 5 軸の識別子。
 *
 * [FavoriteSignals.dominantTastingAxis] で評価と最も相関する軸を特定するために使う。
 * Blue Bottle「Elements of Coffee Tasting」の 5 要素に対応する。
 *
 * @see [TastingAxisCorrelation]
 * @see [data-model.md] §1.6 集計ルール（dominantTastingAxis）
 */
enum class TastingAxis { Sweetness, Body, Acidity, Flavor, Aftertaste }

/**
 * テイスティング 1 軸と評価（rating）のピアソン相関係数の計算結果。
 *
 * @param axis 相関が最大だった軸
 * @param correlation ピアソン相関係数 r（-1.0..1.0、符号付き）。
 *   r > 0 ＝「その軸が高いほど高評価」、r < 0 ＝「低いほど高評価」
 * @param sampleSize 相関の母数（tasting != null かつ rating != null の件数）
 */
data class TastingAxisCorrelation(
    val axis: TastingAxis,
    val correlation: Double,
    val sampleSize: Int,
)

/**
 * 階層2（傾向抽出）の結果。
 *
 * 評価済みレコード群から経験ベイズ収縮＋相関分析で「弱い好み傾向」を抽出する。
 * Phase B-1 で実体化。
 *
 * @param bestBrewMethod 収縮平均で全体平均を最も上回る抽出方法（正方向のみ。閾値未満なら null）
 * @param bestOrigin 同上、産地
 * @param bestRoastLevel 同上、焙煎度
 * @param bestProcessing 同上、精製方法（[bestRoastLevel] と対称のロジック）
 * @param dominantTastingAxis 評価と最も相関するテイスティング軸（|r| 閾値以上のみ。母数不足なら null）
 * @param minSampleSize この件数未満の群は信号にしない（既定 3）。サンプル不足の過大解釈を防ぐガード
 *
 * @see [BuildCoffeeStatsUseCase.SHRINKAGE_PRIOR_WEIGHT]
 * @see [BuildCoffeeStatsUseCase.CORRELATION_MIN_SAMPLE]
 * @see [BuildCoffeeStatsUseCase.CORRELATION_MIN_ABS]
 * @see [data-model.md] §1.6 集計ルール（favoriteSignals）
 */
data class FavoriteSignals(
    val bestBrewMethod: CategoryStat? = null,
    val bestOrigin: CategoryStat? = null,
    val bestRoastLevel: CategoryStat? = null,
    val bestProcessing: CategoryStat? = null,
    val dominantTastingAxis: TastingAxisCorrelation? = null,
    val minSampleSize: Int = 3,
)

/**
 * 階層3（自然言語解釈）のプロバイダインターフェース。
 *
 * iOS の Foundation Models 実装を `shared/domain` のインターフェースで抽象化し、
 * プラットフォーム非対称を吸収する（Firebase の [com.noricoffee.repository.RemoteCoffeeDataSource] と同じパターン）。
 *
 * - iOS 実装: `LanguageModelSession` を用い、`SystemLanguageModel.availability` で利用可否を判定
 * - Android / Apple Intelligence 無効端末: `AnalysisViewModel` には null が注入され、統計のみ表示にフォールバック
 *
 * Phase A では宣言のみ。実装は Phase A-4 で iOS 側に追加する。
 */
interface CoffeeInsightProvider {
    /**
     * [CoffeeStats] を入力に 2–3 文のサマリを生成する。
     *
     * @param stats 集計済みの統計情報。生レコードは渡さない（コンテキスト窓・正確性・再現性のため）
     * @return 生成されたインサイト
     * @throws Exception Foundation Models の呼び出しに失敗した場合
     */
    @Throws(Exception::class)
    suspend fun summarize(stats: CoffeeStats): CoffeeInsight

    /**
     * ユーザーの質問に [CoffeeStats] digest のみを文脈として 1 問 1 答で回答する（Phase B-2）。
     *
     * - **単発・ステートレス**: 会話履歴を持たない。[LanguageModelSession] は呼び出しごとに新規生成
     * - **接地制約**: [stats] の範囲でのみ回答し、digest に無い情報は「記録からは分かりません」と返す
     * - **逐次表示なし**: suspend 一発で最終回答 [String] を返す（streaming は Phase 2 以降）
     *
     * iOS 実装は `__answer(question:stats:completionHandler:)` の protocol witness 形式。
     * Android は [com.noricoffee.AppContainer] に null が注入されるため、実装は不要。
     *
     * @param question ユーザーが入力した質問テキスト（trim 済みであることを想定）
     * @param stats 集計済みの統計情報。LLM に渡す唯一の文脈（生レコードは渡さない）
     * @return 日本語プレーンテキストの回答（整形済み）
     * @throws Exception Foundation Models の呼び出しに失敗した場合
     */
    @Throws(Exception::class)
    suspend fun answer(question: String, stats: CoffeeStats): String

    /**
     * [PreferredBeanTraits] を入力に「好みの豆の傾向」を自然言語で言語化する（Phase 12-C）。
     *
     * - iOS 実装: Foundation Models で生成。`__summarizeBeanTraits(traits:completionHandler:)` として見える
     * - null を返す実装は許可（Foundation Models が利用できない端末向けのフォールバック）
     *
     * @param traits 好みの豆の特徴まとめ
     * @return 言語化されたインサイト。null の場合は UI はタグのみ表示にフォールバックする
     * @throws Exception Foundation Models の呼び出しに失敗した場合
     */
    @Throws(Exception::class)
    suspend fun summarizeBeanTraits(traits: PreferredBeanTraits): CoffeeInsight?
}

/**
 * Foundation Models が生成した自然言語サマリ。
 *
 * @param headline 短い見出し（1 文）
 * @param body 詳細説明（1–3 文）
 */
data class CoffeeInsight(
    val headline: String,
    val body: String,
)

/**
 * テイスティング 5 要素それぞれの平均値。
 *
 * all-or-nothing 方式のため、5 要素の母数は常に同一（`ratedCount` を共通の単一 Int で持つ）。
 * tasting を持つ記録が 1 件も無い場合は各要素 null、ratedCount = 0。
 *
 * @property sweetness 甘味の平均（tasting あり記録のみ。無ければ null）
 * @property body ボディの平均
 * @property acidity 酸味の平均
 * @property flavor 風味の平均
 * @property aftertaste 後味の平均
 * @property ratedCount tasting を持つ記録の件数（all-or-nothing なので 5 要素で共通）
 *
 * @see [data-model.md] §1.6 集計ルール
 */
data class TastingAverages(
    val sweetness: Double?,                    // 甘味の平均（tasting ありの記録のみ、無ければ null）
    val body: Double?,
    val acidity: Double?,
    val flavor: Double?,
    val aftertaste: Double?,
    val ratedCount: Int,                       // tasting を持つ記録の件数（all-or-nothing なので 5 要素共通）
)
