package com.noricoffee.data.places

import com.noricoffee.domain.LocationBias

/**
 * Google Places API (New) v1 のクライアントインターフェース。
 *
 * スライス 3 で `searchNearby` / `getDetails` を追加済。
 * スライス 7-A で `searchText(query, locationBias)` オーバーロードを追加。
 * `photoMediaUrl` はスライス 4 で追加予定。
 */
interface PlacesClient {

    /**
     * テキストクエリでカフェを検索する（位置バイアスなし）。
     *
     * POST `https://places.googleapis.com/v1/places:searchText`
     *
     * @param query 検索キーワード（例: "渋谷 コーヒー"）
     * @return 検索結果の [PlaceSummary] リスト。0 件の場合は空リスト
     * @throws Exception API 呼び出し失敗時
     */
    @Throws(Exception::class)
    suspend fun searchText(query: String): List<PlaceSummary>

    /**
     * テキストクエリでカフェを検索する（位置バイアスあり）。
     *
     * POST `https://places.googleapis.com/v1/places:searchText`
     *
     * SKIE がデフォルト引数を Swift に引き出さないため、バイアスなし版と別のオーバーロードにする。
     *
     * @param query 検索キーワード（例: Apple Maps POI の表示名）
     * @param locationBias 検索結果を優先するエリア（中心座標 + 半径）
     * @return 検索結果の [PlaceSummary] リスト。0 件の場合は空リスト
     * @throws Exception API 呼び出し失敗時
     */
    @Throws(Exception::class)
    suspend fun searchText(query: String, locationBias: LocationBias): List<PlaceSummary>

    /**
     * 現在地の周辺にあるカフェを検索する。
     *
     * POST `https://places.googleapis.com/v1/places:searchNearby`
     *
     * @param latitude 検索中心点の緯度
     * @param longitude 検索中心点の経度
     * @param radiusMeters 検索半径（メートル）。デフォルトは 500m
     * @return 周辺カフェの [PlaceSummary] リスト。0 件の場合は空リスト
     * @throws Exception API 呼び出し失敗時
     */
    @Throws(Exception::class)
    suspend fun searchNearby(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 500.0,
    ): List<PlaceSummary>

    /**
     * 指定した Place ID の詳細情報を取得する。
     *
     * GET `https://places.googleapis.com/v1/places/{placeId}`
     *
     * @param placeId Google Places の Place ID（例: `"ChIJ..."` 形式）
     * @return Place の [PlaceSummary]
     * @throws Exception API 呼び出し失敗時（404 など）
     */
    @Throws(Exception::class)
    suspend fun getDetails(placeId: String): PlaceSummary
}
