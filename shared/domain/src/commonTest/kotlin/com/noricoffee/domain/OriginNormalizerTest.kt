package com.noricoffee.domain

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * [OriginNormalizer] のユニットテスト。
 */
class OriginNormalizerTest {

    // --- 英語国名シノニム ---

    @Test
    fun englishCountryName_normalizesToJapaneseOrigin() {
        assertEquals("エチオピア", OriginNormalizer.normalize("Ethiopia"))
        assertEquals("ケニア", OriginNormalizer.normalize("Kenya"))
        assertEquals("コロンビア", OriginNormalizer.normalize("Colombia"))
        assertEquals("グアテマラ", OriginNormalizer.normalize("Guatemala"))
        assertEquals("コスタリカ", OriginNormalizer.normalize("Costa Rica"))
        assertEquals("コスタリカ", OriginNormalizer.normalize("CostaRica"))
        assertEquals("エルサルバドル", OriginNormalizer.normalize("El Salvador"))
        assertEquals("ブラジル", OriginNormalizer.normalize("Brazil"))
        assertEquals("ブラジル", OriginNormalizer.normalize("Brasil"))
        assertEquals("パプアニューギニア", OriginNormalizer.normalize("Papua New Guinea"))
        assertEquals("パプアニューギニア", OriginNormalizer.normalize("PNG"))
    }

    @Test
    fun normalize_isCaseInsensitive() {
        assertEquals("エチオピア", OriginNormalizer.normalize("ETHIOPIA"))
        assertEquals("エチオピア", OriginNormalizer.normalize("ethiopia"))
        assertEquals("エチオピア", OriginNormalizer.normalize("EthioPia"))
    }

    @Test
    fun normalize_trimsSurroundingWhitespace() {
        assertEquals("エチオピア", OriginNormalizer.normalize("  Ethiopia  "))
        assertEquals("エチオピア", OriginNormalizer.normalize("\tEthiopia\n"))
    }

    // --- サブ地域・通称シノニム ---

    @Test
    fun subRegionSynonym_normalizesToCountryOrigin() {
        assertEquals("エチオピア", OriginNormalizer.normalize("イルガチェフェ"))
        assertEquals("エチオピア", OriginNormalizer.normalize("Yirgacheffe"))
        assertEquals("エチオピア", OriginNormalizer.normalize("グジ"))
        assertEquals("エチオピア", OriginNormalizer.normalize("シダモ"))
        assertEquals("タンザニア", OriginNormalizer.normalize("キリマンジャロ"))
        assertEquals("タンザニア", OriginNormalizer.normalize("Kilimanjaro"))
        assertEquals("グアテマラ", OriginNormalizer.normalize("アンティグア"))
        assertEquals("グアテマラ", OriginNormalizer.normalize("ウエウエテナンゴ"))
        assertEquals("ハワイ", OriginNormalizer.normalize("コナ"))
        assertEquals("ハワイ", OriginNormalizer.normalize("Kona"))
        assertEquals("ジャマイカ", OriginNormalizer.normalize("ブルーマウンテン"))
        assertEquals("ジャマイカ", OriginNormalizer.normalize("Blue Mountain"))
        assertEquals("中国", OriginNormalizer.normalize("雲南"))
        assertEquals("中国", OriginNormalizer.normalize("Yunnan"))
        assertEquals("インドネシア", OriginNormalizer.normalize("スマトラ"))
        assertEquals("インドネシア", OriginNormalizer.normalize("マンデリン"))
        assertEquals("インドネシア", OriginNormalizer.normalize("トラジャ"))
        assertEquals("インドネシア", OriginNormalizer.normalize("ジャワ"))
        assertEquals("インドネシア", OriginNormalizer.normalize("バリ"))
        assertEquals("インドネシア", OriginNormalizer.normalize("スラウェシ"))
        assertEquals("イエメン", OriginNormalizer.normalize("マタリ"))
        assertEquals("イエメン", OriginNormalizer.normalize("Mattari"))
    }

    // --- 辞書外の文字列 ---

    @Test
    fun unknownOrigin_fallsBackToTrimLowercase() {
        assertEquals("グアテマラ アンティグア", OriginNormalizer.normalize("グアテマラ アンティグア"))
        assertEquals("some unknown origin", OriginNormalizer.normalize("  Some Unknown Origin  "))
    }

    @Test
    fun moka_isAmbiguousAndNotInDictionary() {
        // 「モカ」はイエメン / エチオピアいずれの通称にもなり得る多義語のため辞書に含めない
        assertEquals("モカ", OriginNormalizer.normalize("モカ"))
    }

    // --- CoffeeOriginCatalog との整合（2026-07-22） ---

    @Test
    fun catalogCountries_areFixedPointsOfNormalize() {
        // カタログ各国は normalize の固定点であること（正規化しても自分自身に戻る）
        CoffeeOriginCatalog.countries.forEach { country ->
            assertEquals(country, OriginNormalizer.normalize(country), "$country が固定点ではない")
        }
    }

    @Test
    fun synonymValues_areAllContainedInCatalog() {
        // シノニム辞書の正規形（RHS）は全て CoffeeOriginCatalog.countries に含まれる
        val synonymValues = setOf(
            "エチオピア", "ケニア", "コロンビア", "パナマ", "グアテマラ", "コスタリカ", "エルサルバドル",
            "ホンジュラス", "ブラジル", "ペルー", "ボリビア", "ルワンダ", "ブルンジ", "タンザニア", "イエメン",
            "インドネシア", "インド", "中国", "ジャマイカ", "ハワイ", "パプアニューギニア",
            "ウガンダ", "コンゴ民主共和国", "マラウイ", "ザンビア", "カメルーン", "コートジボワール",
            "ニカラグア", "メキシコ", "エクアドル", "ベネズエラ", "ドミニカ共和国", "ハイチ", "キューバ",
            "プエルトリコ", "ベトナム", "東ティモール", "タイ", "フィリピン", "ラオス", "ミャンマー", "台湾", "ネパール",
        )
        synonymValues.forEach { value ->
            assertTrue(
                CoffeeOriginCatalog.countries.contains(value),
                "$value が CoffeeOriginCatalog.countries に含まれない",
            )
        }
    }
}
