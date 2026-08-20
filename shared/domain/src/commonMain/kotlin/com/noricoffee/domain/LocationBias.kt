package com.noricoffee.domain

/**
 * テキスト検索（`searchText`）に渡す位置バイアス。
 *
 * Places API (New) v1 の `locationBias.circle.center` / `radius` に対応する。
 * 位置バイアスがある場合、サーバ側で「指定した円内に近い結果を優先」して返す。
 * 同名チェーン店が全国に存在する場合などに特定の店舗を絞り込む目的で使用する。
 *
 * @param latitude 中心点の緯度
 * @param longitude 中心点の経度
 * @param radiusMeters 円の半径（メートル）。Apple Maps POI タップ連携では 500m を使用する
 */
data class LocationBias(
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Double,
)
