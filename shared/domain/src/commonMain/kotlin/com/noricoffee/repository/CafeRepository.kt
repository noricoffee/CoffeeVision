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
}
