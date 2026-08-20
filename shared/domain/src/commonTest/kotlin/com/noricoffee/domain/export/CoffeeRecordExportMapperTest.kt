package com.noricoffee.domain.export

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.Photo
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.TastingScores
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * [CoffeeRecordExportMapper] を検証する（データモデル §8 / [ExportCoffeeRecordsUseCaseTest] と対）。
 *
 * [CoffeeRecord] にフィールドを追加した際、export DTO / Mapper への追随を忘れると無言のデータ欠損に
 * なる（2026-07-22 `region` 追加で実際に発生）。[fullyPopulatedRecord_allFieldsMapToExportDto] は
 * [CoffeeRecord] の全フィールドを非デフォルト値で埋めた上で DTO の対応フィールドと突き合わせる
 * ため、同種の追随漏れをテストレベルで検出できる（新しいフィールドを [CoffeeRecord] に追加したら、
 * このテストの record にも値を足し assertion を追加すること）。
 */
class CoffeeRecordExportMapperTest {

    private fun cafe() = Cafe(
        placeId = "place-1",
        name = "Blue Bottle 三軒茶屋",
        address = "東京都世田谷区",
        latitude = 35.6448,
        longitude = 139.6694,
        photoReferences = listOf("photo-ref-1"),
        photoAttributions = listOf("Jane Doe"),
        websiteUrl = "https://bluebottlecoffee.jp/",
        mapsUrl = "https://maps.google.com/?cid=1",
        // 揮発フィールド（Places API 取得時のみ）。export DTO は含めないので敢えて非 null にして
        // 「漏れて出力される」ことがないかも一緒に検証する。
        openNow = true,
        weekdayDescriptions = listOf("月曜日: 8:00～20:00"),
        phoneNumber = "03-0000-0000",
        priceLevel = "PRICE_LEVEL_MODERATE",
        googleRating = 4.5,
        userRatingCount = 120,
    )

    private fun photo() = Photo(
        id = "photo-1",
        fileName = "photo-1.jpg",
        localPath = "/local/path/photo-1.jpg", // export 対象外（端末固有パス）
        remoteUrl = "https://example.com/photo-1.jpg",
        width = 100,
        height = 200,
        createdAt = Instant.fromEpochMilliseconds(1_700_000_000_000),
    )

    private fun tasting() = TastingScores(
        sweetness = 7,
        body = 5,
        acidity = 9,
        flavor = 7,
        aftertaste = 6,
    )

    private fun fullyPopulatedRecord() = CoffeeRecord(
        id = "record-1",
        userId = "user-1",
        cafe = cafe(),
        visitedOn = LocalDate(2026, 6, 2),
        rating = 4.5,
        notes = "ベリー系の華やかな酸味",
        photos = listOf(photo()),
        name = "本日のコーヒー",
        brewMethod = BrewMethod.HandDrip,
        origin = "ケニア",
        region = "ニエリ",
        variety = "SL28",
        processing = ProcessingMethod.Washed,
        roastLevel = RoastLevel.Light,
        cup = "白磁カップ",
        brewRecipe = "豆 15g / 湯 240ml / 92℃ / 2:30",
        tasting = tasting(),
        tags = listOf("ラテアート", "浅煎り"),
        createdAt = Instant.fromEpochMilliseconds(1_700_000_000_000),
        updatedAt = Instant.fromEpochMilliseconds(1_700_000_100_000),
    )

    @Test
    fun fullyPopulatedRecord_allFieldsMapToExportDto() {
        val record = fullyPopulatedRecord()

        val dto = CoffeeRecordExportMapper.toDto(record)

        assertEquals(record.id, dto.id)
        assertEquals(record.userId, dto.userId)
        assertEquals(record.visitedOn.toString(), dto.visitedOn)
        assertEquals(record.rating, dto.rating)
        assertEquals(record.notes, dto.notes)
        assertEquals(record.name, dto.name)
        assertEquals(record.brewMethod.name, dto.brewMethod)
        assertEquals(record.origin, dto.origin)
        assertEquals(record.region, dto.region)
        assertEquals(record.variety, dto.variety)
        assertEquals(record.processing?.name, dto.processing)
        assertEquals(record.roastLevel?.name, dto.roastLevel)
        assertEquals(record.cup, dto.cup)
        assertEquals(record.brewRecipe, dto.brewRecipe)
        assertEquals(record.tags, dto.tags)
        assertEquals(record.createdAt.toString(), dto.createdAt)
        assertEquals(record.updatedAt.toString(), dto.updatedAt)

        val cafeDto = requireNotNull(dto.cafe)
        val cafe = requireNotNull(record.cafe)
        assertEquals(cafe.placeId, cafeDto.placeId)
        assertEquals(cafe.name, cafeDto.name)
        assertEquals(cafe.address, cafeDto.address)
        assertEquals(cafe.latitude, cafeDto.latitude)
        assertEquals(cafe.longitude, cafeDto.longitude)
        assertEquals(cafe.photoReferences, cafeDto.photoReferences)
        assertEquals(cafe.photoAttributions, cafeDto.photoAttributions)
        assertEquals(cafe.websiteUrl, cafeDto.websiteUrl)
        assertEquals(cafe.mapsUrl, cafeDto.mapsUrl)

        val tastingDto = requireNotNull(dto.tasting)
        val tasting = requireNotNull(record.tasting)
        assertEquals(tasting.sweetness, tastingDto.sweetness)
        assertEquals(tasting.body, tastingDto.body)
        assertEquals(tasting.acidity, tastingDto.acidity)
        assertEquals(tasting.flavor, tastingDto.flavor)
        assertEquals(tasting.aftertaste, tastingDto.aftertaste)

        assertEquals(1, dto.photos.size)
        val photoDto = dto.photos.first()
        val photo = record.photos.first()
        assertEquals(photo.id, photoDto.id)
        assertEquals(photo.fileName, photoDto.fileName)
        assertEquals(photo.width, photoDto.width)
        assertEquals(photo.height, photoDto.height)
        assertEquals(photo.createdAt.toString(), photoDto.createdAt)
    }
}
