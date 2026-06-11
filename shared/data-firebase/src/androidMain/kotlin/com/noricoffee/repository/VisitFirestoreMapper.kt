package com.noricoffee.repository

import com.google.firebase.Timestamp
import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeItem
import com.noricoffee.domain.FoodItem
import com.noricoffee.domain.Photo
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.Visit
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

/**
 * Kotlin の [Visit] ドメインモデル ↔ Firestore ドキュメント `Map<String, Any?>` を変換するヘルパ。
 *
 * iOS 側の `VisitFirestoreMapper.swift` と同等のフィールド扱い:
 * - nullable フィールドは **キーごと省略**（Firestore の null 比較を避けるため）
 * - enum は Kotlin の `name` 文字列（例: `BrewMethod.HandDrip` → `"HandDrip"`）
 * - `createdAt` / `updatedAt` は Firestore `Timestamp`
 * - `Photo.localPath` は端末固有値のため Firestore に書かない
 * - `Photo.fileName` は Firestore に保存する（機種変時の再構築に使う）
 * - `sortOrder` はドメインモデルに持たせず、upload 時に配列 index で採番。
 *   decode 時は sortOrder でソート後に破棄する
 */
object VisitFirestoreMapper {

    // ─────────────────────────────────────────────────
    // Visit（親ドキュメント）
    // ─────────────────────────────────────────────────

    /**
     * Visit を Firestore 親ドキュメント形式に変換する。
     * 子コレクション（coffees / foods / photos）はサブコレクションで別途保存するため含めない。
     */
    fun toDocument(visit: Visit): Map<String, Any?> {
        val cafe = visit.cafe
        val cafeDict = mutableMapOf<String, Any?>(
            "placeId" to cafe.placeId,
            "name" to cafe.name,
            "photoReferences" to cafe.photoReferences,
        )
        cafe.address?.let { cafeDict["address"] = it }
        cafe.latitude?.let { cafeDict["latitude"] = it }
        cafe.longitude?.let { cafeDict["longitude"] = it }
        cafe.websiteUrl?.let { cafeDict["websiteUrl"] = it }
        cafe.mapsUrl?.let { cafeDict["mapsUrl"] = it }

        return mapOf(
            "id" to visit.id,
            "userId" to visit.userId,
            "cafe" to cafeDict,
            "visitedOn" to visit.visitedOn.toString(),
            "ambiance" to visit.ambiance,
            "rating" to visit.rating,
            "notes" to visit.notes,
            "createdAt" to Timestamp(
                visit.createdAt.epochSeconds,
                visit.createdAt.nanosecondsOfSecond,
            ),
            "updatedAt" to Timestamp(
                visit.updatedAt.epochSeconds,
                visit.updatedAt.nanosecondsOfSecond,
            ),
        )
    }

    /**
     * Firestore 親ドキュメントを Visit に変換する。
     * 子配列は呼び出し側でサブコレクションから取得して埋める前提で、ここでは空リストを返す。
     * パース失敗時は null を返す（呼び出し側でスキップ）。
     */
    @Suppress("UNCHECKED_CAST")
    fun fromDocument(data: Map<String, Any>): Visit? {
        val id = data["id"] as? String ?: return null
        val userId = data["userId"] as? String ?: return null
        @Suppress("UNCHECKED_CAST")
        val cafeDict = data["cafe"] as? Map<String, Any> ?: return null
        val placeId = cafeDict["placeId"] as? String ?: return null
        val cafeName = cafeDict["name"] as? String ?: return null
        val visitedOnStr = data["visitedOn"] as? String ?: return null
        val visitedOn = parseLocalDate(visitedOnStr) ?: return null
        val ambiance = data["ambiance"] as? String ?: return null
        val rating = (data["rating"] as? Number)?.toInt() ?: return null
        val notes = data["notes"] as? String ?: return null
        val createdAtTs = data["createdAt"] as? Timestamp ?: return null
        val updatedAtTs = data["updatedAt"] as? Timestamp ?: return null

        @Suppress("UNCHECKED_CAST")
        val photoReferences = (cafeDict["photoReferences"] as? List<String>) ?: emptyList()

        val cafe = Cafe(
            placeId = placeId,
            name = cafeName,
            address = cafeDict["address"] as? String,
            latitude = (cafeDict["latitude"] as? Number)?.toDouble(),
            longitude = (cafeDict["longitude"] as? Number)?.toDouble(),
            photoReferences = photoReferences,
            websiteUrl = cafeDict["websiteUrl"] as? String,
            mapsUrl = cafeDict["mapsUrl"] as? String,
        )

        return Visit(
            id = id,
            userId = userId,
            cafe = cafe,
            visitedOn = visitedOn,
            ambiance = ambiance,
            rating = rating,
            notes = notes,
            photos = emptyList(),
            coffees = emptyList(),
            foods = emptyList(),
            createdAt = Instant.fromEpochSeconds(
                epochSeconds = createdAtTs.seconds,
                nanosecondAdjustment = createdAtTs.nanoseconds.toLong(),
            ),
            updatedAt = Instant.fromEpochSeconds(
                epochSeconds = updatedAtTs.seconds,
                nanosecondAdjustment = updatedAtTs.nanoseconds.toLong(),
            ),
        )
    }

    // ─────────────────────────────────────────────────
    // CoffeeItem
    // ─────────────────────────────────────────────────

