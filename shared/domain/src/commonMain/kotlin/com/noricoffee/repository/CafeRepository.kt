package com.noricoffee.repository

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.LocationBias

/**
 * カフェ情報の Repository インターフェース。
 *
 * 実装は `shared/data-places` の `CafeRepositoryImpl` が担当する。
 *
 * ## プラットフォーム対称性
 * - Android / iOS 両方で同一実装（Ktor KMP）を使うため、非対称実装はない
 * - Firestore の `VisitRepository` と異なり、`data-places` モジュールに KMP 実装を置く
 */
interface CafeRepository {

    /**
     * テキストクエリでカフェを検索する（位置バイアスなし）。
     *
     * @param query 検索キーワード（例: "渋谷 コーヒー"）
     * @return 検索結果の [Cafe] リスト。0 件の場合は空リスト
     * @throws Exception API 呼び出し失敗時
     */
    @Throws(Exception::class)
    suspend fun searchText(query: String): List<Cafe>

    /**
     * テキストクエリでカフェを検索する（位置バイアスあり）。
     *
     * Apple Maps POI タップ連携など、特定の座標の近傍で名前照合したいケースで使用する。
     * SKIE がデフォルト引数を Swift に引き出さないため、バイアスなし版と 2 つのオーバーロードに分けている。
     *
     * @param query 検索キーワード（例: POI の表示名）
     * @param locationBias 検索結果を優先するエリア（中心座標 + 半径）
     * @return 検索結果の [Cafe] リスト。0 件の場合は空リスト
     * @throws Exception API 呼び出し失敗時
     */
    @Throws(Exception::class)
    suspend fun searchText(query: String, locationBias: LocationBias): List<Cafe>

    /**
     * 名前 + 位置バイアスで**型フィルタなし**のテキスト検索を行う（Apple Maps POI タップ解決専用）。
     *
     * [searchText] は `includedType=cafe` を強制するため、Apple が cafe 分類する店でも Google Places で
     * `cafe`/`coffee_shop` 型でない店（ランドリー併設カフェ・食事カフェ等）は結果に出ない。POI タップの
     * ように名前と座標が分かっている解決では、型フィルタを外して名前と位置で拾う（フェーズ 17-D）。
     *
     * @param query 検索キーワード（POI の表示名）
     * @param locationBias 検索結果を優先するエリア（中心座標 + 半径）
     * @return 検索結果の [Cafe] リスト。0 件の場合は空リスト
     * @throws Exception API 呼び出し失敗時
     */
    @Throws(Exception::class)
    suspend fun searchByNameNear(query: String, locationBias: LocationBias): List<Cafe>

    /**
     * 現在地の周辺にあるカフェを検索する。
     *
     * @param latitude 検索中心点の緯度
     * @param longitude 検索中心点の経度
     * @param radiusMeters 検索半径（メートル）。デフォルトは 500m
     * @return 周辺カフェの [Cafe] リスト。0 件の場合は空リスト
     * @throws Exception API 呼び出し失敗時
     */
    @Throws(Exception::class)
    suspend fun searchNearby(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 500.0,
    ): List<Cafe>

    /**
     * 指定した Place ID の詳細情報を取得する。
     *
     * @param placeId Google Places の Place ID（例: `"ChIJ..."` 形式）
     * @return [Cafe] ドメインモデル
     * @throws Exception API 呼び出し失敗時（404 など）
     */
    @Throws(Exception::class)
    suspend fun getDetails(placeId: String): Cafe

    /**
     * 写真の表示用 URL を取得する（Photo Media API）。
     *
     * GET `https://places.googleapis.com/v1/{photoName}/media?skipHttpRedirect=true&maxWidthPx=...&maxHeightPx=...`
     *
     * `photoName` は `Cafe.photoReferences` の要素（`"places/{placeId}/photos/{photoRef}"` 形式）。
     * 返値は Google CDN の時限署名 URL。Places 利用規約により永続キャッシュは禁止。
     *
     * @param photoName `"places/{placeId}/photos/{photoRef}"` 形式の写真名
     * @param maxWidthPx 最大幅（px）。null の場合はサイズ未指定
     * @param maxHeightPx 最大高さ（px）。null の場合はサイズ未指定
     * @return 時限署名 URL 文字列
     * @throws Exception API 呼び出し失敗時
     */
    @Throws(Exception::class)
    suspend fun photoMediaUrl(
        photoName: String,
        maxWidthPx: Int?,
        maxHeightPx: Int?,
    ): String
}
