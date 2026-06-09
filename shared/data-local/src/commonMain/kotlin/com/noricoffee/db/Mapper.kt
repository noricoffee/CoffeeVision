package com.noricoffee.db

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.CoffeeItem as DomainCoffeeItem
import com.noricoffee.domain.FoodItem as DomainFoodItem
import com.noricoffee.domain.Photo as DomainPhoto
import com.noricoffee.domain.Visit as DomainVisit
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json

private val json = Json
private val photoRefsSerializer = ListSerializer(String.serializer())

internal fun List<String>.encodeToJson(): String =
    json.encodeToString(photoRefsSerializer, this)

internal fun String.decodeStringList(): List<String> =
    json.decodeFromString(photoRefsSerializer, this)

internal fun DomainVisit.toRow(): Visit = Visit(
    id = id,
    user_id = userId,
    cafe_place_id = cafe.placeId,
    cafe_name = cafe.name,
    cafe_address = cafe.address,
    cafe_latitude = cafe.latitude,
    cafe_longitude = cafe.longitude,
    cafe_photo_references = cafe.photoReferences.encodeToJson(),
    cafe_website_url = cafe.websiteUrl,
    cafe_maps_url = cafe.mapsUrl,
    visited_on = visitedOn.toString(),
    ambiance = ambiance,
    rating = rating.toLong(),
    notes = notes,
    created_at = createdAt.toEpochMilliseconds(),
    updated_at = updatedAt.toEpochMilliseconds(),
)

internal fun Visit.toDomain(
    coffees: List<DomainCoffeeItem>,
    foods: List<DomainFoodItem>,
    photos: List<DomainPhoto>,
): DomainVisit = DomainVisit(
    id = id,
    userId = user_id,
    cafe = Cafe(
        placeId = cafe_place_id,
        name = cafe_name,
        address = cafe_address,
        latitude = cafe_latitude,
        longitude = cafe_longitude,
        photoReferences = cafe_photo_references.decodeStringList(),
        websiteUrl = cafe_website_url,
        mapsUrl = cafe_maps_url,
    ),
    visitedOn = LocalDate.parse(visited_on),
    ambiance = ambiance,
    rating = rating.toInt(),
    notes = notes,
    photos = photos,
    coffees = coffees,
    foods = foods,
    createdAt = Instant.fromEpochMilliseconds(created_at),
    updatedAt = Instant.fromEpochMilliseconds(updated_at),
)

internal fun DomainCoffeeItem.toRow(visitId: String, sortOrder: Int): Coffee_item = Coffee_item(
    id = id,
    visit_id = visitId,
    name = name,
    brew_method = brewMethod.name,
    origin = origin,
    variety = variety,
    processing = processing?.name,
    roast_level = roastLevel?.name,
    cup = cup,
    rating = rating.toLong(),
    notes = notes,
    sort_order = sortOrder.toLong(),
)

internal fun Coffee_item.toDomain(): DomainCoffeeItem = DomainCoffeeItem(
    id = id,
    name = name,
    brewMethod = BrewMethod.valueOf(brew_method),
    origin = origin,
    variety = variety,
    processing = processing?.let { ProcessingMethod.valueOf(it) },
    roastLevel = roast_level?.let { RoastLevel.valueOf(it) },
    cup = cup,
    rating = rating.toInt(),
    notes = notes,
)

internal fun DomainFoodItem.toRow(visitId: String, sortOrder: Int): Food_item = Food_item(
    id = id,
    visit_id = visitId,
    name = name,
    rating = rating.toLong(),
    notes = notes,
    sort_order = sortOrder.toLong(),
)

internal fun Food_item.toDomain(): DomainFoodItem = DomainFoodItem(
    id = id,
    name = name,
    rating = rating.toInt(),
    notes = notes,
)

internal fun DomainPhoto.toRow(visitId: String, sortOrder: Int): Photo = Photo(
    id = id,
    visit_id = visitId,
    file_name = fileName,
    local_path = localPath,
    remote_url = remoteUrl,
    width = width?.toLong(),
    height = height?.toLong(),
    created_at = createdAt.toEpochMilliseconds(),
    sort_order = sortOrder.toLong(),
)

internal fun Photo.toDomain(): DomainPhoto = DomainPhoto(
    id = id,
    fileName = file_name,
    localPath = local_path,
    remoteUrl = remote_url,
    width = width?.toInt(),
    height = height?.toInt(),
    createdAt = Instant.fromEpochMilliseconds(created_at),
)
