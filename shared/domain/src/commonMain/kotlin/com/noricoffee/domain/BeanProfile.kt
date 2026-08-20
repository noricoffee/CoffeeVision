package com.noricoffee.domain

/**
 * コーヒー豆ナレッジベース。
 *
 * Firestore のグローバルコレクション `beanProfiles/{beanId}` を read-only で参照するサービス管理データ。
 * ユーザーの [CoffeeRecord] と `beanProfileId` では紐付けしない。
 * `origin` は `OriginNormalizer.normalize`（trim + lowercase + シノニム辞書）を通した上でファジーマッチし、
 * 分析タブの2機能（[com.noricoffee.domain.usecase.PreferredBeanTraitsUseCase]「好みの豆の傾向」/
 * [com.noricoffee.domain.usecase.SuggestUnexploredBeansUseCase]「未経験の豆への探索提案」）に活用する。
 * マッチ方式・スコアの正本は `docs/data-model.md` §1.8。
 *
 * @see [docs/data-model.md] §1.8
 */
data class BeanProfile(
    val beanId: String,                        // Firestore ドキュメント ID
    val name: String,                          // 豆名（表示用）
    val origin: String,                        // 産地（「エチオピア」「コロンビア」等。日本語表記 = §3.2 表記規約）
    val variety: String?,                      // 品種（「ゲイシャ」「ブルボン」等）
    val processings: List<ProcessingMethod>,   // 精製方法（複数可）
    val flavorNotes: List<String>,             // フレーバーノート（「チョコレート」「シトラス」等。統一語彙から選ぶ・自由記述禁止 = §3.2）
    val description: String?,                  // 12-C LLM インプット用説明
)
