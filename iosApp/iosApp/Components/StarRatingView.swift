import SwiftUI

// MARK: - StarRatingView

/// 星評価表示 / 入力コンポーネント。0.5 刻みのハーフスターに対応。
///
/// - `onChange` が `nil` のとき: read-only モード（タップ非反応）
/// - `onChange` が非 `nil` のとき: 編集モード（星の左半分タップ → value - 0.5、右半分 → value）
/// - 有効値: 0.0（未評価）〜 maxRating（0.5 刻み）
struct StarRatingView: View {

    /// 現在の評価値（0.0...maxRating、0.5 刻み）
    let rating: Double

    /// 評価の上限。デフォルト 5
    var maxRating: Int = 5

    /// 星のフォントサイズ。Dynamic Type に合わせる前提で Font で受け取る
    var size: Font = .body

    /// タップ・VoiceOver 操作で評価が変わった時のハンドラ。
    /// nil なら read-only モード（タップ非反応）
    var onChange: ((Double) -> Void)? = nil

    var body: some View {
        if onChange != nil {
            editableStars
        } else {
            readOnlyStars
        }
    }

    // MARK: - 星アイコン選択

    /// value（1...maxRating）に対して、現在の rating に応じた SF Symbol 名を返す。
    private func starSymbol(for value: Int) -> String {
        if rating >= Double(value) {
            return "star.fill"
        } else if rating >= Double(value) - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }

    // MARK: - Read-only

    private var readOnlyStars: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { value in
                Image(systemName: starSymbol(for: value))
                    .font(size)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "評価"))
        .accessibilityValue(accessibilityValueString)
    }

    // MARK: - 編集モード

    private var editableStars: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { value in
                // 各星を左右 2 分割した透明タップ領域で 0.5 / 1.0 を判定する
                StarTapCell(
                    symbol: starSymbol(for: value),
                    font: size,
                    onTapHalf: { onChange?(Double(value) - 0.5) },
                    onTapFull: { onChange?(Double(value)) }
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "評価"))
        .accessibilityValue(accessibilityValueString)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onChange?(min(rating + 0.5, Double(maxRating)))
            case .decrement:
                onChange?(max(rating - 0.5, 0.0))
            @unknown default:
                break
            }
        }
        .sensoryFeedback(.selection, trigger: rating)
    }

    // MARK: - アクセシビリティ

    /// 整数なら「4星」、0.5 刻みなら「3.5星」と読む
    private var accessibilityValueString: String {
        if rating.truncatingRemainder(dividingBy: 1) == 0 {
            return String(localized: "\(Int(rating))星")
        } else {
            return String(localized: "\(rating)星")
        }
    }
}

// MARK: - StarTapCell

/// 1 つの星を左右 2 分割してタップ領域を作るプライベートコンポーネント。
///
/// - 左半分タップ → `onTapHalf`（value - 0.5）
/// - 右半分タップ → `onTapFull`（value）
/// - 最小タップ領域 44×44pt を維持するため各セル全体は 44pt 以上確保する
private struct StarTapCell: View {

    let symbol: String
    let font: Font
    let onTapHalf: () -> Void
    let onTapFull: () -> Void

    var body: some View {
        Image(systemName: symbol)
            .font(font)
            .foregroundStyle(.yellow)
            .accessibilityHidden(true)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .overlay(
                // 左半分: value - 0.5
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Color.clear
                            .frame(width: geo.size.width / 2)
                            .contentShape(Rectangle())
                            .onTapGesture { onTapHalf() }
                        // 右半分: value
                        Color.clear
                            .frame(width: geo.size.width / 2)
                            .contentShape(Rectangle())
                            .onTapGesture { onTapFull() }
                    }
                }
            )
    }
}

// MARK: - Preview

#Preview("Read-only（0〜5, 0.5 刻み）") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach([0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0], id: \.self) { value in
            HStack(spacing: 8) {
                Text(value.truncatingRemainder(dividingBy: 1) == 0
                     ? "\(Int(value))星"
                     : "\(value)星"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
                StarRatingView(rating: value)
            }
        }
    }
    .padding()
}

#Preview("編集モード") {
    VStack(alignment: .leading, spacing: 16) {
        StarRatingViewEditorPreview()
    }
    .padding()
}

private struct StarRatingViewEditorPreview: View {
    @State private var rating: Double = 3.5
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rating.truncatingRemainder(dividingBy: 1) == 0
                 ? "現在の評価: \(Int(rating))星"
                 : "現在の評価: \(rating)星"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            StarRatingView(rating: rating, onChange: { rating = $0 })
            Divider()
            Text("サイズバリエーション（編集モード）")
                .font(.caption)
                .foregroundStyle(.secondary)
            StarRatingView(rating: rating, size: .caption2, onChange: { rating = $0 })
            StarRatingView(rating: rating, size: .title2, onChange: { rating = $0 })
        }
    }
}
