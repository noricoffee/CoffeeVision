package com.noricoffee.repository

import com.google.android.gms.tasks.Task
import com.google.firebase.firestore.FirebaseFirestore
import com.noricoffee.domain.CoffeeRecord
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Firestore の Android 実装。
 *
 * ## コレクション構造
 * `users/{uid}/coffees/{coffeeId}` — 子サブコレクションを持たない。
 * photos は `CoffeeRecord` ドキュメントに埋め込み配列として保存するため、
 * **1 本のリスナで完結**する（旧 Visit 実装の N+1 子取得は不要）。
 *
 * ## observe 方針
 * `coffees` コレクションに `addSnapshotListener` を 1 本立て、
 * `callbackFlow` で [CoffeeRecord] の `Flow<List<CoffeeRecord>>` として公開する。
 * 各ドキュメントは [CoffeeFirestoreMapper.fromDocument] でデコードし、
 * 失敗ドキュメントは null を返してスキップする。
 *
 * ## 書き込み方針
 * - upload: `coffees/{record.id}` に単一 `set` 1 回（WriteBatch 差分削除は不要）
 * - remove: `coffees/{id}` を単一 `delete` 1 回
 *
 * ## Task await
 * `kotlinx-coroutines-play-services` に依存せず [suspendCancellableCoroutine] で
 * `Task<T>` を薄く自前ラップする（[docs/implementation_note.md] Phase 3.5 実装判断参照）。
 */
class RemoteCoffeeDataSourceAndroidImpl : RemoteCoffeeDataSource {

    private val db: FirebaseFirestore get() = FirebaseFirestore.getInstance()

    /**
     * `users/{userId}/coffees` コレクションのリアルタイム変化を購読する。
     *
     * snapshot 受信のたびに全ドキュメントを [CoffeeFirestoreMapper.fromDocument] でデコードし、
     * デコード失敗ドキュメントはスキップする（null フィルタ）。
     * photos は埋め込み配列のため 1 リスナで完結し、子取得の N+1 は発生しない。
     */
    override fun observeChanges(userId: String): Flow<List<CoffeeRecord>> = callbackFlow {
        val coffeesRef = db.collection("users").document(userId).collection("coffees")

        // callbackFlow の ProducerScope は CoroutineScope を実装しているため
        // IO ディスパッチャで launch できる（旧 RemoteVisitDataSourceAndroidImpl と同じパターン）
        val flowScope = this

        val listener = coffeesRef.addSnapshotListener { snapshot, error ->
            if (error != null) {
                close(error)
                return@addSnapshotListener
            }
            if (snapshot == null) return@addSnapshotListener

            flowScope.launch(Dispatchers.IO) {
                val records = snapshot.documents.mapNotNull { doc ->
                    doc.data?.let { CoffeeFirestoreMapper.fromDocument(it) }
                }
                trySend(records)
            }
        }

        awaitClose {
            listener.remove()
        }
    }

    /**
     * `users/{record.userId}/coffees/{record.id}` に [CoffeeRecord] を書き込む（作成・更新共通）。
     *
     * photos は埋め込み配列のため単一 `set` 1 回で完結する。
     * 旧 Visit 実装の WriteBatch 差分削除は不要。
     */
    @Throws(Exception::class)
    override suspend fun upload(record: CoffeeRecord) {
        val coffeeRef = db.collection("users")
            .document(record.userId)
            .collection("coffees")
            .document(record.id)

        awaitTask(coffeeRef.set(CoffeeFirestoreMapper.toDocument(record)))
    }

    /**
     * `users/{userId}/coffees/{id}` の単一ドキュメントを削除する。
     *
     * photos は埋め込み配列のため子コレクション削除は不要。
     */
    @Throws(Exception::class)
    override suspend fun remove(userId: String, id: String) {
        val coffeeRef = db.collection("users")
            .document(userId)
            .collection("coffees")
            .document(id)

        awaitTask(coffeeRef.delete())
    }

    // ─────────────────────────────────────────────────
    // Task<T> を suspend 化するヘルパ
    // ─────────────────────────────────────────────────

    /**
     * Firebase `Task<T>` を suspend 関数で awaitable にする薄いラッパ。
     * `kotlinx-coroutines-play-services` を入れずに自前実装する方針
     * （[docs/implementation_note.md] Phase 3.5 Android 検証スライスの事前設計 参照）。
     */
    private suspend fun <T> awaitTask(task: Task<T>): T =
        suspendCancellableCoroutine { continuation ->
            task.addOnSuccessListener { result ->
                continuation.resume(result)
            }
            task.addOnFailureListener { e ->
                continuation.resumeWithException(e)
            }
            // Firebase Task のキャンセルはできないが、coroutine がキャンセルされた場合は
            // コールバック無視で自然に破棄される
        }
}
