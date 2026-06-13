package com.noricoffee.domain.model

import com.noricoffee.domain.Cafe
import kotlinx.datetime.Instant

/**
 * 同一カフェへの訪問を集計した集約モデル。
 *
 * [Cafe.placeId] をキーに [com.noricoffee.domain.Visit] を集約し、
 * マップピンや訪問済みカフェ一覧で表示するために使う。
 *
 * ## Cafe スナップショットの採用方針
 * [cafe] には **最新訪問時の Cafe スナップショット** を採用する。
 * 同一 [Cafe.placeId] に対して過去に店舗名や住所が変わっていた場合は「最新値勝ち」になる。
 * 過去訪問時点の店舗情報を残したい要件が出た場合は別途 Visit 側に snapshot を持たせる必要がある
 * （親への申し送り参照）。
 *
 * ## averageRating の計算方針
 * [averageRating] は [com.noricoffee.domain.Visit.rating] が 0 のものを除外して算術平均を取る。
 * ただし、`Visit.rating` は現行ドメインモデルでは `Int`（1–5）で非 nullable。
 * スキーマが将来 `Int?` に変わった場合は `null` を除外対象に変える。
 * 現状はすべての rating を使って平均を出し、訪問が 0 件のときのみ [averageRating] が null になる。
 *
 * @property cafe 最新訪問時点の [Cafe] スナップショット
 * @property lastVisitedAt 最新 [com.noricoffee.domain.Visit.visitedOn] から導出した [Instant]
 * @property visitCount 同じ [Cafe.placeId] を持つ [com.noricoffee.domain.Visit] の件数
 * @property averageRating 訪問の平均評価。訪問が 0 件のとき null
 */
data class VisitedCafe(
    val cafe: Cafe,
    val lastVisitedAt: Instant,
    val visitCount: Int,
    val averageRating: Double?,
)
