package com.noricoffee.data.places

/**
 * Places API (New) v1 のレスポンスをフラットにまとめた内部モデル。
 *
 * `PlacesClient` が返す型であり、`CafeRepositoryImpl` で `Cafe` ドメインモデルに変換される。
 * このクラスは `shared/data-places` 内部の実装詳細であるため `internal` 修飾は付けず、
 * `CafeRepositoryImpl`（同モジュール）からのみ参照される。
 *
 * - [photoNames]: `places.photos[].name` をそのまま格納（`"places/{placeId}/photos/{photoRef}"` 形式）
 */
data class PlaceSummary(
    val id: String,
    val displayName: String,
    val formattedAddress: String?,
    val latitude: Double?,
    val longitude: Double?,
    val websiteUri: String?,
    val googleMapsUri: String?,
    val photoNames: List<String>,
)
