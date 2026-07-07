package com.noricoffee.data.places

import com.noricoffee.domain.LocationBias

/**
 * Google Places API (New) v1 のクライアントインターフェース。
 *
 * スライス 3 で `searchNearby` / `getDetails` を追加済。
 * スライス 7-A で `searchText(query, locationBias)` オーバーロードを追加。
 * スライス 4 で `photoMediaUrl` を追加済。
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
     * 名前 + 位置バイアスで**型フィルタなし**のテキスト検索を行う（POI タップ解決専用）。
     *
     * POST `https://places.googleapis.com/v1/places:searchText`（`includedType` を送らない）
     *
     * [searchText] は `includedType=cafe` を強制するため、Apple が cafe 分類する店でも Google Places で
     * `cafe`/`coffee_shop` 型でない店（ランドリー併設カフェ・食事カフェ等）は結果に出ない。POI タップの
     * ように名前と座標が分かっている解決では型フィルタを外し、名前と位置で拾う。
     *
     * @param query 検索キーワード（Apple Maps POI の表示名）
     * @param locationBias 検索結果を優先するエリア（中心座標 + 半径）
     * @return 検索結果の [PlaceSummary] リスト。0 件の場合は空リスト
     * @throws Exception API 呼び出し失敗時
     */
    @Throws(Exception::class)
    suspend fun searchByNameNear(query: String, locationBias: LocationBias): List<PlaceSummary>

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

    /**
     * 写真の表示用 URL を取得する（Photo Media API）。
     *
     * GET `https://places.googleapis.com/v1/{photoName}/media?skipHttpRedirect=true&maxWidthPx=...&maxHeightPx=...`
     * ヘッダ: `X-Goog-Api-Key: <apiKey>`
     *
     * `photoName` は `"places/{placeId}/photos/{photoRef}"` 形式（[PlaceSummary.photoNames] の要素）。
     * `skipHttpRedirect=true` を付けることでリダイレクトせず JSON を返し、`photoUri` フィールドに
     * Google CDN の時限署名 URL が入る。Places 利用規約により永続キャッシュは禁止。
     *
     * @param photoName `"places/{placeId}/photos/{photoRef}"` 形式の写真名
     * @param maxWidthPx 最大幅（px）。null の場合はクエリパラメータを付与しない
     * @param maxHeightPx 最大高さ（px）。null の場合はクエリパラメータを付与しない
     * @return 時限署名 URL 文字列（Google CDN: lh3.googleusercontent.com 等）
     * @throws Exception API 呼び出し失敗時
     */
    @Throws(Exception::class)
    suspend fun photoMediaUrl(
        photoName: String,
        maxWidthPx: Int?,
        maxHeightPx: Int?,
    ): String
}
