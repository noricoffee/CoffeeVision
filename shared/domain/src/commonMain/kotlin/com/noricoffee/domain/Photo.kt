package com.noricoffee.domain

import kotlin.time.Instant

data class Photo(
    val id: String,
    val fileName: String?,
    val localPath: String?,
    val remoteUrl: String?,
    val width: Int?,
    val height: Int?,
    val createdAt: Instant,
)
