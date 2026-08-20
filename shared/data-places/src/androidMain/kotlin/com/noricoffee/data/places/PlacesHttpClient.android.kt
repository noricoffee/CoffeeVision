package com.noricoffee.data.places

import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp

internal actual fun createPlacesHttpClient(): HttpClient = HttpClient(OkHttp)
