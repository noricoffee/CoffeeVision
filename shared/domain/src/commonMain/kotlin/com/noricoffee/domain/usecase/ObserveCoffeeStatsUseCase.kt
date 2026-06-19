package com.noricoffee.domain.usecase

import com.noricoffee.domain.model.CoffeeStats
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * [CoffeeRepository] を観測して [CoffeeStats] の Flow を返す UseCase。
 *
 * [CoffeeRepository.observeAll] を `map` し、[BuildCoffeeStatsUseCase] で集計することで
 * コーヒー記録の変化をリアルタイムに分析 UI へ反映できる。
 *
 * @param coffeeRepository コーヒー記録の観測に使うリポジトリ
 * @param buildCoffeeStatsUseCase 集計 UseCase。テストで差し替えられるよう外部注入
 */
class ObserveCoffeeStatsUseCase(
    private val coffeeRepository: CoffeeRepository,
    private val buildCoffeeStatsUseCase: BuildCoffeeStatsUseCase = BuildCoffeeStatsUseCase(),
) {

    /**
     * 指定ユーザーのコーヒー記録を集計した [CoffeeStats] の Flow を返す。
     *
     * レコードが変化するたびに新しい [CoffeeStats] が emit される。
     *
     * @param userId 対象ユーザーの ID
     * @return 最新の集計結果を持つ Flow
     */
    operator fun invoke(userId: String): Flow<CoffeeStats> =
        coffeeRepository.observeAll(userId).map { records ->
            buildCoffeeStatsUseCase(records)
        }
}
