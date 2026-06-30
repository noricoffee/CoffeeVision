import SwiftUI
@preconcurrency import SharedLogic

// MARK: - TasteSearchSheet

/// 自然言語のテイスト説明を Places API 検索補完キーワードに変換するシート。
///
/// 使用者が「酸味が強くてフルーティな一杯が飲みたい」と入力すると、
/// Foundation Models が `TastePreference` に変換し、`searchKeywords` を生成して
/// `onKeywordsGenerated` コールバックで呼び出す。
///
/// ## 動作フロー
///
/// 1. ユーザーが自然言語テキストを入力
/// 2. 「カフェを探す」ボタンをタップ
/// 3. `TastePreferenceExtractor.extract(from:)` でテキスト → `TastePreference`（5軸ベクトル）に変換
/// 4. `searchKeywords` で `TastePreference` → 日本語キーワード文字列に変換
/// 5. `onKeywordsGenerated` コールバックでキーワードを呼び出し元に返す
/// 6. シートを自動で閉じる
///
/// ## Foundation Models 非対応端末
///
/// `extractor` が nil のとき `ContentUnavailableView` を表示する（graceful degradation）。
/// ただし呼び出し元の `searchBarView` が `TastePreferenceExtractor.makeIfAvailable() != nil` を
/// ガードしているため、通常この分岐には到達しない。
@MainActor
struct TasteSearchSheet: View {

    let onKeywordsGenerated: (String) -> Void
    @Environment(\.dismiss) private var dismiss

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
                    searchContent(extractor: extractor)
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
            .navigationTitle(String(localized: "テイストでカフェを探す"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "閉じる")) { dismiss() }
                        .accessibilityLabel(String(localized: "シートを閉じる"))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 検索コンテンツ

    @ViewBuilder
    private func searchContent(extractor: TastePreferenceExtractor) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // 説明テキスト
                Text(String(localized: "飲みたいコーヒーの味わいを入力してください。キーワードに変換してカフェを検索します。"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    TextField(
                        String(localized: "例: 酸味が強くてフルーティな一杯"),
                        text: $inputText,
                        axis: .vertical
                    )
                    .font(.body)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(String(localized: "飲みたいコーヒーの味わいの入力欄"))

                    Button {
                        startSearch(extractor: extractor)
                    } label: {
                        HStack(spacing: 8) {
                            if isExtracting {
                                ProgressView().scaleEffect(0.85).tint(.white)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.subheadline)
                            }
                            Text(
                                isExtracting
                                    ? String(localized: "変換中…")
                                    : String(localized: "カフェを探す")
                            )
                            .font(.body.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.white)
                        .background(
                            searchButtonDisabled ? Color(.systemGray4) : Color.accentColor,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(searchButtonDisabled)
                    .accessibilityLabel(
                        isExtracting
                            ? String(localized: "変換中")
                            : String(localized: "テイストでカフェを探す")
                    )
                }

                if let message = errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel(String(localized: "エラー: \(message)"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - ヘルパ

    private var searchButtonDisabled: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExtracting
    }

    // MARK: - 検索処理

    private func startSearch(extractor: TastePreferenceExtractor) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isExtracting = true
        errorMessage = nil

        Task {
            do {
                let preference = try await extractor.extract(from: text)
                let keywords = preference.searchKeywords
                guard !keywords.isEmpty else {
                    // キーワードが空のときはそのまま検索（通常はないが safety check）
                    isExtracting = false
                    errorMessage = String(localized: "テイスト特徴が検出できませんでした。より具体的な説明を試してください。")
                    return
                }
                print("[CoffeeVision] TasteSearchSheet: 生成キーワード='\(keywords)'")
                onKeywordsGenerated(keywords)
                dismiss()
            } catch {
                print("[CoffeeVision] TasteSearchSheet: extraction failed: \(error)")
                isExtracting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
