import SwiftUI
import CoreLocation
import SharedLogic

// MARK: - ApplePoiCafe

/// Apple 検索（`MKLocalPointsOfInterestRequest`）由来の周辺カフェ。
///
/// まだ記録も保存もしていない「周辺の店」を示す低強調ピンの表示専用モデル。
/// Google `placeId` を持たないため座標文字列を `id` として使う（フェーズ 17）。
struct ApplePoiCafe: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - MapTabView ピン UI（M-1 で独立 View 構造体化）

/// 訪問済みカフェピン（アクセントカラー / 訪問回数バッジ付き）。
///
/// - 2 回以上訪問した場合は右上コーナーに訪問回数バッジを表示する
/// - 10 回以上は "9+" と表示して 1 桁に収める
struct VisitedCafePin: View {
    let visitedCafe: VisitedCafe

    var body: some View {
        let count = Int(visitedCafe.visitCount)
        let badgeText = count >= 10 ? "9+" : "\(count)"

        return ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                .shadow(color: Color.accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .overlay(alignment: .topTrailing) {
            if count >= 2 {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                    Text(badgeText)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accentColor)
                }
                .offset(x: 4, y: -4)
            }
        }
        .accessibilityLabel(
            String(localized: "\(visitedCafe.cafe.name) 訪問済み \(visitedCafe.visitCount)回")
        )
    }
}

/// 検索結果オーバーレイピン（青 / `mappin.and.ellipse`）。
///
/// 選択中（`isHighlighted`）は scale 1.3 + 影を強調する
/// （色は既存の `Color.blue` を維持。2026-07-22 マップ検索結果刷新）。
struct SearchResultPin: View {
    let cafe: Cafe
    let isHighlighted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                .shadow(
                    color: Color.blue.opacity(isHighlighted ? 0.6 : 0.4),
                    radius: isHighlighted ? 6 : 4,
                    x: 0,
                    y: 2
                )
            Image(systemName: "mappin.and.ellipse")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .scaleEffect(isHighlighted ? 1.3 : 1.0)
        .accessibilityLabel(
            isHighlighted
                ? String(localized: "\(cafe.name) 検索結果、選択中")
                : String(localized: "\(cafe.name) 検索結果")
        )
    }
}

/// 保存済み（行きたい）店ピン（indigo + bookmark。フェーズ 15-A）。
///
/// 既存 3 種ピン（訪問済み=accentColor / 好み一致=pink / 検索結果=blue）と区別できる
/// 色（indigo）を採用し、`bookmark.fill` で「保存済み」を示す。
/// 「保存済み」チップ強調中はひとまわり大きく表示する（フェーズ 16）。
struct SavedCafePin: View {
    let savedCafe: SavedCafe
    let emphasized: Bool

    var body: some View {
        let size: CGFloat = emphasized ? 38 : 34

        return ZStack {
            Circle()
                .fill(Color.indigo)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                .shadow(color: Color.indigo.opacity(0.4), radius: 4, x: 0, y: 2)
            Image(systemName: "bookmark.fill")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .accessibilityLabel(String(localized: "\(savedCafe.cafe.name) 保存済み"))
    }
}

/// 好み一致カフェピン（pink + ハート）。
///
/// 通常訪問済みピン（アクセントカラー）よりひとまわり大きく表示して視覚的に区別する。
struct RecommendedCafePin: View {
    let visitedCafe: VisitedCafe

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.pink)
                .frame(width: 38, height: 38)
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                .shadow(color: Color.pink.opacity(0.4), radius: 4, x: 0, y: 2)
            Image(systemName: "heart.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(
            String(
                localized: "好み一致のカフェ、\(visitedCafe.cafe.name)。タップして理由を確認"
            )
        )
    }
}

/// おすすめカフェ（curated）ピン（system orange + cup.and.saucer.fill。フェーズ 19 意匠変更）。
///
/// Google Maps の「人気 POI 強調」表現に寄せ、Apple 周辺ピン（`AppleNearbyCafePin`）と
/// **同じカフェアイコン**（`cup.and.saucer.fill`）を使ったうえで、サイズ（34pt。Apple 周辺ピンの
/// 28pt よりひとまわり大きい）と色の彩度だけで「同じカフェだが特に推されている」ことを
/// 表現する。色は既存 5 色（accentColor / pink / indigo / blue / secondaryLabel）と被らない
/// システムカラー `Color.orange` をそのまま使う（黒ミックスなし）。訪問済みピン（`accentColor`
/// = 茶 #8B5A2B）と一目で区別できるよう明るいオレンジを維持する判断（シミュレータ確認
/// フィードバックで黒ミックス濃色は茶に寄って見分けにくいと判定されたため）。
/// トグルなし。ズームゲート（`AppleNearbyCafeLoader.zoomGateRadiusMeters`）を Apple 周辺ピンと共用し、
/// 可視領域が一定以上広い（ズームアウトした）ときは非表示にする（`displayedCuratedCafes` 参照）。
struct CuratedCafePin: View {
    let cafe: CuratedCafe

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                .shadow(color: Color.orange.opacity(0.5), radius: 4, x: 0, y: 2)
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .accessibilityLabel(String(localized: "\(cafe.name)、おすすめのカフェ"))
    }
}

/// 周辺カフェ（Apple 検索由来）ピン。まだ記録も保存もしていない店を示す低強調ピン。
///
/// 既存 4 種ピン（訪問済み=accentColor / 保存済み=indigo / 検索結果=blue / 好み一致=pink）より
/// 明確に控えめな意匠（小径 24pt + ミュートしたセカンダリ配色）にする（フェーズ 17）。
struct AppleNearbyCafePin: View {
    let cafe: ApplePoiCafe

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondaryLabel))
                .frame(width: 28, height: 28)
                // 白フチ + 影で地図の情報密度に負けず見つけやすくする（意味ピンより一段下の強調は維持）
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption2)
                .foregroundStyle(Color(.systemBackground))
        }
        .accessibilityLabel(String(localized: "\(cafe.name)、周辺のカフェ"))
    }
}
