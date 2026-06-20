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

/**
 * 0.5 刻みの評価 1 バケットの度数。
 *
 * [rating] は 0.5..5.0 の値（0.5 刻み）。0.0（未評価）は含まない。
 */
data class RatingBucket(val rating: Double, val count: Int)

/**
 * カテゴリ軸の統計情報（抽出方法 / 焙煎度 / 精製方法 / 産地 など）。
 *
 * @param label enum.name または正規化済み産地文字列
 * @param count このカテゴリに属するレコード件数
 * @param averageRating このカテゴリ内の平均評価（未評価(0.0)除外、全未評価なら null）
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
 * @param averageRating その月の平均評価（未評価(0.0)除外、全未評価なら null）
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
 * @param averageRating このカフェでの平均評価（未評価(0.0)除外、全未評価なら null）
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
 * @param rating 評価値（0.5..5.0。0.0 = 未評価は通常含まないが防御的に許容）
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
 * 階層2（傾向抽出）の結果。
 *
 * 高評価群（rating >= 4.0）に共通する属性を最小サンプル数の閾値付きで抽出する。
 * Phase B-1 まで全フィールドは null（空の [FavoriteSignals] を返す）。
 *
 * @param bestBrewMethod 平均評価が突出する抽出方法（閾値未満なら null）
 * @param bestOrigin 平均評価が突出する産地（閾値未満なら null）
 * @param bestRoastLevel 平均評価が突出する焙煎度（閾値未満なら null）
 * @param minSampleSize この件数未満の群は信号にしない（既定 3）。サンプル不足の過大解釈を防ぐガード
 */
data class FavoriteSignals(
    val bestBrewMethod: CategoryStat? = null,
    val bestOrigin: CategoryStat? = null,
    val bestRoastLevel: CategoryStat? = null,
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
 * 各要素は `null`（未設定）の記録を母数から除外した平均。
 * 1 件も設定が無い要素は `null`。
 * [ratedCount] に各要素の設定済み件数を入れる（UI が「n 件の平均」を出せる）。
 *
 * @see [data-model.md] §1.6 集計ルール
 */
data class TastingAverages(
    val sweetness: Double?,                    // 甘味の平均（設定済み記録のみ、無ければ null）
    val body: Double?,
    val acidity: Double?,
    val flavor: Double?,
    val aftertaste: Double?,
    val ratedCount: TastingRatedCount,         // 各要素の母数（設定済み件数）
)

/**
 * テイスティング 5 要素それぞれの設定済みレコード件数。
 *
 * [TastingAverages.ratedCount] として格納され、UI が「n 件の平均」を表示できる。
 */
data class TastingRatedCount(
    val sweetness: Int,
    val body: Int,
    val acidity: Int,
    val flavor: Int,
    val aftertaste: Int,
)
