package com.noricoffee.domain

/**
 * テイスティング 5 要素の評価を保持する value object。
 *
 * Blue Bottle「Elements of Coffee Tasting」に基づく 5 要素（甘味/ボディ/酸味/風味/後味）。
 * 各要素は **1〜10 の強度スケール**（未入力は `null`）。「良し悪し」ではなく強度を表す。
 *
 * - `TastingScores()` 全引数デフォルト → 全要素 null = 未入力状態
 * - [CoffeeRecord.tasting] は常に非 null（未入力は全要素 null の空インスタンスで表す）
 * - バリデーションは ViewModel 層で行う: 設定済みの値は `1..10` に収める
 *
 * @property sweetness 甘味（1..10。null = 未設定）
 * @property body ボディ（コク）（1..10。null = 未設定）
 * @property acidity 酸味（1..10。null = 未設定）
 * @property flavor 風味（1..10。null = 未設定）
 * @property aftertaste 後味（1..10。null = 未設定）
 *
 * @see [data-model.md] §1.1a
 */
data class TastingScores(
    val sweetness: Int? = null,    // 甘味     1..10、null = 未設定
    val body: Int? = null,         // ボディ（コク）
    val acidity: Int? = null,      // 酸味
    val flavor: Int? = null,       // 風味
    val aftertaste: Int? = null,   // 後味
)
