package com.noricoffee.domain

import kotlinx.datetime.Instant

data class Photo(
    val id: String,
    val localPath: String?,
    val remoteUrl: String?,
    val width: Int?,
    val height: Int?,
    val createdAt: Instant,
)
