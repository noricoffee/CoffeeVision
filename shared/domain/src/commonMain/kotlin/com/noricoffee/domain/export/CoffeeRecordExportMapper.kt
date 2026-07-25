package com.noricoffee.domain.export

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.Photo
import com.noricoffee.domain.TastingScores

/**
 * [CoffeeRecord] → export DTO への変換。
 *
 * Firestore 直列化規則（[CoffeeFirestoreMapper] と同等。[data-model.md] §3.2）を踏襲する:
 * - enum は `.name` 文字列
 * - `visitedOn` は `"YYYY-MM-DD"`（[kotlinx.datetime.LocalDate.toString] がその形式）
 * - `createdAt` / `updatedAt` は ISO-8601 文字列（[kotlinx.datetime.Instant.toString]）
 */
object CoffeeRecordExportMapper {

    fun toDto(record: CoffeeRecord): CoffeeRecordExportDto = CoffeeRecordExportDto(
        id = record.id,
        userId = record.userId,
        cafe = record.cafe?.let { toDto(it) },
        visitedOn = record.visitedOn.toString(),
        rating = record.rating,
        notes = record.notes,
        name = record.name,
        brewMethod = record.brewMethod.name,
        origin = record.origin,
        region = record.region,
        variety = record.variety,
        processing = record.processing?.name,
        roastLevel = record.roastLevel?.name,
        cup = record.cup,
        brewRecipe = record.brewRecipe,
        tasting = record.tasting?.let { toDto(it) },
        tags = record.tags,
        photos = record.photos.map { toDto(it) },
        createdAt = record.createdAt.toString(),
        updatedAt = record.updatedAt.toString(),
    )

    private fun toDto(cafe: Cafe): CafeExportDto = CafeExportDto(
        placeId = cafe.placeId,
        name = cafe.name,
        address = cafe.address,
        latitude = cafe.latitude,
        longitude = cafe.longitude,
        photoReferences = cafe.photoReferences,
        websiteUrl = cafe.websiteUrl,
        mapsUrl = cafe.mapsUrl,
    )

    private fun toDto(photo: Photo): PhotoExportDto = PhotoExportDto(
        id = photo.id,
        fileName = photo.fileName,
        width = photo.width,
        height = photo.height,
        createdAt = photo.createdAt.toString(),
    )

    private fun toDto(tasting: TastingScores): TastingScoresExportDto = TastingScoresExportDto(
        sweetness = tasting.sweetness,
        body = tasting.body,
        acidity = tasting.acidity,
        flavor = tasting.flavor,
        aftertaste = tasting.aftertaste,
    )
}
