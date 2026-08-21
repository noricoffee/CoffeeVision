import SwiftUI
import SharedLogic

/// マップの選択カフェ下部カード（検索結果ピン / 行タップ、または周辺ピンタップで表示）。
///
/// 「詳細を見る」「保存トグル」「閉じる」のアクションはすべて呼び出し元（`MapTabView`）が
/// クロージャで実装する（`navigationPath` / `selectedSearchCafe` 等の状態は親が保持するため）。
struct CafeSelectionCard: View {

    let cafe: Cafe
    let bridge: MapViewModelBridge
    let appState: AppState
    let onClose: () -> Void
    let onOpenDetail: (Cafe) -> Void
    let onToggleSave: (Cafe) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if let photoName = cafe.photoReferences.first {
                    PlacePhotoThumbnail(
                        photoName: photoName,
                        maxWidthPx: 150,
                        loader: appState.placePhotoLoader
                    )
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.name)
                        .font(.headline)
                        .lineLimit(2)
                    if let address = cafe.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    cafeCardInfoRow(cafe, bridge: bridge)
                }
                Spacer(minLength: 0)
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "閉じる"))
            }
            HStack(spacing: 12) {
                Button {
                    onOpenDetail(cafe)
                } label: {
                    Text(String(localized: "詳細を見る"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(String(localized: "\(cafe.name) の詳細を見る"))

                Button {
                    onToggleSave(cafe)
                } label: {
                    Image(systemName: isCafeSaved(cafe, bridge: bridge) ? "bookmark.fill" : "bookmark")
                        .font(.body.weight(.medium))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.indigo)
                .sensoryFeedback(.selection, trigger: isCafeSaved(cafe, bridge: bridge))
                .accessibilityLabel(
                    isCafeSaved(cafe, bridge: bridge)
                        ? String(localized: "行きたい店から削除")
                        : String(localized: "行きたい店に追加")
                )
            }
            HStack {
                Spacer()
                GoogleMapsAttributionText()
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: -4)
    }

    // MARK: - 補助情報

    private func cafeCardInfoRow(_ cafe: Cafe, bridge: MapViewModelBridge) -> some View {
        HStack(spacing: 8) {
            if let openNow = cafe.openNow?.boolValue {
                HStack(spacing: 4) {
                    Circle()
                        .fill(openNow ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(openNow ? String(localized: "営業中") : String(localized: "営業時間外"))
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(openNow ? .green : .red)
                }
            }
            if let rating = cafe.googleRating?.doubleValue {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(ratingText(rating: rating, count: cafe.userRatingCount?.intValue))
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            if let level = cafe.priceLevel {
                Text(mapPriceLevelText(level))
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            if let visits = visitCount(for: cafe, bridge: bridge) {
                HStack(spacing: 2) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.caption2)
                    Text(String(localized: "\(visits)杯"))
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    /// 「★4.5 (128件)」形式の評価テキスト。件数が nil または 0 のときは括弧を省略する。
    private func ratingText(rating: Double, count: Int?) -> String {
        let ratingStr = String(format: "%.1f", rating)
        if let count, count > 0 {
            return "\(ratingStr) (\(count)件)"
        }
        return ratingStr
    }

    /// カードの保存状態（`bridge.savedCafes` の placeId 一致で判定）。
    private func isCafeSaved(_ cafe: Cafe, bridge: MapViewModelBridge) -> Bool {
        bridge.savedCafes.contains { $0.cafe.placeId == cafe.placeId }
    }

    /// このカフェの記録杯数（`bridge.visitedCafes` の placeId 一致。0 件 or 未訪問なら nil）。
    private func visitCount(for cafe: Cafe, bridge: MapViewModelBridge) -> Int? {
        guard let visited = bridge.visitedCafes.first(where: { $0.cafe.placeId == cafe.placeId }) else {
            return nil
        }
        let count = Int(visited.visitCount)
        return count > 0 ? count : nil
    }

    private func mapPriceLevelText(_ level: String) -> String {
        switch level {
        case "PRICE_LEVEL_FREE": return String(localized: "無料")
        case "PRICE_LEVEL_INEXPENSIVE": return "¥"
        case "PRICE_LEVEL_MODERATE": return "¥¥"
        case "PRICE_LEVEL_EXPENSIVE": return "¥¥¥"
        case "PRICE_LEVEL_VERY_EXPENSIVE": return "¥¥¥¥"
        default: return ""
        }
    }
}
