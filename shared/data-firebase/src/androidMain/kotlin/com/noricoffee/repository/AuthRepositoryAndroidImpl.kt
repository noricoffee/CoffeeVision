@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package com.noricoffee.repository

import com.google.android.gms.tasks.Task
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.noricoffee.domain.model.AuthAccount
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Firebase Auth / Firestore の Android 実装。
 *
 * - 匿名サインインは [suspendCancellableCoroutine] で `Task<AuthResult>` を suspend 化する
 *   （`kotlinx-coroutines-play-services` に依存せず、`Task` を薄く自前ラップ）
 * - uid の観測は [callbackFlow] + `addAuthStateListener` / `awaitClose` で Flow 化する
 * - analyticsConsent は Firestore `users/{uid}` ルートドキュメントで管理する
 *
 * iOS 側の `AuthRepositoryIosImpl.swift` と同等の契約を Kotlin で実装する。
 *
 * ## Apple サインインについて
 * [linkWithApple] は Android プラットフォームに Apple サインイン UI が存在しないため、
 * `UnsupportedOperationException` を投げるスタブになる。Android 検証ターゲットとしての
 * コンパイル維持が目的。
 */
class AuthRepositoryAndroidImpl : AuthRepository {

    private val auth: FirebaseAuth get() = FirebaseAuth.getInstance()
    private val firestore: FirebaseFirestore get() = FirebaseFirestore.getInstance()

    /**
     * 現在の uid を返す。未サインインの場合は匿名サインインを実行してから uid を返す。
     */
    @Throws(Exception::class)
    override suspend fun signInAnonymouslyIfNeeded(): String {
        val currentUser = auth.currentUser
        if (currentUser != null) {
            return currentUser.uid
        }

        return suspendCancellableCoroutine { continuation ->
            val task = auth.signInAnonymously()
            task.addOnSuccessListener { result ->
                val uid = result.user?.uid
                if (uid != null) {
                    continuation.resume(uid)
                } else {
                    continuation.resumeWithException(
                        IllegalStateException("signInAnonymously succeeded but uid is null")
                    )
                }
            }
            task.addOnFailureListener { e ->
                continuation.resumeWithException(e)
            }
            continuation.invokeOnCancellation {
                // Task のキャンセルは Firebase SDK 側にはない。
                // coroutine がキャンセルされた場合はコールバック無視で自然に破棄される
            }
        }
    }

    /**
     * uid の変化を観測する Flow。
     * サインイン状態のとき: 現在の uid。
     * サインアウト状態のとき: null。
     */
    override fun observeUserId(): Flow<String?> = callbackFlow {
        val listener = FirebaseAuth.AuthStateListener { firebaseAuth ->
            trySend(firebaseAuth.currentUser?.uid)
        }
        auth.addAuthStateListener(listener)
        awaitClose {
            auth.removeAuthStateListener(listener)
        }
    }

    /**
     * 現在のアカウント情報（[AuthAccount]）の変化を観測する Flow。
     *
     * Auth 状態の変化と Firestore の `analyticsConsent` を [flatMapLatest] で合成する。
     * - サインアウト中: null を emit
     * - サインイン中: [observeConsentForUser] でリアルタイム購読した consent を含む [AuthAccount] を emit
     *   Auth 状態が変化したとき（サインアウト → サインイン等）、前の Firestore リスナは自動で破棄される
     */
    override fun observeAccount(): Flow<AuthAccount?> =
        observeFirebaseUser().flatMapLatest { user ->
            if (user == null) {
                flowOf(null)
            } else {
                observeConsentForUser(user.uid).map { consent ->
                    makeAuthAccount(user, consent)
                }
            }
        }

    /**
     * Firestore `users/{uid}` ルートドキュメントの `analyticsConsent` をリッスンし、
     * 変化を [Flow] として返す。
     *
     * Auth 状態の変化を [flatMapLatest] で監視し、サインアウト中は `false` を emit、
     * サインイン中は Firestore リスナに切り替える。
     * ドキュメントが存在しない場合も `false` を emit する。
     */
    override fun observeAnalyticsConsent(): Flow<Boolean> =
        observeFirebaseUser().flatMapLatest { user ->
            if (user == null) flowOf(false)
            else observeConsentForUser(user.uid)
        }

