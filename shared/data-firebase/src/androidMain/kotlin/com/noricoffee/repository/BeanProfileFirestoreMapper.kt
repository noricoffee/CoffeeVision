package com.noricoffee.repository

import com.noricoffee.domain.BeanProfile
import com.noricoffee.domain.ProcessingMethod

/**
 * Firestore `beanProfiles/{beanId}` ドキュメント → [BeanProfile] ドメインモデル の変換ヘルパ。
 *
 * read-only なので [BeanProfile] → Firestore の逆変換（toDocument）は持たない。
 *
 * ## フィールド規則
 * - `beanId` / `name` / `origin` は必須。欠如・型不一致の場合は null を返す（呼び出し側でスキップ）
 * - `processings`: Firestore の `List<String>` → [ProcessingMethod] に変換。
 *   不明な文字列は無視する（`entries.firstOrNull { it.name == str }`）
 * - `variety` / `description`: nullable（キーが欠如した場合は null）
 * - `flavorNotes`: `List<String>`（キーが欠如した場合は空リスト）
 *
 * @see [docs/data-model.md] §3.2 beanProfiles ドキュメント定義
 */
object BeanProfileFirestoreMapper {

    /**
     * Firestore `beanProfiles/{beanId}` ドキュメントの Map を [BeanProfile] に変換する。
     *
     * 必須フィールド（`beanId` / `name` / `origin`）が欠如 / 型不一致の場合は null を返す。
     */
    @Suppress("UNCHECKED_CAST")
    fun fromDocument(data: Map<String, Any>): BeanProfile? {
        val beanId = data["beanId"] as? String ?: return null
        val name = data["name"] as? String ?: return null
        val origin = data["origin"] as? String ?: return null

        // processings: Firestore Array<String> → List<ProcessingMethod>（不明文字列はスキップ）
        val processings = (data["processings"] as? List<*>)
            ?.filterIsInstance<String>()
            ?.mapNotNull { str -> ProcessingMethod.entries.firstOrNull { it.name == str } }
            ?: emptyList()

        // nullable フィールド
        val variety = data["variety"] as? String
        val description = data["description"] as? String

        // flavorNotes: キー欠如は空リスト
        val flavorNotes = (data["flavorNotes"] as? List<*>)
            ?.filterIsInstance<String>()
            ?: emptyList()

        return BeanProfile(
            beanId = beanId,
            name = name,
            origin = origin,
            variety = variety,
            processings = processings,
            flavorNotes = flavorNotes,
            description = description,
        )
    }
}
