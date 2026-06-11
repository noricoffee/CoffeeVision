package com.noricoffee.data.places

/**
 * Google Places API (New) v1 のクライアントインターフェース。
 *
 * 将来スライスで `searchNearby` / `getDetails` / `photoMediaUrl` を追加予定。
 * スライス 1 では Text Search のみ実装する。
 */
interface PlacesClient {

    /**
     * テキストクエリでカフェを検索する。
     *
     * @param query 検索キーワード（例: "渋谷 コーヒー"）
     * @return 検索結果の [PlaceSummary] リスト。0 件の場合は空リスト
     * @throws Exception API 呼び出し失敗時
     */
    @Throws(Exception::class)
    suspend fun searchText(query: String): List<PlaceSummary>
}
