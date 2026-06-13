package com.noricoffee.domain.usecase

import com.noricoffee.domain.Visit
import com.noricoffee.domain.model.VisitedCafe
import com.noricoffee.repository.VisitRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn

/**
 * ユーザーが訪れたカフェを集計して [VisitedCafe] のリストとして返す UseCase。
 *
 * [VisitRepository.observeAll] の `Flow<List<Visit>>` を `place_id` ごとに集計し、
 * 最新訪問日降順に並べて返す。
 *
 * ## 集計ロジック
 * 1. [Visit.cafe.placeId] でグループ化
 * 2. 各グループから最新 [Visit] の `cafe` スナップショットを採用（最新値勝ち）
 * 3. `lastVisitedAt` = グループ内最新 [Visit.visitedOn] の UTC 開始 Instant
 * 4. `visitCount` = グループ内 Visit 件数
 * 5. `averageRating` = [Visit.rating] が 1 以上のものを平均（全件 0 なら null を返す）
 *    ※ 現行 [Visit.rating] は `Int`（1–5 または 0 未入力）。0 を「未評価」として除外する
 * 6. `lastVisitedAt` 降順でソート
 *
 * ## rating 0 の扱い
 * ドメインモデル上 `rating: Int`（非 nullable）だが、バリデーションで「0 は未入力」とする設計。
 * 将来 `rating: Int?` に変更した場合は、除外条件を `null` チェックに変えること。
 *
 * @param visitRepository [Visit] の観測に使うリポジトリ
 */
class ObserveVisitedCafesUseCase(
    private val visitRepository: VisitRepository,
) {

    /**
     * 指定ユーザーの訪問を集計した [VisitedCafe] の Flow を返す。
     *
     * @param userId 対象ユーザーの ID
     * @return 最新訪問日降順に並んだ [VisitedCafe] の Flow
     */
    operator fun invoke(userId: String): Flow<List<VisitedCafe>> =
        visitRepository.observeAll(userId).map { visits ->
            visits
                .groupBy { it.cafe.placeId }
                .map { (_, group) -> group.toVisitedCafe() }
                .sortedByDescending { it.lastVisitedAt }
        }

    private fun List<Visit>.toVisitedCafe(): VisitedCafe {
        // 最新訪問の Visit（visitedOn が最も新しいもの）
        val latest = maxBy { it.visitedOn }
        val lastVisitedAt = latest.visitedOn.toInstant()

        val validRatings = map { it.rating }.filter { it > 0 }
        val averageRating = if (validRatings.isEmpty()) {
            null
        } else {
            validRatings.sum().toDouble() / validRatings.size
        }

        return VisitedCafe(
            cafe = latest.cafe,
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
