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

// MARK: - MapPinBadge（概念ピン共通の右上バッジ）

/// 概念ピン共通の右上バッジ（白地 18pt 円 + 自色シンボル / 文字、`.offset(x: 4, y: -4)`）。
///
/// 4 種の概念ピン（訪問済み / 保存済み / 好み一致 / おすすめ）すべてが同じ構成のバッジを持つため
/// 共通化した。中身（シンボルまたは訪問回数のテキスト）は呼び出し側が `content` で渡す。
/// バッジは強弱ではなく意味を載せる枠のため `accessibilityHidden(true)` とし、内容は各ピンの
/// `accessibilityLabel` に集約する。規則の詳細は `docs/ui-ux-guidelines.md`「ピンの意匠ルール」参照。
private struct MapPinBadge<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 18, height: 18)
            content
        }
        .offset(x: 4, y: -4)
        .accessibilityHidden(true)
    }
}

// MARK: - MapTabView ピン UI（M-1 で独立 View 構造体化）

/// 訪問済みカフェピン（アクセントカラー + カップ / 訪問回数バッジ付き）。
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
                MapPinBadge {
                    Text(badgeText)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accentColor)
                }
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

/// 保存済み（行きたい）店ピン（indigo + カップ + `bookmark.fill` バッジ。フェーズ 15-A、
/// 2026-08-07 に本体をカップへ統一しバッジ化）。
///
/// 他ピンと区別できる色（indigo）を採用し、右上の `bookmark.fill` バッジで「保存済み」を示す。
/// 本体アイコンは他の概念ピンと同じ `cup.and.saucer.fill`（「何の店か」だけを担う）。
/// 「保存済み」チップ強調中はひとまわり大きく表示する（フェーズ 16）。
/// 色・サイズの一覧は `docs/ui-ux-guidelines.md`「ピンの意匠ルール」参照。
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
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .overlay(alignment: .topTrailing) {
            MapPinBadge {
                Image(systemName: "bookmark.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.indigo)
            }
        }
        .accessibilityLabel(String(localized: "\(savedCafe.cafe.name) 保存済み"))
    }
}

/// 好み一致カフェピン（pink + カップ + `heart.fill` バッジ。2026-08-07 に本体をカップへ統一しバッジ化）。
///
/// 通常訪問済みピン（アクセントカラー）よりひとまわり大きく表示して視覚的に区別する。
/// 本体アイコンは他の概念ピンと同じ `cup.and.saucer.fill`、右上の `heart.fill` バッジで
/// 「好み一致」を示す。
struct RecommendedCafePin: View {
    let visitedCafe: VisitedCafe

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.pink)
                .frame(width: 38, height: 38)
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                .shadow(color: Color.pink.opacity(0.4), radius: 4, x: 0, y: 2)
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .overlay(alignment: .topTrailing) {
            MapPinBadge {
                Image(systemName: "heart.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.pink)
            }
        }
        .accessibilityLabel(
            String(
                localized: "好み一致のカフェ、\(visitedCafe.cafe.name)。タップして理由を確認"
            )
        )
    }
}

/// おすすめカフェ（curated）ピン（system orange + カップ + 星バッジ。フェーズ 19 意匠変更、
/// 2026-08-07 に星バッジを追加し、この構成をマップ概念ピン 4 種共通の型に拡張）。
///
/// Google Maps の「人気 POI 強調」表現に寄せ、他の概念ピン（訪問済み / 保存済み / 好み一致）と
/// **同じカフェアイコン**（`cup.and.saucer.fill`）を使ったうえで、右上の星バッジで
/// 「同じカフェだが特に推されている」ことを表現する。色相を訪問済みピンと離さない理由・
/// 凡例を追加しない理由は `docs/ui-ux-guidelines.md`「おすすめピンを色で区別しない理由」参照。
/// 色は他ピンと被らないシステムカラー `Color.orange` をそのまま使う（黒ミックスなし）。
/// トグルなし。ズームゲート（`AppleNearbyCafeLoader.zoomGateRadiusMeters`）を Apple 周辺ピンと共用し、
/// 可視領域が一定以上広い（ズームアウトした）ときは非表示にする（`displayedCuratedCafes` 参照）。
struct CuratedCafePin: View {
    let cafe: CuratedCafe

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                .shadow(color: Color.orange.opacity(0.4), radius: 4, x: 0, y: 2)
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .overlay(alignment: .topTrailing) {
            MapPinBadge {
                Image(systemName: "star.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.orange)
            }
        }
        .accessibilityLabel(String(localized: "\(cafe.name)、おすすめのカフェ"))
    }
}

/// 周辺カフェ（Apple 検索由来）ピン。まだ記録も保存もしていない店を示す低強調ピン（フェーズ 17）。
///
/// 低強調は最小サイズ・ミュートしたセカンダリ配色・弱い影で表現する（白フチ自体は
/// 全ピン共通の「地図から切り離すための処理」であり強調の手段ではない）。
/// ピン全種の意匠ルールの詳細は `docs/ui-ux-guidelines.md`「ピンの意匠ルール」参照。
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
