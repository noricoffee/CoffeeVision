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
)
