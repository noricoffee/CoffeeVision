import SwiftUI

/// マップ / 一覧画面で共通利用するフィルタ切替チップ。
///
/// - 選択時: `Color.accentColor` で塗り潰し + 白文字
/// - 非選択時: `.regularMaterial` 背景 + secondary テキスト
/// - `count` を指定すると右上に件数バッジを表示する（100 以上は "99+"）
struct TagChip: View {

    let label: String
    let systemImage: String
    let isOn: Bool
    var count: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Label(label, systemImage: systemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isOn ? .white : Color.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(
                        Capsule()
                            .fill(isOn ? Color.accentColor : Color.clear)
                            .background(
                                Capsule().fill(.regularMaterial)
                            )
                    )

                if let count, count > 0 {
                    countBadge(count)
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    // MARK: - 件数バッジ

    private func countBadge(_ count: Int) -> some View {
        Text(count >= 100 ? "99+" : "\(count)")
            .font(.caption2.bold())
            .foregroundStyle(isOn ? Color.accentColor : .white)
            .padding(.horizontal, 4)
            .frame(minWidth: 16, minHeight: 16)
            .background(Circle().fill(isOn ? Color.white : Color.accentColor))
    }

    // MARK: - アクセシビリティ

    private var accessibilityText: String {
        if let count, count > 0 {
            return String(localized: "\(label)、\(count)件")
        }
        return label
    }
}

// MARK: - TagLegendChip

/// インタラクションを持たない凡例チップ（例: 好み一致ピンの凡例表示）。
///
/// ピンの意味をユーザーに伝えるための静的表示専用で、タップ操作は受け付けない。
struct TagLegendChip: View {

    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 44, minHeight: 44)
            .background(
                Capsule().fill(.regularMaterial)
            )
            .accessibilityLabel(String(localized: "\(label)のカフェが強調表示されています"))
            .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Preview

#Preview("TagChip") {
    VStack(spacing: 16) {
        HStack(spacing: 8) {
            TagChip(label: "訪問済み", systemImage: "cup.and.saucer.fill", isOn: true) {}
            TagChip(label: "保存済み", systemImage: "bookmark.fill", isOn: false, count: 3) {}
            TagChip(label: "保存済み", systemImage: "bookmark.fill", isOn: true, count: 128) {}
        }
        HStack(spacing: 8) {
            TagLegendChip(label: "好み一致", systemImage: "heart.fill", tint: .pink)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
