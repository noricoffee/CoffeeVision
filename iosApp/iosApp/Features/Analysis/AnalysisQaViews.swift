import SharedLogic
import SwiftUI

// MARK: - QaSectionContainer

/// 対話 Q&A セクションのコンテナ。
///
/// `qaStatus` に応じて入力欄・候補チップ・回答カードを表示する。
/// `Unsupported` の判定は呼び出し側（`insightCardSection`）で行い、本コンポーネントには渡さない。
@MainActor
struct QaSectionContainer: View {

    var viewModel: AnalysisViewModelBridge
    let qaStatus: any AnalysisViewModelQaStatus

    @State private var inputText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // セクションヘッダ
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(String(localized: "Q&A"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            // 回答カード（Answered / Asking / Failed）
            if qaStatus is AnalysisViewModelQaStatusAnswered {
                if let question = viewModel.qaQuestion, let answer = viewModel.qaAnswer {
                    QaAnsweredCard(question: question, answer: answer) {
                        viewModel.onQaCleared()
                        inputText = ""
                    }
                }
            } else if qaStatus is AnalysisViewModelQaStatusAsking {
                QaAskingCard(question: viewModel.qaQuestion ?? "")
            } else if qaStatus is AnalysisViewModelQaStatusFailed {
                if let question = viewModel.qaQuestion {
                    QaFailedCard(question: question) {
                        viewModel.onQuestionAsked(question)
                    }
                }
            }

            // 候補チップ（Idle / Failed 時に表示）
            if qaStatus is AnalysisViewModelQaStatusIdle
                || qaStatus is AnalysisViewModelQaStatusFailed {
                QaSuggestedChips(
                    questions: viewModel.suggestedQuestions,
                    onSelected: { q in
                        inputText = ""
                        viewModel.onQuestionAsked(q)
                    }
                )
            }

            // 入力欄 + 送信ボタン（Idle / Answered / Failed 時に表示）
            if qaStatus is AnalysisViewModelQaStatusIdle
                || qaStatus is AnalysisViewModelQaStatusAnswered
                || qaStatus is AnalysisViewModelQaStatusFailed {
                QaInputRow(
                    text: $inputText,
                    onSubmit: {
                        let q = inputText
                        inputText = ""
                        viewModel.onQuestionAsked(q)
                    }
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - QaAnsweredCard

/// 回答到着（`Answered` 状態）に表示するカード。
private struct QaAnsweredCard: View {
    let question: String
    let answer: String
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(question)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(String(localized: "Q&A をクリア"))
            }
            Text(answer)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "質問: \(question)。回答: \(answer)"))
    }
}

// MARK: - QaAskingCard

/// 回答生成中（`Asking` 状態）に表示するカード。
private struct QaAskingCard: View {
    let question: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text(String(localized: "回答を生成中…"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "質問: \(question)。回答を生成中"))
    }
}

// MARK: - QaFailedCard

/// 回答生成失敗（`Failed` 状態）に表示するカード。
private struct QaFailedCard: View {
    let question: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(String(localized: "回答の生成に失敗しました"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(String(localized: "再試行"), action: onRetry)
                    .font(.footnote)
                    .buttonStyle(.borderless)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(String(localized: "回答の生成を再試行"))
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - QaSuggestedChips

/// 候補質問チップの横スクロール行。
private struct QaSuggestedChips: View {
    let questions: [String]
    let onSelected: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(questions, id: \.self) { question in
                    Button(action: { onSelected(question) }) {
                        Text(question)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemBackground), in: Capsule())
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .accessibilityLabel(String(localized: "候補: \(question)"))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "候補質問"))
    }
}

// MARK: - QaInputRow

/// 質問入力欄と送信ボタン。
private struct QaInputRow: View {
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(String(localized: "気になることを質問してみよう"), text: $text, axis: .vertical)
                .font(.body)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSubmit()
                    }
                }
                .accessibilityLabel(String(localized: "質問入力欄"))

            Button(action: {
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onSubmit()
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color(.systemGray4)
                            : Color.accentColor
                    )
            }
            .buttonStyle(.borderless)
            .frame(minWidth: 44, minHeight: 44)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(String(localized: "質問を送信"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}
