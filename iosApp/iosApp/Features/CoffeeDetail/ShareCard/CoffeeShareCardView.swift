import SwiftUI
import SharedLogic

// MARK: - CoffeeShareCardView

/// コーヒー記録 1 件を SNS 共有向けカード画像として描画する View。
///
/// - 出力サイズは 1080×1350px（4:5）。`ImageRenderer` の `scale = 3` を掛ける前提で
///   `cardWidth × cardHeight`（360×450pt）固定フレームで組む（`ShareCardRenderer` 参照）
/// - 写真 / テイスティングレーダー / 評価は「あれば載せる」可変レイアウト。何が欠けても破綻しない
/// - メモ・タグは載せない（誤共有防止 / カードの簡潔性、`docs/requirements.md` §2 2-12）
/// - ライトテーマ固定は呼び出し側（`ShareCardRenderer`）が `.environment(\.colorScheme, .light)` を
///   適用する。このファイル自体はシステムカラーを使うだけで環境非依存に保つ
struct CoffeeShareCardView: View {

    let coffee: CoffeeRecord

    // MARK: - サイズ定数

    static let cardWidth: CGFloat = 360
    static let cardHeight: CGFloat = 450

    private static let photoBandHeight: CGFloat = 128
    private static let headerBarHeight: CGFloat = 40
    private static let nameRowHeight: CGFloat = 28
    private static let ratingRowHeight: CGFloat = 22
    private static let locationRowHeight: CGFloat = 20
    private static let chipsRowHeight: CGFloat = 32
    private static let footerHeight: CGFloat = 22
    private static let sectionSpacing: CGFloat = 8
    private static let contentTopPadding: CGFloat = 14
    private static let contentBottomPadding: CGFloat = 10
    private static let contentHorizontalPadding: CGFloat = 16
    private static let radarNativeHeight: CGFloat = 260
    private static let radarMinHeight: CGFloat = 96

    // MARK: - 派生データ

    /// 先頭の有効写真（読み込みに成功したもの）。**`init` で 1 度だけ解決する。**
    ///
    /// computed property にしてはいけない。`bandHeight` → `infoAreaHeight` →
    /// `radarHeight` → `radarScale` の連鎖と `headerOrPhotoBand` から参照されるため、
    /// **body 1 回の評価につき 3 回以上**（写真あり + テイスティングありのとき）
    /// 呼ばれる。しかも `ImageRenderer` はレイアウト確定のため body を複数回
    /// 評価するので、実際の回数はさらに増える。中身は長辺 2048px の JPEG の
    /// フルデコードで、すべてメインスレッド上・キャッシュなしだった。
    private let loadedPhoto: UIImage?

    // MARK: - Init

    init(coffee: CoffeeRecord) {
        self.coffee = coffee
        self.loadedPhoto = Self.resolveFirstPhoto(of: coffee)
    }

    /// 先頭の有効写真を解決する。`Photo.fileName` は nullable のため nil をスキップし、
    /// 最初にロード成功したものを採用する。
    ///
    /// **フルデコード（`PhotoFileStore.loadImage`）を使うのは意図的。** 共有カードは
    /// 1080×1350px 出力で、写真帯は 360×128pt × `scale = 3` = 1080×384px を占めるため、
    /// サムネイル縮小デコードでは足りない（implementation_note 2026-08-08「対象外（意図的）」）。
    /// ここで問題だったのは解像度ではなく**回数**。
    private static func resolveFirstPhoto(of coffee: CoffeeRecord) -> UIImage? {
        for photo in coffee.photos {
            guard let fileName = photo.fileName,
                  let image = PhotoFileStore.loadImage(fileName: fileName) else { continue }
            return image
        }
        return nil
    }

    private var bandHeight: CGFloat {
        loadedPhoto != nil ? Self.photoBandHeight : Self.headerBarHeight
    }

    private var tastingAxes: [RadarChartAxis]? {
        guard let tasting = coffee.tasting else { return nil }
        return [
            RadarChartAxis(id: "sweetness", label: String(localized: "甘味"), value: Double(tasting.sweetness)),
            RadarChartAxis(id: "body", label: String(localized: "ボディ"), value: Double(tasting.body)),
            RadarChartAxis(id: "acidity", label: String(localized: "酸味"), value: Double(tasting.acidity)),
            RadarChartAxis(id: "flavor", label: String(localized: "風味"), value: Double(tasting.flavor)),
            RadarChartAxis(id: "aftertaste", label: String(localized: "後味"), value: Double(tasting.aftertaste)),
        ]
    }

    /// 産地 / 焙煎度 / 抽出方法の属性チップ。`brewMethod` は非 Optional のため必ず 1 件以上になる。
    private var attributeChips: [(label: String, systemImage: String)] {
        var chips: [(label: String, systemImage: String)] = []
        if let origin = coffee.originDisplayText {
            chips.append((origin, "globe.asia.australia"))
        }
        if let roastLevel = coffee.roastLevel {
            chips.append((roastLevel.localizedLabel, "flame"))
        }
        chips.append((coffee.brewMethod.localizedLabel, "drop"))
        return chips
    }

