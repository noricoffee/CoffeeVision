package com.noricoffee.domain.model

import com.noricoffee.domain.BeanProfile

/**
 * ユーザーが好みやすい豆の特徴をまとめた派生モデル（Phase 12-C）。
 *
 * [FavoriteSignals] と [BeanProfile] を突合し、
 * [com.noricoffee.domain.usecase.PreferredBeanTraitsUseCase] が決定論的に生成する。
 * 永続化しない（[CoffeeStats.preferredBeanTraits] として保持される）。
 *
 * @param matchedProfiles [FavoriteSignals.bestOrigin] のラベルと origin が部分一致するプロファイル一覧
 * @param dominantFlavorNotes マッチしたプロファイルの flavorNotes を頻度集計した降順 top-5
 * @param originHint [FavoriteSignals.bestOrigin] のラベル（産地のヒント）。信号がない場合は null
 * @param roastLevelHint [FavoriteSignals.bestRoastLevel] のラベル（焙煎度のヒント）。信号がない場合は null
 * @param dominantTastingAxis [FavoriteSignals.dominantTastingAxis] の axis（最も相関するテイスティング軸）。信号がない場合は null
 *
 * @see [data-model.md] §1.8（BeanProfile 参照）
 * @see [com.noricoffee.domain.usecase.PreferredBeanTraitsUseCase]
 */
data class PreferredBeanTraits(
    val matchedProfiles: List<BeanProfile>,
    val dominantFlavorNotes: List<String>,    // 頻度降順 top-5
    val originHint: String?,
    val roastLevelHint: String?,
    val dominantTastingAxis: TastingAxis?,
)
