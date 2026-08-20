package com.noricoffee.domain.model

/**
 * サービス管理のキュレーション済みおすすめカフェ（都道府県別 / フェーズ 19）。
 *
 * マップ上に専用ピンで強調表示する（見た目と表示条件の詳細は iOS 側 / `docs/data-model.md`
 * §1.10 参照）。トグル（表示切替チップ）の対象外だが常時表示ではなく、周辺の Apple 由来ピンと
 * 同じズームゲートを共有するため、地図を引くと非表示になりうる。既存の
 * [RecommendedCafe]（ユーザーの味覚プロファイル好み一致）とは別概念のため命名を分離している。
 *
 * ## 保持フィールドが最小限な理由（Places 規約対応）
 * 評価・営業時間等の揮発データは保存しない。placeId 以外の Places 由来データ表示は
 * ピンタップ時にカフェ詳細画面が既存の `CafeRepository.getDetails` で解決する。
 *
 * @property placeId Google Places ID（ピンタップ時の詳細解決キー）
 * @property name 表示名
 * @property latitude 緯度（非 null。座標なし候補はシード時に弾く）
 * @property longitude 経度（非 null）
 * @property prefectureCode 都道府県コード（JIS X 0401 の 2 桁ゼロ埋め文字列。"01".."47"）
 *
 * @see [docs/data-model.md] §1.10
 */
data class CuratedCafe(
    val placeId: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val prefectureCode: String,
)
