import SwiftUI
@preconcurrency import SharedLogic

// MARK: - TasteMapFilterSheet

/// 「今飲みたい味」テイストフィルタを設定するシート。
///
/// - 自由記述のテキスト入力 → Foundation Models で `TastePreference`（5軸ベクトル）に変換
/// - → `toCoffeeRecordFilter()` で `TastingScores` min/max を生成
/// - → `bridge.onTasteProfileChanged(tastingMin:tastingMax:)` でマップを絞り込む
/// - Foundation Models 非対応端末では `ContentUnavailableView` を表示する（graceful degradation）
/// - 現在フィルタが active な場合は「解除する」ボタンも表示する
@MainActor
struct TasteMapFilterSheet: View {

    let bridge: MapViewModelBridge
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var inputText: String = ""
    @State private var isExtracting: Bool = false
    @State private var errorMessage: String? = nil

    // makeIfAvailable() は struct 初期化時に呼ばれる。
    // Foundation Models の可否確認（SystemLanguageModel.default.availability チェック）のみで軽量。
    private let extractor = TastePreferenceExtractor.makeIfAvailable()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if let extractor {
                    filterContent(extractor: extractor)
                } else {
                    ContentUnavailableView(
                        String(localized: "Foundation Models 未対応"),
                        systemImage: "brain.head.profile",
                        description: Text(
                            String(localized: "この機能は Apple Intelligence が有効な iPhone / iPad（iOS 26 以降）でのみ利用できます。")
                        )
                    )
                }
            }
            .navigationTitle(String(localized: "今飲みたい味で絞り込む"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "閉じる")) {
                        dismiss()
                    }
                    .accessibilityLabel(String(localized: "シートを閉じる"))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - フィルタコンテンツ

    @ViewBuilder
    private func filterContent(extractor: TastePreferenceExtractor) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 現在のフィルタ状態バナー（active なときのみ表示）
                if bridge.activeTastingMin != nil {
                    currentFilterBanner
                }

                // テキスト入力 + 実行ボタン
                inputSection(extractor: extractor)

                // エラー表示
                if let message = errorMessage {
                    errorView(message: message)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - 現在のフィルタバナー

    private var currentFilterBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(String(localized: "テイストで絞り込み中"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            Button {
                bridge.onTasteProfileChanged(tastingMin: nil, tastingMax: nil)
                dismiss()
            } label: {
                Text(String(localized: "フィルタを解除する"))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .accessibilityLabel(String(localized: "テイストフィルタを解除する"))
            .accessibilityHint(String(localized: "テイストフィルタを解除してすべてのカフェを表示します"))
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    // MARK: - 入力セクション

    private func inputSection(extractor: TastePreferenceExtractor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "text.cursor")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(String(localized: "どんなコーヒーが飲みたいですか？"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            TextField(
                String(localized: "例: 酸味が強くてフルーティな一杯"),
                text: $inputText,
                axis: .vertical
            )
            .font(.body)
            .lineLimit(3...6)
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel(String(localized: "飲みたいコーヒーの感想入力欄"))

            Button {
                startExtraction(extractor: extractor)
            } label: {
                HStack(spacing: 8) {
                    if isExtracting {
                        ProgressView()
                            .scaleEffect(0.85)
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.subheadline)
                    }
                    Text(
                        isExtracting
                            ? String(localized: "絞り込み中…")
                            : String(localized: "この味で絞り込む")
                    )
                    .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(.white)
                .background(
                    extractButtonDisabled
                        ? Color(.systemGray4)
                        : Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .buttonStyle(.plain)
            .disabled(extractButtonDisabled)
            .accessibilityLabel(
                isExtracting
                    ? String(localized: "絞り込み中")
                    : String(localized: "今飲みたい味でマップを絞り込む")
            )
            .accessibilityHint(
                String(localized: "Foundation Models でテキストをテイスティングスコアに変換してマップを絞り込みます")
            )
        }
    }

    private var extractButtonDisabled: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExtracting
    }

    // MARK: - エラー表示

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                Text(String(localized: "絞り込みに失敗しました"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "エラー: \(message)"))
    }

    // MARK: - 抽出処理

    private func startExtraction(extractor: TastePreferenceExtractor) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isExtracting = true
        errorMessage = nil

        Task {
            do {
                let preference = try await extractor.extract(from: text)
                let filter = preference.toCoffeeRecordFilter()
                bridge.onTasteProfileChanged(
                    tastingMin: filter.tastingMin,
                    tastingMax: filter.tastingMax
                )
                dismiss()
            } catch {
                print("[CoffeeVision] TasteMapFilterSheet: extraction failed: \(error)")
                isExtracting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
