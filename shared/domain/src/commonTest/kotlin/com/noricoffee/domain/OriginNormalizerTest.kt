package com.noricoffee.domain

import kotlin.test.Test
import kotlin.test.assertEquals

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
}
