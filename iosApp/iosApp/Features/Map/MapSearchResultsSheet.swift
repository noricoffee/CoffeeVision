import SwiftUI
import SharedLogic
import GoogleMobileAds

// MARK: - SearchSheetDetent

/// 検索結果 下部ドラッグシートの 2 detent（2026-07-22 マップ検索結果刷新）。
enum SearchSheetDetent {
    case peek
    case expanded
}

// MARK: - MapSearchResultsSheet

/// マップ主体 + 下部ドラッグシートで検索結果一覧を提示する（Apple/Google マップ風）。
///
/// - native `.sheet` は使わない（検索モード中は ✨ `TasteSearchSheet` が併存し得るため、
///   同一 View に 2 枚目の `.sheet` を出すと競合する。詳細は ui-ux-guidelines.md）
/// - 表示条件（`isShowingSearchResultsSheet`）の判定は呼び出し元（`MapTabView`）が持つ
/// - detent（peek / expanded）とドラッグ追従量は呼び出し元が `@State` として保持し、`Binding` で
///   受け取る。サイズ計算（`currentHeight` / `baseHeight` / `expandedHeight`）も呼び出し元が算出
///   したものを渡す（呼び出し元は現在地 FAB の下端インセット計算にも同じ高さを使うため。
///   この結合を壊さないよう、detent の状態オーナーはあえて本 View 側へ移していない）
/// - 2 detent を `DragGesture` + スナップで実装。ドラッグはハンドル行のみに付け、リスト本体の
///   `ScrollView` とジェスチャーが競合しないようにする
/// - インラインアダプティブバナー（`InlineBannerAdView`、3 件目の後）は既定の peek detent では
///   `LazyVStack` の fold 下に隠れて実体化されず、`.task` によるロードトリガーが発火しない
///   （2026-07-22 回帰で確認）。そのため `CafeDetailView.cafeDetailList` と同じパターンで、
///   常に実体化されるルート `VStack` 自身の `.background(GeometryReader)` から
///   `searchAdLoader.load(...)` を先読みトリガーする（`InlineBannerAdView` 側の `.task` は
///   そのまま残し、行が実体化された瞬間に `isLoaded` 済みなら即描画される）
struct MapSearchResultsSheet: View {

    /// peek detent の固定高さ。
    static let peekHeight: CGFloat = 180

    /// expanded detent の高さ比率（コンテナ高さに対して）。
    static let expandedFraction: CGFloat = 0.6

    /// 一覧・ピンに反映する表示用の検索結果（`MapSearchController.displayedResults`。
    /// エリア検索は表示範囲でフィルタ済み、テキスト検索は全件。2026-07-24）。
    let results: [Cafe]
    /// 検索実行中フラグ（`CafeSearchViewModelBridge.isLoading`）。
    let isLoading: Bool
    let searchAdLoader: BannerAdLoader

    /// ドラッグ追従を反映した実際の表示高さ（呼び出し元が算出済み）。
    let currentHeight: CGFloat
    /// 現在の detent に対応する基準高さ（ドラッグ追従前の値。呼び出し元が算出済み）。
    let baseHeight: CGFloat
    /// expanded detent の高さ（呼び出し元が算出済み）。
    let expandedHeight: CGFloat

    @Binding var detent: SearchSheetDetent
    @Binding var dragTranslation: CGFloat

    let onSelectCafe: (Cafe) -> Void

