package com.noricoffee.domain.usecase

import com.noricoffee.domain.BeanProfile
import com.noricoffee.domain.OriginNormalizer
import com.noricoffee.domain.ProcessingMethod

/**
 * [BeanProfile] リストに対して origin / processing でファジーマッチしてスコアリングする UseCase。
 *
 * ## スコアリング
 * | フィールド | マッチ方式 | スコア |
 * |---|---|---|
 * | `origin` | [OriginNormalizer.normalize] 後の完全一致 | +2 |
 * | `origin` | 正規化後の contains（どちらかが他方を含む） | +1 |
 * | `processings` | enum 完全一致（いずれか 1 件） | +1 |
 *
 * - 完全一致と部分一致はどちらか一方のみ（完全一致優先、else ブランチで部分一致チェック）
 * - score > 0 のもののみを降順でソートして返す
 * - `origin` と `processing` がともに null の場合は全件 score 0 → 空リストを返す
 *
 * @see [docs/data-model.md] §1.8
 */
class BeanProfileMatchUseCase {

    /**
     * [profiles] を [origin] / [processing] でスコアリングし、score > 0 のものを降順で返す。
     *
     * @param profiles マッチ対象のプロファイルリスト（通常は [BeanProfileRepository.getAll] の結果）
     * @param origin 入力された産地文字列（null の場合は origin スコアは 0）
     * @param processing 選択された精製方法（null の場合は processing スコアは 0）
     */
    operator fun invoke(
        profiles: List<BeanProfile>,
        origin: String?,
        processing: ProcessingMethod?,
    ): List<BeanProfile> =
        profiles
            .mapNotNull { profile ->
                val score = score(profile, origin, processing)
                if (score > 0) profile to score else null
            }
            .sortedByDescending { it.second }
            .map { it.first }

    private fun score(
        profile: BeanProfile,
        origin: String?,
        processing: ProcessingMethod?,
    ): Int {
        var score = 0

        // origin スコアリング（完全一致 +2、部分一致 +1）
        if (origin != null) {
            val normalizedInput = OriginNormalizer.normalize(origin)
            val normalizedProfile = OriginNormalizer.normalize(profile.origin)
            score += when {
                normalizedProfile == normalizedInput -> 2
                normalizedProfile.contains(normalizedInput) ||
                    normalizedInput.contains(normalizedProfile) -> 1
                else -> 0
            }
        }

        // processing スコアリング（enum 完全一致で +1）
        if (processing != null && profile.processings.contains(processing)) {
            score += 1
        }

        return score
    }
}
