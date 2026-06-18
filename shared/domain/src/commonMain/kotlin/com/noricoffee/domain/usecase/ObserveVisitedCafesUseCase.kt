package com.noricoffee.domain.usecase

import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.model.VisitedCafe
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn

/**
 * ユーザーのコーヒー記録からカフェを集計して [VisitedCafe] のリストとして返す UseCase。
 *
 * [CoffeeRepository.observeAll] の `Flow<List<CoffeeRecord>>` のうち **`cafe != null` のもの** を
 * `cafe.placeId` ごとに集計し、最新訪問日降順に並べて返す。
 * `cafe == null`（セルフ抽出）は座標が無くマップに出せないため集計対象外。
 *
 * ## 集計ロジック
 * 1. `cafe != null` のレコードのみフィルタ
 * 2. [CoffeeRecord.cafe.placeId] でグループ化
 * 3. 各グループから最新 [CoffeeRecord] の `cafe` スナップショットを採用（最新値勝ち）
 * 4. `lastVisitedAt` = グループ内最新 [CoffeeRecord.visitedOn] の UTC 開始 Instant
 * 5. `visitCount` = グループ内 CoffeeRecord 件数
 * 6. `averageRating` = [CoffeeRecord.rating] が 1 以上のものを平均（全件 0 なら null を返す）
 * 7. `lastVisitedAt` 降順でソート
 *
 * @param coffeeRepository [CoffeeRecord] の観測に使うリポジトリ
 */
class ObserveVisitedCafesUseCase(
    private val coffeeRepository: CoffeeRepository,
) {

    /**
     * 指定ユーザーのコーヒー記録を集計した [VisitedCafe] の Flow を返す。
     *
     * @param userId 対象ユーザーの ID
     * @return 最新訪問日降順に並んだ [VisitedCafe] の Flow
     */
    operator fun invoke(userId: String): Flow<List<VisitedCafe>> =
        coffeeRepository.observeAll(userId).map { records ->
            records
                .filter { it.cafe != null }
                .groupBy { it.cafe!!.placeId }
                .map { (_, group) -> group.toVisitedCafe() }
                .sortedByDescending { it.lastVisitedAt }
        }

    private fun List<CoffeeRecord>.toVisitedCafe(): VisitedCafe {
        // 最新記録（visitedOn が最も新しいもの）
        val latest = maxBy { it.visitedOn }
        val lastVisitedAt = latest.visitedOn.toInstant()

        val validRatings = map { it.rating }.filter { it > 0 }
        val averageRating = if (validRatings.isEmpty()) {
            null
        } else {
            validRatings.sum().toDouble() / validRatings.size
        }

        return VisitedCafe(
            cafe = latest.cafe!!,
            lastVisitedAt = lastVisitedAt,
            visitCount = size,
            averageRating = averageRating,
        )
    }

    /**
     * [LocalDate] を UTC 日付の開始時刻（00:00:00 UTC）の [Instant] に変換する。
     *
     * `visitedOn` は日付のみのフィールドのため、比較・ソート用途に UTC 基点の Instant を使う。
     * iOS 表示では `visitedOn` を直接使うことを推奨（タイムゾーンずれなし）。
     */
    private fun LocalDate.toInstant(): Instant =
        atStartOfDayIn(TimeZone.UTC)
}
