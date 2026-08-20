package com.noricoffee.repository

import com.google.firebase.firestore.FirebaseFirestore
import com.noricoffee.domain.model.CuratedCafe
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * [CuratedCafeRepository] の Android 実装。
 *
 * Firestore のグローバルコレクション `curatedCafes` を one-shot get で読み込む（snapshotListener 不使用）。
 * 全ドキュメント（都道府県ごと 1 件）を取得し、各ドキュメントの `cafes` 配列を
 * [CuratedCafeFirestoreMapper.fromDocument] で flatMap して 1 本のリストにする。
 *
 * ## キャッシュ戦略
 * - [getAll] は初回のみ Firestore へアクセスし、以降はメモリキャッシュ（[cache]）を返す。
 * - アプリ再起動で自動リフレッシュされる。手動リフレッシュは持たない（サービス管理データのため頻繁な更新なし）。
 *
 * ## Firestore セキュリティルール
 * `curatedCafes/{prefectureCode}`: 認証済みユーザー read-only（[docs/data-model.md] §3.3 参照）。
 *
 * ## Task await パターン
 * [BeanProfileRepositoryAndroidImpl] と同様に [suspendCancellableCoroutine] で
 * Firestore `Task<T>` を suspend 化する（`kotlinx-coroutines-play-services` 不使用）。
 *
 * @param db [FirebaseFirestore] インスタンス（[AppContainer] から DI）
 *
 * @see [docs/data-model.md] §1.10
 */
class CuratedCafeRepositoryAndroidImpl(
    private val db: FirebaseFirestore,
) : CuratedCafeRepository {

    /** メモリキャッシュ。非 null = 初回ロード済み。 */
    private var cache: List<CuratedCafe>? = null

    /**
     * 全都道府県のおすすめカフェを取得する。
     *
     * キャッシュが存在すれば即返す。なければ `curatedCafes` コレクションを one-shot get して
     * 各ドキュメントを [CuratedCafeFirestoreMapper.fromDocument] で flatMap し、
     * キャッシュに保存してから返す。
     */
    @Throws(Exception::class)
    override suspend fun getAll(): List<CuratedCafe> {
        cache?.let { return it }

        return suspendCancellableCoroutine { continuation ->
            val task = db.collection("curatedCafes").get()

            task.addOnSuccessListener { snapshot ->
                val cafes = snapshot.documents.flatMap { doc ->
                    doc.data?.let { CuratedCafeFirestoreMapper.fromDocument(it) } ?: emptyList()
                }
                cache = cafes
                continuation.resume(cafes)
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
