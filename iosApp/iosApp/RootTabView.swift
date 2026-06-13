import SwiftUI

/// アプリのルートタブビュー。iOS 26 の `TabView` 新 API を使用。
///
/// 3 タブ構成:
/// - マップタブ: 訪問済みカフェと周辺カフェをマップ上に表示
/// - 訪問タブ: 訪問記録一覧（VisitListView）
/// - 検索タブ: カフェ検索（CafeSearchView / `Tab(role: .search)`）
///
/// 新規 Visit 作成の導線: マップ / 検索 → カフェ詳細 → 「+ Visit を追加」ボタン → VisitEditorView
@MainActor
struct RootTabView: View {

    var appState: AppState

    var body: some View {
        TabView {
            Tab(String(localized: "マップ"), systemImage: "map") {
                NavigationStack {
                    MapTabView(appState: appState)
                }
            }

            Tab(String(localized: "訪問"), systemImage: "list.bullet") {
                NavigationStack {
                    if let bridge = appState.visitListBridge {
                        VisitListView(viewModel: bridge, appState: appState)
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
