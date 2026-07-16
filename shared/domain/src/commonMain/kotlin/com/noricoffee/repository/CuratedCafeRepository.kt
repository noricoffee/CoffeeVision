package com.noricoffee.repository

import com.noricoffee.domain.model.CuratedCafe

/**
 * 都道府県別おすすめカフェ（[CuratedCafe]）の取得を担うリポジトリインターフェース（フェーズ 19）。
 *
 * Firestore のグローバルコレクション `curatedCafes/{prefectureCode}` を read-only で参照する。
 * write 操作は持たない（サービス管理データのため。投入はシードスクリプト経由）。
 *
 * ## 実装方針
 * [getAll] はメモリキャッシュ前提（Firestore への one-shot get、snapshotListener 不要）。
 * 全都道府県ドキュメントの `cafes` 配列を flatten した 1 本のリストを返す
 * （クライアントは県別ロジックを持たず、全件一括ロードのみ）。
 *
 * ## 実装
 * - Android: `shared/data-firebase/androidMain` の `CuratedCafeRepositoryAndroidImpl`
 * - iOS: `iosApp/iosApp/FirebaseRepositories/CuratedCafeRepositoryIosImpl.swift`（iOS 側で実装）
 *
 * @see [docs/data-model.md] §1.10
 */
interface CuratedCafeRepository {

    /**
     * 全都道府県のおすすめカフェを取得する。
     *
     * 初回呼び出しで Firestore から one-shot get し、以降はメモリキャッシュを返す。
     * 失敗時は例外を投げる。
     */
    @Throws(Exception::class)
    suspend fun getAll(): List<CuratedCafe>
}
