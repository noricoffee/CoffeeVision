import SwiftUI
import SharedLogic

/// カフェ詳細画面の横スクロール写真帯。
///
/// - Places 写真（`cafe.photoReferences` 先頭 6 件、都度取得。独自キャッシュは規約で禁止）と
///   自分の記録写真（`coffees.flatMap { $0.photos }`、`PhotoFileStore` からローカル読み込み）を
///   1 本の横スクロールに合成する
/// - 両方 0 件のときは呼び出し側で判定してヘッダー自体を非表示にすること（`isEmpty` を参照）
struct CafePhotoHeader: View {

    let cafe: Cafe
    let coffees: [CoffeeRecord]
    let photoLoader: PlacePhotoLoader

    /// 表示するアイテムが 1 件もないか。呼び出し側でヘッダー全体の表示可否判定に使う。
    var isEmpty: Bool {
        items.isEmpty
    }

    private var items: [Item] {
        let placeItems = cafe.photoReferences.prefix(6).map { Item.place(photoName: $0) }
        let ownItems = coffees.flatMap { $0.photos }.map { Item.own(photo: $0) }
        return Array(placeItems) + ownItems
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
        case .place(let photoName):
            PlacePhotoThumbnail(photoName: photoName, maxWidthPx: 400, loader: photoLoader)
                .frame(width: 224, height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        case .own(let photo):
            ownPhotoCell(photo)
        }
    }

    @ViewBuilder
    private func ownPhotoCell(_ photo: Photo_) -> some View {
        Group {
            if let fileName = photo.fileName,
               let uiImage = PhotoFileStore.loadImage(fileName: fileName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
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
        case place(photoName: String)
        case own(photo: Photo_)

        var id: String {
            switch self {
            case .place(let photoName):
                return "place-\(photoName)"
            case .own(let photo):
                return "own-\(photo.id)"
            }
        }
    }
}
