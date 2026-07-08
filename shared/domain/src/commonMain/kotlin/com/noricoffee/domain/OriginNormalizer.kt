package com.noricoffee.domain

/**
 * 産地文字列のシノニム正規化。
 *
 * `CoffeeRecord.origin` / `BeanProfile.origin` はユーザー入力・サービスデータ双方が自由文字列のため、
 * 「Ethiopia」「イルガチェフェ」のような表記ゆれが集計・突合をすり抜ける。[normalize] は
 * trim + lowercase の軽い正規化のあと、既知のシノニム辞書（英語国名 / サブ地域・通称）に
 * 完全一致すれば正規形（日本語産地表記）を返す決定論の名寄せを提供する。
 *
 * - 辞書外の文字列は trim + lowercase したものをそのまま返す（後方互換。表記ゆれの完全解消は非対象）
 * - 「モカ」はイエメン / エチオピアいずれの通称にもなり得る多義語のため辞書に含めない（誤名寄せ回避）
 * - 品種（variety）のシノニムは対象外
 *
 * @see [docs/data-model.md] §1.6 集計ルール
 */
object OriginNormalizer {

    /**
     * [raw] を trim + lowercase したうえで、シノニム辞書に完全一致すれば正規形（日本語産地）を返す。
     * 辞書外の場合は trim + lowercase した文字列をそのまま返す。
     */
    fun normalize(raw: String): String {
        val base = raw.trim().lowercase()
        return SYNONYMS[base] ?: base
    }

    private val SYNONYMS: Map<String, String> = mapOf(
        // --- 英語国名 → 日本語産地（20 ヶ国） ---
        "ethiopia" to "エチオピア",
        "kenya" to "ケニア",
        "colombia" to "コロンビア",
        "panama" to "パナマ",
        "guatemala" to "グアテマラ",
        "costa rica" to "コスタリカ",
        "costarica" to "コスタリカ",
        "el salvador" to "エルサルバドル",
        "honduras" to "ホンジュラス",
        "brazil" to "ブラジル",
        "brasil" to "ブラジル",
        "peru" to "ペルー",
        "bolivia" to "ボリビア",
        "rwanda" to "ルワンダ",
        "burundi" to "ブルンジ",
        "tanzania" to "タンザニア",
        "yemen" to "イエメン",
        "indonesia" to "インドネシア",
        "india" to "インド",
        "china" to "中国",
        "jamaica" to "ジャマイカ",
        "hawaii" to "ハワイ",
        "papua new guinea" to "パプアニューギニア",
        "png" to "パプアニューギニア",

        // --- サブ地域・通称（カタカナ + 英語綴り） ---
        "イルガチェフェ" to "エチオピア",
        "yirgacheffe" to "エチオピア",
        "グジ" to "エチオピア",
        "guji" to "エチオピア",
        "シダモ" to "エチオピア",
        "sidamo" to "エチオピア",
        "キリマンジャロ" to "タンザニア",
        "kilimanjaro" to "タンザニア",
        "アンティグア" to "グアテマラ",
        "antigua" to "グアテマラ",
        "ウエウエテナンゴ" to "グアテマラ",
        "huehuetenango" to "グアテマラ",
        "コナ" to "ハワイ",
        "kona" to "ハワイ",
        "ブルーマウンテン" to "ジャマイカ",
        "blue mountain" to "ジャマイカ",
        "雲南" to "中国",
        "yunnan" to "中国",
        "スマトラ" to "インドネシア",
        "sumatra" to "インドネシア",
        "マンデリン" to "インドネシア",
        "mandheling" to "インドネシア",
        "トラジャ" to "インドネシア",
        "toraja" to "インドネシア",
        "ジャワ" to "インドネシア",
        "java" to "インドネシア",
        "バリ" to "インドネシア",
        "bali" to "インドネシア",
        "スラウェシ" to "インドネシア",
        "sulawesi" to "インドネシア",
        "マタリ" to "イエメン",
        "mattari" to "イエメン",
    )
}
