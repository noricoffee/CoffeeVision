import SwiftUI
import SharedLogic

// MARK: - ShareCardSheet

/// 共有カードのプレビューシート。
///
/// `.task` でカード画像を生成 → 縮小プレビュー + `ShareLink` を提示する。
/// 共有前に出ていく内容を目視確認させるのが目的（`docs/requirements.md` §2 2-12）。
struct ShareCardSheet: View {

    let coffee: CoffeeRecord
    @Environment(\.dismiss) private var dismiss

    private enum RenderState {
        case generating
        case ready(ShareCardRenderer.Result)
        case failed
    }

    @State private var state: RenderState = .generating

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

            ShareLink(
                item: result.fileURL,
                preview: SharePreview(shareTitle, image: Image(uiImage: result.image))
            ) {
                Label(String(localized: "共有する"), systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
            .padding(.horizontal)
            .accessibilityLabel(String(localized: "カードを共有する"))
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

    // MARK: - レンダリング

    @MainActor
    private func generate() async {
        state = .generating
        do {
            let result = try ShareCardRenderer.render(coffee: coffee)
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
