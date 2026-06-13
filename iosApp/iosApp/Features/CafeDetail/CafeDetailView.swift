import SwiftUI
import SharedLogic

/// カフェ詳細画面。
///
/// - カフェ情報（名前 / 住所 / 訪問回数）+ 過去 Visit 一覧を表示する
/// - ツールバーの `+` ボタンで `VisitEditorView` を sheet で起動（cafe pre-filled）
/// - NavigationStack push ごとに新規 Bridge を生成するため、`@State` で保持する
/// - マップの Annotation タップ / 検索結果タップの両方から push される
struct CafeDetailView: View {

    // MARK: - Properties

    let placeId: String
    let initialCafe: Cafe?
    var appState: AppState

    @State private var bridge: CafeDetailViewModelBridge?
    @State private var isPresentingEditor = false

    // MARK: - Body

    var body: some View {
        Group {
            if let bridge {
                if bridge.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    cafeDetailList(bridge: bridge)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(bridge?.cafe?.name ?? initialCafe?.name ?? String(localized: "カフェ詳細"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            if bridge == nil, let uid = appState.uid {
                bridge = CafeDetailViewModelBridge(
                    viewModel: appState.container.makeCafeDetailViewModel(
                        placeId: placeId,
                        initialCafe: initialCafe,
                        userId: uid
                    )
                )
            }
        }
        .onDisappear {
            bridge?.cancel()
        }
        .sheet(isPresented: $isPresentingEditor) {
            VisitEditorView(
                mode: VisitEditorViewModelModeCreate.shared,
                appState: appState,
                initialCafe: bridge?.cafe ?? initialCafe
            )
        }
    }

    // MARK: - リストコンテンツ

    private func cafeDetailList(bridge: CafeDetailViewModelBridge) -> some View {
        List {
            cafeInfoSection(bridge: bridge)
            pastVisitsSection(bridge: bridge)
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - カフェ情報セクション

    private func cafeInfoSection(bridge: CafeDetailViewModelBridge) -> some View {
        Section(String(localized: "カフェ情報")) {
            if let cafe = bridge.cafe ?? initialCafe {
                LabeledContent(String(localized: "名前")) {
                    Text(cafe.name)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityLabel(String(localized: "カフェ名 \(cafe.name)"))

                if let address = cafe.address, !address.isEmpty {
                    LabeledContent(String(localized: "住所")) {
                        Text(address)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(String(localized: "住所 \(address)"))
                }

                LabeledContent(String(localized: "訪問回数")) {
                    Text(String(localized: "\(bridge.pastVisits.count) 回"))
                        .foregroundStyle(bridge.pastVisits.isEmpty ? .secondary : .primary)
                }
                .accessibilityLabel(String(localized: "訪問回数 \(bridge.pastVisits.count) 回"))
            } else {
                Text(String(localized: "カフェ情報を読み込み中..."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 過去 Visit セクション

    private func pastVisitsSection(bridge: CafeDetailViewModelBridge) -> some View {
        Section(String(localized: "訪問記録")) {
            if bridge.pastVisits.isEmpty {
                emptyVisitsView
            } else {
                ForEach(bridge.pastVisits) { visit in
                    NavigationLink {
                        VisitDetailView(visitId: visit.id, appState: appState)
                    } label: {
                        VisitSummaryRow(visit: visit)
                    }
                }
            }
        }
    }

    /// 過去 Visit がない場合の空表示 + Visit 追加誘導。
    private var emptyVisitsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cup.and.saucer")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(String(localized: "まだ訪問記録がありません"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                isPresentingEditor = true
            } label: {
                Label(
                    String(localized: "Visit を追加"),
                    systemImage: "plus.circle.fill"
                )
                .font(.body.bold())
            }
            .accessibilityLabel(String(localized: "Visit を追加"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - ツールバー

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isPresentingEditor = true
            } label: {
                Label(
                    String(localized: "Visit を追加"),
                    systemImage: "plus"
                )
            }
            .accessibilityLabel(String(localized: "Visit を追加"))
            .disabled(appState.uid == nil)
        }
    }
}

// MARK: - VisitSummaryRow

/// カフェ詳細画面内の過去 Visit 行コンポーネント。
private struct VisitSummaryRow: View {

    let visit: Visit_

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate)
                .font(.subheadline)
                .foregroundStyle(.primary)
            StarRatingView(rating: Int(visit.rating), size: .caption)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "\(formattedDate), \(Int(visit.rating))星")
        )
    }

    private var formattedDate: String {
        let d = visit.visitedOn
        return String(
            format: "%04d/%02d/%02d",
            Int(d.year),
            Int(d.monthNumber),
            Int(d.dayOfMonth)
        )
    }
}
