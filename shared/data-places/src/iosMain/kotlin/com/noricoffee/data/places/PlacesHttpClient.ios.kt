package com.noricoffee.data.places

import io.ktor.client.HttpClient
import io.ktor.client.engine.darwin.Darwin

internal actual fun createPlacesHttpClient(): HttpClient = HttpClient(Darwin)
