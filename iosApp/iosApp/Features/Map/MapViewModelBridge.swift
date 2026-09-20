import CoreLocation
import Foundation
import Observation
import SharedLogic

/// 既存ピン（訪問済み / 保存済み / 検索結果 / おすすめ）の座標。
///
/// `CLLocationCoordinate2D` は `Equatable` 非準拠で `.onChange(of:)` に渡せないため、
/// 比較可能な最小構造体として持つ（`AppleNearbyCafeLoader` への受け渡し用）。
struct MapPinCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

/// `MapViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - 観測は `observe()`（構造化 `Task`。`MapTabView` の `.task` から呼ぶ）が担う。
///   ブリッジ自身は `Task` を保持しない（B-11）
/// - マップタブは TabBar 常時生存のため `AppState` で 1 つだけ保持する
/// - ピン競合解決後の派生コレクション（`displayedSavedCafes` 等）もここで持つ。
///   計算タイミングと `body` からの追い出しの理由は「派生ピン集合」節の doc コメント参照（SL-4）
@MainActor
@Observable
final class MapViewModelBridge {

    private let kotlin: MapViewModel

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var visitedCafes: [VisitedCafe] = []
    /// 好み一致カフェ（マップ強調ピン用）。FavoriteSignals 不足時は空。
    private(set) var recommendedCafes: [RecommendedCafe] = []
    /// 好み一致カフェの placeId 集合（ピン強調判定を O(1) にする）。
    private(set) var recommendedPlaceIds: Set<String> = []
    private(set) var showVisited: Bool = true
    /// 検索タブからのオーバーレイ表示用。空 = 表示なし。
    private(set) var searchResultPlaces: [Cafe] = []
    private(set) var error: String?
    /// 選択中のタグフィルター。
    private(set) var selectedTags: [String] = []
    /// 利用可能なタグの distinct ソート済みリスト。
    private(set) var availableTags: [String] = []
    /// 「行きたい店」（savedAt 降順。フェーズ 15-A）。マップピン / 一覧シート用。
    private(set) var savedCafes: [SavedCafe] = []
    /// 記録済み（コーヒー記録が 1 件以上ある）カフェの placeId 集合。一覧シートの「記録あり」バッジ用。
    private(set) var recordedPlaceIds: Set<String> = []
    /// 都道府県別おすすめカフェ（マップ常時強調ピン用。フェーズ 19）。init 時に一括ロード、失敗時は空のまま。
    private(set) var curatedCafes: [CuratedCafe] = []
    /// おすすめカフェの placeId 集合（既存ピンとの重複除外 / 一覧判定を O(1) にする）。
    private(set) var curatedPlaceIds: Set<String> = []

    // MARK: - POI ルックアップ状態

    private(set) var isLookingUpPoi: Bool = false
    private(set) var poiLookupResult: Cafe? = nil
    /// POI ルックアップで発生したエラー。`message` は表示用文言、`isNotFound` で
    /// 「該当なし（ネガティブキャッシュ対象）」と「通信エラー等（キャッシュ対象外）」を区別する。
    private(set) var poiLookupError: MapViewModel.PoiLookupError? = nil

    // MARK: - 派生ピン集合（ピン競合解決。SL-4 で `MapTabView` の body から移設）
    //
    // いずれも `MapTabView` の body で毎回計算していたもの。SwiftUI の `body` は
    // 「読んでいる @Observable プロパティのどれか 1 つが変わるたび」に丸ごと再評価されるため、
    // 無関係な state 変化（`isLookingUpPoi` の切り替え等）でも Set 構築 / `CLLocation` 生成 /
    // 測地距離計算（curated は最大 421 件）が走っていた。
    //
    // 入力が実際に変わったときだけ再計算する:
    //   - Kotlin state 由来の入力（visited / saved / searchResults / curated）→ `apply(_:)`
    //   - カメラ由来の入力（`AppState.mapSearchCenter`）→ `updateMapSearchCenter(_:)`
    //     （`MapTabView` の `.onMapCameraChange` から、既存の `isEquivalent` 同値ガードの中で呼ぶ）
    //
    // body からカメラ状態を読む依存は増やさない（2026-08-09 のウォッチドッグ障害は
    // 「カメラ → ピン表示数 → カメラ」の循環が原因。lessons 2026-08-09）。

