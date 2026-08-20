package com.noricoffee.data.places

import io.ktor.client.HttpClient
import io.ktor.client.engine.darwin.Darwin
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.request.header
import platform.Foundation.NSBundle

/**
 * iOS 向けの [HttpClient] ファクトリ。Darwin エンジンを使用する。
 *
 * Google Places API (New) は iOS バンドル ID 制限付き API キーを使用するため、
 * `X-Ios-Bundle-Identifier` ヘッダをすべてのリクエストに自動付与する。
 * このヘッダは Google が GMS SDK の代わりに使うもので、Ktor 生 REST 呼び出しでは
 * 手動で付与しなければ 403 (API_KEY_IOS_APP_BLOCKED) が返る。
 *
 * バンドル ID が取得できない場合（テストホスト環境等）はヘッダを付与しない。
 *
 * **継承について**: `PlacesClientImpl` はこの client を `.config { install(ContentNegotiation) }` で
 * 再構成するが、[HttpClient.config] は元の `userConfig`（DefaultRequest を含む）を
 * `plusAssign` で引き継ぐため、ここで install した DefaultRequest は伝播する。
 */
internal actual fun createPlacesHttpClient(): HttpClient {
    val bundleId = NSBundle.mainBundle.bundleIdentifier
    return HttpClient(Darwin) {
        if (bundleId != null) {
            defaultRequest {
                header("X-Ios-Bundle-Identifier", bundleId)
            }
        }
    }
}
