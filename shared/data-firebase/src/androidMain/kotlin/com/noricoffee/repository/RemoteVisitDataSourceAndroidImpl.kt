package com.noricoffee.repository

import com.google.android.gms.tasks.Task
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.QuerySnapshot
import com.noricoffee.domain.Visit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Firestore の Android 実装。
 *
 * ## observe 方針（案 A）
 * 親 `visits` コレクションに snapshotListener を 1 本立て、スナップショット受信ごとに
 * 各 Visit の子 3 種（coffeeItems / foodItems / photos）を `getDocuments` で並列取得して
 * 完全な [Visit] リストとして emit する。
 * iOS 側 `RemoteVisitDataSourceIosImpl.swift` と同等のアプローチ。
 *
 * ## WriteBatch 方針
 * upload / remove は WriteBatch で「親 set + 子 set + 差分 delete」を 1 commit に原子化。
 *
 * ## Task await
 * `kotlinx-coroutines-play-services` に依存せず、[suspendCancellableCoroutine] で
 * `Task<T>` を薄く自前ラップする。
 */
class RemoteVisitDataSourceAndroidImpl : RemoteVisitDataSource {

    private val db: FirebaseFirestore get() = FirebaseFirestore.getInstance()

    override fun observeChanges(userId: String): Flow<List<Visit>> = callbackFlow {
        val visitsRef = db.collection("users").document(userId).collection("visits")

        // callbackFlow のスコープを取得して IO ディスパッチャで子取得を並列実行する
        val flowScope = this

        val listener = visitsRef.addSnapshotListener { snapshot, error ->
            if (error != null) {
                close(error)
                return@addSnapshotListener
            }
            if (snapshot == null) return@addSnapshotListener

            val visitDocs = snapshot.documents

            flowScope.launch(Dispatchers.IO) {
                try {
                    val visits = fetchVisitsWithChildren(userId, visitDocs)
                    trySend(visits)
                } catch (e: Exception) {
                    close(e)
                }
            }
        }

        awaitClose {
            listener.remove()
        }
    }

    private suspend fun fetchVisitsWithChildren(
        userId: String,
        visitDocs: List<com.google.firebase.firestore.DocumentSnapshot>,
    ): List<Visit> = coroutineScope {
        visitDocs.mapNotNull { doc ->
            val data = doc.data ?: return@mapNotNull null
            VisitFirestoreMapper.fromDocument(data)
        }.map { partialVisit ->
            async {
                val visitRef = db.collection("users")
                    .document(userId)
                    .collection("visits")
                    .document(partialVisit.id)

                val coffeeDeferreds = async {
                    awaitTask(visitRef.collection("coffeeItems").get()).documents
                }
                val foodDeferreds = async {
                    awaitTask(visitRef.collection("foodItems").get()).documents
                }
                val photoDeferreds = async {
                    awaitTask(visitRef.collection("photos").get()).documents
                }

                val coffeeDocList = coffeeDeferreds.await()
                val foodDocList = foodDeferreds.await()
                val photoDocList = photoDeferreds.await()

                val coffees = coffeeDocList
                    .mapNotNull { d ->
                        d.data?.let { VisitFirestoreMapper.coffeeItemFromDocument(it) }
                    }
                    .sortedBy { it.second }
                    .map { it.first }

                val foods = foodDocList
                    .mapNotNull { d ->
                        d.data?.let { VisitFirestoreMapper.foodItemFromDocument(it) }
                    }
                    .sortedBy { it.second }
                    .map { it.first }

                val photos = photoDocList
                    .mapNotNull { d ->
                        d.data?.let { VisitFirestoreMapper.photoFromDocument(it) }
                    }
                    .sortedBy { it.second }
                    .map { it.first }

                partialVisit.copy(coffees = coffees, foods = foods, photos = photos)
            }
        }.awaitAll()
    }

    @Throws(Exception::class)
    override suspend fun upload(visit: Visit) {
        val userId = visit.userId
        val visitRef = db.collection("users")
            .document(userId)
            .collection("visits")
            .document(visit.id)

        // 既存の子 ID を並列取得
        val existingCoffeeIds = awaitTask(visitRef.collection("coffeeItems").get())
            .documents.map { it.id }.toSet()
        val existingFoodIds = awaitTask(visitRef.collection("foodItems").get())
            .documents.map { it.id }.toSet()
        val existingPhotoIds = awaitTask(visitRef.collection("photos").get())
            .documents.map { it.id }.toSet()

        val batch = db.batch()

        // 親 visit
        batch.set(visitRef, VisitFirestoreMapper.toDocument(visit))

        // coffeeItems: 新規/更新 set + 差分 delete
        val newCoffeeIds = visit.coffees.map { it.id }.toSet()
        visit.coffees.forEachIndexed { index, item ->
            batch.set(visitRef.collection("coffeeItems").document(item.id),
                VisitFirestoreMapper.toDocument(item, index))
        }
        (existingCoffeeIds - newCoffeeIds).forEach { id ->
            batch.delete(visitRef.collection("coffeeItems").document(id))
        }

        // foodItems: 新規/更新 set + 差分 delete
        val newFoodIds = visit.foods.map { it.id }.toSet()
        visit.foods.forEachIndexed { index, item ->
            batch.set(visitRef.collection("foodItems").document(item.id),
                VisitFirestoreMapper.toDocument(item, index))
        }
        (existingFoodIds - newFoodIds).forEach { id ->
            batch.delete(visitRef.collection("foodItems").document(id))
        }

        // photos: 新規/更新 set + 差分 delete
        val newPhotoIds = visit.photos.map { it.id }.toSet()
        visit.photos.forEachIndexed { index, photo ->
            batch.set(visitRef.collection("photos").document(photo.id),
                VisitFirestoreMapper.toDocument(photo, index))
        }
        (existingPhotoIds - newPhotoIds).forEach { id ->
            batch.delete(visitRef.collection("photos").document(id))
        }

        awaitTask(batch.commit())
    }

    @Throws(Exception::class)
    override suspend fun remove(userId: String, id: String) {
        val visitRef = db.collection("users")
            .document(userId)
            .collection("visits")
            .document(id)

        // 子コレクションを取得して batch delete
        val coffeeDocs = awaitTask(visitRef.collection("coffeeItems").get()).documents
        val foodDocs = awaitTask(visitRef.collection("foodItems").get()).documents
        val photoDocs = awaitTask(visitRef.collection("photos").get()).documents

        val batch = db.batch()
        coffeeDocs.forEach { batch.delete(it.reference) }
        foodDocs.forEach { batch.delete(it.reference) }
        photoDocs.forEach { batch.delete(it.reference) }
        batch.delete(visitRef)

        awaitTask(batch.commit())
    }

    // ─────────────────────────────────────────────────
    // Task<T> を suspend 化するヘルパ
    // ─────────────────────────────────────────────────

    /**
     * Firebase `Task<T>` を suspend 関数で awaitable にする薄いラッパ。
     * `kotlinx-coroutines-play-services` を入れずに自前で実装する方針
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
        }
}
