package com.noricoffee.domain.usecase

import com.noricoffee.domain.BeanProfile
import com.noricoffee.domain.model.FavoriteSignals
import com.noricoffee.domain.model.PreferredBeanTraits

/**
 * [FavoriteSignals] と [BeanProfile] リストを突合し、ユーザーが好みやすい豆の特徴を導出する UseCase。
 *
 * - origin の突合は [BeanProfileMatchUseCase] と同じ trim/lowercase 部分一致ロジックを採用する
 * - flavorNotes の頻度集計はマッチしたプロファイルのみを対象にする
 * - 純粋関数（IO なし）のため、テストが容易
 *
 * @see [BeanProfileMatchUseCase] origin マッチロジックの参照実装
 * @see [data-model.md] §1.8（BeanProfile 参照）
 */
class PreferredBeanTraitsUseCase {

    /**
     * @param profiles Firestore から取得した全 [BeanProfile] リスト
     * @param signals [BuildCoffeeStatsUseCase] が算出した [FavoriteSignals]
     * @return 突合結果。`originHint` が null かつ `dominantFlavorNotes` が空のとき UI は非表示にする
     */
    operator fun invoke(profiles: List<BeanProfile>, signals: FavoriteSignals): PreferredBeanTraits {
        val originLabel = signals.bestOrigin?.label

        val matched = if (originLabel != null) {
            val needle = originLabel.trim().lowercase()
            profiles.filter { profile ->
                val hay = profile.origin.trim().lowercase()
                hay == needle || hay.contains(needle) || needle.contains(hay)
            }
        } else {
            emptyList()
        }

        val dominantFlavorNotes = matched
            .flatMap { it.flavorNotes }
            .groupingBy { it }
            .eachCount()
            .entries
            .sortedByDescending { it.value }
            .take(TOP_FLAVOR_NOTES_LIMIT)
            .map { it.key }

        return PreferredBeanTraits(
            matchedProfiles = matched,
            dominantFlavorNotes = dominantFlavorNotes,
            originHint = originLabel,
            roastLevelHint = signals.bestRoastLevel?.label,
            dominantTastingAxis = signals.dominantTastingAxis?.axis,
        )
    }

    companion object {
        const val TOP_FLAVOR_NOTES_LIMIT = 5
    }
}
