package com.noricoffee.repository

import com.google.firebase.Timestamp
import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.Photo
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.TastingScores
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

/**
 * Kotlin の [CoffeeRecord] ドメインモデル ↔ Firestore ドキュメント `Map<String, Any?>` を変換するヘルパ。
 *
 * ## Firestore コレクション構造
 * `users/{uid}/coffees/{coffeeId}` — 子サブコレクションを持たない。
 * photos は `CoffeeRecord` ドキュメントに埋め込み配列として保存する。
 *
 * ## フィールド規則
 * - nullable なコーヒー属性（origin / variety / processing / roastLevel / cup）は null ならキーごと省略
 * - cafe が null（セルフ抽出）の場合は `cafe` キーごと省略
 * - photos は埋め込み配列。`localPath` / `remoteUrl` は端末固有値または未使用のため Firestore に書かない
 * - `sortOrder` はドメインモデルに持たせず、upload 時に配列 index で採番。decode 時はソートに使い破棄
 * - enum は Kotlin の `name` 文字列（例: `BrewMethod.HandDrip` → `"HandDrip"`）
 * - `visitedOn` は `"YYYY-MM-DD"` 文字列、`createdAt` / `updatedAt` は Firestore `Timestamp`
 */
object CoffeeFirestoreMapper {

    // ─────────────────────────────────────────────────
    // CoffeeRecord → Firestore ドキュメント
    // ─────────────────────────────────────────────────

    /**
     * [CoffeeRecord] を Firestore `coffees/{coffeeId}` ドキュメントの Map に変換する。
     *
     * - [CoffeeRecord.cafe] が null の場合は `cafe` キーを省略する（セルフ抽出）
     * - nullable コーヒー属性は null ならキーを省略
     * - [CoffeeRecord.photos] は埋め込み配列に変換し、`sortOrder` を配列 index で採番する
     */
    fun toDocument(record: CoffeeRecord): Map<String, Any?> {
        val doc = mutableMapOf<String, Any?>(
            "id" to record.id,
            "userId" to record.userId,
            "visitedOn" to record.visitedOn.toString(),
            "rating" to record.rating,
            "notes" to record.notes,
            "name" to record.name,
            "brewMethod" to record.brewMethod.name,
            "photos" to record.photos.mapIndexed { index, photo -> photoToMap(photo, index) },
            "createdAt" to Timestamp(
                record.createdAt.epochSeconds,
                record.createdAt.nanosecondsOfSecond,
            ),
            "updatedAt" to Timestamp(
                record.updatedAt.epochSeconds,
                record.updatedAt.nanosecondsOfSecond,
            ),
        )

        // cafe が非 null のときのみキーを追加（null = セルフ抽出、キーごと省略）
        record.cafe?.let { doc["cafe"] = cafeToMap(it) }

        // nullable コーヒー属性は null ならキーごと省略
        record.origin?.let { doc["origin"] = it }
        record.variety?.let { doc["variety"] = it }
        record.processing?.let { doc["processing"] = it.name }
        record.roastLevel?.let { doc["roastLevel"] = it.name }
        record.cup?.let { doc["cup"] = it }

        // tasting: 非 null の要素だけ書き出す。全 null なら tasting ごと省略
        val tastingMap = tastingToMap(record.tasting)
        if (tastingMap.isNotEmpty()) {
            doc["tasting"] = tastingMap
        }

        return doc
    }