    /**
     * ユーザーのデータ共有同意フラグを Firestore `users/{uid}` ルートドキュメントへ保存する。
     *
     * `SetOptions.merge()` を使い、他のフィールドを上書きしない。
     */
    @Throws(Exception::class)
    override suspend fun updateAnalyticsConsent(consent: Boolean) {
        val uid = auth.currentUser?.uid ?: throw Exception("Not signed in")
        awaitTask(
            firestore.collection("users").document(uid)
                .set(mapOf("analyticsConsent" to consent), SetOptions.merge())
        )
    }

    /**
     * Apple サインイン資格情報をリンクする。
     *
     * Android プラットフォームには Apple サインイン UI が存在しないため、
     * スタブとして [UnsupportedOperationException] を投げる。
     * Android 検証ターゲットとしてのインターフェースコンパイル維持が目的。
     */
    @Throws(Exception::class)
    override suspend fun linkWithApple(idToken: String, rawNonce: String): AuthAccount {
        throw UnsupportedOperationException("Apple sign-in is iOS only")
    }

    /**
     * 現在のアカウントをサインアウトする。
     */
    @Throws(Exception::class)
    override suspend fun signOut() {
        auth.signOut()
    }

    /**
     * Firebase Auth からユーザー本体を削除する。
     *
     * `currentUser?.delete()` を `Task` 経由で suspend 化する。
     * 呼び出し前に対象 uid の全データ削除が完了していること（[DeleteAccountUseCase] 参照）。
     */
    @Throws(Exception::class)
    override suspend fun deleteAuthUser() {
        val user = auth.currentUser
            ?: throw IllegalStateException("deleteAuthUser called but no current user")

        suspendCancellableCoroutine { continuation ->
            val task = user.delete()
            task.addOnSuccessListener {
                continuation.resume(Unit)
            }
            task.addOnFailureListener { e ->
                continuation.resumeWithException(e)
            }
        }
    }

    // ─────────────────────────────────────────────────
    // 内部ヘルパ
    // ─────────────────────────────────────────────────

    /**
     * Firebase Auth 状態の変化を [Flow]<[FirebaseUser]?> として公開する内部ヘルパ。
     *
     * [observeAccount] / [observeAnalyticsConsent] が共通で利用し、
     * `addAuthStateListener` の登録を 1 コレクタにつき 1 回に限定する。
     */
    private fun observeFirebaseUser(): Flow<FirebaseUser?> = callbackFlow {
        val listener = FirebaseAuth.AuthStateListener { firebaseAuth ->
            trySend(firebaseAuth.currentUser)
        }
        auth.addAuthStateListener(listener)
        awaitClose { auth.removeAuthStateListener(listener) }
    }

    /**
     * 指定 uid の `users/{uid}` ドキュメントを購読し、`analyticsConsent` フィールドの変化を emit する。
     *
     * ドキュメントが存在しない場合 / エラー時は `false` を emit する。
     */
    private fun observeConsentForUser(uid: String): Flow<Boolean> = callbackFlow {
        val listener = firestore.collection("users").document(uid)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    trySend(false)
                    return@addSnapshotListener
                }
                trySend(snapshot?.getBoolean("analyticsConsent") ?: false)
            }
        awaitClose { listener.remove() }
    }

    /**
     * [FirebaseUser] と同意フラグから [AuthAccount] を組み立てるファクトリヘルパ。
     */
    private fun makeAuthAccount(user: FirebaseUser, analyticsConsent: Boolean) = AuthAccount(
        uid = user.uid,
        isAnonymous = user.isAnonymous,
        providerLabel = user.providerData
            .firstOrNull { info -> info.providerId != "firebase" }
            ?.providerId,
        email = user.email,
        analyticsConsent = analyticsConsent,
    )

    /**
     * Firebase `Task<T>` を suspend 関数で awaitable にする薄いラッパ。
     * `kotlinx-coroutines-play-services` を入れずに自前実装する方針
     * （[docs/implementation_note.md] Phase 3.5 参照）。
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
