package com.noricoffee.domain.model

import com.noricoffee.domain.Cafe
import kotlinx.datetime.Instant

/**
 * 同一カフェへのコーヒー記録を集計した集約モデル。
 *
 * [Cafe.placeId] をキーに [com.noricoffee.domain.CoffeeRecord] のうち
 * **`cafe != null` のもの（カフェ紐づき記録）** を集約し、
 * マップピンや訪問済みカフェ一覧で表示するために使う。
 * セルフ抽出（`cafe == null`）は座標が無くマップに出せないため集計対象外。
 *
 * ## Cafe スナップショットの採用方針
 * [cafe] には **最新記録時の Cafe スナップショット** を採用する。
 * 同一 [Cafe.placeId] に対して過去に店舗名や住所が変わっていた場合は「最新値勝ち」になる。
 *
 * ## averageRating の計算方針
 * [averageRating] は [com.noricoffee.domain.CoffeeRecord.rating] が 0 より大きいものだけ算術平均を取る。
 * 全件 0 のときは null を返す。
 *
 * @property cafe 最新記録時点の [Cafe] スナップショット
 * @property lastVisitedAt そのカフェで最後にコーヒーを記録した日（UTC 開始 Instant）
 * @property visitCount そのカフェでのコーヒー記録件数
 * @property averageRating 記録の平均評価（rating=0 は除外、全 0 なら null）
 */
data class VisitedCafe(
    val cafe: Cafe,                       // 最新記録時のカフェスナップショット
    val lastVisitedAt: Instant,           // そのカフェで最後にコーヒーを記録した日
    val visitCount: Int,                  // そのカフェでのコーヒー記録件数
    val averageRating: Double?,           // 記録の平均評価（rating=0 は除外、全 0 なら null）
)
