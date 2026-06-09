import SwiftUI
import SharedLogic

// MARK: - Identifiable 拡張

extension Visit_: @retroactive Identifiable {}

// MARK: - VisitListView

/// 訪問記録一覧画面。
///
/// - `NavigationStack` でラップし、大タイトル「訪問記録」を表示する
/// - 空状態は `ContentUnavailableView`、リストは swipe-to-delete 付き `List` で表示する
/// - ツールバーの `+` ボタンで VisitEditorView（新規作成モード）を sheet で開く
struct VisitListView: View {

    @State var viewModel: VisitListViewModelBridge
    var appState: AppState

    @State private var isPresentingEditor = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "訪問記録"))
                .navigationBarTitleDisplayMode(.large)
                .toolbar { toolbarContent }
                .task {
                    guard let uid = appState.uid else { return }
                    viewModel.onAppear(userId: uid)
                }
                .onDisappear {
                    viewModel.onDisappear()
                }
                .alert(
                    String(localized: "エラー"),
                    isPresented: Binding(
                        get: { viewModel.error != nil },
                        set: { if !$0 { viewModel.onErrorDismissed() } }
                    )
                ) {
                    Button(String(localized: "OK")) {
                        viewModel.onErrorDismissed()
                    }
                } message: {
                    Text(viewModel.error ?? "")
                }
                .sheet(isPresented: $isPresentingEditor) {
                    VisitEditorView(
                        mode: VisitEditorViewModelModeCreate.shared,
                        appState: appState
                    )
                }
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
            description: Text(String(localized: "右上の + ボタンで訪問記録を追加してみましょう"))
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

    // MARK: - ツールバー

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                isPresentingEditor = true
            } label: {
                Label(
                    String(localized: "訪問記録を追加"),
                    systemImage: "plus"
                )
                .labelStyle(.iconOnly)
            }
            .accessibilityLabel(String(localized: "訪問記録を追加"))
            .disabled(appState.uid == nil)
        }
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

// MARK: - Preview

#Preview {
    Text(String(localized: "VisitListView preview placeholder"))
        .padding()
}
