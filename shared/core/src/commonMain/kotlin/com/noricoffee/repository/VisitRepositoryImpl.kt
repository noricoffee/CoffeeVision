package com.noricoffee.repository

import com.noricoffee.domain.Visit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch

/**
 * `LocalVisitRepository`（SQLDelight）と [RemoteVisitDataSource]（Firestore）を合成した
 * `VisitRepository` 実装。
 *
 * ## 設計方針
 *
 * - UI は `VisitRepository` 1 本だけを見る
 * - **読み取り**: ローカル DB をそのまま流す（[LocalVisitRepository] へ委譲）。Firestore からの
 *   変更は [startSync] でローカル DB に反映してから UI に流れる（二重キャッシュを避ける）
 * - **書き込み**: ローカル → リモート の順序を共通層で保証する。リモート側の失敗時の挙動は
 *   [WritePolicy] で切り替える
 *
 * ## 同期の起動
 *
 * 起動コードで [startSync] を呼ぶと、リモート変更の購読が始まる。サインアウトや uid 変更時は
 * 返り値の [Job] をキャンセルし、新しい uid で再度 [startSync] を呼ぶこと（uid のライフサイクル
 * 管理は本クラスのスコープ外）。
 *
 * @param local SQLDelight ベースのローカル実装。実体は [LocalVisitRepository]
 * @param remote Firestore 等のリモートデータソース。実装はプラットフォーム別
 * @param writePolicy 書き込み時のリモート失敗を「無視」「例外伝播」のどちらにするか
 */
class VisitRepositoryImpl(
    private val local: VisitRepository,
    private val remote: RemoteVisitDataSource,
    private val writePolicy: WritePolicy = WritePolicy.PropagateRemoteFailure,
) : VisitRepository {

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

    override fun observeAll(userId: String): Flow<List<Visit>> =
        local.observeAll(userId)

    override fun observeById(id: String): Flow<Visit?> =
        local.observeById(id)

    override fun observeByCafe(userId: String, placeId: String): Flow<List<Visit>> =
        local.observeByCafe(userId, placeId)

    // --- 書き込み: ローカル → リモートの順序を共通層で保証 ---

    override suspend fun save(visit: Visit) {
        local.save(visit)
        runRemote { remote.upload(visit) }
    }

    // ローカル → リモートの順序を保証する。ローカルが Source of Truth のためローカル削除は必ず先行する。
    override suspend fun delete(userId: String, id: String) {
        local.delete(userId, id)
        runRemote { remote.remove(userId, id) }
    }

    /**
     * リモート変更の購読を開始し、ローカル DB に反映する。
     *
     * - 呼び出し元（`AppContainer` 等）が `userId` 確定後に呼ぶ
     * - 返り値の [Job] をキャンセルすれば購読が止まる
     * - リモートからの全件スナップショットを受けるたびにローカル DB を更新する
     *   （差分計算は本層では行わず、Firestore SDK の効率に委ねる）
     */
    fun startSync(userId: String, scope: CoroutineScope): Job =
        scope.launch {
            remote.observeChanges(userId).collect { visits ->
                visits.forEach { local.save(it) }
            }
        }

    private suspend fun runRemote(block: suspend () -> Unit) {
        when (writePolicy) {
            WritePolicy.PropagateRemoteFailure -> block()
            WritePolicy.IgnoreRemoteFailure -> runCatching { block() }
        }
    }
}
