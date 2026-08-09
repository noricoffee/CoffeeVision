package com.noricoffee.repository

import com.noricoffee.domain.model.SavedCafe
import kotlinx.coroutines.flow.Flow

/**
 * Firestore（または同等のリモート KVS）への薄いアダプタインターフェース（「行きたい店」用）。
 *
 * [RemoteCoffeeDataSource] と同じ設計方針を踏襲する（[data-model.md] §4.3）。
 *
 * - `commonMain` には interface のみを置き、実装は各プラットフォームの公式 SDK で行う
 *   （iOS は `iosApp/FirebaseRepositories/`、Android は `shared/data-firebase/androidMain`）
 * - 本データソースは UI から **直接参照されない**。[SavedCafeRepositoryImpl] が
 *   [LocalSavedCafeRepository] と本データソースを合成して、UI には [SavedCafeRepository] 1 本だけを見せる
 *
 * Firestore のコレクション構造: `users/{uid}/savedCafes/{placeId}`（ドキュメント ID = placeId）。
 */
interface RemoteSavedCafeDataSource {

    /**
     * リモート側の変更を観測する。
     *
     * 各要素は **指定 userId の全 [SavedCafe] のスナップショット**（差分ではなく全体）を返す。
     * [SavedCafeRepositoryImpl] はこの Flow を購読してローカル DB を更新する
     * （reconciliation を含む。詳細は [SavedCafeRepositoryImpl.startSync]）。
     *
     * **エラー契約は [RemoteCoffeeDataSource.observeChanges] と同じ**。回復不能な失敗では
     * 握り潰さず Flow をその例外で終了させること。
     */
    fun observeChanges(userId: String): Flow<List<SavedCafe>>

    /**
     * [SavedCafe] をリモートに書き込む（保存 = `set` による上書き）。
     *
     * 呼び出し前提: [SavedCafeRepositoryImpl] が既にローカル DB への upsert を成功させていること。
     */
    @Throws(Exception::class)
    suspend fun upload(savedCafe: SavedCafe)

    /**
     * `users/{userId}/savedCafes/{placeId}` を削除する（解除）。
     *
     * 呼び出し前提: [SavedCafeRepositoryImpl] が既にローカル DB からの削除を成功させていること。
     */
    @Throws(Exception::class)
    suspend fun remove(userId: String, placeId: String)
}
