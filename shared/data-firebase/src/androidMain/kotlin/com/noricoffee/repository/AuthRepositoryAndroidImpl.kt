package com.noricoffee.repository

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.OAuthProvider
import com.noricoffee.domain.model.AuthAccount
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Firebase Auth の Android 実装。
 *
 * - 匿名サインインは [suspendCancellableCoroutine] で `Task<AuthResult>` を suspend 化する
 *   （`kotlinx-coroutines-play-services` に依存せず、`Task` を薄く自前ラップ）
 * - uid の観測は [callbackFlow] + `addAuthStateListener` / `awaitClose` で Flow 化する
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
     * `addAuthStateListener` で Auth 状態の変化を購読し、[AuthAccount] にマッピングして emit する。
     * サインアウト中は null を emit する。
     */
    override fun observeAccount(): Flow<AuthAccount?> = callbackFlow {
        val listener = FirebaseAuth.AuthStateListener { firebaseAuth ->
            val user = firebaseAuth.currentUser
            val account = user?.let {
                AuthAccount(
                    uid = it.uid,
                    isAnonymous = it.isAnonymous,
                    providerLabel = it.providerData
                        .firstOrNull { info -> info.providerId != "firebase" }
                        ?.providerId,
                    email = it.email,
                )
            }
            trySend(account)
        }
        auth.addAuthStateListener(listener)
        awaitClose {
            auth.removeAuthStateListener(listener)
        }
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
}
