package com.noricoffee.framework

import com.noricoffee.AppContainer
import com.noricoffee.feature.visitlist.VisitListViewModel

/**
 * [AppContainer] の ViewModel ファクトリ拡張。
 *
 * ## 配置理由（core ではなく framework に置く）
 *
 * `AppContainer` は `shared/core` に、`VisitListViewModel` は `shared/feature/visit-list` に
 * 存在する。`kmp.feature` Convention Plugin が `feature -> core` の依存を自動設定するため、
 * `core` が `feature` を参照すると循環依存になる。
 *
 * `shared/framework`（iOS Umbrella）は `core` / `feature` の両方を `api` で再 export する
 * 最上位レイヤーのため、ここにファクトリを置くと循環なしで双方向の参照が可能になる。
 *
 * ## Swift / iOS からの使い方
 *
 * `import SharedLogic` のみで利用可能。Kotlin/Native は同モジュール内のレシーバを持つ
 * 拡張関数を Obj-C category（インスタンスメソッド）として出力するため、Swift 側からは
 * `appContainer.makeVisitListViewModel()` の形で呼び出す。
 */

/**
 * [VisitListViewModel] を生成して返す。
 *
 * [AppContainer] が保持する [com.noricoffee.repository.VisitRepository] と
 * CoroutineScope（内部の MainScope）を自動配線する。
 */
fun AppContainer.makeVisitListViewModel(): VisitListViewModel =
    VisitListViewModel(visitRepository, scope)
