package com.noricoffee.domain

/**
 * コーヒー豆ナレッジベース。
 *
 * Firestore のグローバルコレクション `beanProfiles/{beanId}` を read-only で参照するサービス管理データ。
 * ユーザーの [CoffeeRecord] と `beanProfileId` では紐付けしない。
 * `origin`（trim/lowercase）+ `processings`（enum 名）でファジーマッチし、
 * 記録入力時のサジェストや将来の分析強化（12-C）に活用する。
 *
 * @see [docs/data-model.md] §1.8
 */
data class BeanProfile(
    val beanId: String,                        // Firestore ドキュメント ID
    val name: String,                          // 豆名（表示用）
    val origin: String,                        // 産地（"Ethiopia" "Colombia" 等）
    val variety: String?,                      // 品種（"Geisha" "Bourbon" 等）
    val processings: List<ProcessingMethod>,   // 精製方法（複数可）
    val flavorNotes: List<String>,             // フレーバーノート（"Chocolate" "Citrus" 等）
    val description: String?,                  // 12-C LLM インプット用説明
)
