package com.noricoffee.repository

import com.noricoffee.dev.DummyCoffeeData
import com.noricoffee.domain.CoffeeRecord
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * [LocalCoffeeRepository]（SQLDelight）と [RemoteCoffeeDataSource]（Firestore）を合成した
 * [CoffeeRepository] 実装。
 *
 * ## 設計方針
 *
 * - UI は [CoffeeRepository] 1 本だけを見る
 * - **読み取り**: ローカル DB をそのまま流す（[LocalCoffeeRepository] へ委譲）。Firestore からの
 *   変更は [startSync] でローカル DB に反映してから UI に流れる（二重キャッシュを避ける）。反映は
 *   upsert だけでなく reconciliation（スナップショットに無い id のローカル削除）も含む（詳細は [startSync]）
 * - **書き込み**: ローカル → リモート の順序を共通層で保証する。リモート側の失敗時の挙動は
 *   [WritePolicy] で切り替える
 *
 * ## 同期の起動
 *
 * 起動コードで [startSync] を呼ぶと、リモート変更の購読が始まる。サインアウトや uid 変更時は
 * 返り値の [Job] をキャンセルし、新しい uid で再度 [startSync] を呼ぶこと（uid のライフサイクル
 * 管理は本クラスのスコープ外）。
 *
 * @param local SQLDelight ベースのローカル実装。実体は [LocalCoffeeRepository]
 * @param remote Firestore 等のリモートデータソース。実装はプラットフォーム別
 * @param writePolicy 書き込み時のリモート失敗を「無視」「例外伝播」のどちらにするか
 */
class CoffeeRepositoryImpl(
    private val local: CoffeeRepository,
    private val remote: RemoteCoffeeDataSource,
    private val writePolicy: WritePolicy = WritePolicy.PropagateRemoteFailure,
) : CoffeeRepository {

    enum class WritePolicy {
        /**
         * リモート書き込み失敗時に例外を呼び出し元に伝播する（既定）。
         * ローカル書き込みは成功している点に注意。
         */
        PropagateRemoteFailure,

        /**
         * リモート書き込み失敗を握りつぶす（Firestore のオフライン永続化が
         * 後続のオンライン復帰時に同期するため、UI に出さない選択肢）。
         */
        IgnoreRemoteFailure,
    }

    // --- 読み取り: ローカル DB を Single Source として流す ---

    override fun observeAll(userId: String): Flow<List<CoffeeRecord>> =
        local.observeAll(userId)

    override fun observeById(id: String): Flow<CoffeeRecord?> =
        local.observeById(id)

    override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> =
        local.observeByCafe(userId, placeId)

    // --- 書き込み: ローカル → リモートの順序を共通層で保証 ---

    override suspend fun save(record: CoffeeRecord) {
        local.save(record)
        runRemote { remote.upload(record) }
    }

    // ローカル → リモートの順序を保証する。ローカルが Source of Truth のためローカル削除は必ず先行する。
    override suspend fun delete(userId: String, id: String) {
        local.delete(userId, id)
        runRemote { remote.remove(userId, id) }
    }

    /**
     * リモート変更の購読を開始し、ローカル DB に反映する。
     *
     * - 呼び出し元（[com.noricoffee.AppContainer] 等）が `userId` 確定後に呼ぶ
     * - 返り値の [Job] をキャンセルすれば購読が止まる
     * - [RemoteCoffeeDataSource.observeChanges] は指定 `userId` の**全件スナップショット**を返す契約。
     *   スナップショットを受けるたびに次の reconciliation を行う:
     *   1. スナップショットに存在しない id のローカル行を削除する（他端末での削除をローカルに伝播）
     *      - 例外: [DummyCoffeeData.ids] はローカル DB 限定の dev データ（Firestore に流さない設計）
     *        のため、スナップショットに無くても削除しない
     *   2. スナップショットの全件を upsert する（差分計算は行わず Firestore SDK の効率に委ねる）
     * - **既知の許容トレードオフ**: [save] のローカル書き込みから [RemoteCoffeeDataSource.upload] 完了
     *   までの間に「その新規レコードを含まないスナップショット」が届くと、reconciliation で一瞬ローカル
     *   から消え、upload 完了後のリスナ echo で復活しうる。Firestore リスナは pending writes を含むため
     *   窓は極小であり MVP では許容する（本格的な競合解決は backlog）
     */
    fun startSync(userId: String, scope: CoroutineScope): Job =
        scope.launch {
            remote.observeChanges(userId).collect { records ->
                val remoteIds = records.map { it.id }.toSet()
                local.observeAll(userId).first()
                    .filter { it.id !in remoteIds && it.id !in DummyCoffeeData.ids }
                    .forEach { local.delete(userId, it.id) }
                records.forEach { local.save(it) }
            }
        }

    private suspend fun runRemote(block: suspend () -> Unit) {
        when (writePolicy) {
            WritePolicy.PropagateRemoteFailure -> block()
            WritePolicy.IgnoreRemoteFailure -> try {
                block()
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // Firestore のオフライン永続化による再送に委ねる
            }
        }
    }
}
