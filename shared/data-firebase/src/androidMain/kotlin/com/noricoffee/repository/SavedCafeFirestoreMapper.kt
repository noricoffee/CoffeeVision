package com.noricoffee.repository

import com.google.firebase.Timestamp
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.model.SavedCafe
import kotlinx.datetime.Instant

/**
 * Kotlin の [SavedCafe] ドメインモデル ↔ Firestore ドキュメント `Map<String, Any?>` を変換するヘルパ。
 *
 * ## Firestore コレクション構造
 * `users/{uid}/savedCafes/{placeId}` — ドキュメント ID = `cafe.placeId`（[data-model.md] §1.9 の自然キー）。
 *
 * ## フィールド規則（[CoffeeFirestoreMapper] と共通化）
 * - `cafe` マップは [CoffeeFirestoreMapper] と同じスナップショット 8 フィールド + `photoAttributions`
 *   のみ。nullable フィールドは null 時にキーを省略する。`photoAttributions` は空リストならキーごと省略
 * - `note` は空文字を含めて常に書き出す
 * - `savedAt` は Firestore `Timestamp`
 */
object SavedCafeFirestoreMapper {

    /** [SavedCafe] を Firestore `savedCafes/{placeId}` ドキュメントの Map に変換する。 */
    fun toDocument(savedCafe: SavedCafe): Map<String, Any?> = mapOf(
        "cafe" to cafeToMap(savedCafe.cafe),
        "note" to savedCafe.note,
        "savedAt" to Timestamp(
            savedCafe.savedAt.epochSeconds,
            savedCafe.savedAt.nanosecondsOfSecond,
        ),
    )

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
        // 空リストならキーごと省略（CoffeeFirestoreMapper.cafeToMap と共通の流儀）
        if (cafe.photoAttributions.isNotEmpty()) {
            map["photoAttributions"] = cafe.photoAttributions
        }
        return map
    }

    /**
     * Firestore `savedCafes/{placeId}` ドキュメントの Map を [SavedCafe] に変換する。
     *
     * @param userId ドキュメントの親パス `users/{uid}` から得られる uid（ドキュメント自体には持たない）
     * 必須フィールドが欠如 / パース失敗した場合は null を返す（呼び出し側でスキップ）。
     */
    @Suppress("UNCHECKED_CAST")
    fun fromDocument(userId: String, data: Map<String, Any>): SavedCafe? {
        val cafeMap = data["cafe"] as? Map<String, Any> ?: return null
        val cafe = cafeFromMap(cafeMap) ?: return null
        val note = data["note"] as? String ?: ""
        val savedAtTs = data["savedAt"] as? Timestamp ?: return null

        return SavedCafe(
            userId = userId,
            cafe = cafe,
            note = note,
            savedAt = Instant.fromEpochSeconds(
                epochSeconds = savedAtTs.seconds,
                nanosecondAdjustment = savedAtTs.nanoseconds.toLong(),
            ),
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun cafeFromMap(map: Map<String, Any>): Cafe? {
        val placeId = map["placeId"] as? String ?: return null
        val cafeName = map["name"] as? String ?: return null
        val photoReferences = (map["photoReferences"] as? List<String>) ?: emptyList()
        val photoAttributions = (map["photoAttributions"] as? List<String>) ?: emptyList()
        return Cafe(
            placeId = placeId,
            name = cafeName,
            address = map["address"] as? String,
            latitude = (map["latitude"] as? Number)?.toDouble(),
            longitude = (map["longitude"] as? Number)?.toDouble(),
            photoReferences = photoReferences,
            photoAttributions = photoAttributions,
            websiteUrl = map["websiteUrl"] as? String,
            mapsUrl = map["mapsUrl"] as? String,
        )
    }
}
