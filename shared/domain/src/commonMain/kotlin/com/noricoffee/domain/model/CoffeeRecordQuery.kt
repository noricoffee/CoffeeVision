package com.noricoffee.domain.model

import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.TastingScores
import com.noricoffee.repository.AuthRepository
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.first

/**
 * iOS の Foundation Models `Tool`（function calling）から呼ばれる生レコード照会インターフェース（Phase B-3 / 9-4b）。
 *
 * - Swift は `CoffeeRecordQuery` を実装しない。`Tool.call` の中から呼ぶだけ（calling direction）。
 * - SKIE により `searchRecords(filter:) async throws -> [CoffeeRecordSummary]` が Swift に見える。
 * - `userId` は実装（[CoffeeRecordQueryImpl]）が内部で解決するため、Swift は [CoffeeRecordFilter] だけ渡す。
 *
 * @see [docs/data-model.md] §1.6「対話 Q&A v2」
 * @see [docs/kmp-bridge.md]「対話 Q&A v2（CoffeeRecordQuery.searchRecords）」
 */
interface CoffeeRecordQuery {

    /**
     * フィルター条件に一致するコーヒー記録の要約リストを返す。
     *
     * - フィルター条件が全て null の場合は全件（[CoffeeRecordFilter.limit] 件まで）を返す。
     * - 返却順序は `visitedOn` 降順（新しい記録が先）。
     *
     * @param filter 絞り込み条件。全フィールドが null の場合はフィルタなし。
     * @return 条件に一致する記録の要約リスト（最大 [CoffeeRecordFilter.limit] 件）
     * @throws Exception 認証失敗またはリポジトリエラー時
     */
    @Throws(Exception::class)
    suspend fun searchRecords(filter: CoffeeRecordFilter): List<CoffeeRecordSummary>
}

/**
 * [CoffeeRecordQuery.searchRecords] の絞り込み条件。
 *
 * 全フィールドが null（+ limit = 10 既定）のときはフィルタなし（全件 limit まで）を意味する。
 *
 * ## マッチング仕様
 *
 * - [origin] / [cafeName]: **フィールド横断の部分一致・大小無視**。
 *   どちらのフィールドに入っても、次の union のいずれかに部分一致すればマッチとする:
 *   `record.cafe?.name`（カフェ名）/ `record.origin`（産地）/ `record.name`（コーヒー名）/ `record.variety`（品種）。
 *   両方指定された場合は AND（各 term が union のいずれかにヒットすること）。
 *   どちらも null ならこのテキスト条件は無視する。
 * - [brewMethod] / [roastLevel]: enum `.name`（"HandDrip" 等）に対し大小無視 + 部分一致
 *   （例: "drip" は "HandDrip" にマッチ）。roastLevel が null のレコードは [roastLevel] 指定時は除外。
 * - [minRating] / [maxRating]: `rating` の範囲。`record.rating == null`（未評価。2026-07-12 B-4 で
 *   0.0 sentinel を廃止し nullable 化）は評価範囲フィルタが指定されている場合は除外
 *   （未評価を「評価済みとして扱う」誤りを防ぐ）。
 * - [fromYearMonth] / [toYearMonth]: `visitedOn` の年月（"YYYY-MM" 文字列比較）で範囲絞り込み。
 *   "YYYY-MM" 文字列の辞書順比較で正しく機能する（ISO-8601 年月形式の性質）。
 * - [tastingMin] / [tastingMax]: テイスティング各軸の範囲条件。`record.tasting == null`（未記録）は
 *   いずれかが指定されている場合は除外。各軸の比較は独立（すべての軸が範囲内に入る必要あり）。
 * - [limit]: 負数・0 は既定値 10 として扱う。100 超は 100 に clamp する。
 *
 * ## Swift からの呼び出し例
 * ```swift
 * let filter = CoffeeRecordFilter(
 *     origin: "エチオピア",
 *     brewMethod: nil,
 *     roastLevel: nil,
 *     cafeName: nil,
 *     minRating: nil,
 *     maxRating: nil,
 *     fromYearMonth: nil,
 *     toYearMonth: nil,
 *     tastingMin: nil,
 *     tastingMax: nil,
 *     limit: 10
 * )
 * let summaries = try await container.coffeeRecordQuery.searchRecords(filter: filter)
 * ```
 */
