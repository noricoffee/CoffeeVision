package com.noricoffee.domain.model

import com.noricoffee.domain.BeanProfile

/**
 * 好みの産地に近いが、ユーザーがまだ記録していない [BeanProfile] の探索提案 1 件（フェーズ 15-E-3 / 要件 9-8）。
 *
 * [com.noricoffee.domain.usecase.SuggestUnexploredBeansUseCase] が決定論的に生成する。
 * 永続化しない（[CoffeeStats.unexploredBeanSuggestions] として保持される）。
 *
 * @property profile 提案する豆プロファイル
 * @property matchedOriginLabel マッチ理由として使った [FavoriteSignals.bestOrigin] のラベル（表示用）
 *
 * @see [com.noricoffee.domain.usecase.SuggestUnexploredBeansUseCase]
 */
data class UnexploredBeanSuggestion(
    val profile: BeanProfile,
    val matchedOriginLabel: String,
)
