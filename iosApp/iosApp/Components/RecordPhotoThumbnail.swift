import SwiftUI
import UIKit

/// 記録写真（`Photo_`）1 枚分のサムネイル表示コンポーネント。
///
/// - `pendingData`（エディタで保存前の新規追加写真の JPEG データ）があればそちらを優先して
///   `ImageDownsampler.downsampledImage` で縮小デコードする。無ければ `fileName` から
///   `PhotoFileStore.loadThumbnail`（`NSCache` 対応済み）で読み込む
/// - `PhotoFileStore.loadImage`（長辺 2048px のフルデコード）は使わない。表示サイズに応じた
///   縮小デコードのみを行うことで、`LazyHStack` の横スクロール中に毎回フルデコードが走るのを避ける
/// - `.frame` / `clipShape` などの装飾は呼び出し側に委ねる（`PlacePhotoThumbnail` と同じ設計）
/// - `.task(id:)` の `id` は `fileName` を使う。新規追加した写真も `handlePickerSelection` が
///   保存前に一意な `fileName`（`"\(photoId).jpg"`）を採番するため、保存前でも一意になる
struct RecordPhotoThumbnail<Placeholder: View>: View {

    let fileName: String?
    let pendingData: Data?
    /// 長辺の目標サイズ（pt）。`maxPixelSize = targetPointSize * displayScale` として縮小デコードする。
    let targetPointSize: CGFloat
    @ViewBuilder let placeholder: () -> Placeholder

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .task(id: fileName) {
            image = nil
            let maxPixelSize = Int(targetPointSize * displayScale)
            if let pendingData {
                image = await ImageDownsampler.downsampledImage(from: pendingData, maxPixelSize: maxPixelSize)
            } else if let fileName {
                image = await PhotoFileStore.loadThumbnail(fileName: fileName, maxPixelSize: maxPixelSize)
            }
        }
    }
}

// MARK: - Preview (プレースホルダ表示)

#Preview("プレースホルダ表示（fileName なし）") {
    RecordPhotoThumbnail(fileName: nil, pendingData: nil, targetPointSize: 100) {
        Rectangle()
            .fill(Color(.secondarySystemFill))
            .overlay {
                Image(systemName: "cup.and.saucer")
                    .foregroundStyle(.tertiary)
            }
    }
    .frame(width: 100, height: 100)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding()
}
