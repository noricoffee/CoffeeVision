import Foundation
import CoreLocation
import MapKit
import Observation
import SharedLogic

/// マップタブの検索 / エリア検索のデータ state とビジネスロジックを保持する `@Observable` コントローラ。
///
/// - `MapTabView` の SwiftUI 固有要素（`@FocusState` / `MapCameraPosition`）には依存しない。
///   カメラ移動と検索欄フォーカス解除は `onRequestCamera` / `onDismissKeyboard` のコールバック注入で
///   View 側へ委譲する（M-3 分割リファクタ）。
/// - 検索結果下部ドラッグシートの detent / サイズ計算は現在地 FAB のインセット計算と二重消費される
///   ため `MapTabView` 側に残置している（M-1 の申し送り。`docs/implementation_note.md` 2026-07-24 参照）。
@MainActor
@Observable
final class MapSearchController {

    // MARK: - コールバック（SwiftUI 固有要素との分離のための注入）

    /// カメラを指定 region へ移動させる（View 側で `withAnimation { cameraPosition = .region(...) }` する）。
    private var onRequestCamera: (MKCoordinateRegion) -> Void

    /// 検索欄のフォーカスを解除する（View 側で `@FocusState` を false にする）。
    private var onDismissKeyboard: () -> Void

    // MARK: - 検索 State

    /// 検索バーのテキスト入力。
    var query: String = ""

    /// マップ上部検索バー用の CafeSearch ブリッジ。`setup(makeViewModel:)` で 1 度だけ生成する。
    private(set) var searchBridge: CafeSearchViewModelBridge?

    /// 検索結果ドロップダウン（下部ドラッグシート）の表示フラグ。
    var showingResults: Bool = false

    /// 検索結果から選択されたカフェ（下部カード表示用）。nil = カード非表示。
    var selectedCafe: Cafe?

    /// 選択中の検索結果ピンの placeId（マップ上でのハイライト表示用）。nil = ハイライトなし。
    var highlightedPlaceId: String?

    // MARK: - 「このエリアを検索」関連 State

    /// 最後にエリア検索（またはカメラ初期化）した際のマップ中心。
    ///
    /// - `nil`: まだエリア検索・初期カメラ確定が行われていない（ボタン非表示）
    /// - 非 `nil`: 「このエリアを検索」ボタンの出現判定の基準点
    var lastAreaSearchCenter: MapSearchCenter?

    /// 「このエリアを検索」ボタンの表示フラグ。
    var showAreaSearchButton: Bool = false

    /// 「このエリアを検索」の検索実行中フラグ（ボタンのローディング表示用）。
    var isAreaSearchInFlight: Bool = false

    /// エリア検索が 0 件だったときの軽量案内メッセージ。`errorToast` 経由で表示する。
    var areaSearchEmptyMessage: String?

    /// 一覧・ピンの表示に使う結果（`sb.results` を表示用に加工したもの。単一ソース）。
    ///
    /// テキスト検索は `sb.results` をそのまま反映する。エリア検索は `areaSearchRegion`
    /// （検索実行時にスナップした表示範囲矩形）で絞り込んだ結果を反映する
    /// （Places の `locationBias` は範囲制限ではなく近傍ヒントに過ぎず、範囲外の同名店が
    /// 混ざりうるため。2026-07-24 ユーザー報告対応）。
    private(set) var displayedResults: [Cafe] = []

    /// 直近のエリア検索実行時にスナップした表示範囲矩形（`displayedResults` の絞り込み基準）。
    private var areaSearchRegion: MKCoordinateRegion?

    // MARK: - Init

    init(
        onRequestCamera: @escaping (MKCoordinateRegion) -> Void,
        onDismissKeyboard: @escaping () -> Void
    ) {
        self.onRequestCamera = onRequestCamera
        self.onDismissKeyboard = onDismissKeyboard
    }

    /// 検索ブリッジを 1 度だけ生成する。`MapTabView` の `.task` から呼ぶ。
    func setup(makeViewModel: () -> CafeSearchViewModel) {
        guard searchBridge == nil else { return }
        searchBridge = CafeSearchViewModelBridge(kotlin: makeViewModel())
    }

    /// `.task` で View 生成後にカメラ / キーボードのコールバックを差し替える。
    ///
    /// `@State` で保持するクラスの初期値式は `self`（`cameraPosition` 等）を参照できないため、
    /// `setup(makeViewModel:)` と同じ「初回 `.task` で 1 度だけ配線する」タイミングに合わせている。
    func configureCallbacks(
        onRequestCamera: @escaping (MKCoordinateRegion) -> Void,
        onDismissKeyboard: @escaping () -> Void
    ) {
        self.onRequestCamera = onRequestCamera
        self.onDismissKeyboard = onDismissKeyboard
    }

