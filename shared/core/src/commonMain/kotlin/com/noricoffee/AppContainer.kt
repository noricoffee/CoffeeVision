package com.noricoffee

import app.cash.sqldelight.db.SqlDriver
import com.noricoffee.data.places.createCafeRepository
import com.noricoffee.db.AppDatabase
import com.noricoffee.repository.AuthRepository
import com.noricoffee.repository.CafeRepository
import com.noricoffee.repository.LocalVisitRepository
import com.noricoffee.repository.RemoteVisitDataSource
import com.noricoffee.repository.VisitRepository
import com.noricoffee.repository.VisitRepositoryImpl
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope

/**
 * Phase 2 で iOS / Android の起動コードから使い始めるための簡易 DI コンテナ。
 *
 * ## 設計方針
 *
 * - 専用 DI フレームワークは導入せず、手書きのコンストラクタ注入で済ませる
 *   （[docs/architecture.md](../../../../docs/architecture.md) §依存性の注入）
 * - Firebase 関連の実装はプラットフォーム別 SDK を使うため、Repository / RemoteDataSource は
 *   外部から受け取る:
 *   - iOS: Swift で実装したクラスを Kotlin の interface に準拠させて渡す
 *   - Android: `shared/data-firebase/androidMain` の Kotlin 実装を渡す
 * - 内部で [LocalVisitRepository]（SQLDelight）と [RemoteVisitDataSource] を合成して
 *   [VisitRepositoryImpl] を組み立て、UI には [VisitRepository] 1 本だけを見せる
 *
 * ## CoroutineScope の取り扱い（重要）
 *
 * 通常用途（iOS / Android のアプリ起動時）では **scope 引数なし** のセカンダリコンストラクタを
 * 使い、内部で [MainScope]（`SupervisorJob() + Dispatchers.Main`）を生成させること。
 * Swift から見える初期化シグネチャは
 * `init(sqlDriver:remoteVisitDataSource:authRepository:placesApiKey:)` になる。
 *
 * scope を引数で受け取るプライマリコンストラクタは **テスト用途専用**（`TestDispatcher` の
 * 差し替え等）。Kotlin のデフォルト引数は SKIE 経由で Swift には引き出されないため、デフォルト
 * 値を持たせず、用途を分けるためにセカンダリコンストラクタを別建てにしている。
 *
 * [docs/kmp-bridge.md](../../../../docs/kmp-bridge.md) §CoroutineScope の橋渡し のとおり、
 * 「AppContainer 内で隠蔽する」方針。
 *
 * ## Phase 4 時点の責務
 *
 * - 依存配線（ローカル DB + リポジトリ合成）
 * - 起動時の同期開始（[startInitialSync]）
 * - ViewModel ファクトリ: `core → feature` の循環依存を避けるため、ファクトリ関数は
 *   `shared/framework` の `AppContainerViewModelFactory.kt`（拡張関数）として定義する。
 *   Kotlin/Native は同モジュール内のレシーバを持つ拡張関数を Obj-C category（インスタンス
 *   メソッド）として出力するため、Swift 側からは `appContainer.makeVisitListViewModel()` の
 *   形でそのまま呼べる。
 * - Places API: `placesApiKey` を受け取り、`PlacesClient` / `CafeRepository` を内部で組み立てる。
 *   キーは Android は BuildConfig 経由、iOS は Info.plist 経由（スライス 2 で整備）で渡す。
 */
class AppContainer(
    sqlDriver: SqlDriver,
    private val remoteVisitDataSource: RemoteVisitDataSource,
    val authRepository: AuthRepository,
    val placesApiKey: String,
    val scope: CoroutineScope,
) {

    /**
     * 通常用途（iOS / Android のアプリ起動時）で使うセカンダリコンストラクタ。
     *
     * 内部で [MainScope]（= `SupervisorJob() + Dispatchers.Main`）を生成し、プライマリ
     * コンストラクタに委譲する。Swift からはこのシグネチャを使うこと。
     *
     * Swift 側の呼び出しシグネチャ:
     * `init(sqlDriver:remoteVisitDataSource:authRepository:placesApiKey:)`
     */
    constructor(
        sqlDriver: SqlDriver,
        remoteVisitDataSource: RemoteVisitDataSource,
        authRepository: AuthRepository,
        placesApiKey: String,
    ) : this(
        sqlDriver = sqlDriver,
        remoteVisitDataSource = remoteVisitDataSource,
        authRepository = authRepository,
        placesApiKey = placesApiKey,
        scope = MainScope(),
    )

    private val db: AppDatabase = AppDatabase(sqlDriver)

    private val localVisitRepository: LocalVisitRepository = LocalVisitRepository(db)

    val visitRepository: VisitRepository = VisitRepositoryImpl(
        local = localVisitRepository,
        remote = remoteVisitDataSource,
    )

    val cafeRepository: CafeRepository = createCafeRepository(apiKey = placesApiKey)

    /**
     * 匿名サインインを起こし、確定した uid でリモート → ローカルの同期購読を開始する。
     *
     * 戻り値の uid を呼び出し元（iOS / Android のアプリ層）が保持し、UI からの参照や
     * [VisitRepository.observeAll] の引数に渡すのに使う。
     *
     * 失敗時は例外を投げる（呼び出し元で UI 通知すること）。
     */
    @Throws(Exception::class)
    suspend fun startInitialSync(): String {
        val uid = authRepository.signInAnonymouslyIfNeeded()
        (visitRepository as VisitRepositoryImpl).startSync(uid, scope)
        return uid
    }
}