    /// 表示対象の行きたい店（訪問済みと競合するものを除外。優先順位: 訪問済み > 行きたい）。
    private(set) var displayedSavedCafes: [SavedCafe] = []

    /// 表示対象の検索結果ピン（訪問済み / 行きたいと競合するものを除外。
    /// 優先順位: 訪問済み > 行きたい > 検索結果）。
    private(set) var displayedSearchResultPlaces: [Cafe] = []

    /// 表示対象のおすすめカフェ（curated）。
    ///
    /// 訪問済み / 行きたい / 検索結果と競合するものを除外する（優先順位: 訪問済み > 行きたい >
    /// 検索結果 > おすすめ（curated）。表示切替チップの状態に関わらず適用する）。
    ///
    /// ズームゲート: Apple 周辺ピン（`AppleNearbyCafeLoader.schedule`）と同じしきい値
    /// `AppleNearbyCafeLoader.zoomGateRadiusMeters`（可視半径 3000m）を再利用し、
    /// 直近のカメラ中心がしきい値を超える（ズームアウトしている）場合は空にして非表示にする
    /// （東京全域規模の引きの地図で常時表示になり煩雑という確認フィードバックへの対応）。
    ///
    /// 可視範囲フィルタ（2026-08-09 追加、MU-1）: ズームゲートを通ると `curatedCafes` 全件
    /// （実データ 421 件）が `Annotation` に載り、**画面外のピンまで SwiftUI の View として
    /// 構築されていた**（実測で 1 回の body 評価あたり curated ピン 210 個）。カメラ中心からの
    /// 距離で可視範囲外を落とす。
    ///
    /// **基準に地図の可視領域の矩形（`MapTabView.latestVisibleRegion`）を使ってはいけない。**
    /// 矩形の方が正確だが、`latestVisibleRegion` は `onMapCameraChange` で**無条件代入**されている
    /// `@State` で、同値ガードが無い（`MKCoordinateRegion` は `Equatable` 非準拠で書きにくい）。
    /// ここで読むと「カメラが微動するたびに curated ピンを作り直す」経路が生まれる。
    /// `MapSearchCenter` は `isEquivalent`（1m 許容）の同値ガードを通った値だけが届く。
    ///
    /// 矩形と半径のズレ（横長の地図で角が漏れる）は、`radiusMeters` が `max(latMeters, lngMeters)`
    /// = 可視領域の外接半径相当であるため**半径側が広く出る**方向であり、実用上は可視領域を包含する。
    private(set) var displayedCuratedCafes: [CuratedCafe] = []

    /// 既存ピンの座標一覧（訪問済み / 保存済み / 検索結果 / おすすめ（curated）。表示トグルの
    /// 状態に関わらず全件）。Apple 周辺ピンの重複排除（`AppleNearbyCafeLoader`）に使う。
    private(set) var existingPinCoordinates: [MapPinCoordinate] = []

    /// おすすめカフェ（curated）ピンの可視範囲マージン（`MapSearchCenter.radiusMeters` に対する倍率）。
    ///
    /// パン時にピンが画面端で遅れて出るのを避けるための先読み分。`shouldShowAreaSearchButton` が
    /// 「中心移動 > 半径 × 0.3」で「このエリアを検索」を出す設計より手前で先読みが効く値にしている。
    private static let curatedVisibilityMargin: Double = 1.3

    /// curated ピンのズームゲート / 可視範囲フィルタの基準になる直近のカメラ中心。
    /// UI が直接読む値ではないため観測対象から外す。
    @ObservationIgnored private var mapSearchCenter: MapSearchCenter?

    // MARK: - Init

    init(viewModel: MapViewModel) {
        self.kotlin = viewModel
    }

    isolated deinit {
        kotlin.clear()
    }

    // MARK: - ライフサイクル

    /// state 購読を開始する。`MapTabView` の `.task` から呼ぶ（構造化 `Task`）。
    func observe() async {
        for await state in kotlin.state {
            apply(state)
        }
    }

    // MARK: - ユーザーアクション

    /// 訪問済みカフェのピン表示 / 非表示を切り替える。
    func onShowVisitedToggled(_ show: Bool) {
        kotlin.onShowVisitedToggled(show: show)
    }

    /// エラーアラートを閉じたときに呼ぶ。
    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    // MARK: - POI ルックアップアクション

