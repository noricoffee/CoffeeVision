package com.noricoffee

import app.cash.sqldelight.db.SqlDriver
import com.noricoffee.db.AppDatabase
import com.noricoffee.repository.AuthRepository
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
 * `init(sqlDriver:remoteVisitDataSource:authRepository:)` になる。
 *
 * scope を引数で受け取るプライマリコンストラクタは **テスト用途専用**（`TestDispatcher` の
 * 差し替え等）。Kotlin のデフォルト引数は SKIE 経由で Swift には引き出されないため、デフォルト
 * 値を持たせず、用途を分けるためにセカンダリコンストラクタを別建てにしている。
 *
 * [docs/kmp-bridge.md](../../../../docs/kmp-bridge.md) §CoroutineScope の橋渡し のとおり、
 * 「AppContainer 内で隠蔽する」方針。
 *
 * ## Phase 2 時点の責務
 *
 * - 依存配線（ローカル DB + リポジトリ合成）
 * - 起動時の同期開始（[startInitialSync]）
 *
 * ViewModel ファクトリ（`makeVisitListViewModel()` 等）は Phase 3 で ViewModel を作る際に
 * 追加する。Phase 2 ではスタブも置かない（YAGNI）。
 */
class AppContainer(
    sqlDriver: SqlDriver,
    private val remoteVisitDataSource: RemoteVisitDataSource,
    val authRepository: AuthRepository,
    val scope: CoroutineScope,
) {

    /**
     * 通常用途（iOS / Android のアプリ起動時）で使うセカンダリコンストラクタ。
     *
     * 内部で [MainScope]（= `SupervisorJob() + Dispatchers.Main`）を生成し、プライマリ
     * コンストラクタに委譲する。Swift からはこのシグネチャを使うこと。
     */
    constructor(
        sqlDriver: SqlDriver,
        remoteVisitDataSource: RemoteVisitDataSource,
        authRepository: AuthRepository,
    ) : this(
        sqlDriver = sqlDriver,
        remoteVisitDataSource = remoteVisitDataSource,
        authRepository = authRepository,
        scope = MainScope(),
    )

    private val db: AppDatabase = AppDatabase(sqlDriver)

    private val localVisitRepository: LocalVisitRepository = LocalVisitRepository(db)

    val visitRepository: VisitRepository = VisitRepositoryImpl(
        local = localVisitRepository,
        remote = remoteVisitDataSource,
    )

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
