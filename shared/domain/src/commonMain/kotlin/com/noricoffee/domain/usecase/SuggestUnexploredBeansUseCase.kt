package com.noricoffee.domain.usecase

import com.noricoffee.domain.BeanProfile
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.model.FavoriteSignals
import com.noricoffee.domain.model.UnexploredBeanSuggestion

/**
 * [FavoriteSignals.bestOrigin] に合致するが、ユーザーがまだ記録していない [BeanProfile] を提案する
 * 決定論の UseCase（Foundation Models 不要。フェーズ 15-E-3 / 要件 9-8）。
 *
 * - **合致軸は origin のみ**: [BeanProfile] には焙煎度・抽出方法に対応するフィールドが無いため、
 *   [FavoriteSignals.bestRoastLevel] / [FavoriteSignals.bestBrewMethod] は使わない
 * - **origin のファジーマッチ・スコアリングは [BeanProfileMatchUseCase] を再利用**する
 *   （[docs/data-model.md] §1.8 と同じ trim/lowercase 完全一致 +2 / 部分一致 +1 のロジック。スコア降順で返る）
 * - **「未経験」の判定は origin + variety のペアで行う**:
 *   - [BeanProfile.variety] が null の候補は origin のみで判定する
 *     （ユーザーがその産地を一度でも記録していれば経験済み扱い。品種情報が無いので、これ以上絞り込めない）
 *   - [BeanProfile.variety] が非 null の候補は (origin, variety) の正規化ペアで判定する
 *     （同じ産地でも品種違いは別の体験として残す。産地だけ一致していても未経験として提案対象になり得る）
 * - 純粋関数（IO なし）のため、テストが容易
 *
 * @see [BeanProfileMatchUseCase] origin マッチ・スコアリングの参照実装
 * @see [docs/data-model.md] §1.8（BeanProfile 参照）
 */
class SuggestUnexploredBeansUseCase(
    private val beanProfileMatchUseCase: BeanProfileMatchUseCase = BeanProfileMatchUseCase(),
) {

    /**
     * @param records ユーザーの全 [CoffeeRecord]（記録済み origin / variety 集合の算出に使う）
     * @param profiles Firestore から取得した全 [BeanProfile] リスト
     * @param signals [BuildCoffeeStatsUseCase] が算出した [FavoriteSignals]
     * @return 好み合致 かつ 未経験の [BeanProfile] 提案（スコア降順）上位 [SUGGESTED_BEANS_LIMIT] 件。
     *   [FavoriteSignals.bestOrigin] が null、または [profiles] が空なら空リスト
     */
    operator fun invoke(
        records: List<CoffeeRecord>,
        profiles: List<BeanProfile>,
        signals: FavoriteSignals,
    ): List<UnexploredBeanSuggestion> {
        val originLabel = signals.bestOrigin?.label ?: return emptyList()
        if (profiles.isEmpty()) return emptyList()

        val recordedPairs = mutableSetOf<Pair<String, String?>>()
        val recordedOrigins = mutableSetOf<String>()
        for (record in records) {
            val normalizedOrigin = record.origin?.trim()?.lowercase() ?: continue
            val normalizedVariety = record.variety?.trim()?.lowercase()
            recordedOrigins.add(normalizedOrigin)
            recordedPairs.add(normalizedOrigin to normalizedVariety)
        }

        return beanProfileMatchUseCase(profiles, origin = originLabel, processing = null)
            .filter { profile -> isUnexplored(profile, recordedPairs, recordedOrigins) }
            .take(SUGGESTED_BEANS_LIMIT)
            .map { profile -> UnexploredBeanSuggestion(profile = profile, matchedOriginLabel = originLabel) }
    }

    /**
     * [profile] がユーザー未経験かどうかを判定する（内部ヘルパ）。
     *
     * variety が null の候補は origin のみで判定し、variety がある候補は (origin, variety) の
     * 正規化ペアで判定する（同一産地でも品種違いは未経験扱いにする）。
     */
    private fun isUnexplored(
        profile: BeanProfile,
        recordedPairs: Set<Pair<String, String?>>,
        recordedOrigins: Set<String>,
    ): Boolean {
        val normalizedOrigin = profile.origin.trim().lowercase()
        val normalizedVariety = profile.variety?.trim()?.lowercase()
        return if (normalizedVariety == null) {
            normalizedOrigin !in recordedOrigins
        } else {
            (normalizedOrigin to normalizedVariety) !in recordedPairs
        }
    }

    companion object {
        /** 返す提案の上位件数。 */
        const val SUGGESTED_BEANS_LIMIT = 5
    }
}
