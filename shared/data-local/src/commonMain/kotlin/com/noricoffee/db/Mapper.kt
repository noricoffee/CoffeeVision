package com.noricoffee.db

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.Photo as DomainPhoto
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
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

/**
 * [CoffeeRecord] を SQLDelight の [Coffee_record] 行に変換する。
 * cafe が null（セルフ抽出）の場合は全 cafe_* カラムを null にする。
 */
internal fun CoffeeRecord.toRow(): Coffee_record = Coffee_record(
    id = id,
    user_id = userId,
    cafe_place_id = cafe?.placeId,
    cafe_name = cafe?.name,
    cafe_address = cafe?.address,
    cafe_latitude = cafe?.latitude,
    cafe_longitude = cafe?.longitude,
    cafe_photo_references = cafe?.photoReferences?.encodeToJson(),
    cafe_website_url = cafe?.websiteUrl,
    cafe_maps_url = cafe?.mapsUrl,
    visited_on = visitedOn.toString(),
    rating = rating.toLong(),
    notes = notes,
    name = name,
    brew_method = brewMethod.name,
    origin = origin,
    variety = variety,
    processing = processing?.name,
    roast_level = roastLevel?.name,
    cup = cup,
    created_at = createdAt.toEpochMilliseconds(),
    updated_at = updatedAt.toEpochMilliseconds(),
)

/**
 * SQLDelight の [Coffee_record] 行を [CoffeeRecord] ドメインモデルに変換する。
 * [cafe_place_id] が null の場合は `cafe = null`（セルフ抽出）として組み立てる。
 *
 * @param photos 対応する [DomainPhoto] のリスト（別クエリで取得済みのもの）
 */
internal fun Coffee_record.toDomain(photos: List<DomainPhoto>): CoffeeRecord {
    val cafe = if (cafe_place_id != null && cafe_name != null) {
        Cafe(
            placeId = cafe_place_id,
            name = cafe_name,
            address = cafe_address,
            latitude = cafe_latitude,
            longitude = cafe_longitude,
            photoReferences = cafe_photo_references?.decodeStringList() ?: emptyList(),
            websiteUrl = cafe_website_url,
            mapsUrl = cafe_maps_url,
        )
    } else {
        null
    }

    return CoffeeRecord(
        id = id,
        userId = user_id,
        cafe = cafe,
        visitedOn = LocalDate.parse(visited_on),
        rating = rating.toInt(),
        notes = notes,
        photos = photos,
        name = name,
        brewMethod = BrewMethod.valueOf(brew_method),
        origin = origin,
        variety = variety,
        processing = processing?.let { ProcessingMethod.valueOf(it) },
        roastLevel = roast_level?.let { RoastLevel.valueOf(it) },
        cup = cup,
        createdAt = Instant.fromEpochMilliseconds(created_at),
        updatedAt = Instant.fromEpochMilliseconds(updated_at),
    )
}

/**
 * [DomainPhoto] を SQLDelight の [Photo] 行に変換する。
 *
 * @param recordId 親 [CoffeeRecord] の ID
 * @param sortOrder 表示順序
 */
internal fun DomainPhoto.toRow(recordId: String, sortOrder: Int): Photo = Photo(
    id = id,
    record_id = recordId,
    file_name = fileName,
    local_path = localPath,
    remote_url = remoteUrl,
    width = width?.toLong(),
    height = height?.toLong(),
    created_at = createdAt.toEpochMilliseconds(),
    sort_order = sortOrder.toLong(),
)

/** SQLDelight の [Photo] 行を [DomainPhoto] ドメインモデルに変換する。 */
internal fun Photo.toDomain(): DomainPhoto = DomainPhoto(
    id = id,
    fileName = file_name,
    localPath = local_path,
    remoteUrl = remote_url,
    width = width?.toInt(),
    height = height?.toInt(),
    createdAt = Instant.fromEpochMilliseconds(created_at),
)
