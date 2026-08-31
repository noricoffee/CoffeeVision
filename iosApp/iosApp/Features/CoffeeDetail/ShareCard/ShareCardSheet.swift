import SwiftUI
import SharedLogic

// MARK: - ShareCardSheet

/// 共有カードのプレビューシート。
///
/// `.task` でカード画像を生成 → 縮小プレビュー + 共有ボタン（`UIActivityViewController`）を提示する。
/// 共有前に出ていく内容を目視確認させるのが目的（`docs/requirements.md` §2 2-12）。
///
/// 共有は `ShareLink` ではなく `UIActivityViewController`（`ActivityShareSheet` でラップ）を使う。
/// `ShareLink(items:)` は単一の `Transferable` にしか対応せず、画像ファイルと
/// App Store 導線テキスト（ASO-7②-a）を同時に渡せないため。
struct ShareCardSheet: View {

    let coffee: CoffeeRecord
    @Environment(\.dismiss) private var dismiss

    private enum RenderState {
        case generating
        case ready(ShareCardRenderer.Result)
        case failed
    }

    @State private var state: RenderState = .generating
    @State private var isSharePresented = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "カードを共有"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "閉じる")) { dismiss() }
                    }
                }
                .task { await generate() }
        }
    }

    // MARK: - コンテンツ切り替え

    @ViewBuilder
    private var content: some View {
        switch state {
        case .generating:
            generatingView
        case .ready(let result):
            readyView(result: result)
        case .failed:
            failedView
        }
    }

    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(String(localized: "カードを作成しています..."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func readyView(result: ShareCardRenderer.Result) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Image(uiImage: result.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                .accessibilityLabel(String(localized: "共有カードのプレビュー"))

            Spacer(minLength: 0)

            Button {
                isSharePresented = true
            } label: {
                Label(String(localized: "共有する"), systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
            .padding(.horizontal)
            .accessibilityLabel(String(localized: "カードを共有する"))
            .sheet(isPresented: $isSharePresented) {
                ActivityShareSheet(activityItems: [
                    ShareCardActivityItemSource(
                        image: result.image,
                        fileURL: result.fileURL,
                        previewTitle: shareTitle
                    ),
                    shareText,
                ])
            }
        }
        .padding(.vertical, 24)
    }

    private var failedView: some View {
        ContentUnavailableView {
            Label(String(localized: "カードを作成できませんでした"), systemImage: "exclamationmark.triangle")
        } actions: {
            Button(String(localized: "再試行")) {
                Task { await generate() }
            }
        }
    }

    private var shareTitle: String {
        String(localized: "\(coffee.name) - CoffeeVision")
    }

    /// App Store への導線を含む共有本文（ASO-7②-a）。
    ///
    /// - 1 行目は `shareTitle` と同じ組み立て
    /// - URL は短縮形を固定で使う（長い URL のスラグはアプリ名から生成される装飾で、
    ///   ASO でアプリ名を変えるたびに変わるため）
    /// - カフェ名は含めない（訪問先を投稿本文へ自動掲載しない = 誤共有防止の趣旨、`docs/requirements.md` 2-12）
    private var shareText: String {
        "\(shareTitle)\nhttps://apps.apple.com/app/id6788339362"
    }

    // MARK: - レンダリング

    @MainActor
    private func generate() async {
        state = .generating
        do {
            let result = try await ShareCardRenderer.render(coffee: coffee)
            state = .ready(result)
        } catch {
            state = .failed
        }
    }
}

// MARK: - Preview

#Preview {
    ShareCardSheet(coffee: PreviewSamples.sampleCoffeeRecord)
}
