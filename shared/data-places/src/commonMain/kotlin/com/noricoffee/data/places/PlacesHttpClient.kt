package com.noricoffee.data.places

import io.ktor.client.HttpClient

/**
 * プラットフォーム別 Ktor エンジンで [HttpClient] を生成する。
 *
 * - iOS: `iosMain` で Darwin エンジン（`HttpClient(Darwin)`）を使う `actual` を提供
 * - Android: `androidMain` で OkHttp エンジン（`HttpClient(OkHttp)`）を使う `actual` を提供
 *
 * `internal` にすることで `data-places` モジュール外からは直接呼べない。
 */
internal expect fun createPlacesHttpClient(): HttpClient
