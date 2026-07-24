import SwiftUI
import SharedLogic

/// マップ上部のフィルタチップ行（訪問済み / 好み一致 / 保存済み / タグフィルタ）。
///
/// 「好み一致」/「保存済み」チップのタップは常に一覧シートを開くアクション（`onOpenRecommended` /
/// `onOpenSaved`）に一本化されている。マップ上の強調表示（他ピン減光）は一覧シート表示中かどうかに
/// 連動するため、強調フラグ（`recommendedEmphasisActive` / `savedEmphasisActive`）は呼び出し元
/// （`MapTabView`）の `activeCafeListSheet` から算出した値を渡す（2026-07-24 操作モデル改修）。
struct MapFilterChipRow: View {

    let bridge: MapViewModelBridge
    let recommendedEmphasisActive: Bool
    let savedEmphasisActive: Bool
    let onOpenRecommended: () -> Void
    let onOpenSaved: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagChip(
                    label: String(localized: "訪問済み"),
                    systemImage: "cup.and.saucer.fill",
                    isOn: bridge.showVisited
                ) {
                    bridge.onShowVisitedToggled(!bridge.showVisited)
                }

                // 「好み一致」チップ（1 件以上あるときのみ表示。2026-07-24 操作モデル改修）
                // タップで常に一覧シートを開く（既に開いていれば no-op）。マップ強調はシート表示中
                // だけ連動して ON になり、下スワイプで閉じると自動的に OFF になる。「保存済み」との
                // 排他性は `activeCafeListSheet`（単一 item state）が構造的に保証する。
                if !bridge.recommendedCafes.isEmpty {
                    TagChip(
                        label: String(localized: "好み一致"),
                        systemImage: "heart.fill",
                        isOn: recommendedEmphasisActive,
                        count: bridge.recommendedCafes.count,
                        tint: .pink
                    ) {
                        onOpenRecommended()
                    }
                }

                // 「保存済み」チップ（1 件以上あるときのみ表示。2026-07-24 操作モデル改修）
                // タップで常に一覧シートを開く（既に開いていれば no-op）。マップ強調はシート表示中
                // だけ連動して ON になり、下スワイプで閉じると自動的に OFF になる。
                if !bridge.savedCafes.isEmpty {
                    TagChip(
                        label: String(localized: "保存済み"),
                        systemImage: "bookmark.fill",
                        isOn: savedEmphasisActive,
                        count: bridge.savedCafes.count
                    ) {
                        onOpenSaved()
                    }
                }

                // タグフィルタチップ（availableTags が空でないとき）
                if !bridge.availableTags.isEmpty {
                    Divider()
                        .frame(height: 24)

                    ForEach(bridge.availableTags, id: \.self) { tag in
                        TagChip(
                            label: tag,
                            systemImage: "tag",
                            isOn: bridge.selectedTags.contains(tag)
                        ) {
                            bridge.onTagFilterToggled(tag)
                        }
                    }

                    if !bridge.selectedTags.isEmpty {
                        Button {
                            bridge.onTagFilterCleared()
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "タグフィルターをクリア"))
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