    // MARK: - 検索アクション

    /// 検索バーの送信時に呼ばれる。位置バイアスがあれば付与する。
    ///
    /// 結果の全件ピン反映は `MapTabView` の `.onChange(of: searchController.searchBridge?.isLoading)`
    /// （→ `handleCompletion`）が検索完了を検知して行う。ここでは「このエリアを検索」ボタンを
    /// テキスト検索直後は出さないよう非表示にするのみ。
    func performSearch(center: MapSearchCenter?) {
        guard let sb = searchBridge, !query.isEmpty else { return }
        sb.onQueryChanged(query)
        if let center {
            sb.onSearchTapped(
                latitude: center.latitude,
                longitude: center.longitude,
                radiusMeters: center.radiusMeters
            )
        } else {
            sb.onSearchTapped()
        }
        showingResults = true
        showAreaSearchButton = false
    }

    /// 検索選択状態をクリアし、マップオーバーレイもリセットする。フォーカスも解除しブラウズモードへ戻す。
    func clearSelection(mapBridge: MapViewModelBridge?) {
        selectedCafe = nil
        highlightedPlaceId = nil
        showingResults = false
        onDismissKeyboard()
        mapBridge?.onSearchResultsCleared()
    }

    /// 検索結果（一覧行またはピン）からカフェを選択する。
    ///
    /// ピン集合（全検索結果）はそのまま維持し、下部カードの表示とマップ中心移動のみ行う
    /// （ピン集合と選択状態の関心を分離するため、ここでは `onSearchResultsUpdated` を呼ばない）。
    /// 結果一覧シートを退避し（`showingResults = false`）、選択ピンをハイライトする。
    func selectResult(_ cafe: Cafe) {
        selectedCafe = cafe
        highlightedPlaceId = cafe.placeId
        showingResults = false
        onDismissKeyboard()
        guard let lat = cafe.latitude?.doubleValue,
              let lng = cafe.longitude?.doubleValue else { return }
        onRequestCamera(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                latitudinalMeters: 800,
                longitudinalMeters: 800
            )
        )
    }

    /// 検索完了（`searchBridge.isLoading` が false に変わった時）の共通ハンドラ。
    ///
    /// テキスト検索・「このエリアを検索」の両方の完了を検知し、成功時は結果を全件ピンとして
    /// `mapBridge` に反映する。「このエリアを検索」由来の完了時はさらにアンカーを更新して
    /// ボタンを隠し、0 件だった場合は軽量な案内メッセージを出す
    /// （「このエリアを検索」はキーワードがあれば `searchText` 相当を実行するが、`isAreaSearchInFlight`
    /// による `wasAreaSearch` 判定はキーワード有無に関わらず「エリア検索由来」として扱う。2026-07-24）。
    /// テキスト検索（検索バー送信）由来の完了時は、結果が画面外に落ちないよう全結果ピンへカメラを
    /// 自動フィットする（「このエリアを検索」は表示範囲内検索で結果が構造的に画面内のため対象外。2026-07-22）。
    func handleCompletion(mapBridge: MapViewModelBridge, currentCenter: MapSearchCenter?) {
        guard let sb = searchBridge else { return }
        let wasAreaSearch = isAreaSearchInFlight
        isAreaSearchInFlight = false

        // hasSearched が false（未検索）、または直近の呼び出しが失敗（error 設定済み）の場合は
        // ピン反映しない。失敗時はボタンを隠さず再試行できる状態のまま残す。
        guard sb.hasSearched, sb.error == nil else { return }

        // エリア検索は表示範囲外の結果（Places の locationBias は範囲制限ではないため混入しうる）
        // を除外する。テキスト検索は全件をそのまま反映する。
        displayedResults = wasAreaSearch ? filterResultsWithinAreaSearchRegion(sb.results) : sb.results
        mapBridge.onSearchResultsUpdated(displayedResults)

        if wasAreaSearch {
            if let currentCenter {
                lastAreaSearchCenter = currentCenter
            }
            showAreaSearchButton = false
            if displayedResults.isEmpty {
                areaSearchEmptyMessage = String(localized: "このエリアにカフェが見つかりませんでした")
            }
        } else {
            fitCameraToSearchResults(sb.results)
        }
    }

    /// `areaSearchRegion`（エリア検索実行時にスナップした表示範囲矩形）で結果を絞り込む。
    ///
    /// 座標が取れない結果は範囲外扱いで除外する。矩形が未確定（想定外経路。ボタン表示前に
    /// `onMapCameraChange` が一度も発火していない等）の場合は絞り込まず全件を返す
    /// （誤って全件非表示になるより安全側に倒す）。
    private func filterResultsWithinAreaSearchRegion(_ results: [Cafe]) -> [Cafe] {
        guard let region = areaSearchRegion else { return results }
        let latHalf = region.span.latitudeDelta / 2
        let lngHalf = region.span.longitudeDelta / 2
        let latRange = (region.center.latitude - latHalf)...(region.center.latitude + latHalf)
        let lngRange = (region.center.longitude - lngHalf)...(region.center.longitude + lngHalf)
        return results.filter { cafe in
            guard let lat = cafe.latitude?.doubleValue, let lng = cafe.longitude?.doubleValue else {
                return false
            }
            return latRange.contains(lat) && lngRange.contains(lng)
        }
    }

    /// テキスト検索完了時、全結果ピンの bounding box に収まるようカメラをフィットする。
    ///
    /// 結果 1 件のときは `selectResult` と同じ 800m ズームにフォールバックする。
    /// 座標が取れない結果のみの場合は何もしない（現在のカメラ位置を維持）。
    private func fitCameraToSearchResults(_ results: [Cafe]) {
        let coordinates: [CLLocationCoordinate2D] = results.compactMap { cafe in
            guard let lat = cafe.latitude?.doubleValue, let lng = cafe.longitude?.doubleValue else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        guard !coordinates.isEmpty else { return }

        if coordinates.count == 1 {
            onRequestCamera(
                MKCoordinateRegion(
                    center: coordinates[0],
                    latitudinalMeters: 800,
                    longitudinalMeters: 800
                )
            )
            return
        }

        let lats = coordinates.map { $0.latitude }
        let lngs = coordinates.map { $0.longitude }
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLng = lngs.min()!
        let maxLng = lngs.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        // 1.3 倍（片側 15% 相当）は setInitialCameraFromVisitedCafes と同じ padding 係数。
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
            longitudeDelta: max((maxLng - minLng) * 1.3, 0.01)
        )
        onRequestCamera(MKCoordinateRegion(center: center, span: span))
    }

    // MARK: - このエリアを検索

    /// 表示中のマップ範囲でカフェを検索する。「このエリアを検索」ボタンから呼ぶ。
    ///
    /// 検索バーにキーワードが入力されていれば、そのキーワード + 表示範囲の位置バイアスで
    /// `searchText` 相当（`performSearch` と同じ `onQueryChanged` → `onSearchTapped(center:)` の順序）を
    /// 実行する。キーワードが空（空白のみ含む）なら従来どおりキーワード非依存の周辺一括検索
    /// （`onNearbySearchRequested`）にフォールバックする。
    ///
    /// - Parameter visibleRegion: 検索実行時点の地図可視領域（`MapTabView` の
    ///   `.onMapCameraChange` で得た最新 region）。`handleCompletion` での結果フィルタ基準として
    ///   スナップする（検索実行中にユーザーが地図を動かしても、押した瞬間の範囲を基準にする）。
    func performAreaSearch(center: MapSearchCenter?, visibleRegion: MKCoordinateRegion?) {
        guard let sb = searchBridge,
              let center,
              !isAreaSearchInFlight else { return }
        isAreaSearchInFlight = true
        areaSearchRegion = visibleRegion
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        if !trimmedQuery.isEmpty {
            // performSearch と同じ順序: onSearchTapped(center:) は shared 側の直近 query を使うため、
            // 先に onQueryChanged で最新化してから呼ぶ（未確定入力のまま地図移動されたケースへの対応）。
            sb.onQueryChanged(query)
            sb.onSearchTapped(
                latitude: center.latitude,
                longitude: center.longitude,
                radiusMeters: center.radiusMeters
            )
        } else {
            sb.onNearbySearchRequested(
                latitude: center.latitude,
                longitude: center.longitude,
                radiusMeters: center.radiusMeters
            )
        }
    }

    /// 現在のマップ中心が前回エリア検索アンカーから閾値以上動いたかを判定する。
    ///
    /// - 中心移動距離がアンカー半径の 30% を超える、または
    /// - 半径比（ズーム変化）が 1.5 倍以上乖離する
    /// のいずれかで `true` を返す（Google Maps 的な「この範囲を再検索」導線の一般的な目安）。
    func shouldShowAreaSearchButton(current: MapSearchCenter, anchor: MapSearchCenter) -> Bool {
        let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
        let anchorLocation = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
        let movedDistance = currentLocation.distance(from: anchorLocation)
        let centerMoved = movedDistance > anchor.radiusMeters * 0.3

        let radiusRatio = current.radiusMeters / anchor.radiusMeters
        let zoomChanged = radiusRatio > 1.5 || radiusRatio < (1.0 / 1.5)

        return centerMoved || zoomChanged
    }
}
