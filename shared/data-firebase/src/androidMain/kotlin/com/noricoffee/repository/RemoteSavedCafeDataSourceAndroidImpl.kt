package com.noricoffee.repository

import com.google.android.gms.tasks.Task
import com.google.firebase.firestore.FirebaseFirestore
import com.noricoffee.domain.model.SavedCafe
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Firestore の Android 実装（「行きたい店」用）。[RemoteCoffeeDataSourceAndroidImpl] と同じパターン。
 *
 * ## コレクション構造
 * `users/{userId}/savedCafes/{placeId}` — ドキュメント ID = `cafe.placeId`。
 *
 * ## observe 方針
 * `savedCafes` コレクションに `addSnapshotListener` を 1 本立て、
 * `callbackFlow` で [SavedCafe] の `Flow<List<SavedCafe>>` として公開する。
 * 各ドキュメントは [SavedCafeFirestoreMapper.fromDocument] でデコードし、失敗ドキュメントはスキップする。
 *
 * ## 書き込み方針
 * - upload: `savedCafes/{savedCafe.cafe.placeId}` に単一 `set` 1 回（保存 = 上書き）
 * - remove: `savedCafes/{placeId}` を単一 `delete` 1 回（解除）
 */
class RemoteSavedCafeDataSourceAndroidImpl : RemoteSavedCafeDataSource {

    private val db: FirebaseFirestore get() = FirebaseFirestore.getInstance()

    override fun observeChanges(userId: String): Flow<List<SavedCafe>> = callbackFlow {
        val savedCafesRef = db.collection("users").document(userId).collection("savedCafes")

        val flowScope = this

        val listener = savedCafesRef.addSnapshotListener { snapshot, error ->
            if (error != null) {
                close(error)
                return@addSnapshotListener
            }
            if (snapshot == null) return@addSnapshotListener

            flowScope.launch(Dispatchers.Default) {
                val savedCafes = snapshot.documents.mapNotNull { doc ->
                    doc.data?.let { SavedCafeFirestoreMapper.fromDocument(userId, it) }
                }
                trySend(savedCafes)
            }
        }

        awaitClose {
            listener.remove()
        }
    }

    @Throws(Exception::class)
    override suspend fun upload(savedCafe: SavedCafe) {
        val docRef = db.collection("users")
            .document(savedCafe.userId)
            .collection("savedCafes")
            .document(savedCafe.cafe.placeId)

        awaitTask(docRef.set(SavedCafeFirestoreMapper.toDocument(savedCafe)))
    }

    @Throws(Exception::class)
    override suspend fun remove(userId: String, placeId: String) {
        val docRef = db.collection("users")
            .document(userId)
            .collection("savedCafes")
            .document(placeId)

        awaitTask(docRef.delete())
    }

    /**
     * Firebase `Task<T>` を suspend 関数で awaitable にする薄いラッパ。
     * [RemoteCoffeeDataSourceAndroidImpl.awaitTask] と同じ自前実装方針。
     */
    private suspend fun <T> awaitTask(task: Task<T>): T =
        suspendCancellableCoroutine { continuation ->
            task.addOnSuccessListener { result ->
                continuation.resume(result)
            }
            task.addOnFailureListener { e ->
                continuation.resumeWithException(e)
            }
        }
}