data class CoffeeRecordFilter(
    val origin: String? = null,         // free-text term（横断マッチ: cafe名/産地/コーヒー名/品種のいずれかに部分一致）
    val brewMethod: String? = null,     // 抽出方法（enum 名に寛容マッチ）
    val roastLevel: String? = null,     // 焙煎度（enum 名に寛容マッチ）
    val cafeName: String? = null,       // free-text term（横断マッチ: cafe名/産地/コーヒー名/品種のいずれかに部分一致）
    val minRating: Double? = null,      // 評価の下限（含む）
    val maxRating: Double? = null,      // 評価の上限（含む）
    val fromYearMonth: String? = null,  // "YYYY-MM" 以降（含む）
    val toYearMonth: String? = null,    // "YYYY-MM" まで（含む）
    val tastingMin: TastingScores? = null,  // テイスティング各軸の下限（null = 条件なし）
    val tastingMax: TastingScores? = null,  // テイスティング各軸の上限（null = 条件なし）
    val limit: Int = DEFAULT_LIMIT,     // 最大取得件数（負数/0 → 10、101 以上 → 100）
) {
    companion object {
        const val DEFAULT_LIMIT = 10
        const val MAX_LIMIT = 100
    }
}

/**
 * [CoffeeRecordQuery.searchRecords] が返す 1 件の要約。
 *
 * - [brewMethod]: `BrewMethod.name`（"HandDrip" 等）。iOS 側で日本語化する。
 * - [roastLevel]: `RoastLevel.name` または null（未設定）。
 * - [rating]: LLM ブリッジ境界の例外として `Double` を維持（domain の `CoffeeRecord.rating` は
 *   2026-07-12 B-4 で nullable 化済みだが、ここでは `0.0` を未評価 sentinel として使い続ける。
 *   マッピングは `record.rating ?: 0.0`）。
 * - [visitedOn]: "YYYY-MM-DD" 文字列（ISO-8601 LocalDate）。
 */
data class CoffeeRecordSummary(
    val name: String,
    val cafeName: String?,
    val origin: String?,
    val brewMethod: String,   // enum 名（iOS 側で日本語化）
    val roastLevel: String?,  // enum 名 or null
    val rating: Double,       // 0.0 = 未評価
    val visitedOn: String,    // "YYYY-MM-DD"
)

/**
 * [CoffeeRecordQuery] の共通層実装。
 *
 * [CoffeeRepository] + [AuthRepository] の **インターフェースのみ** に依存し（実装クラスに依存しない）、
 * テスト時は Fake で差し替え可能にする。
 *
 * ## 動作概要
 * 1. [AuthRepository.signInAnonymouslyIfNeeded] で uid を解決する
 * 2. [CoffeeRepository.observeAll] で全件取得し `first()` でスナップショット化する
 * 3. Kotlin で [CoffeeRecordFilter] を適用してフィルタ・ソート・limit を処理する
 * 4. [CoffeeRecordSummary] に変換して返す
 *
 * ## スケール前提
 * 個人アプリ規模（数十〜数百件）を想定した全件読み込み + インメモリフィルタ方式。
 * 件数が増えた場合は SQLDelight の WHERE 句での DB 側フィルタに移行する。
 *
 * @see [docs/data-model.md] §1.6「対話 Q&A v2」
 */
