package com.noricoffee.framework

import com.noricoffee.AppContainer
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.usecase.ObserveVisitedCafesUseCase
import com.noricoffee.feature.cafedetail.CafeDetailViewModel
import com.noricoffee.feature.cafesearch.CafeSearchViewModel
import com.noricoffee.feature.map.MapViewModel
import com.noricoffee.feature.visitdetail.VisitDetailViewModel
import com.noricoffee.feature.visiteditor.VisitEditorViewModel
import com.noricoffee.feature.visitlist.VisitListViewModel

/**
 * [AppContainer] の ViewModel ファクトリ拡張。
 *
 * ## 配置理由（core ではなく framework に置く）
 *
 * `AppContainer` は `shared/core` に、各 ViewModel は `shared/feature/<name>` に存在する。
 * `kmp.feature` Convention Plugin が `feature -> core` の依存を自動設定するため、
 * `core` が `feature` を参照すると循環依存になる。
 *
 * `shared/framework`（iOS Umbrella）は `core` / `feature` の両方を `api` で再 export する
 * 最上位レイヤーのため、ここにファクトリを置くと循環なしで双方向の参照が可能になる。
 *
 * ## Swift / iOS からの使い方
 *
 * `import SharedLogic` のみで利用可能。Kotlin/Native は同モジュール内のレシーバを持つ
 * 拡張関数を Obj-C category（インスタンスメソッド）として出力するため、Swift 側からは
 * `appContainer.makeVisitListViewModel()` / `appContainer.makeVisitDetailViewModel()` の形で呼び出す。
 *
 * feature を追加するたびに本ファイルにファクトリ拡張を追記する。
 */

/**
 * [VisitListViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.VisitRepository] と
 * CoroutineScope（内部の MainScope）を自動配線する。
 */
fun AppContainer.makeVisitListViewModel(): VisitListViewModel =
    VisitListViewModel(visitRepository, scope)

/**
 * [VisitDetailViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.VisitRepository] と
 * CoroutineScope（内部の MainScope）を自動配線する。
 */
fun AppContainer.makeVisitDetailViewModel(): VisitDetailViewModel =
    VisitDetailViewModel(visitRepository, scope)

/**
 * [VisitEditorViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.VisitRepository] と
 * CoroutineScope（内部の MainScope）を自動配線する。
 *
 * 新規作成（[VisitEditorViewModel.Mode.Create]）と編集（[VisitEditorViewModel.Mode.Edit]）の
 * 両モードを同一 ViewModel で扱う。モードの切り替えは [VisitEditorViewModel.onAppear] に渡す。
 */
fun AppContainer.makeVisitEditorViewModel(): VisitEditorViewModel =
    VisitEditorViewModel(visitRepository, scope)

/**
 * [CafeSearchViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.CafeRepository] と
 * CoroutineScope（内部の MainScope）を自動配線する。
 */
fun AppContainer.makeCafeSearchViewModel(): CafeSearchViewModel =
    CafeSearchViewModel(cafeRepository, scope)

/**
 * [MapViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.VisitRepository] /
 * [com.noricoffee.repository.CafeRepository] と CoroutineScope（内部の MainScope）を自動配線する。
 * [ObserveVisitedCafesUseCase] のインスタンスはファクトリ内で都度生成する（DI コンテナ化は YAGNI）。
 *
 * ## Bridge のライフサイクル
 * マップタブは TabBar 常時生存のため、`AppState` で 1 つだけ生成・保持すること（`visitListBridge` と同等）。
 *
 * @param userId 現在サインイン中のユーザー ID（`AppState.uid` を渡す）
 */
fun AppContainer.makeMapViewModel(userId: String): MapViewModel =
    MapViewModel(
        observeVisitedCafesUseCase = ObserveVisitedCafesUseCase(visitRepository),
        cafeRepository = cafeRepository,
        userId = userId,
        scope = scope,
    )

/**
 * [CafeDetailViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.VisitRepository] と
 * CoroutineScope（内部の MainScope）を自動配線する。
 *
 * ## Bridge のライフサイクル
 * カフェ詳細画面は NavigationStack push ごとに新規生成・pop で破棄すること（`VisitDetailView` と同等）。
 * `AppState` にホルダープロパティを追加せず、View 内 `@State` で保持する。
 *
 * @param placeId 対象カフェの Google Places ID
 * @param initialCafe マップピン / 検索結果から渡される Cafe スナップショット。
 *                    未訪問カフェの場合に過去 Visit がなくてもカフェ情報を表示するために使う。
 *                    訪問済みの場合は最新 Visit の cafe で上書きされる
 * @param userId 現在サインイン中のユーザー ID（`AppState.uid` を渡す）
 */
fun AppContainer.makeCafeDetailViewModel(
    placeId: String,
    initialCafe: Cafe?,
    userId: String,
): CafeDetailViewModel =
    CafeDetailViewModel(
        visitRepository = visitRepository,
        placeId = placeId,
        initialCafe = initialCafe,
        userId = userId,
        scope = scope,
    )
