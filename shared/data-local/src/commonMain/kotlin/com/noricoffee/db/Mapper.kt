package com.noricoffee.db

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.Photo as DomainPhoto
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.TastingScores
import com.noricoffee.domain.model.SavedCafe
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
 * [List<String>] を `tags` カラム用の JSON 配列文字列に変換する。
 * 空リストは `"[]"` になる。
 */
internal fun List<String>.toTagsJson(): String =
    json.encodeToString(photoRefsSerializer, this)

/**
 * `tags` カラムの JSON 配列文字列を [List<String>] に変換する。
 *
 * - 空文字（`DEFAULT ''` の行）→ `emptyList()`
 * - `"[]"` → `emptyList()`
 * - パース失敗（不正 JSON）→ `emptyList()`（防御的処理）
 */
internal fun String.toTagList(): List<String> {
    if (isBlank()) return emptyList()
    return runCatching { json.decodeFromString(photoRefsSerializer, this) }.getOrDefault(emptyList())
}

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
    rating = rating,
    notes = notes,
    name = name,
    brew_method = brewMethod.name,
    origin = origin,
    variety = variety,
    processing = processing?.name,
    roast_level = roastLevel?.name,
    cup = cup,
    // all-or-nothing: tasting が null なら全列 null、非 null なら全列セット（Long として保存）
    sweetness = tasting?.sweetness?.toLong(),
    body = tasting?.body?.toLong(),
    acidity = tasting?.acidity?.toLong(),
    flavor = tasting?.flavor?.toLong(),
    aftertaste = tasting?.aftertaste?.toLong(),
    tags = tags.toTagsJson(),
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

    // all-or-nothing: 5 列すべてが非 null のときのみ TastingScores を構築、それ以外は null
    val tastingScores: TastingScores? = if (
        sweetness != null && body != null && acidity != null && flavor != null && aftertaste != null
    ) {
        TastingScores(
            sweetness = sweetness.toInt(),
            body = body.toInt(),
            acidity = acidity.toInt(),
            flavor = flavor.toInt(),
            aftertaste = aftertaste.toInt(),
        )
    } else {
        null
    }

    return CoffeeRecord(
        id = id,
        userId = user_id,
        cafe = cafe,
        visitedOn = LocalDate.parse(visited_on),
        rating = rating,
        notes = notes,
        photos = photos,
        name = name,
        brewMethod = BrewMethod.valueOf(brew_method),
        origin = origin,
        variety = variety,
        processing = processing?.let { ProcessingMethod.valueOf(it) },
        roastLevel = roast_level?.let { RoastLevel.valueOf(it) },
        cup = cup,
        tasting = tastingScores,
        tags = tags.toTagList(),
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

/**
 * [SavedCafe] を SQLDelight の [Saved_cafe] 行に変換する。
 * `cafe_*` 列の直列化規則は [CoffeeRecord.toRow] と共通化する（photoReferences の JSON 化等）。
 */
internal fun SavedCafe.toRow(): Saved_cafe = Saved_cafe(
    place_id = cafe.placeId,
    user_id = userId,
    cafe_name = cafe.name,
    cafe_address = cafe.address,
    cafe_latitude = cafe.latitude,
    cafe_longitude = cafe.longitude,
    cafe_photo_references = cafe.photoReferences.encodeToJson(),
    cafe_website_url = cafe.websiteUrl,
    cafe_maps_url = cafe.mapsUrl,
    note = note,
    saved_at = savedAt.toEpochMilliseconds(),
)

/** SQLDelight の [Saved_cafe] 行を [SavedCafe] ドメインモデルに変換する。 */
internal fun Saved_cafe.toDomain(): SavedCafe = SavedCafe(
    userId = user_id,
    cafe = Cafe(
        placeId = place_id,
        name = cafe_name,
        address = cafe_address,
        latitude = cafe_latitude,
        longitude = cafe_longitude,
        photoReferences = cafe_photo_references?.decodeStringList() ?: emptyList(),
        websiteUrl = cafe_website_url,
        mapsUrl = cafe_maps_url,
    ),
    note = note,
    savedAt = Instant.fromEpochMilliseconds(saved_at),
)
