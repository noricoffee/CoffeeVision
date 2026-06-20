package com.noricoffee.domain

/**
 * テイスティング 5 要素の評価を保持する value object。
 *
 * Blue Bottle「Elements of Coffee Tasting」に基づく 5 要素（甘味/ボディ/酸味/風味/後味）。
 * 各要素は **1〜10 の強度スケール**。「良し悪し」ではなく強度を表す。
 *
 * **all-or-nothing**: テイスティングを付ける場合は 5 要素すべて必須。
 * 部分入力は型として表現不可能（各フィールドが非 null）。
 * 「付けない」は [CoffeeRecord.tasting] = null で表す。
 *
 * UI は「＋」ボタンで `TastingScores(5,5,5,5,5)` を生成して 5 スライダーを一度に出し、
 * 「削除」で `CoffeeRecord.tasting` を null に戻す。部分状態は発生しない。
 *
 * @property sweetness 甘味（1..10）
 * @property body ボディ（コク）（1..10）
 * @property acidity 酸味（1..10）
 * @property flavor 風味（1..10）
 * @property aftertaste 後味（1..10）
 *
 * @see [data-model.md] §1.1a
 */
data class TastingScores(
    val sweetness: Int,     // 甘味     1..10
    val body: Int,          // ボディ（コク）
    val acidity: Int,       // 酸味
    val flavor: Int,        // 風味
    val aftertaste: Int,    // 後味
)
