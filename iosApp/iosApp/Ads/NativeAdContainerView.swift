import GoogleMobileAds
import SwiftUI
import UIKit

/// `NativeAd` を UIKit の `NativeAdView` へレンダリングする `UIViewRepresentable`。
///
/// SwiftUI にはネイティブ広告専用のビューが存在しないため、Google 公式サンプルに準拠して
/// `NativeAdView`（`headlineView` 等の IBOutlet 風プロパティを持つ基底クラス）を
/// `UIViewRepresentable` でラップする。
struct NativeAdContainerView: UIViewRepresentable {

    enum Layout {
        /// カフェ詳細 / マップ検索ドロップダウン用（アイコン + 見出し + 本文 + CTA）。
        case card
        /// コーヒー記録 / 分析タブ下部固定用（1 行のコンパクト表示）。
        case compact
    }

    let nativeAd: NativeAd
    let layout: Layout

    func makeUIView(context: Context) -> NativeAdView {
        NativeAdContainerBuilder.makeAdView(layout: layout)
    }

    func updateUIView(_ uiView: NativeAdView, context: Context) {
        NativeAdContainerBuilder.populate(adView: uiView, nativeAd: nativeAd, layout: layout)
    }
}

/// `NativeAdContainerView` が使う UIKit ビュー組み立てヘルパー。
///
/// アイコン + 見出し + 本文 + 広告主 + CTA ボタンのみを使うテキスト主体のシンプルなテンプレート
/// （AdMob の Small テンプレート相当）。既存 UI の行の高さと揃えるため `mediaView` は使用しない
/// （`headline` 以外は任意アセットのため非表示でもポリシー上問題ない）。
enum NativeAdContainerBuilder {

    static func makeAdView(layout: NativeAdContainerView.Layout) -> NativeAdView {
        let adView = NativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView()
        icon.contentMode = .scaleAspectFill
        icon.clipsToBounds = true
        icon.layer.cornerRadius = 8
        icon.translatesAutoresizingMaskIntoConstraints = false
        let iconSize: CGFloat = layout == .compact ? 32 : 44
        icon.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: iconSize).isActive = true

        let headline = UILabel()
        headline.font = .preferredFont(forTextStyle: .subheadline)
        headline.adjustsFontForContentSizeCategory = true
        headline.numberOfLines = 1
        headline.textColor = .label

        let body = UILabel()
        body.font = .preferredFont(forTextStyle: .footnote)
        body.adjustsFontForContentSizeCategory = true
        body.textColor = .secondaryLabel
        body.numberOfLines = layout == .compact ? 1 : 2

        let advertiser = UILabel()
        advertiser.font = .preferredFont(forTextStyle: .caption2)
        advertiser.adjustsFontForContentSizeCategory = true
        advertiser.textColor = .tertiaryLabel

        let cta = UIButton(type: .system)
        var ctaConfig = UIButton.Configuration.filled()
        ctaConfig.baseBackgroundColor = .systemBrown
        ctaConfig.cornerStyle = .medium
        ctaConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        ctaConfig.titleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .preferredFont(forTextStyle: .footnote)
                return outgoing
            }
        cta.configuration = ctaConfig
        // CTA のタップ処理は SDK 側のジェスチャー認識に委ねる（公式サンプル準拠）。
        cta.isUserInteractionEnabled = false
        cta.setContentCompressionResistancePriority(.required, for: .horizontal)

        let adBadge = UILabel()
        adBadge.text = String(localized: "広告", comment: "ネイティブ広告の必須表示ラベル")
        adBadge.font = Self.boldPreferredFont(forTextStyle: .caption2)
        adBadge.adjustsFontForContentSizeCategory = true
        adBadge.textColor = .white
        adBadge.backgroundColor = .secondaryLabel
        adBadge.textAlignment = .center
        adBadge.layer.cornerRadius = 3
        adBadge.layer.masksToBounds = true
        adBadge.isAccessibilityElement = true
        adBadge.accessibilityLabel = String(localized: "広告")
        adBadge.translatesAutoresizingMaskIntoConstraints = false
        adBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        adBadge.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let adChoicesView = AdChoicesView()
        adChoicesView.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: layout == .compact
            ? [headline, body]
            : [headline, body, advertiser])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading

        let badgeRow = UIStackView(arrangedSubviews: [adBadge, UIView(), adChoicesView])
        badgeRow.axis = .horizontal
        badgeRow.alignment = .center
        badgeRow.spacing = 4

        let contentRow = UIStackView(arrangedSubviews: [icon, textStack, cta])
        contentRow.axis = .horizontal
        contentRow.alignment = .center
        contentRow.spacing = 12

        let outerStack = UIStackView(arrangedSubviews: [badgeRow, contentRow])
        outerStack.axis = .vertical
        outerStack.spacing = 6
        outerStack.translatesAutoresizingMaskIntoConstraints = false

        adView.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            outerStack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            outerStack.topAnchor.constraint(equalTo: adView.topAnchor, constant: 8),
            outerStack.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -8),
        ])

        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = cta
        adView.iconView = icon
        adView.advertiserView = layout == .compact ? nil : advertiser
        adView.adChoicesView = adChoicesView

        return adView
    }

    static func populate(adView: NativeAdView, nativeAd: NativeAd, layout: NativeAdContainerView.Layout) {
        (adView.headlineView as? UILabel)?.text = nativeAd.headline

        (adView.bodyView as? UILabel)?.text = nativeAd.body
        adView.bodyView?.isHidden = nativeAd.body == nil

        if var config = (adView.callToActionView as? UIButton)?.configuration {
            config.title = nativeAd.callToAction
            (adView.callToActionView as? UIButton)?.configuration = config
        }
        adView.callToActionView?.isHidden = nativeAd.callToAction == nil

        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        adView.iconView?.isHidden = nativeAd.icon == nil

        if layout != .compact {
            (adView.advertiserView as? UILabel)?.text = nativeAd.advertiser
            adView.advertiserView?.isHidden = nativeAd.advertiser == nil
        }

        // 登録は最後（クリックスルー有効化のため公式サンプル通りの順序を維持する）。
        adView.nativeAd = nativeAd
    }

    /// Dynamic Type に追随する太字フォントを生成する（`UIFont` に `Font.bold()` 相当の API が無いため）。
    private static func boldPreferredFont(forTextStyle style: UIFont.TextStyle) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(.traitBold) else {
            return base
        }
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }
}
