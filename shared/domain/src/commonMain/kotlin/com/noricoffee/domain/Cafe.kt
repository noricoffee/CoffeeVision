package com.noricoffee.domain

data class Cafe(
    val placeId: String,
    val name: String,
    val address: String?,
    val latitude: Double?,
    val longitude: Double?,
    val photoReferences: List<String>,
    val websiteUrl: String?,
    val mapsUrl: String?,
    val openNow: Boolean? = null,
    val weekdayDescriptions: List<String> = emptyList(),
    val phoneNumber: String? = null,
    val priceLevel: String? = null,
    val googleRating: Double? = null,
    val userRatingCount: Int? = null,
    // photoReferences と同じ順序・同じ長さで保持する（index i の写真の作者が index i の要素）。
    // 各要素は Places authorAttributions[0].displayName。存在しない場合は空文字で長さを揃える。
    // 永続化対象（Places 写真表示時の作者クレジット表示に必須。App Store ガイドライン 5.2.2 対応）。
    val photoAttributions: List<String> = emptyList(),
)
