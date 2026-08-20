import SwiftUI
import SharedLogic

/// 「行きたい店」一覧ハーフシート（フェーズ 15-A）。
///
/// - `savedCafes` は `savedAt` 降順（`MapViewModel.UIState.savedCafes` の契約。呼び出し側で再ソートしない）
/// - `recordedPlaceIds` に含まれる店には「記録あり」バッジを表示する
/// - タップで `onSelect` を呼ぶ（呼び出し側でシートを閉じてカフェ詳細へ push する）
/// - スワイプで `onRemove` を呼ぶ（解除。`MapViewModelBridge.onSavedCafeRemoved(placeId:)` 経由）
struct SavedCafeListSheet: View {

    let savedCafes: [SavedCafe]
    let recordedPlaceIds: Set<String>
    let onSelect: (SavedCafe) -> Void
    let onRemove: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if savedCafes.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(savedCafes, id: \.cafe.placeId) { savedCafe in
                            Button {
                                onSelect(savedCafe)
                            } label: {
                                row(savedCafe)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onRemove(savedCafe.cafe.placeId)
                                } label: {
                                    Label(String(localized: "解除"), systemImage: "bookmark.slash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(String(localized: "行きたい店"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 行

    private func row(_ savedCafe: SavedCafe) -> some View {
        let isRecorded = recordedPlaceIds.contains(savedCafe.cafe.placeId)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bookmark.fill")
                .font(.body)
                .foregroundStyle(Color.indigo)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(savedCafe.cafe.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if let address = savedCafe.cafe.address, !address.isEmpty {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }

                if isRecorded {
                    Label(String(localized: "記録あり"), systemImage: "cup.and.saucer.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isRecorded
                ? String(localized: "\(savedCafe.cafe.name)、記録あり")
                : savedCafe.cafe.name
        )
    }

    // MARK: - 空状態

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(String(localized: "まだ「行きたい店」がありません"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(localized: "カフェ詳細画面のブックマークボタンから保存できます"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}
