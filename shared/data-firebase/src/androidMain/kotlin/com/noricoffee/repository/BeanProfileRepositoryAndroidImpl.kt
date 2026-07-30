package com.noricoffee.repository

import com.google.firebase.firestore.FirebaseFirestore
import com.noricoffee.domain.BeanProfile
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * [BeanProfileRepository] の Android 実装。
 *
 * Firestore のグローバルコレクション `beanProfiles` を one-shot get で読み込む（snapshotListener 不使用）。
 *
 * ## キャッシュ戦略
 * - [getAll] は初回のみ Firestore へアクセスし、以降はメモリキャッシュ（[cache]）を返す。
 * - アプリ再起動で自動リフレッシュされる。手動リフレッシュは持たない（サービス管理データのため頻繁な更新なし）。
 *
 * ## Firestore セキュリティルール
 * `beanProfiles/{beanId}`: 認証済みユーザー read-only（[docs/data-model.md] §3.3 参照）。
 *
 * ## Task await パターン
 * [RemoteCoffeeDataSourceAndroidImpl] と同様に [suspendCancellableCoroutine] で
 * Firestore `Task<T>` を suspend 化する（`kotlinx-coroutines-play-services` 不使用）。
 *
 * @param db [FirebaseFirestore] インスタンス（[AppContainer] から DI）
 *
 * @see [docs/data-model.md] §1.8
 * @see [docs/implementation_note.md] Phase 3.5 Task await 自前実装判断
 */
class BeanProfileRepositoryAndroidImpl(
    private val db: FirebaseFirestore,
) : BeanProfileRepository {

    /** メモリキャッシュ。非 null = 初回ロード済み。 */
    private var cache: List<BeanProfile>? = null

    /**
     * 全豆プロファイルを取得する。
     *
     * キャッシュが存在すれば即返す。なければ `beanProfiles` コレクションを one-shot get して
     * [BeanProfileFirestoreMapper.fromDocument] でデコードし、キャッシュに保存してから返す。
     */
    @Throws(Exception::class)
    override suspend fun getAll(): List<BeanProfile> {
        cache?.let { return it }

        return suspendCancellableCoroutine { continuation ->
            val task = db.collection("beanProfiles").get()

            task.addOnSuccessListener { snapshot ->
                val profiles = snapshot.documents.mapNotNull { doc ->
                    doc.data?.let { BeanProfileFirestoreMapper.fromDocument(it) }
                }
                cache = profiles
                continuation.resume(profiles)
            }

            task.addOnFailureListener { e ->
                continuation.resumeWithException(e)
            }

            // Firebase Task はキャンセル不可。コルーチンがキャンセルされた場合は
            // コールバック到達時に resume が無視され自然に破棄される。
            continuation.invokeOnCancellation {
                // 明示的なリソース解放は不要
            }
        }
    }
}
