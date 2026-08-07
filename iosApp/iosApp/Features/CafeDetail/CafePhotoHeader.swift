import SwiftUI
import SharedLogic

/// カフェ詳細画面の横スクロール写真帯。
///
/// - Places 写真（`cafe.photoReferences` 先頭 10 件を上限に段階読み込み。都度取得で独自キャッシュは規約で禁止）と
///   自分の記録写真（`coffees.flatMap { $0.photos }`、`PhotoFileStore` からローカル読み込み）を
///   1 本の横スクロールに合成する
/// - Places 写真は初期 3 枚表示、「さらに表示」タップで 3 枚ずつ最大 10 枚まで拡大する
/// - 自分の記録写真は段階読み込みの対象外で常に全件表示する
/// - 両方 0 件のときは呼び出し側で判定してヘッダー自体を非表示にすること（`isEmpty` を参照）
struct CafePhotoHeader: View {

    private static let initialVisibleCount = 3
    private static let incrementCount = 3
    private static let maxVisibleCount = 10

    let cafe: Cafe
    let coffees: [CoffeeRecord]
    let photoLoader: PlacePhotoLoader

    @State private var visibleCount = CafePhotoHeader.initialVisibleCount

    /// 表示するアイテムが 1 件もないか（元データ基準。段階読み込みの表示件数には依存させない）。
    /// 呼び出し側でヘッダー全体の表示可否判定に使う。
    var isEmpty: Bool {
        cafe.photoReferences.isEmpty && ownItems.isEmpty
    }

    /// 段階読み込みの対象となる Places 写真（上限 10 件）。作者帰属を同じ index で対応付ける。
    ///
    /// `cafe.photoAttributions` は `photoReferences` と同じ順序・同じ長さの契約だが、
    /// 旧データ・旧経路では空または短いことがあるため、安全に index アクセスする。
    /// 対応する要素が空文字（作者不明）のときは nil にする。
    private var placePhotoItems: [(photoName: String, attribution: String?)] {
        let names = Array(cafe.photoReferences.prefix(Self.maxVisibleCount))
        return names.enumerated().map { index, name in
            let raw = cafe.photoAttributions.indices.contains(index) ? cafe.photoAttributions[index] : nil
            let attribution = (raw?.isEmpty ?? true) ? nil : raw
            return (photoName: name, attribution: attribution)
        }
    }

    private var ownItems: [Item] {
        coffees.flatMap { $0.photos }.map { Item.own(photo: $0) }
    }

    private var hasMorePlacePhotos: Bool {
        visibleCount < placePhotoItems.count
    }

    private var items: [Item] {
        var result = placePhotoItems.prefix(visibleCount).map {
            Item.place(photoName: $0.photoName, attribution: $0.attribution)
        }
        if hasMorePlacePhotos {
            result.append(.loadMore)
        }
        return result + ownItems
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(items) { item in
                    cell(for: item)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 168)
    }

    // MARK: - セル

    @ViewBuilder
    private func cell(for item: Item) -> some View {
        switch item {
        case .place(let photoName, let attribution):
            placePhotoCell(photoName: photoName, attribution: attribution)
        case .own(let photo):
            ownPhotoCell(photo)
        case .loadMore:
            loadMoreCell
        }
    }

    /// Places 写真セル。作者帰属（`cafe.photoAttributions`）が判明している場合のみ
    /// 左下にバッジで表示する（App Store ガイドライン 5.2.2 対応）。
    @ViewBuilder
    private func placePhotoCell(photoName: String, attribution: String?) -> some View {
        PlacePhotoThumbnail(photoName: photoName, maxWidthPx: 400, loader: photoLoader)
            .frame(width: 224, height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .bottomLeading) {
                if let attribution {
                    Text(attribution)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(8)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(
                attribution.map { String(localized: "撮影: \($0)") }
                    ?? String(localized: "カフェの写真")
            )
    }

    private var loadMoreCell: some View {
        Button {
            visibleCount = min(visibleCount + Self.incrementCount, placePhotoItems.count)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text(String(localized: "さらに表示"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 224, height: 168)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel(String(localized: "さらに表示"))
    }

    @ViewBuilder
    private func ownPhotoCell(_ photo: Photo_) -> some View {
        RecordPhotoThumbnail(
            fileName: photo.fileName,
            pendingData: nil,
            targetPointSize: 224
        ) {
            Rectangle()
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
        .frame(width: 224, height: 168)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottomLeading) {
            Label(String(localized: "自分の記録"), systemImage: "checkmark.seal.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.5), in: Capsule())
                .padding(8)
                .accessibilityHidden(true)
        }
        .accessibilityLabel(String(localized: "自分が撮影した写真"))
    }

    // MARK: - Item

    private enum Item: Identifiable {
        case place(photoName: String, attribution: String?)
        case own(photo: Photo_)
        case loadMore

        var id: String {
            switch self {
            case .place(let photoName, _):
                return "place-\(photoName)"
            case .own(let photo):
                return "own-\(photo.id)"
            case .loadMore:
                return "load-more"
            }
        }
    }
}
