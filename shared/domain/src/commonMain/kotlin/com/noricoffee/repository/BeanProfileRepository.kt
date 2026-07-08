package com.noricoffee.repository

import com.noricoffee.domain.BeanProfile

/**
 * コーヒー豆ナレッジベースの取得を担うリポジトリインターフェース。
 *
 * Firestore のグローバルコレクション `beanProfiles/{beanId}` を read-only で参照する。
 * write 操作は持たない（サービス管理データのため）。
 *
 * ## 実装方針
 * - [getAll] はメモリキャッシュ前提（Firestore への one-shot get、snapshotListener 不要）
 * - [getByOrigin] はクライアントサイドフィルタ（[getAll] の結果に対して trim/lowercase 完全一致）
 *
 * ## 実装
 * - Android: `shared/data-firebase/androidMain` の [BeanProfileRepositoryAndroidImpl]
 * - iOS: `iosApp/iosApp/FirebaseRepositories/BeanProfileRepositoryIosImpl.swift`（iOS 側で実装）
 *
 * @see [docs/data-model.md] §1.8
 */
interface BeanProfileRepository {

    /**
     * 全豆プロファイルを取得する。
     *
     * 初回呼び出しで Firestore から one-shot get し、以降はメモリキャッシュを返す。
     * 失敗時は例外を投げる。
     */
    @Throws(Exception::class)
    suspend fun getAll(): List<BeanProfile>

    /**
     * 指定産地（trim/lowercase 完全一致）の豆プロファイルを取得する。
     *
     * [getAll] の結果を `origin.trim().lowercase()` でフィルタして返す（クライアントサイド）。
     *
     * **シノニム正規化（[com.noricoffee.domain.OriginNormalizer]）は非対応**: 本メソッドは
     * trim/lowercase の完全一致のみで、「Ethiopia」→「エチオピア」等の名寄せは行わない。
     * 本番コードに呼び出し元が無いため実害はないが、新規に呼び出す場合は呼び出し側で
     * `OriginNormalizer.normalize` を適用したうえでフィルタするか、本メソッドの実装刷新を検討すること。
     */
    @Throws(Exception::class)
    suspend fun getByOrigin(origin: String): List<BeanProfile>
}