class CoffeeRecordQueryImpl(
    private val coffeeRepository: CoffeeRepository,
    private val authRepository: AuthRepository,
) : CoffeeRecordQuery {

    override suspend fun searchRecords(filter: CoffeeRecordFilter): List<CoffeeRecordSummary> {
        val uid = authRepository.signInAnonymouslyIfNeeded()
        val allRecords = coffeeRepository.observeAll(uid).first()
        val effectiveLimit = resolveLimit(filter.limit)
        return allRecords
            .filter { applyFilter(it, filter) }
            .sortedByDescending { it.visitedOn.toString() }
            .take(effectiveLimit)
            .map { it.toSummary() }
    }

    // ----- フィルタ適用 -----

    private fun applyFilter(record: CoffeeRecord, filter: CoffeeRecordFilter): Boolean {
        // origin / cafeName: フィールド横断の free-text term マッチ（AND）
        // 各 term が cafe名 / 産地 / コーヒー名 / 品種 のいずれかに部分一致すればヒット
        if (filter.origin != null && !matchesTextTerm(record, filter.origin)) return false
        if (filter.cafeName != null && !matchesTextTerm(record, filter.cafeName)) return false

        // brewMethod: enum.name に大小無視 + 部分一致
        if (filter.brewMethod != null) {
            val enumName = record.brewMethod.name
            if (!enumName.contains(filter.brewMethod, ignoreCase = true)) return false
        }

        // roastLevel: enum.name に大小無視 + 部分一致。roastLevel が null のレコードは除外
        if (filter.roastLevel != null) {
            val roastLevelValue = record.roastLevel ?: return false
            val enumName = roastLevelValue.name
            if (!enumName.contains(filter.roastLevel, ignoreCase = true)) return false
        }

        // 評価範囲フィルタ: rating=null（未評価）は除外
        val hasRatingFilter = filter.minRating != null || filter.maxRating != null
        if (hasRatingFilter) {
            val rating = record.rating ?: return false
            if (filter.minRating != null && rating < filter.minRating) return false
            if (filter.maxRating != null && rating > filter.maxRating) return false
        }

        // fromYearMonth / toYearMonth: visitedOn の "YYYY-MM" 文字列比較
        if (filter.fromYearMonth != null || filter.toYearMonth != null) {
            val yearMonth = record.visitedOn.toYearMonthString()
            if (filter.fromYearMonth != null && yearMonth < filter.fromYearMonth) return false
            if (filter.toYearMonth != null && yearMonth > filter.toYearMonth) return false
        }

        // テイスティングフィルタ: tasting なしのレコードは除外
        val hasTastingFilter = filter.tastingMin != null || filter.tastingMax != null
        if (hasTastingFilter) {
            val tasting = record.tasting ?: return false
            filter.tastingMin?.let { min ->
                if (tasting.sweetness < min.sweetness) return false
                if (tasting.body < min.body) return false
                if (tasting.acidity < min.acidity) return false
                if (tasting.flavor < min.flavor) return false
                if (tasting.aftertaste < min.aftertaste) return false
            }
            filter.tastingMax?.let { max ->
                if (tasting.sweetness > max.sweetness) return false
                if (tasting.body > max.body) return false
                if (tasting.acidity > max.acidity) return false
                if (tasting.flavor > max.flavor) return false
                if (tasting.aftertaste > max.aftertaste) return false
            }
        }

        return true
    }

    // ----- 変換 -----

    private fun CoffeeRecord.toSummary() = CoffeeRecordSummary(
        name = name,
        cafeName = cafe?.name,
        origin = origin,
        brewMethod = brewMethod.name,
        roastLevel = roastLevel?.name,
        rating = rating ?: 0.0, // LLM ブリッジ境界の例外: domain の null を 0.0 sentinel に写す
        visitedOn = visitedOn.toString(), // LocalDate.toString() は "YYYY-MM-DD"
    )

    // ----- ヘルパ -----

    /**
     * `term` がレコードのテキスト union（カフェ名 / 産地 / コーヒー名 / 品種）のいずれかに
     * 部分一致（大小無視）するか判定する。
     *
     * LLM が `origin` と `cafeName` を誤分類した場合でも、
     * どちらのフィールドに入っていても同じ union に当てるためのフィールド横断マッチ。
     *
     * - `record.cafe?.name`: cafe が null（セルフ抽出）のときは比較対象から除外
     * - `record.origin`: null のときは比較対象から除外
     * - `record.name`: コーヒー名（必須フィールド、常に比較対象）
     * - `record.variety`: null のときは比較対象から除外
     */
    private fun matchesTextTerm(record: CoffeeRecord, term: String): Boolean {
        val candidates = listOfNotNull(
            record.cafe?.name,
            record.origin,
            record.name,
            record.variety,
        )
        return candidates.any { it.contains(term, ignoreCase = true) }
    }

    /**
     * LocalDate を "YYYY-MM" 形式に変換する。
     *
     * [kotlinx.datetime.LocalDate.toString] は "YYYY-MM-DD" を返すため、先頭 7 文字を取る。
     */
    private fun kotlinx.datetime.LocalDate.toYearMonthString(): String =
        toString().take(7)

    /**
     * limit の妥当性ガード。
     *
     * - 負数・0 → [CoffeeRecordFilter.DEFAULT_LIMIT]（= 10）
     * - [CoffeeRecordFilter.MAX_LIMIT] 超 → [CoffeeRecordFilter.MAX_LIMIT]（= 100）
     * - それ以外はそのまま返す
     */
    private fun resolveLimit(limit: Int): Int = when {
        limit <= 0 -> CoffeeRecordFilter.DEFAULT_LIMIT
        limit > CoffeeRecordFilter.MAX_LIMIT -> CoffeeRecordFilter.MAX_LIMIT
        else -> limit
    }
}
