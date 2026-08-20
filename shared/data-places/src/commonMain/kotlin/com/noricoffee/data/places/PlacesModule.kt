package com.noricoffee.data.places

import com.noricoffee.repository.CafeRepository

/**
 * [CafeRepository] のインスタンスを生成するファクトリ関数。
 *
 * `createPlacesHttpClient()` が `internal` のため、外部モジュール（`shared/core` 等）から
 * 直接呼べない。このファクトリを通じて `AppContainer` が [CafeRepository] を組み立てる。
 *
 * @param apiKey Google Places API キー。空文字を渡すと API 呼び出し時に 401 が返る
 *   （ビルド検証目的なら空文字でも構わない）。
 */
fun createCafeRepository(apiKey: String): CafeRepository =
    CafeRepositoryImpl(
        placesClient = PlacesClientImpl(
            httpClient = createPlacesHttpClient(),
            apiKey = apiKey,
        )
    )