    /**
     * [TastingScores] を Firestore の `tasting` マップに変換する。
     *
     * - 非 null の要素だけキーを含む。null 要素はキーごと省略
     * - 全要素 null の場合は空 Map を返す（呼び出し側が `tasting` キーを省略する）
     *
     * @see [data-model.md] §3.2
     */
    private fun tastingToMap(tasting: TastingScores): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        tasting.sweetness?.let { map["sweetness"] = it }
        tasting.body?.let { map["body"] = it }
        tasting.acidity?.let { map["acidity"] = it }
        tasting.flavor?.let { map["flavor"] = it }
        tasting.aftertaste?.let { map["aftertaste"] = it }
        return map
    }

    private fun cafeToMap(cafe: Cafe): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>(
            "placeId" to cafe.placeId,
            "name" to cafe.name,
            "photoReferences" to cafe.photoReferences,
        )
        cafe.address?.let { map["address"] = it }
        cafe.latitude?.let { map["latitude"] = it }
        cafe.longitude?.let { map["longitude"] = it }
        cafe.websiteUrl?.let { map["websiteUrl"] = it }
        cafe.mapsUrl?.let { map["mapsUrl"] = it }
        return map
    }

    /**
     * [Photo] を埋め込み配列要素の Map に変換する。
     *
     * - [Photo.localPath] は端末固有値のため書かない
     * - [Photo.remoteUrl] は Storage 採用見送りのため書かない（常に null）
     * - [sortOrder] は呼び出し側が配列 index で採番して渡す
     */
    private fun photoToMap(photo: Photo, sortOrder: Int): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>(
            "id" to photo.id,
            "sortOrder" to sortOrder,
            "createdAt" to Timestamp(
                photo.createdAt.epochSeconds,
                photo.createdAt.nanosecondsOfSecond,
            ),
        )
        photo.fileName?.let { map["fileName"] = it }
        photo.width?.let { map["width"] = it }
        photo.height?.let { map["height"] = it }
        return map
    }

    // ─────────────────────────────────────────────────
    // Firestore ドキュメント → CoffeeRecord
    // ─────────────────────────────────────────────────

    /**
     * Firestore `coffees/{coffeeId}` ドキュメントの Map を [CoffeeRecord] に変換する。
     *
     * - `cafe` キーが欠如していたら `cafe = null`（セルフ抽出）
     * - 必須フィールドが欠如 / パース失敗した場合は null を返す（呼び出し側でスキップ）
     * - photos 埋め込み配列は `sortOrder` でソートした後に `sortOrder` を破棄する
     */
    @Suppress("UNCHECKED_CAST")
    fun fromDocument(data: Map<String, Any>): CoffeeRecord? {
        val id = data["id"] as? String ?: return null
        val userId = data["userId"] as? String ?: return null
        val visitedOnStr = data["visitedOn"] as? String ?: return null
        val visitedOn = parseLocalDate(visitedOnStr) ?: return null
        val rating = (data["rating"] as? Number)?.toDouble() ?: return null
        val notes = data["notes"] as? String ?: return null
        val name = data["name"] as? String ?: return null
        val brewMethodName = data["brewMethod"] as? String ?: return null
        val brewMethod = BrewMethod.entries.firstOrNull { it.name == brewMethodName } ?: return null
        val createdAtTs = data["createdAt"] as? Timestamp ?: return null
        val updatedAtTs = data["updatedAt"] as? Timestamp ?: return null

        // cafe は任意（セルフ抽出では "cafe" キーが存在しない）
        val cafe = (data["cafe"] as? Map<String, Any>)?.let { cafeFromMap(it) }

        // nullable コーヒー属性
        val origin = data["origin"] as? String
        val variety = data["variety"] as? String
        val processing = (data["processing"] as? String)?.let { processingName ->
            ProcessingMethod.entries.firstOrNull { it.name == processingName }
        }
        val roastLevel = (data["roastLevel"] as? String)?.let { roastName ->
            RoastLevel.entries.firstOrNull { it.name == roastName }
        }
        val cup = data["cup"] as? String

        // photos 埋め込み配列: sortOrder でソートして破棄
        val rawPhotos = (data["photos"] as? List<Map<String, Any>>) ?: emptyList()
        val photos = rawPhotos
            .mapNotNull { photoFromMap(it) }
            .sortedBy { it.second }
            .map { it.first }

        // tasting: マップ欠如 → TastingScores()、キー欠如 → null
        val tasting = (data["tasting"] as? Map<String, Any>)?.let { tastingFromMap(it) }
            ?: TastingScores()

        return CoffeeRecord(
            id = id,
            userId = userId,
            cafe = cafe,
            visitedOn = visitedOn,
            rating = rating,
            notes = notes,
            photos = photos,
            name = name,
            brewMethod = brewMethod,
            origin = origin,
            variety = variety,
            processing = processing,
            roastLevel = roastLevel,
            cup = cup,
            tasting = tasting,
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

    @Suppress("UNCHECKED_CAST")
    private fun cafeFromMap(map: Map<String, Any>): Cafe? {
        val placeId = map["placeId"] as? String ?: return null
        val cafeName = map["name"] as? String ?: return null
        val photoReferences = (map["photoReferences"] as? List<String>) ?: emptyList()
        return Cafe(
            placeId = placeId,
            name = cafeName,
            address = map["address"] as? String,
            latitude = (map["latitude"] as? Number)?.toDouble(),
            longitude = (map["longitude"] as? Number)?.toDouble(),
            photoReferences = photoReferences,
            websiteUrl = map["websiteUrl"] as? String,
            mapsUrl = map["mapsUrl"] as? String,
        )
    }

    /**
     * 埋め込み配列要素の Map を [Photo] + sortOrder のペアに変換する。
     * パース失敗時は null を返す。
     */
    private fun photoFromMap(map: Map<String, Any>): Pair<Photo, Int>? {
        val id = map["id"] as? String ?: return null
        val createdAtTs = map["createdAt"] as? Timestamp ?: return null
        val sortOrder = (map["sortOrder"] as? Number)?.toInt() ?: 0

        val photo = Photo(
            id = id,
            fileName = map["fileName"] as? String,
            localPath = null,   // 端末固有値のため Firestore には保存せず、decode 時も常に null
            remoteUrl = null,   // Storage 採用見送り。将来復活時まで null 固定
            width = (map["width"] as? Number)?.toInt(),
            height = (map["height"] as? Number)?.toInt(),
            createdAt = Instant.fromEpochSeconds(
                epochSeconds = createdAtTs.seconds,
                nanosecondAdjustment = createdAtTs.nanoseconds.toLong(),
            ),
        )
        return photo to sortOrder
    }

    /**
     * Firestore `tasting` マップを [TastingScores] に変換する。
     *
     * キーが欠如していた場合は該当要素を null として扱う。
     * 呼び出し側でマップ欠如（`tasting` キー自体がない）は空 [TastingScores] を返す。
     */
    private fun tastingFromMap(map: Map<String, Any>): TastingScores = TastingScores(
        sweetness = (map["sweetness"] as? Number)?.toInt(),
        body = (map["body"] as? Number)?.toInt(),
        acidity = (map["acidity"] as? Number)?.toInt(),
        flavor = (map["flavor"] as? Number)?.toInt(),
        aftertaste = (map["aftertaste"] as? Number)?.toInt(),
    )

    // ─────────────────────────────────────────────────
    // ヘルパ
    // ─────────────────────────────────────────────────

    /** `"YYYY-MM-DD"` 文字列を [LocalDate] に変換する。失敗時は null を返す。 */
    private fun parseLocalDate(str: String): LocalDate? = try {
        LocalDate.parse(str)
    } catch (e: Exception) {
        null
    }
}
