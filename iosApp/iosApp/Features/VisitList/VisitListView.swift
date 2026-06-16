import SwiftUI
import SharedLogic

// MARK: - Identifiable 拡張

extension Visit_: @retroactive Identifiable {}

// MARK: - VisitListView

/// 訪問記録一覧画面。
///
/// - RootTabView の NavigationStack 内に配置されるため、自身では NavigationStack を持たない
/// - 新規 Visit の作成導線は「マップ / 検索 → カフェ詳細 → + Visit を追加」に一本化されたため、
///   toolbar `+` ボタンと VisitEditorView sheet は撤去済み
/// - 既存 Visit の詳細は NavigationLink で VisitDetailView に push する
struct VisitListView: View {

    @State var viewModel: VisitListViewModelBridge
    var appState: AppState

    var body: some View {
        content
            .navigationTitle(String(localized: "訪問記録"))
            .navigationBarTitleDisplayMode(.large)
            .task {
                guard let uid = appState.uid else { return }
                viewModel.onAppear(userId: uid)
            }
            .onDisappear {
                viewModel.onDisappear()
            }
            .errorToast(message: viewModel.error) {
                viewModel.onErrorDismissed()
            }
    }

    // MARK: - コンテンツ

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
        } else if viewModel.visits.isEmpty {
            emptyView
        } else {
            visitList
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            String(localized: "まだ訪問記録がありません"),
            systemImage: "cup.and.saucer",
            description: Text(
                String(localized: "マップまたは検索タブからカフェを選んで訪問記録を追加しましょう")
            )
        )
    }

    private var visitList: some View {
        List {
            ForEach(viewModel.visits) { visit in
                NavigationLink {
                    VisitDetailView(visitId: visit.id, appState: appState)
                } label: {
                    VisitRow(visit: visit)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        // Visit 削除前に紐付く写真ファイルを Documents から物理削除する
                        for photo in visit.photos {
                            if let fileName = photo.fileName {
                                try? PhotoFileStore.delete(fileName: fileName)
                            }
                        }
                        viewModel.onVisitDeleted(id: visit.id)
                    } label: {
                        Label(
                            String(localized: "削除"),
                            systemImage: "trash"
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - VisitRow

/// 訪問記録一覧の行コンポーネント。
private struct VisitRow: View {

    let visit: Visit_

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(visit.cafe.name)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)

            starRating
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Private

    private var formattedDate: String {
        let d = visit.visitedOn
        return String(
            format: "%04d/%02d/%02d",
            Int(d.year),
            Int(d.monthNumber),
            Int(d.dayOfMonth)
        )
    }

    private var starRating: some View {
        StarRatingView(rating: Int(visit.rating), size: .caption2)
    }

    private var accessibilityDescription: String {
        "\(visit.cafe.name), \(formattedDate), \(Int(visit.rating))星"
    }
}

// MARK: - Preview (VisitRow 単体)

#Preview("VisitRow") {
    List {
        VisitRow(visit: PreviewSamples.sampleVisit)
        VisitRow(visit: PreviewSamples.sampleVisitWithoutPhotos)
        VisitRow(visit: PreviewSamples.sampleVisitMinimal)
    }
}

// MARK: - Preview (空状態)

#Preview("空状態") {
    NavigationStack {
        ContentUnavailableView(
            String(localized: "まだ訪問記録がありません"),
            systemImage: "cup.and.saucer",
            description: Text(
                String(localized: "マップまたは検索タブからカフェを選んで訪問記録を追加しましょう")
            )
        )
        .navigationTitle(String(localized: "訪問記録"))
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview (一覧 Demo)

#Preview("一覧 Demo") {
    NavigationStack {
        List {
            ForEach(PreviewSamples.sampleVisits) { visit in
                VisitRow(visit: visit)
            }
        }
        .listStyle(.plain)
        .navigationTitle(String(localized: "訪問記録"))
        .navigationBarTitleDisplayMode(.large)
    }
}
