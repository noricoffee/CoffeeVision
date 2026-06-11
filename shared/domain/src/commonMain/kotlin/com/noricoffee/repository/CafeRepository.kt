package com.noricoffee.repository

import com.noricoffee.domain.Cafe

/**
 * カフェ情報の Repository インターフェース。
 *
 * スライス 1 では Text Search のみ。後続スライスで `searchNearby` / `getDetails` を追加予定。
 * 実装は `shared/data-places` の `CafeRepositoryImpl` が担当する。
 *
 * ## プラットフォーム対称性
 * - Android / iOS 両方で同一実装（Ktor KMP）を使うため、非対称実装はない
 * - Firestore の `VisitRepository` と異なり、`data-places` モジュールに KMP 実装を置く
 */
interface CafeRepository {

    /**
     * テキストクエリでカフェを検索する。
     *
     * @param query 検索キーワード（例: "渋谷 コーヒー"）
     * @return 検索結果の [Cafe] リスト。0 件の場合は空リスト
     * @throws Exception API 呼び出し失敗時
     */
    @Throws(Exception::class)
    suspend fun searchText(query: String): List<Cafe>
}
