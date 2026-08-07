package com.noricoffee.domain.export

import kotlinx.serialization.Serializable

/**
 * データエクスポート（要件 §7-4 / tasks.md フェーズ 15-E-2）用の JSON 直列化 DTO 群。
 *
 * ドメインモデル（[com.noricoffee.domain.CoffeeRecord] 等）に直接 `@Serializable` を付けず、
 * export 専用の DTO に変換してから直列化する。理由:
 * - ドメインモデルに kotlinx-serialization を持ち込まずに済む
 * - Firestore 直列化規則（[data-model.md] §3.2: enum は `.name`、日時は文字列）を素直に踏襲できる
 *
 * バイナリ本体（写真ファイル）は含めない。[PhotoExportDto] はメタデータのみ。
 */
@Serializable
data class CoffeeRecordExportDto(
    val id: String,
    val userId: String,
    val cafe: CafeExportDto?,
    val visitedOn: String,
    val rating: Double? = null,
    val notes: String,
    val name: String,
    val brewMethod: String,
    val origin: String? = null,
    val region: String? = null,
    val variety: String? = null,
    val processing: String? = null,
    val roastLevel: String? = null,
    val cup: String? = null,
    val brewRecipe: String? = null,
    val tasting: TastingScoresExportDto? = null,
    val tags: List<String> = emptyList(),
    val photos: List<PhotoExportDto> = emptyList(),
    val createdAt: String,
    val updatedAt: String,
)

/**
 * [com.noricoffee.domain.Cafe] の永続化 9 フィールドのみを持つ export DTO。
 *
 * Places API 取得時のみ使う揮発フィールド（openNow 等、[data-model.md] §1.2）は含めない。
 */
@Serializable
data class CafeExportDto(
    val placeId: String,
    val name: String,
    val address: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val photoReferences: List<String> = emptyList(),
    val photoAttributions: List<String> = emptyList(),
    val websiteUrl: String? = null,
    val mapsUrl: String? = null,
)

/**
 * [com.noricoffee.domain.Photo] のメタデータのみを持つ export DTO。
 *
 * `localPath`（端末固有パス）は含めない。画像本体（バイナリ）はエクスポート対象外。
 */
@Serializable
data class PhotoExportDto(
    val id: String,
    val fileName: String? = null,
    val width: Int? = null,
    val height: Int? = null,
    val createdAt: String,
)

/** [com.noricoffee.domain.TastingScores] の export DTO。all-or-nothing のため全フィールド非 null。 */
@Serializable
data class TastingScoresExportDto(
    val sweetness: Int,
    val body: Int,
    val acidity: Int,
    val flavor: Int,
    val aftertaste: Int,
)

/**
 * エクスポート JSON のトップレベル包み。
 *
 * [version] は将来のフォーマット変更に備えたスキーマバージョン番号（現在は 1 固定）。
 */
@Serializable
data class CoffeeRecordExportEnvelope(
    val exportedAt: String,
    val version: Int = 1,
    val records: List<CoffeeRecordExportDto>,
)
