import SwiftUI
import SharedLogic

// MARK: - PhotoThumbnailCell

/// 写真セクション内の 1 枚サムネイルセル（削除ボタン付き）。
struct PhotoThumbnailCell: View {

    let photo: Photo_
    let pendingData: Data?
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RecordPhotoThumbnail(
                fileName: photo.fileName,
                pendingData: pendingData,
                targetPointSize: 100
            ) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        Image(systemName: "photo.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 100, height: 100)
            .clipped()
            .cornerRadius(8)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.title3)
            }
            .accessibilityLabel(String(localized: "写真を削除"))
            .padding(4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "写真"))
    }
}
