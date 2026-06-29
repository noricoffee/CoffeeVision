import SwiftUI

/// アプリのルートタブビュー。iOS 26 の `TabView` 新 API を使用。
///
/// 3 タブ構成:
/// - マップタブ: 訪問済みカフェと周辺カフェをマップ上に表示。上部に Google Maps スタイルの検索バーを内蔵
/// - コーヒータブ: コーヒー記録一覧（CoffeeListView）+ FAB で新規記録作成
/// - 分析タブ: コーヒー記録の記述統計を可視化（Swift Charts）
///
/// 新規 CoffeeRecord 作成の導線:
/// - コーヒータブの FAB（右下に浮かぶ +）: セルフ抽出または後からカフェ選択
/// - マップ検索バー → カフェ選択 → 「詳細を見る」→ CafeDetailView → 「コーヒーを記録」→ CoffeeEditorView
@MainActor
struct RootTabView: View {

    var appState: AppState

    var body: some View {
        TabView {
            Tab(String(localized: "マップ"), systemImage: "map") {
                MapTabView(appState: appState)
            }

            Tab(String(localized: "コーヒー"), systemImage: "cup.and.saucer") {
                NavigationStack {
                    if let bridge = appState.coffeeListBridge {
                        CoffeeListView(viewModel: bridge, appState: appState)
                    }
                }
            }

            Tab(String(localized: "分析"), systemImage: "chart.bar.xaxis") {
                if let bridge = appState.analysisBridge {
                    AnalysisView(viewModel: bridge, appState: appState)
                }
            }
        }
    }
}