    /// Apple Maps の標準 POI がタップされたときに呼ぶ。
    /// Places API で名前 + 位置バイアスによる照合を開始する。
    func onPoiTapped(name: String, latitude: Double, longitude: Double) {
        kotlin.onPoiTapped(name: name, latitude: latitude, longitude: longitude)
    }

    /// POI ルックアップ結果を画面遷移（push）で消費したあとに呼ぶ。
    /// `poiLookupResult` を nil にリセットして次のタップを受け入れる状態に戻す。
    func onPoiLookupConsumed() {
        kotlin.onPoiLookupConsumed()
    }

    /// POI ルックアップエラーアラートを閉じたときに呼ぶ。
    func onPoiLookupErrorDismissed() {
        kotlin.onPoiLookupErrorDismissed()
    }

    /// 検索タブから検索結果カフェを受け取り、マップオーバーレイに反映する。
    func onSearchResultsUpdated(_ cafes: [Cafe]) {
        kotlin.onSearchResultsUpdated(cafes: cafes)
    }

    /// 検索タブの結果クリア時にマップオーバーレイをリセットする。
    func onSearchResultsCleared() {
        kotlin.onSearchResultsCleared()
    }

    // MARK: - タグフィルターアクション

    /// タグフィルターのオン / オフを切り替える。
    func onTagFilterToggled(_ tag: String) {
        kotlin.onTagFilterToggled(tag: tag)
    }

    /// タグフィルターをすべてクリアする。
    func onTagFilterCleared() {
        kotlin.onTagFilterCleared()
    }

    // MARK: - 「行きたい店」アクション（フェーズ 15-A）

    /// 一覧シートでのスワイプ解除操作を受ける。
    func onSavedCafeRemoved(placeId: String) {
        kotlin.onSavedCafeRemoved(placeId: placeId)
    }

    /// マップ下部カードの保存トグルボタンから呼ぶ（フェーズ 16）。
    /// 保存済みなら解除、未保存なら保存する（Kotlin 側で判定）。
    func onCafeSaveToggled(cafe: Cafe) {
        kotlin.onCafeSaveToggled(cafe: cafe)
    }

    // MARK: - カメラ連動（`MapTabView` の `.onMapCameraChange` から呼ぶ）

    /// 直近のカメラ中心を受け取り、curated ピンのズームゲート / 可視範囲フィルタを更新する。
    ///
    /// 同値判定（1m 許容の `MapSearchCenter.isEquivalent`）はここで持つ。呼び出し側
    /// （`AppState.mapSearchCenter` への代入）のガードに相乗りしないのは、サインアウト →
    /// 再ブートストラップでブリッジだけが作り直されたときに `AppState` 側の値が残り、
    /// 「同値だから渡されない」でカメラ中心を受け取れなくなるため。
    /// カメラに依存しない派生集合（saved / search / 座標一覧）はここでは再計算しない。
    func updateMapSearchCenter(_ center: MapSearchCenter) {
        if let current = mapSearchCenter, current.isEquivalent(to: center) { return }
        mapSearchCenter = center
        recomputeDisplayedCuratedCafes()
    }

    // MARK: - Private

    private func apply(_ state: MapViewModel.UIState) {
        // `@Observable` は値を比較せず、代入するだけで observer に変更を通知する
        // （`ObservationRegistrar.withMutation` は旧値と新値を比較しない）。Kotlin の
        // StateFlow は 1 フィールドだけ変わった state も丸ごと emit するため、無条件代入だと
        // 無関係な body まで再評価される。同値ガードで実際に変わった分だけ通知する（SL-3）。
        //
        // Kotlin の `data class` は Obj-C 側で `isEqual:` を `equals()` から生成しており
        // （`SharedLogic.h` で確認）、Foundation の `extension NSObject: Equatable` 経由で
        // Swift の `==` がそのまま値比較になる。

        // ピン競合解決の入力が変わったかどうか。変わったときだけ派生集合を作り直す。
        var pinInputsChanged = false

        if visitedCafes != state.visitedCafes {
            visitedCafes = state.visitedCafes
            pinInputsChanged = true
        }
        if savedCafes != state.savedCafes {
            savedCafes = state.savedCafes
            pinInputsChanged = true
        }
        if searchResultPlaces != state.searchResultPlaces {
            searchResultPlaces = state.searchResultPlaces
            pinInputsChanged = true
        }
        if curatedCafes != state.curatedCafes {
            curatedCafes = state.curatedCafes
            pinInputsChanged = true
        }

        if recommendedCafes != state.recommendedCafes {
            recommendedCafes = state.recommendedCafes
        }
        if recommendedPlaceIds != state.recommendedPlaceIds {
            recommendedPlaceIds = state.recommendedPlaceIds
        }
        if showVisited != state.showVisited {
            showVisited = state.showVisited
        }
        if error != state.error {
            error = state.error
        }
        if isLookingUpPoi != state.isLookingUpPoi {
            isLookingUpPoi = state.isLookingUpPoi
        }
        if poiLookupResult != state.poiLookupResult {
            poiLookupResult = state.poiLookupResult
        }
        if poiLookupError != state.poiLookupError {
            poiLookupError = state.poiLookupError
        }
        let newSelectedTags = Array(state.selectedTags)
        if selectedTags != newSelectedTags {
            selectedTags = newSelectedTags
        }
        if availableTags != state.availableTags {
            availableTags = state.availableTags
        }
        if recordedPlaceIds != state.recordedPlaceIds {
            recordedPlaceIds = state.recordedPlaceIds
        }
        if curatedPlaceIds != state.curatedPlaceIds {
            curatedPlaceIds = state.curatedPlaceIds
        }

        if pinInputsChanged {
            recomputeDerivedPinSets()
        }
    }

