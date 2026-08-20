import SwiftUI

/// Google Maps Platform ポリシー遵守のための帰属表示（App Store ガイドライン 5.2.2 / 5.2.1）。
///
/// 本アプリは Places API のコンテンツを Apple MapKit + 自前 UI 上に表示しており、Google マップ
/// そのものを表示していないため、Google のロゴ画像は同梱していない。スペースが限られる場合の
/// 代替として認められている「Google Maps」テキスト表記で控えめに添える。
///
/// 帰属義務の正本は `docs/requirements.md` §5 の注記、写真の作者帰属は `docs/data-model.md` §1.2。
///
/// 使用箇所（Places 由来データを**その場で提示している面**のみ。記録一覧・記録詳細・共有カード・
/// 保存済みリストは保存済みスナップショット = ユーザー自身の記録の表示なので対象外）:
/// - `CafeDetailView`（カフェ情報セクション）
/// - `MapSearchResultsSheet`（検索結果リスト）
/// - `CafeSelectionCard`（ピン選択カード）
/// - `CafeSearchView`（エディタからのカフェ検索シート）
struct GoogleMapsAttributionText: View {

    var body: some View {
        Text(String(localized: "Google Maps"))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityLabel(String(localized: "提供元 Google Maps"))
    }
}

#Preview {
    GoogleMapsAttributionText()
        .padding()
}
