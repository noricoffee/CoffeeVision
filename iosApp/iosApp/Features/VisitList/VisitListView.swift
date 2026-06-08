import SwiftUI
import SharedLogic

// MARK: - Identifiable 拡張

extension Visit_: @retroactive Identifiable {}

// MARK: - VisitListView

/// 訪問記録一覧画面。
///
/// - `NavigationStack` でラップし、大タイトル「訪問記録」を表示する
/// - 空状態は `ContentUnavailableView`、リストは swipe-to-delete 付き `List` で表示する
/// - ツールバーの `+` ボタンで暫定ダミー Visit 書き込みを行う（VisitEditor 完成まで）
struct VisitListView: View {

    @State var viewModel: VisitListViewModelBridge
    var appState: AppState

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
                    // VisitDetail は未実装。準備中プレースホルダを表示
                    VisitDetailPlaceholderView(visitId: visit.id)
                } label: {
                    VisitRow(visit: visit)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
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
                Task { await appState.writeDummyVisit() }
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
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < Int(visit.rating) ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .accessibilityHidden(true) // 合成アクセシビリティラベルで代替
    }

    private var accessibilityDescription: String {
        "\(visit.cafe.name), \(formattedDate), \(Int(visit.rating))星"
    }
}

// MARK: - VisitDetailPlaceholderView

/// VisitDetail 画面が実装されるまでのプレースホルダ。
struct VisitDetailPlaceholderView: View {
    let visitId: String

    var body: some View {
        ContentUnavailableView(
            String(localized: "詳細画面は準備中です"),
            systemImage: "hammer.fill",
            description: Text(visitId)
                .font(.caption.monospaced())
        )
        .navigationTitle(String(localized: "詳細"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    Text(String(localized: "VisitListView preview placeholder"))
        .padding()
}
