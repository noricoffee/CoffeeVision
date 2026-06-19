import SwiftUI

/// アプリのルートタブビュー。iOS 26 の `TabView` 新 API を使用。
///
/// 3 タブ構成:
/// - マップタブ: 訪問済みカフェと周辺カフェをマップ上に表示
/// - コーヒータブ: コーヒー記録一覧（CoffeeListView）+ FAB で新規記録作成
/// - 検索タブ: カフェ検索（CafeSearchView / `Tab(role: .search)`）
///
/// 新規 CoffeeRecord 作成の導線:
/// - コーヒータブの FAB（検索タブ上に浮かぶ +）: セルフ抽出または後からカフェ選択
/// - マップ / 検索 → カフェ詳細 → 「コーヒーを記録」ボタン → CoffeeEditorView（カフェ pre-fill）
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

            Tab(role: .search) {
                NavigationStack {
                    CafeSearchView(appState: appState)
                        .navigationDestination(for: CafeDetailRoute.self) { route in
                            CafeDetailView(
                                placeId: route.placeId,
                                initialCafe: route.initialCafe,
                                appState: appState
                            )
                        }
                }
            }
        }
    }
}