    var body: some View {
        VStack(spacing: 0) {
            handleBar(resultCount: results.count)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 24)
                    } else {
                        ForEach(Array(results.enumerated()), id: \.element.placeId) { index, cafe in
                            row(cafe: cafe, isLast: cafe.placeId == results.last?.placeId)
                            // 3 件目の後にインラインアダプティブバナー 1 枠（結果 3 件未満のときは
                            // 到達しないため非表示。requirements.md §11-2）。
                            if index == 2 {
                                InlineBannerAdView(loader: searchAdLoader, maxHeight: 100)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                if cafe.placeId != results.last?.placeId {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(height: currentHeight)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(
            // 結果 3 件以上になった時点で、広告スロットが fold 下でも先読みロードする
            // （`InlineBannerAdView` 自身の `.task` は `LazyVStack` の遅延実体化に依存するため、
            // peek detent では発火しない。ルート VStack は常に実体化されるため確実に発火する）。
            GeometryReader { proxy in
                Color.clear
                    .task(id: "\(Int(proxy.size.width))-\(results.count >= 3)") {
                        guard results.count >= 3 else { return }
                        let width = proxy.size.width - 32
                        // レイアウト測定の過渡状態（ゴミ幅・負値）でリクエストしない
                        // （`BannerAdLoader.minimumRequestableWidth` 参照。2026-07-14 実機診断で確認）。
                        guard width >= BannerAdLoader.minimumRequestableWidth else { return }
                        searchAdLoader.load(adSize: inlineAdaptiveBanner(width: width, maxHeight: 100))
                    }
            }
        )
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: -4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// 結果シートのドラッグハンドル行。
    ///
    /// - タップで peek ⇄ expanded をトグルする（ドラッグ操作が難しい VoiceOver 利用者向けの代替導線。
    ///   VoiceOver 有効時はダブルタップと `.accessibilityAction` の双方から toggle できる）
    /// - ドラッグは本行にのみ付け、下部 `ScrollView` の縦スクロールと競合させない
    /// - `Button` にはしない: タップ判定用の `.simultaneousGesture(DragGesture())` と実ドラッグが
    ///   競合しやすく、また `.local` 座標系のドラッグは本行自身がリサイズで上下に動くため高さが
    ///   自己発振する原因になっていた（2026-07-22 修正）。`onTapGesture` + `.gesture(DragGesture)`
    ///   （`minimumDistance` でタップ/ドラッグを分離）+ `.global` 座標系に置き換える。
    private func handleBar(resultCount: Int) -> some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Color.secondary)
                .frame(width: 36, height: 5)
            HStack {
                Text(String(localized: "\(resultCount)件"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                GoogleMapsAttributionText()
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "検索結果 \(resultCount)件"))
        .accessibilityHint(String(localized: "タップして一覧の表示サイズを切り替えます"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            withAnimation(.snappy) {
                detent = detent == .expanded ? .peek : .expanded
            }
        }
        .onTapGesture {
            withAnimation(.snappy) {
                detent = detent == .expanded ? .peek : .expanded
            }
        }
        .gesture(
            // `.global`: 本行は `.frame(height: currentHeight)` を持つシート上端に乗っており、
            // 高さが変わるたびに本行自身の Y 位置も動く。`.local`（デフォルト）の translation は
            // 「動く View 自身」を基準に測るため、指の画面上の位置が同じでもフレームごとに読み値が
            // ズレて `height = base - translation` が自己発振してしまう。`.global` は画面固定座標
            // なので View の移動に影響されず、発振しない。
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .onChanged { value in
                    // 範囲外へのドラッグで translation が無限に蓄積すると、指を戻す際に
                    // 「height 側のクランプに隠れて反応しない」デッドゾーンが生じる。
                    // height = base - translation を [peek, expanded] に収める translation の
                    // 範囲へあらかじめクランプしておく。
                    let minTranslation = baseHeight - expandedHeight
                    let maxTranslation = baseHeight - Self.peekHeight
                    dragTranslation = min(max(value.translation.height, minTranslation), maxTranslation)
                }
                .onEnded { value in
                    let predictedHeight = baseHeight - value.predictedEndTranslation.height
                    let midpoint = (Self.peekHeight + expandedHeight) / 2
                    withAnimation(.snappy) {
                        detent = predictedHeight > midpoint ? .expanded : .peek
                        dragTranslation = 0
                    }
                }
        )
    }

    /// 結果シート内の 1 行（カフェ名 + 住所）。タップで `onSelectCafe` を呼ぶ。
    @ViewBuilder
    private func row(cafe: Cafe, isLast: Bool) -> some View {
        Button {
            onSelectCafe(cafe)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cafe.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let address = cafe.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if !isLast {
            Divider().padding(.leading, 52)
        }
    }
}