    /// 情報部（写真/ヘッダー帯を除いた残り）の高さ。
    private var infoAreaHeight: CGFloat {
        Self.cardHeight - bandHeight - Self.contentTopPadding - Self.contentBottomPadding
    }

    /// テイスティングレーダーに割り当てる高さ（他の可視セクションを差し引いた残り、下限あり）。
    private var radarHeight: CGFloat {
        guard tastingAxes != nil else { return 0 }
        var visibleCount = 3 // name + location + radar は常時表示
        var fixed: CGFloat = Self.nameRowHeight + Self.locationRowHeight + Self.footerHeight
        visibleCount += 1 // footer は常時表示
        if coffee.rating != nil {
            visibleCount += 1
            fixed += Self.ratingRowHeight
        }
        if !attributeChips.isEmpty {
            visibleCount += 1
            fixed += Self.chipsRowHeight
        }
        let spacing = Self.sectionSpacing * CGFloat(visibleCount - 1)
        let remaining = infoAreaHeight - fixed - spacing
        return max(remaining, Self.radarMinHeight)
    }

    private var radarScale: CGFloat {
        radarHeight / Self.radarNativeHeight
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerOrPhotoBand
            infoSection
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight, alignment: .top)
        .background(Color(.systemBackground))
        .clipped()
    }

    // MARK: - 写真帯 / ヘッダー帯

    @ViewBuilder
    private var headerOrPhotoBand: some View {
        if let loadedPhoto {
            Image(uiImage: loadedPhoto)
                .resizable()
                .scaledToFill()
                .frame(width: Self.cardWidth, height: Self.photoBandHeight)
                .clipped()
                .accessibilityHidden(true)
        } else {
            ZStack {
                Color.accentColor
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .frame(width: Self.cardWidth, height: Self.headerBarHeight)
            .accessibilityHidden(true)
        }
    }

    // MARK: - 情報部

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            Text(coffee.name)
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: Self.nameRowHeight, alignment: .leading)

            if coffee.rating != nil {
                StarRatingView(rating: coffee.rating?.doubleValue, size: .subheadline)
                    .frame(height: Self.ratingRowHeight, alignment: .leading)
            }

            locationDateRow
                .frame(height: Self.locationRowHeight, alignment: .leading)

            if !attributeChips.isEmpty {
                chipsRow
                    .frame(height: Self.chipsRowHeight, alignment: .leading)
            }

            if let tastingAxes {
                TastingRadarChart(axes: tastingAxes, maxValue: 10)
                    .scaleEffect(radarScale)
                    .frame(height: radarHeight)
                    .frame(maxWidth: .infinity)
            } else {
                Spacer(minLength: 8)
            }

            footer
        }
        .padding(.horizontal, Self.contentHorizontalPadding)
        .padding(.top, Self.contentTopPadding)
        .padding(.bottom, Self.contentBottomPadding)
    }

    private var locationDateRow: some View {
        HStack(spacing: 6) {
            if let cafe = coffee.cafe {
                Label(cafe.name, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Label(String(localized: "セルフ抽出"), systemImage: "house")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(formattedDate(coffee.visitedOn))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var chipsRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(attributeChips.enumerated()), id: \.offset) { _, chip in
                Label(chip.label, systemImage: chip.systemImage)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(.secondarySystemBackground)))
            }
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.caption)
            Text("CoffeeVision")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color.accentColor)
        .frame(height: Self.footerHeight, alignment: .leading)
        .accessibilityHidden(true)
    }

    // MARK: - 日付フォーマット

    private func formattedDate(_ date: Kotlinx_datetimeLocalDate) -> String {
        String(format: "%04d/%02d/%02d", Int(date.year), Int(date.monthNumber), Int(date.dayOfMonth))
    }
}

// MARK: - Preview

#Preview("カード（カフェ・写真・評価・テイスティングあり）") {
    CoffeeShareCardView(coffee: PreviewSamples.sampleCoffeeRecord)
        .padding(10)
}

#Preview("カード（カフェ・評価・テイスティングあり / 写真なし）") {
    CoffeeShareCardView(coffee: PreviewSamples.sampleCoffeeRecordWithoutPhotos)
        .padding(10)
}

#Preview("カード（セルフ抽出）") {
    CoffeeShareCardView(coffee: PreviewSamples.sampleCoffeeRecordSelfBrew)
        .padding(10)
}

#Preview("カード（未評価・テイスティングなし・属性なし）") {
    CoffeeShareCardView(coffee: PreviewSamples.sampleCoffeeRecordUnrated)
        .padding(10)
}
