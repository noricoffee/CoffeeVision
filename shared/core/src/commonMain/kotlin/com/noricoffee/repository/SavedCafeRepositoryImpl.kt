package com.noricoffee.repository

import com.noricoffee.domain.model.SavedCafe
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * [LocalSavedCafeRepository]（SQLDelight）と [RemoteSavedCafeDataSource]（Firestore）を合成した
 * [SavedCafeRepository] 実装。
 *
 * [CoffeeRepositoryImpl] と同じ 2 段構成をそのまま踏襲する（[data-model.md] §4.3）。
 * `WritePolicy` は [CoffeeRepositoryImpl.WritePolicy] を共用し、新しい enum を作らない。
 *
 * - **読み取り**: ローカル DB をそのまま流す
 * - **書き込み**: ローカル → リモートの順序を保証する
 * - **同期**: [startSync] は coffees と同じスナップショット reconciliation を行う
 *   （スナップショットに無い placeId のローカル行を削除。dev ダミーデータのような除外対象は無し）
 *
 * @param local SQLDelight ベースのローカル実装。実体は [LocalSavedCafeRepository]
 * @param remote Firestore 等のリモートデータソース。実装はプラットフォーム別
 * @param writePolicy 書き込み時のリモート失敗を「無視」「例外伝播」のどちらにするか
 */
class SavedCafeRepositoryImpl(
    private val local: SavedCafeRepository,
    private val remote: RemoteSavedCafeDataSource,
    private val writePolicy: CoffeeRepositoryImpl.WritePolicy = CoffeeRepositoryImpl.WritePolicy.PropagateRemoteFailure,
) : SavedCafeRepository {

    // --- 読み取り: ローカル DB を Single Source として流す ---

    override fun observeAll(userId: String): Flow<List<SavedCafe>> =
        local.observeAll(userId)

    override fun observeByPlaceId(userId: String, placeId: String): Flow<SavedCafe?> =
        local.observeByPlaceId(userId, placeId)

    // --- 書き込み: ローカル → リモートの順序を共通層で保証 ---

    override suspend fun save(savedCafe: SavedCafe) {
        local.save(savedCafe)
        runRemote { remote.upload(savedCafe) }
    }

    override suspend fun delete(userId: String, placeId: String) {
        local.delete(userId, placeId)
        runRemote { remote.remove(userId, placeId) }
    }

    /**
     * リモート変更の購読を開始し、ローカル DB に反映する。
     *
     * [CoffeeRepositoryImpl.startSync] と同じスナップショット reconciliation を行う:
     * 1. スナップショットに存在しない placeId のローカル行を削除する（他端末での解除をローカルに伝播）
     * 2. スナップショットの全件を upsert する
     *
     * dev ダミーデータのような除外対象は無い（SavedCafe に dev シードデータは存在しないため）。
     *
     * 上流が回復不能な失敗で例外終了したときの扱いも [CoffeeRepositoryImpl.startSync] と同じ
     * （リトライせず同期だけ止め、ローカル DB ベースの動作は続ける）。
     */
    fun startSync(userId: String, scope: CoroutineScope): Job =
        scope.launch {
            try {
                remote.observeChanges(userId).collect { savedCafes ->
                    val remotePlaceIds = savedCafes.map { it.cafe.placeId }.toSet()
                    local.observeAll(userId).first()
                        .filter { it.cafe.placeId !in remotePlaceIds }
                        .forEach { local.delete(userId, it.cafe.placeId) }
                    savedCafes.forEach { local.save(it) }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                println("[SavedCafeRepositoryImpl] リモート同期を停止しました (userId=$userId): $e")
            }
        }

    private suspend fun runRemote(block: suspend () -> Unit) {
        when (writePolicy) {
            CoffeeRepositoryImpl.WritePolicy.PropagateRemoteFailure -> block()
            CoffeeRepositoryImpl.WritePolicy.IgnoreRemoteFailure -> try {
                block()
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // Firestore のオフライン永続化による再送に委ねる
            }
        }
    }
}
