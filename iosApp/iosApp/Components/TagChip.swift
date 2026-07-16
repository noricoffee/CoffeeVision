import SwiftUI

/// マップ / 一覧画面で共通利用するフィルタ切替チップ。
///
/// - 選択時: `tint`（既定 `Color.accentColor`）で塗り潰し + 白文字
/// - 非選択時: `.regularMaterial` 背景 + secondary テキスト
/// - `count` を指定すると右上に件数バッジを表示する（100 以上は "99+"）
struct TagChip: View {

    let label: String
    let systemImage: String
    let isOn: Bool
    var count: Int? = nil
    /// 選択時の塗り色。既定は `Color.accentColor`。
    /// `docs/ui-ux-guidelines.md` の色セマンティクス表に従い、意味付けされた概念（好み一致=pink 等）は
    /// 呼び出し側で明示的に渡す（`accentColor` を流用しない）。
    var tint: Color = .accentColor
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
                            .fill(isOn ? tint : Color.clear)
                            .background(
                                Capsule().fill(.regularMaterial)
                            )
                    )

                if let count, count > 0 {
                    countBadge(count)
                        .offset(x: 6, y: -6)
                }
            }
            // バッジは上・右に 6pt はみ出して描画されるため、そのぶんを自身のレイアウト境界内に
            // 確保する。上下を対称に確保することでカプセル本体の垂直中心はバッジ有無に関わらず
            // 揃ったまま維持され、水平方向は右側だけ広げれば次のチップとの間隔が単に広がるだけで
            // 済む。これにより ScrollView にクリップされず、他チップとの中央揃えも崩れない。
            .padding(badgeReservedInsets)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    /// バッジのはみ出し分（上 6pt・右 6pt）を確保する padding。バッジを表示しないときは 0。
    private var badgeReservedInsets: EdgeInsets {
        guard let count, count > 0 else { return EdgeInsets() }
        return EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 6)
    }

    // MARK: - 件数バッジ

    private func countBadge(_ count: Int) -> some View {
        Text(count >= 100 ? "99+" : "\(count)")
            .font(.caption2.bold())
            .foregroundStyle(isOn ? tint : .white)
            .padding(.horizontal, 4)
            .frame(minWidth: 16, minHeight: 16)
            .background(Circle().fill(isOn ? Color.white : tint))
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
        // `tint` 指定（マップの「好み一致」チップ、2026-07-16 タップ対応でインタラクティブ化）
        HStack(spacing: 8) {
            TagChip(label: "好み一致", systemImage: "heart.fill", isOn: false, count: 5, tint: .pink) {}
            TagChip(label: "好み一致", systemImage: "heart.fill", isOn: true, count: 5, tint: .pink) {}
        }
        HStack(spacing: 8) {
            TagLegendChip(label: "好み一致", systemImage: "heart.fill", tint: .pink)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

/// `MapTabView.filterChipRow` と同じ「横スクロール内に並ぶチップ」を再現した Preview。
///
/// 修正前はここでバッジの上・右側が `ScrollView` の境界でクリップされ、数字の上半分が
/// 途切れて見えていた。修正後は `TagChip` が自身のレイアウト境界内にバッジのはみ出し分を
/// 確保するため、`ScrollView` 内でも欠けずに全体が表示される。
#Preview("TagChip in ScrollView（クリップ確認用）") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
            TagChip(label: "訪問済み", systemImage: "cup.and.saucer.fill", isOn: true) {}
            TagLegendChip(label: "好み一致", systemImage: "heart.fill", tint: .pink)
            // 非選択 + 選択の両状態でバッジが欠けないことを確認
            TagChip(label: "保存済み", systemImage: "bookmark.fill", isOn: false, count: 3) {}
            TagChip(label: "保存済み", systemImage: "bookmark.fill", isOn: true, count: 128) {}
            // 右端に来るケース（トレイリング側のクリップ確認）
            TagChip(label: "右端バッジ", systemImage: "star.fill", isOn: false, count: 9) {}
        }
        .padding(.horizontal, 2)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