    /**
     * CoffeeItem を `coffeeItems/{id}` 用の Firestore ドキュメントに変換する。
     * [sortOrder] は呼び出し側で採番した配列 index を渡す。
     */
    fun toDocument(item: CoffeeItem, sortOrder: Int): Map<String, Any?> {
        val dict = mutableMapOf<String, Any?>(
            "id" to item.id,
            "name" to item.name,
            "brewMethod" to item.brewMethod.name,
            "rating" to item.rating,
            "sortOrder" to sortOrder,
        )
        item.origin?.let { dict["origin"] = it }
        item.variety?.let { dict["variety"] = it }
        item.processing?.let { dict["processing"] = it.name }
        item.roastLevel?.let { dict["roastLevel"] = it.name }
        item.cup?.let { dict["cup"] = it }
        item.notes?.let { dict["notes"] = it }
        return dict
    }

    /**
     * Firestore ドキュメントを `CoffeeItem` + `sortOrder` のペアに変換する。
     * パース失敗時は null を返す。
     */
    fun coffeeItemFromDocument(data: Map<String, Any>): Pair<CoffeeItem, Int>? {
        val id = data["id"] as? String ?: return null
        val name = data["name"] as? String ?: return null
        val brewMethodName = data["brewMethod"] as? String ?: return null
        val brewMethod = BrewMethod.entries.firstOrNull { it.name == brewMethodName } ?: return null
        val rating = (data["rating"] as? Number)?.toInt() ?: return null

        val processing = (data["processing"] as? String)?.let { processingName ->
            ProcessingMethod.entries.firstOrNull { it.name == processingName }
        }
        val roastLevel = (data["roastLevel"] as? String)?.let { roastName ->
            RoastLevel.entries.firstOrNull { it.name == roastName }
        }
        val sortOrder = (data["sortOrder"] as? Number)?.toInt() ?: 0

        val item = CoffeeItem(
            id = id,
            name = name,
            brewMethod = brewMethod,
            origin = data["origin"] as? String,
            variety = data["variety"] as? String,
            processing = processing,
            roastLevel = roastLevel,
            cup = data["cup"] as? String,
            rating = rating,
            notes = data["notes"] as? String,
        )
        return item to sortOrder
    }

    // ─────────────────────────────────────────────────
    // FoodItem
    // ─────────────────────────────────────────────────

    /**
     * FoodItem を `foodItems/{id}` 用の Firestore ドキュメントに変換する。
     */
    fun toDocument(item: FoodItem, sortOrder: Int): Map<String, Any?> {
        val dict = mutableMapOf<String, Any?>(
            "id" to item.id,
            "name" to item.name,
            "rating" to item.rating,
            "sortOrder" to sortOrder,
        )
        item.notes?.let { dict["notes"] = it }
        return dict
    }

    /**
     * Firestore ドキュメントを `FoodItem` + `sortOrder` のペアに変換する。
     */
    fun foodItemFromDocument(data: Map<String, Any>): Pair<FoodItem, Int>? {
        val id = data["id"] as? String ?: return null
        val name = data["name"] as? String ?: return null
        val rating = (data["rating"] as? Number)?.toInt() ?: return null
        val sortOrder = (data["sortOrder"] as? Number)?.toInt() ?: 0

        val item = FoodItem(
            id = id,
            name = name,
            rating = rating,
            notes = data["notes"] as? String,
        )
        return item to sortOrder
    }

    // ─────────────────────────────────────────────────
    // Photo
    // ─────────────────────────────────────────────────

    /**
     * Photo を `photos/{id}` 用の Firestore ドキュメントに変換する。
     * [Photo.localPath] は端末固有値のため Firestore には保存しない。
     * [Photo.fileName] は機種変・iCloud Backup 復元時の localPath 再構築用に保存する。
     */
    fun toDocument(photo: Photo, sortOrder: Int): Map<String, Any?> {
        val dict = mutableMapOf<String, Any?>(
            "id" to photo.id,
            "createdAt" to Timestamp(
                photo.createdAt.epochSeconds,
                photo.createdAt.nanosecondsOfSecond,
            ),
            "sortOrder" to sortOrder,
        )
        photo.fileName?.let { dict["fileName"] = it }
        photo.remoteUrl?.let { dict["remoteUrl"] = it }
        photo.width?.let { dict["width"] = it }
        photo.height?.let { dict["height"] = it }
        return dict
    }

    /**
     * Firestore ドキュメントを `Photo` + `sortOrder` のペアに変換する。
     * `localPath` は Firestore に存在しないため常に null（端末側 DB のみが保持）。
     */
    fun photoFromDocument(data: Map<String, Any>): Pair<Photo, Int>? {
        val id = data["id"] as? String ?: return null
        val createdAtTs = data["createdAt"] as? Timestamp ?: return null
        val sortOrder = (data["sortOrder"] as? Number)?.toInt() ?: 0

        val photo = Photo(
            id = id,
            fileName = data["fileName"] as? String,
            localPath = null,
            remoteUrl = data["remoteUrl"] as? String,
            width = (data["width"] as? Number)?.toInt(),
            height = (data["height"] as? Number)?.toInt(),
            createdAt = Instant.fromEpochSeconds(
                epochSeconds = createdAtTs.seconds,
                nanosecondAdjustment = createdAtTs.nanoseconds.toLong(),
            ),
        )
        return photo to sortOrder
    }

    // ─────────────────────────────────────────────────
    // ヘルパ
    // ─────────────────────────────────────────────────

    /** `YYYY-MM-DD` 形式の文字列を [LocalDate] に変換する。失敗時は null を返す。 */
    private fun parseLocalDate(str: String): LocalDate? {
        return try {
            LocalDate.parse(str)
        } catch (e: Exception) {
            null
        }
    }
}
