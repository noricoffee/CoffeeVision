import SwiftUI

// MARK: - StarRatingView

/// 星評価表示 / 入力コンポーネント。
///
/// - `onChange` が `nil` のとき: read-only モード（タップ非反応）
/// - `onChange` が非 `nil` のとき: 編集モード（タップで評価変更、VoiceOver Stepper 相当）
struct StarRatingView: View {

    /// 現在の評価値（0...maxRating）
    let rating: Int

    /// 評価の上限。デフォルト 5
    var maxRating: Int = 5

    /// 星のフォントサイズ。Dynamic Type に合わせる前提で Font で受け取る
    var size: Font = .body

    /// タップ・VoiceOver 操作で評価が変わった時のハンドラ。
    /// nil なら read-only モード（タップ非反応）
    var onChange: ((Int) -> Void)? = nil

    var body: some View {
        if onChange != nil {
            editableStars
        } else {
            readOnlyStars
        }
    }

    // MARK: - Read-only

    private var readOnlyStars: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .font(size)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "評価"))
        .accessibilityValue(String(localized: "\(rating)星"))
    }

    // MARK: - 編集モード

    private var editableStars: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { value in
                Button {
                    onChange?(value)
                } label: {
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .font(size)
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                }
                .frame(minWidth: 44, minHeight: 44)
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "評価"))
        .accessibilityValue(String(localized: "\(rating)星"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onChange?(min(rating + 1, maxRating))
            case .decrement:
                onChange?(max(rating - 1, 0))
            @unknown default:
                break
            }
        }
        .sensoryFeedback(.selection, trigger: rating)
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        StarRatingView(rating: 0)
        StarRatingView(rating: 3, size: .caption2)
        StarRatingView(rating: 5, size: .title2)
        StatefulEditorPreview()
    }
    .padding()
}

private struct StatefulEditorPreview: View {
    @State private var rating = 3
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("編集モード: \(rating)").font(.caption).foregroundStyle(.secondary)
            StarRatingView(rating: rating, onChange: { rating = $0 })
        }
    }
}
