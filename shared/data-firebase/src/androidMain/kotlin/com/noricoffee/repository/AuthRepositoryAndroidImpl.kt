package com.noricoffee.repository

import com.google.firebase.auth.FirebaseAuth
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
}
