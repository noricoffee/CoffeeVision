import SwiftUI

/// レーダーチャートの 1 軸分のデータ。
///
/// `TastingRadarChart` はドメイン非依存の汎用コンポーネントのため、
/// テイスティング固有の「件数」等の情報を持たない。読み上げ内容を
/// カスタマイズしたい場合は `accessibilityLabel` を明示的に渡す。
struct RadarChartAxis: Identifiable {
    let id: String
    let label: String
    let value: Double
    var accessibilityLabel: String?

    init(id: String, label: String, value: Double, accessibilityLabel: String? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.accessibilityLabel = accessibilityLabel
    }
}

/// `Path` によるカスタム描画のレーダー（スパイダー）チャート。
///
/// Swift Charts にレーダー表現が無いため自前実装する。軸は `axes` の並び順で
/// 12 時位置から時計回りに等間隔配置し、スケールは `0...maxValue` 固定
/// （データの最大値に正規化しない）。
struct TastingRadarChart: View {
    let axes: [RadarChartAxis]
    let maxValue: Double

    /// グリッドの同心多角形の本数（例: maxValue = 10 なら 2/4/6/8/10 の 5 本）。
    var ringCount: Int = 5

    private let labelWidth: CGFloat = 76
    private let labelHeight: CGFloat = 32
    private let labelPadding: CGFloat = 6
    private let markerDiameter: CGFloat = 7

    private var gridColor: Color { Color(.systemGray4) }

    var body: some View {
        GeometryReader { geometry in
            let horizontalInset = labelWidth + labelPadding
            let verticalInset = labelHeight + labelPadding
            let radiusX = geometry.size.width / 2 - horizontalInset
            let radiusY = geometry.size.height / 2 - verticalInset
            let radius = max(min(radiusX, radiusY), 40)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                gridLayer(center: center, radius: radius)
                dataLayer(center: center, radius: radius)
                labelsLayer(center: center, radius: radius)
            }
        }
        .frame(height: 260)
    }

    // MARK: - グリッド（同心多角形 + スポーク）

    private func gridLayer(center: CGPoint, radius: CGFloat) -> some View {
        Group {
            ForEach(1...max(ringCount, 1), id: \.self) { ring in
                regularPolygonPath(center: center, radius: radius * CGFloat(ring) / CGFloat(ringCount))
                    .stroke(gridColor, lineWidth: 0.75)
            }
            spokesPath(center: center, radius: radius)
                .stroke(gridColor, lineWidth: 0.75)
        }
        .accessibilityHidden(true)
    }

    // MARK: - データポリゴン + 頂点マーカー

    private func dataLayer(center: CGPoint, radius: CGFloat) -> some View {
        let path = dataPolygonPath(center: center, radius: radius)
        return Group {
            path.fill(Color.accentColor.opacity(0.2))
            path.stroke(Color.accentColor, lineWidth: 2)
            ForEach(Array(axes.enumerated()), id: \.offset) { index, axis in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: markerDiameter, height: markerDiameter)
                    .position(vertexPoint(index: index, ratio: normalizedRatio(axis.value), radius: radius, center: center))
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - 軸ラベル

    @ViewBuilder
    private func labelsLayer(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(Array(axes.enumerated()), id: \.offset) { index, axis in
            axisLabel(index: index, axis: axis, radius: radius, center: center)
        }
    }

    private func axisLabel(index: Int, axis: RadarChartAxis, radius: CGFloat, center: CGPoint) -> some View {
        let angle = axisAngle(index: index, count: axes.count)
        let cosT = cos(angle)
        let sinT = sin(angle)
        let hOffset = labelWidth / 2 + labelPadding
        let vOffset = labelHeight / 2 + labelPadding

        var dx: CGFloat = 0
        if cosT > 0.35 { dx = hOffset }
        else if cosT < -0.35 { dx = -hOffset }

        var dy: CGFloat = 0
        if sinT < -0.35 { dy = -vOffset }
        else if sinT > 0.35 { dy = vOffset }

        let vertex = CGPoint(x: center.x + radius * CGFloat(cosT), y: center.y + radius * CGFloat(sinT))
        let labelCenter = CGPoint(x: vertex.x + dx, y: vertex.y + dy)

        return Text("\(axis.label) \(formattedValue(axis.value))")
            .font(.caption)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .frame(width: labelWidth)
            .fixedSize(horizontal: false, vertical: true)
            .position(labelCenter)
            .accessibilityLabel(axis.accessibilityLabel ?? "\(axis.label): \(formattedValue(axis.value))")
    }

    // MARK: - ジオメトリヘルパ

    private func normalizedRatio(_ value: Double) -> Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value, 0), maxValue) / maxValue
    }

    private func axisAngle(index: Int, count: Int) -> Double {
        guard count > 0 else { return 0 }
        return -Double.pi / 2 + Double(index) * (2 * .pi / Double(count))
    }

    private func vertexPoint(index: Int, ratio: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = axisAngle(index: index, count: axes.count)
        let r = radius * CGFloat(ratio)
        return CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
    }

    private func regularPolygonPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let count = axes.count
        guard count > 0 else { return path }
        for i in 0..<count {
            let point = vertexPoint(index: i, ratio: 1, radius: radius, center: center)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private func dataPolygonPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        guard !axes.isEmpty else { return path }
        for (index, axis) in axes.enumerated() {
            let point = vertexPoint(index: index, ratio: normalizedRatio(axis.value), radius: radius, center: center)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private func spokesPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for i in 0..<axes.count {
            let point = vertexPoint(index: i, ratio: 1, radius: radius, center: center)
            path.move(to: center)
            path.addLine(to: point)
        }
        return path
    }

    private func formattedValue(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - Preview

#Preview {
    TastingRadarChart(
        axes: [
            RadarChartAxis(id: "甘味", label: String(localized: "甘味"), value: 6.2, accessibilityLabel: "甘味 平均 6.2（12 件の記録）"),
            RadarChartAxis(id: "ボディ", label: String(localized: "ボディ"), value: 7.5, accessibilityLabel: "ボディ 平均 7.5（12 件の記録）"),
            RadarChartAxis(id: "酸味", label: String(localized: "酸味"), value: 4.8, accessibilityLabel: "酸味 平均 4.8（12 件の記録）"),
            RadarChartAxis(id: "風味", label: String(localized: "風味"), value: 8.1, accessibilityLabel: "風味 平均 8.1（12 件の記録）"),
            RadarChartAxis(id: "後味", label: String(localized: "後味"), value: 5.3, accessibilityLabel: "後味 平均 5.3（12 件の記録）"),
        ],
        maxValue: 10
    )
    .padding(24)
}
