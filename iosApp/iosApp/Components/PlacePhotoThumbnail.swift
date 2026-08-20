import SwiftUI

/// Google Places の写真を AsyncImage で表示するサムネコンポーネント。
///
/// `photoName`（`Cafe.photoReferences` の要素）と `loader`（`PlacePhotoLoader`）を受け取り、
/// `.task` で URL を非同期取得して `AsyncImage` で描画する。
///
/// ## 表示状態
///
/// - URL 取得前: `ProgressView` プレースホルダ
/// - URL 取得失敗: SF Symbols `photo` プレースホルダ
/// - AsyncImage ロード中: `ProgressView` プレースホルダ
/// - AsyncImage ロード失敗: SF Symbols `photo` プレースホルダ
/// - 表示成功: `.aspectRatio(.fill)` でコンテナを埋める
///
/// ## アクセシビリティ
///
/// 店舗写真は装飾扱いのため `.accessibilityHidden(true)` を付与している。
/// 呼び出し元でラベルを付与する必要はない。
///
/// ## Preview 利用
///
/// `loader: nil` を渡すとプレースホルダのみ表示する（Preview / offline 用）。
struct PlacePhotoThumbnail: View {

    let photoName: String
    let maxWidthPx: Int
    /// `nil` の場合は URL 取得をスキップし、プレースホルダのみ表示する（Preview 用）。
    let loader: PlacePhotoLoader?

    @State private var url: URL?
    @State private var loadFailed: Bool = false

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder(systemImage: nil)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholder(systemImage: "photo")
                    @unknown default:
                        placeholder(systemImage: "photo")
                    }
                }
            } else if loadFailed {
                placeholder(systemImage: "photo")
            } else {
                placeholder(systemImage: nil)
            }
        }
        .task {
            guard let loader else { return }
            do {
                url = try await loader.fetchUrl(photoName: photoName, maxWidthPx: maxWidthPx)
            } catch {
                loadFailed = true
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Placeholder

    @ViewBuilder
    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }
}

// MARK: - Preview (loader nil → placeholder)

#Preview("プレースホルダ表示（loader nil）") {
    PlacePhotoThumbnail(
        photoName: "places/ChIJxxx/photos/Aap_yyy",
        maxWidthPx: 200,
        loader: nil
    )
    .frame(width: 56, height: 56)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding()
}

// MARK: - Preview (実 URL あり想定デモ)

#Preview("URL あり想定デモ") {
    // loader は nil のためプレースホルダ表示。実動作では PlacePhotoLoader(repository:) を渡す。
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            PlacePhotoThumbnail(
                photoName: "places/ChIJxxx/photos/Aap_yyy",
                maxWidthPx: 200,
                loader: nil
            )
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Starbucks Shibuya")
                    .font(.headline)
                Text("東京都渋谷区道玄坂2-11-1")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)

        HStack(spacing: 12) {
            PlacePhotoThumbnail(
                photoName: "",
                maxWidthPx: 200,
                loader: nil
            )
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Blue Bottle Coffee")
                    .font(.headline)
                Text("写真なし（プレースホルダ確認）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
    }
    .padding(.vertical)
}
