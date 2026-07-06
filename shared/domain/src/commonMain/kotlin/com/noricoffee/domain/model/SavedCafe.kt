package com.noricoffee.domain.model

import com.noricoffee.domain.Cafe
import kotlinx.datetime.Instant

/**
 * 「行きたい店」（ウィッシュリスト）1 件を表すドメインモデル。
 *
 * 記録（訪問済み [com.noricoffee.domain.CoffeeRecord]）とは独立した「これから行く店」の管理。
 * 「探す → 保存 → 訪問 → 記録」のループを閉じる（[requirements.md] §10 / [data-model.md] §1.9）。
 *
 * ## キー設計（§5 の UUID 原則の例外）
 *
 * ID は [cafe] の `placeId`（Google Places の自然キー）とする。UUID v4 は持たない。
 * 同じカフェの二重登録を型レベルで防ぎ、保存 / 解除を冪等トグルにするための意図的な例外
 * （[data-model.md] §1.9 / §5 参照）。
 *
 * @property userId Firebase Auth uid
 * @property cafe Places 由来のカフェスナップショット（保存時点。永続化されるのは §1.2 と同じ 8 フィールドのみ）
 * @property note 任意メモ（「◯◯さんおすすめ」等）。空文字可。v1 では常に空文字で保存し、
 *                編集 UI は将来追加する（フィールドだけ確保）
 * @property savedAt 保存日時。一覧の並び順キー（降順）
 */
data class SavedCafe(
    val userId: String,
    val cafe: Cafe,
    val note: String,
    val savedAt: Instant,
)
