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
            // 追加 FAB: bottom-trailing 固定配置
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
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.regularMaterial))
        }
        .accessibilityLabel(String(localized: "コーヒーを記録"))
    }

    // MARK: - コンテンツ

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
        } else if viewModel.coffees.isEmpty {
            emptyView
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
            ForEach(viewModel.coffees) { coffee in
                NavigationLink {
                    CoffeeDetailView(coffeeId: coffee.id, appState: appState)
                } label: {
                    CoffeeRow(coffee: coffee)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        // CoffeeRecord 削除前に紐付く写真ファイルを Documents から物理削除する
                        for photo in coffee.photos {
                            if let fileName = photo.fileName {
                                try? PhotoFileStore.delete(fileName: fileName)
                            }
                        }
                        viewModel.onCoffeeDeleted(id: coffee.id)
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
