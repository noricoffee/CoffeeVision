import SwiftUI
import SharedLogic

// MARK: - CoffeeListView

/// コーヒー記録一覧画面。
///
/// - RootTabView の NavigationStack 内に配置されるため、自身では NavigationStack を持たない
/// - bottom-trailing 固定の FAB（`addCoffeeFAB`）から `CoffeeEditorView(mode: .Create)` を sheet 表示する
/// - 既存記録の詳細は NavigationLink で CoffeeDetailView に push する
struct CoffeeListView: View {

    @State var viewModel: CoffeeListViewModelBridge
    var appState: AppState

    /// FAB タップで開くエディタの表示状態。
    @State private var isPresentingEditor = false

    var body: some View {
        content
            .navigationTitle(String(localized: "コーヒー記録"))
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: Binding(
                    get: { viewModel.searchQuery },
                    set: { viewModel.searchQuery = $0 }
                ),
                prompt: String(localized: "コーヒー名・カフェ名・メモで検索")
            )
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
            .sheet(isPresented: $isPresentingEditor) {
                CoffeeEditorView(
                    mode: CoffeeEditorViewModelModeCreate.shared,
                    appState: appState,
                    initialCafe: nil
                )
            }
            // 追加 FAB: bottom-trailing 固定配置。検索中も表示したままにする（新規記録は検索状態と無関係）
            .overlay(alignment: .bottomTrailing) {
                addCoffeeFAB
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }
    }

    // MARK: - 追加 FAB

    /// bottom-trailing 固定の「コーヒーを記録」FAB。
    private var addCoffeeFAB: some View {
        Button {
            isPresentingEditor = true
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .accessibilityLabel(String(localized: "コーヒーを記録"))
    }

    // MARK: - コンテンツ

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
        } else if viewModel.sections.isEmpty && viewModel.searchQuery.isEmpty {
            emptyView
        } else if viewModel.sections.isEmpty {
            // 検索クエリはあるがヒット 0 件
            ContentUnavailableView.search(text: viewModel.searchQuery)
        } else {
            coffeeList
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            String(localized: "まだコーヒー記録がありません"),
            systemImage: "cup.and.saucer",
            description: Text(
                String(localized: "右下の + ボタンか、マップのカフェ検索からカフェを選んで記録しましょう")
            )
        )
    }

    private var coffeeList: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.records) { coffee in
                        NavigationLink {
                            CoffeeDetailView(coffeeId: coffee.id, appState: appState)
                        } label: {
                            CoffeeRow(coffee: coffee)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.onCoffeeDeleted(
                                    id: coffee.id,
                                    photoFileNames: coffee.photos.compactMap(\.fileName)
                                )
                            } label: {
                                Label(
                                    String(localized: "削除"),
                                    systemImage: "trash"
                                )
                            }
                        }
                    }
                } header: {
                    Text(Self.monthHeaderText(yearMonth: section.yearMonth))
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - 月ヘッダ文字列の生成

    /// `"YYYY-MM"`（ゼロパディング）を `"YYYY年M月"`（月はゼロ埋めしない）へ変換する。
    ///
    /// 想定外のフォーマットが来た場合はそのまま `yearMonth` を返す（フォールバック）。
    static func monthHeaderText(yearMonth: String) -> String {
        let parts = yearMonth.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]) else {
            return yearMonth
        }
        return String(localized: "\(parts[0])年\(month)月")
    }
}

// MARK: - CoffeeRow

/// コーヒー記録一覧の行コンポーネント。
struct CoffeeRow: View {

    let coffee: CoffeeRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(coffee.cafe?.name ?? String(localized: "セルフ抽出"))
                .font(.headline)
                .foregroundStyle(.primary)

            Text(coffee.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
        let d = coffee.visitedOn
        return String(
            format: "%04d/%02d/%02d",
            Int(d.year),
            Int(d.monthNumber),
            Int(d.dayOfMonth)
        )
    }

    private var starRating: some View {
        StarRatingView(rating: coffee.rating, size: .caption2)
    }

    private var accessibilityDescription: String {
        let cafeName = coffee.cafe?.name ?? String(localized: "セルフ抽出")
        let ratingStr = coffee.rating.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(coffee.rating))星"
            : "\(coffee.rating)星"
        return "\(cafeName), \(coffee.name), \(formattedDate), \(ratingStr)"
    }
}

// MARK: - Preview (CoffeeRow 単体)

#Preview("CoffeeRow") {
    List {
        CoffeeRow(coffee: PreviewSamples.sampleCoffeeRecord)
        CoffeeRow(coffee: PreviewSamples.sampleCoffeeRecordSelfBrew)
    }
}

// MARK: - Preview (空状態)

#Preview("空状態") {
    NavigationStack {
        ContentUnavailableView(
            String(localized: "まだコーヒー記録がありません"),
            systemImage: "cup.and.saucer",
            description: Text(
                String(localized: "右下の + ボタンか、マップのカフェ検索からカフェを選んで記録しましょう")
            )
        )
        .navigationTitle(String(localized: "コーヒー記録"))
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview (一覧 Demo)

#Preview("一覧 Demo") {
    NavigationStack {
        List {
            ForEach(PreviewSamples.sampleCoffeeRecords) { coffee in
                CoffeeRow(coffee: coffee)
            }
        }
        .listStyle(.plain)
        .navigationTitle(String(localized: "コーヒー記録"))
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview (月別セクション Demo)

#Preview("月別セクション Demo") {
    let sections: [CoffeeListViewModel.MonthSection] = [
        CoffeeListViewModel.MonthSection(
            yearMonth: "2026-06",
            records: [PreviewSamples.sampleCoffeeRecord, PreviewSamples.sampleCoffeeRecordSelfBrew]
        ),
        CoffeeListViewModel.MonthSection(
            yearMonth: "2026-05",
            records: [PreviewSamples.sampleCoffeeRecordWithoutPhotos]
        ),
    ]
    NavigationStack {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.records) { coffee in
                        CoffeeRow(coffee: coffee)
                    }
                } header: {
                    Text(CoffeeListView.monthHeaderText(yearMonth: section.yearMonth))
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(String(localized: "コーヒー記録"))
        .navigationBarTitleDisplayMode(.large)
    }
}
