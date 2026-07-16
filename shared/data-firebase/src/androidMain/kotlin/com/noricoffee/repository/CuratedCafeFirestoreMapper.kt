package com.noricoffee.repository

import com.noricoffee.domain.model.CuratedCafe

/**
 * Firestore `curatedCafes/{prefectureCode}` ドキュメント → [CuratedCafe] リスト の変換ヘルパ。
 *
 * read-only なので [CuratedCafe] → Firestore の逆変換（toDocument）は持たない（投入はシードスクリプト経由）。
 *
 * ## フィールド規則
 * - ドキュメント直下の `prefectureCode` が欠如 / 型不一致の場合は空リストを返す
 * - `cafes` 配列の各要素は `placeId` / `name` / `latitude` / `longitude` がすべて必須。
 *   いずれか欠如 / 型不一致の要素は mapNotNull で skip する（ドキュメント全体は無効にしない）
 * - `latitude` / `longitude` は Firestore 上 Long/Double どちらの可能性もあるため `Number` として受けて変換する
 *
 * @see [docs/data-model.md] §3.2 curatedCafes ドキュメント定義
 */
object CuratedCafeFirestoreMapper {

    /**
     * Firestore `curatedCafes/{prefectureCode}` ドキュメントの Map を [CuratedCafe] のリストに変換する。
     *
     * ドキュメント直下の `prefectureCode` が欠如していれば空リストを返す。
     * `cafes` 配列の各要素は必須フィールド欠如時に skip する。
     */
    fun fromDocument(data: Map<String, Any>): List<CuratedCafe> {
        val prefectureCode = data["prefectureCode"] as? String ?: return emptyList()
        val cafesRaw = data["cafes"] as? List<*> ?: return emptyList()

        return cafesRaw.mapNotNull { entry ->
            @Suppress("UNCHECKED_CAST")
            val cafeMap = entry as? Map<String, Any> ?: return@mapNotNull null
            val placeId = cafeMap["placeId"] as? String ?: return@mapNotNull null
            val name = cafeMap["name"] as? String ?: return@mapNotNull null
            val latitude = (cafeMap["latitude"] as? Number)?.toDouble() ?: return@mapNotNull null
            val longitude = (cafeMap["longitude"] as? Number)?.toDouble() ?: return@mapNotNull null

            CuratedCafe(
                placeId = placeId,
                name = name,
                latitude = latitude,
                longitude = longitude,
                prefectureCode = prefectureCode,
            )
        }
    }
}
