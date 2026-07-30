package com.noricoffee.framework

import com.noricoffee.AppContainer
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.usecase.BuildCoffeeStatsUseCase
import com.noricoffee.domain.usecase.DeleteAccountUseCase
import com.noricoffee.domain.usecase.ObserveCoffeeStatsUseCase
import com.noricoffee.domain.usecase.ObserveTasteMatchedCafesUseCase
import com.noricoffee.domain.usecase.ObserveVisitedCafesUseCase
import com.noricoffee.feature.account.AccountViewModel
import com.noricoffee.feature.analysis.AnalysisViewModel
import com.noricoffee.feature.cafedetail.CafeDetailViewModel
import com.noricoffee.feature.cafesearch.CafeSearchViewModel
import com.noricoffee.feature.coffeedetail.CoffeeDetailViewModel
import com.noricoffee.feature.coffeeeditor.CoffeeEditorViewModel
import com.noricoffee.feature.coffeelist.CoffeeListViewModel
import com.noricoffee.feature.map.MapViewModel

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
 * `appContainer.makeCoffeeListViewModel()` / `appContainer.makeCoffeeDetailViewModel()` の形で呼び出す。
 *
 * feature を追加するたびに本ファイルにファクトリ拡張を追記する。
 */

/**
 * [CoffeeListViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.CoffeeRepository] と
 * CoroutineScope（内部の MainScope）を自動配線する。
 */
fun AppContainer.makeCoffeeListViewModel(): CoffeeListViewModel =
    CoffeeListViewModel(coffeeRepository, scope)

/**
 * [CoffeeDetailViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.CoffeeRepository] と
 * CoroutineScope（内部の MainScope）を自動配線する。
 */
fun AppContainer.makeCoffeeDetailViewModel(): CoffeeDetailViewModel =
    CoffeeDetailViewModel(coffeeRepository, scope)

/**
 * [CoffeeEditorViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.CoffeeRepository] /
 * [com.noricoffee.repository.CafeRepository]（現在地カフェサジェスト用）と
 * CoroutineScope（内部の MainScope）を自動配線する。
 *
 * 新規作成（[CoffeeEditorViewModel.Mode.Create]）・編集（[CoffeeEditorViewModel.Mode.Edit]）・
 * 複製（[CoffeeEditorViewModel.Mode.Duplicate]）の 3 モードを同一 ViewModel で扱う。
 * モードの切り替えは [CoffeeEditorViewModel.onAppear] に渡す。
 */
fun AppContainer.makeCoffeeEditorViewModel(): CoffeeEditorViewModel =
    CoffeeEditorViewModel(coffeeRepository, cafeRepository, scope)

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
 * [AppContainer] が保持する [com.noricoffee.repository.CoffeeRepository] /
 * [com.noricoffee.repository.CafeRepository] / [com.noricoffee.repository.CuratedCafeRepository]
 * （都道府県別おすすめカフェ、フェーズ 19）と CoroutineScope（内部の MainScope）を自動配線する。
 * [ObserveVisitedCafesUseCase] のインスタンスはファクトリ内で都度生成する（DI コンテナ化は YAGNI）。
 *
 * ## Bridge のライフサイクル
 * マップタブは TabBar 常時生存のため、`AppState` で 1 つだけ生成・保持すること。
 *
 * @param userId 現在サインイン中のユーザー ID（`AppState.uid` を渡す）
 */
fun AppContainer.makeMapViewModel(userId: String): MapViewModel =
    MapViewModel(
        observeVisitedCafesUseCase = ObserveVisitedCafesUseCase(coffeeRepository),
        cafeRecommendationProvider = ObserveTasteMatchedCafesUseCase(
            coffeeRepository = coffeeRepository,
            buildCoffeeStatsUseCase = BuildCoffeeStatsUseCase(),
        ),
        cafeRepository = cafeRepository,
        coffeeRepository = coffeeRepository,
        savedCafeRepository = savedCafeRepository,
        curatedCafeRepository = curatedCafeRepository,
        userId = userId,
        scope = scope,
    )

/**
 * [CafeDetailViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.CoffeeRepository] と
 * CoroutineScope（内部の MainScope）を自動配線する。
 *
 * ## Bridge のライフサイクル
 * カフェ詳細画面は NavigationStack push ごとに新規生成・pop で破棄すること。
 *
 * @param placeId 対象カフェの Google Places ID
 * @param initialCafe マップピン / 検索結果から渡される Cafe スナップショット。
 *                    未訪問カフェの場合に過去記録がなくてもカフェ情報を表示するために使う。
 *                    訪問済みの場合は最新記録の cafe で上書きされる
 * @param userId 現在サインイン中のユーザー ID（`AppState.uid` を渡す）
 */
fun AppContainer.makeCafeDetailViewModel(
    placeId: String,
    initialCafe: Cafe?,
    userId: String,
): CafeDetailViewModel =
    CafeDetailViewModel(
        coffeeRepository = coffeeRepository,
        cafeRepository = cafeRepository,
        savedCafeRepository = savedCafeRepository,
        placeId = placeId,
        initialCafe = initialCafe,
        userId = userId,
        scope = scope,
    )

/**
 * [AnalysisViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.CoffeeRepository] と
 * [com.noricoffee.domain.model.CoffeeInsightProvider]（nullable）を自動配線する。
 * [ObserveCoffeeStatsUseCase] はファクトリ内で都度生成する（DI コンテナ化は YAGNI）。
 *
 * ## insightProvider の挙動
 * - `appContainer.coffeeInsightProvider` が null（Android / Phase A-4 以前）の場合:
 *   [AnalysisViewModel.UIState.insightStatus] は [AnalysisViewModel.InsightStatus.Unsupported] になり、
 *   要約生成は一切行わない（統計のみ表示）
 * - Phase A-4 以降、iOS 側が `AppContainer` に `CoffeeInsightProvider` 実装を注入した場合:
 *   統計確定後に自動で要約生成を開始する
 *
 * ## Bridge のライフサイクル
 * 分析タブは TabBar 常時生存のため、`AppState` で 1 つだけ生成・保持すること。
 *
 * @param userId 現在サインイン中のユーザー ID（`AppState.uid` を渡す）
 */
fun AppContainer.makeAnalysisViewModel(userId: String): AnalysisViewModel =
    AnalysisViewModel(
        observeCoffeeStatsUseCase = ObserveCoffeeStatsUseCase(
            coffeeRepository = coffeeRepository,
            beanProfileRepository = beanProfileRepository,
        ),
        insightProvider = coffeeInsightProvider,
        userId = userId,
        scope = scope,
    )

/**
 * [AccountViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.AuthRepository] /
 * [com.noricoffee.repository.CoffeeRepository] と CoroutineScope（内部の MainScope）を自動配線する。
 * [DeleteAccountUseCase] はファクトリ内で都度生成する（DI コンテナ化は YAGNI）。
 */
fun AppContainer.makeAccountViewModel(): AccountViewModel =
    AccountViewModel(
        authRepository = authRepository,
        deleteAccountUseCase = DeleteAccountUseCase(
            coffeeRepository = coffeeRepository,
            authRepository = authRepository,
        ),
        scope = scope,
    )