    /// Kotlin state 由来の入力が変わったときに派生ピン集合をすべて作り直す。
    private func recomputeDerivedPinSets() {
        let visited = Set(visitedCafes.map { $0.cafe.placeId })
        let saved = Set(savedCafes.map { $0.cafe.placeId })

        let newSavedCafes = savedCafes.filter { !visited.contains($0.cafe.placeId) }
        if displayedSavedCafes != newSavedCafes {
            displayedSavedCafes = newSavedCafes
        }

        let newSearchResults = searchResultPlaces.filter {
            !visited.contains($0.placeId) && !saved.contains($0.placeId)
        }
        if displayedSearchResultPlaces != newSearchResults {
            displayedSearchResultPlaces = newSearchResults
        }

        recomputeExistingPinCoordinates()
        recomputeDisplayedCuratedCafes()
    }

    private func recomputeExistingPinCoordinates() {
        let visited = visitedCafes.compactMap { vc -> MapPinCoordinate? in
            guard let lat = vc.cafe.latitude?.doubleValue, let lng = vc.cafe.longitude?.doubleValue else {
                return nil
            }
            return MapPinCoordinate(latitude: lat, longitude: lng)
        }
        let saved = savedCafes.compactMap { sc -> MapPinCoordinate? in
            guard let lat = sc.cafe.latitude?.doubleValue, let lng = sc.cafe.longitude?.doubleValue else {
                return nil
            }
            return MapPinCoordinate(latitude: lat, longitude: lng)
        }
        let searched = searchResultPlaces.compactMap { cafe -> MapPinCoordinate? in
            guard let lat = cafe.latitude?.doubleValue, let lng = cafe.longitude?.doubleValue else {
                return nil
            }
            return MapPinCoordinate(latitude: lat, longitude: lng)
        }
        let curated = curatedCafes.map {
            MapPinCoordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        let newCoordinates = visited + saved + searched + curated
        if existingPinCoordinates != newCoordinates {
            existingPinCoordinates = newCoordinates
        }
    }

    private func recomputeDisplayedCuratedCafes() {
        guard let center = mapSearchCenter,
              center.radiusMeters <= AppleNearbyCafeLoader.zoomGateRadiusMeters else {
            if !displayedCuratedCafes.isEmpty {
                displayedCuratedCafes = []
            }
            return
        }
        let visited = Set(visitedCafes.map { $0.cafe.placeId })
        let saved = Set(savedCafes.map { $0.cafe.placeId })
        let searched = Set(searchResultPlaces.map { $0.placeId })
        let visibilityLimitMeters = center.radiusMeters * Self.curatedVisibilityMargin
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let newCuratedCafes = curatedCafes.filter {
            // placeId 競合の除外を先に評価して、距離計算の回数を短絡で減らす
            guard !visited.contains($0.placeId),
                  !saved.contains($0.placeId),
                  !searched.contains($0.placeId) else {
                return false
            }
            let distance = centerLocation.distance(
                from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            )
            return distance <= visibilityLimitMeters
        }
        if displayedCuratedCafes != newCuratedCafes {
            displayedCuratedCafes = newCuratedCafes
        }
    }
}
