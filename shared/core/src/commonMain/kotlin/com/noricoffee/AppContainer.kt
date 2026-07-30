package com.noricoffee

import app.cash.sqldelight.db.SqlDriver
import com.noricoffee.data.places.createCafeRepository
import com.noricoffee.db.AppDatabase
import com.noricoffee.dev.DummyCoffeeData
import com.noricoffee.domain.model.CoffeeInsightProvider
import com.noricoffee.domain.model.CoffeeRecordQuery
import com.noricoffee.domain.model.CoffeeRecordQueryImpl
import com.noricoffee.domain.usecase.ExportCoffeeRecordsUseCase
import com.noricoffee.repository.AuthRepository
import com.noricoffee.repository.BeanProfileRepository
import com.noricoffee.repository.CafeRepository
import com.noricoffee.repository.CoffeeRepository
import com.noricoffee.repository.CoffeeRepositoryImpl
import com.noricoffee.repository.CuratedCafeRepository
import com.noricoffee.repository.LocalCoffeeRepository
import com.noricoffee.repository.LocalSavedCafeRepository
import com.noricoffee.repository.RemoteCoffeeDataSource
import com.noricoffee.repository.RemoteSavedCafeDataSource
import com.noricoffee.repository.SavedCafeRepository
import com.noricoffee.repository.SavedCafeRepositoryImpl
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope

/**
 * iOS / Android の起動コードから使うための簡易 DI コンテナ。
 *
 * ## 設計方針
 *
 * - 専用 DI フレームワークは導入せず、手書きのコンストラクタ注入で済ませる
 * - Firebase 関連の実装はプラットフォーム別 SDK を使うため、Repository / RemoteDataSource は
 *   外部から受け取る:
 *   - iOS: Swift で実装したクラスを Kotlin の interface に準拠させて渡す
 *   - Android: `shared/data-firebase/androidMain` の Kotlin 実装を渡す
 * - 内部で [LocalCoffeeRepository]（SQLDelight）と [RemoteCoffeeDataSource] を合成して
 *   [CoffeeRepositoryImpl] を組み立て、UI には [CoffeeRepository] 1 本だけを見せる
 *
 * ## CoroutineScope の取り扱い（重要）
 *
 * 通常用途（iOS / Android のアプリ起動時）では **scope 引数なし** のセカンダリコンストラクタを
 * 使い、内部で [MainScope]（`SupervisorJob() + Dispatchers.Main`）を生成させること。
 * Android の Swift 側から見える初期化シグネチャは
 * `init(sqlDriver:remoteCoffeeDataSource:remoteSavedCafeDataSource:authRepository:placesApiKey:)` になる。
 * iOS で Foundation Models を注入する場合は
 * `init(sqlDriver:remoteCoffeeDataSource:remoteSavedCafeDataSource:authRepository:placesApiKey:coffeeInsightProvider:)` を使う。
 *
 * scope を引数で受け取るプライマリコンストラクタは **テスト用途専用**（TestDispatcher の差し替え等）。
 */
class AppContainer(
    sqlDriver: SqlDriver,
    private val remoteCoffeeDataSource: RemoteCoffeeDataSource,
    private val remoteSavedCafeDataSource: RemoteSavedCafeDataSource,
    val authRepository: AuthRepository,
    val placesApiKey: String,
    val coffeeInsightProvider: CoffeeInsightProvider?,
    val beanProfileRepository: BeanProfileRepository,
    val curatedCafeRepository: CuratedCafeRepository,
    val scope: CoroutineScope,
) {

    /**
     * 通常用途（iOS / Android のアプリ起動時）で使うセカンダリコンストラクタ。
     *
     * 内部で [MainScope]（= `SupervisorJob() + Dispatchers.Main`）を生成し、プライマリ
     * コンストラクタに委譲する。Swift からはこのシグネチャを使うこと。
     *
     * Swift 側の呼び出しシグネチャ:
     * `init(sqlDriver:remoteCoffeeDataSource:remoteSavedCafeDataSource:authRepository:placesApiKey:coffeeInsightProvider:beanProfileRepository:curatedCafeRepository:)`
     *
     * ## iOS での使い方
     * - Phase A-4 まで: `coffeeInsightProvider: nil` を渡す（分析タブは統計のみ表示）
     * - Phase A-4 以降: iOS が Foundation Models 実装（`CoffeeInsightProviderIosImpl` 等）を渡す
     *
     * ## Android での使い方
     * Foundation Models は iOS 専用のため、Android では `coffeeInsightProvider` を渡さない
     * （nil 既定のオーバーロードを使う）。
     *
     * ## SKIE / デフォルト引数の注意
     * SKIE は Kotlin のデフォルト引数を Swift に出さない（[implementation_note.md] 参照）。
     * そのため `coffeeInsightProvider: null` のデフォルト値付きセカンダリコンストラクタ（Android 用）を
     * 別途定義し、Android の既存呼び出し箇所がコンパイルを通せるようにする。
     */
    constructor(
        sqlDriver: SqlDriver,
        remoteCoffeeDataSource: RemoteCoffeeDataSource,
        remoteSavedCafeDataSource: RemoteSavedCafeDataSource,
        authRepository: AuthRepository,
        placesApiKey: String,
        coffeeInsightProvider: CoffeeInsightProvider?,
        beanProfileRepository: BeanProfileRepository,
        curatedCafeRepository: CuratedCafeRepository,
    ) : this(
        sqlDriver = sqlDriver,
        remoteCoffeeDataSource = remoteCoffeeDataSource,
        remoteSavedCafeDataSource = remoteSavedCafeDataSource,
        authRepository = authRepository,
        placesApiKey = placesApiKey,
        coffeeInsightProvider = coffeeInsightProvider,
        beanProfileRepository = beanProfileRepository,
        curatedCafeRepository = curatedCafeRepository,
        scope = MainScope(),
    )

    /**
     * Android / テスト用のセカンダリコンストラクタ（[coffeeInsightProvider] = null 固定）。
     *
     * Android では Foundation Models を使わないため、既存の Android 呼び出し箇所が
     * 引数変更なしでコンパイルを通せるよう `coffeeInsightProvider` を省略可能にしている。
     *
     * Swift 側の呼び出しシグネチャ:
     * `init(sqlDriver:remoteCoffeeDataSource:remoteSavedCafeDataSource:authRepository:placesApiKey:beanProfileRepository:curatedCafeRepository:)`
     *
     * iOS では Phase A-4 以降に `CoffeeInsightProvider` 実装を注入するため、
     * iOS の `AppState.swift` では上の 8 引数セカンダリコンストラクタを使うこと。
     */
    constructor(
        sqlDriver: SqlDriver,
        remoteCoffeeDataSource: RemoteCoffeeDataSource,
        remoteSavedCafeDataSource: RemoteSavedCafeDataSource,
        authRepository: AuthRepository,
        placesApiKey: String,
        beanProfileRepository: BeanProfileRepository,
        curatedCafeRepository: CuratedCafeRepository,
    ) : this(
        sqlDriver = sqlDriver,
        remoteCoffeeDataSource = remoteCoffeeDataSource,
        remoteSavedCafeDataSource = remoteSavedCafeDataSource,
        authRepository = authRepository,
        placesApiKey = placesApiKey,
        coffeeInsightProvider = null,
        beanProfileRepository = beanProfileRepository,
        curatedCafeRepository = curatedCafeRepository,
        scope = MainScope(),
    )

    private val db: AppDatabase = AppDatabase(sqlDriver)

    private val localCoffeeRepository: LocalCoffeeRepository = LocalCoffeeRepository(db)

    val coffeeRepository: CoffeeRepository = CoffeeRepositoryImpl(
        local = localCoffeeRepository,
        remote = remoteCoffeeDataSource,
    )

    private val localSavedCafeRepository: LocalSavedCafeRepository = LocalSavedCafeRepository(db)

    /**
     * 「行きたい店」リポジトリ（フェーズ 15-A）。[coffeeRepository] と同じ 2 段構成。
     */
    val savedCafeRepository: SavedCafeRepository = SavedCafeRepositoryImpl(
        local = localSavedCafeRepository,
        remote = remoteSavedCafeDataSource,
    )

    /**
     * iOS の Foundation Models `Tool`（function calling）から呼ばれる生レコード照会 API（Phase B-3 / 9-4b）。
     *
     * Swift からの呼び出しシグネチャ（SKIE）:
     * `coffeeRecordQuery.searchRecords(filter: CoffeeRecordFilter) async throws -> [CoffeeRecordSummary]`
     *
     * userId は [CoffeeRecordQueryImpl] が内部で解決するため、Swift は [CoffeeRecordFilter] だけ渡す。
     */
    val coffeeRecordQuery: CoffeeRecordQuery = CoffeeRecordQueryImpl(
        coffeeRepository = coffeeRepository,
        authRepository = authRepository,
    )

    val cafeRepository: CafeRepository = createCafeRepository(apiKey = placesApiKey)

    /**
     * データエクスポート（要件 §7-4 / フェーズ 15-E-2）。全 [CoffeeRecord][com.noricoffee.domain.CoffeeRecord]
     * を JSON 文字列化する。[coffeeRepository] のみに依存する純粋な UseCase なので内部で生成する。
     *
     * Swift からの呼び出しシグネチャ（`.swiftinterface` で裏取り済み）:
     * `appContainer.exportCoffeeRecordsUseCase.invoke(userId: String) async throws -> String`
     */
    val exportCoffeeRecordsUseCase: ExportCoffeeRecordsUseCase = ExportCoffeeRecordsUseCase(
        coffeeRepository = coffeeRepository,
    )

    /**
     * 匿名サインインを起こし、確定した uid でリモート → ローカルの同期購読を開始する。
     *
     * 戻り値の uid を呼び出し元（iOS / Android のアプリ層）が保持し、UI からの参照や
     * [CoffeeRepository.observeAll] の引数に渡すのに使う。
     *
     * 失敗時は例外を投げる（呼び出し元で UI 通知すること）。
     */
    @Throws(Exception::class)
    suspend fun startInitialSync(): String {
        val uid = authRepository.signInAnonymouslyIfNeeded()
        (coffeeRepository as CoffeeRepositoryImpl).startSync(uid, scope)
        (savedCafeRepository as SavedCafeRepositoryImpl).startSync(uid, scope)
        return uid
    }

    /**
     * 開発用: [DummyCoffeeData] のレコード 30 件をローカル DB のみに upsert する。
     *
     * - **ローカル DB 限定**（Firestore には流さない。dev データで本番を汚染しない）
     * - **冪等**（固定 ID で何度呼んでも 30 件）
     * - iOS 側から呼ぶ場合は `#if DEBUG` かつ `SEED_DUMMY_DATA == "1"` の環境変数ガード下に限定すること
     *
     * Swift から呼ぶシグネチャ（SKIE）:
     * `seedDummyData(userId: String) async throws`
     */
    @Throws(Exception::class)
    suspend fun seedDummyData(userId: String) {
        DummyCoffeeData.records(userId).forEach { localCoffeeRepository.save(it) }
    }

    /**
     * 開発用: ローカル DB から [DummyCoffeeData] の固定 ID を持つレコードを全件削除する。
     *
     * - **ローカル DB 限定**（Firestore 側には何もしない）
     * - 通常 Scheme での起動時（`SEED_DUMMY_DATA` 未設定）に呼ぶことで、
     *   ダミー Scheme で seed したデータを綺麗に消せる
     *
     * Swift から呼ぶシグネチャ（SKIE）:
     * `clearDummyData(userId: String) async throws`
     */
    @Throws(Exception::class)
    suspend fun clearDummyData(userId: String) {
        DummyCoffeeData.ids.forEach { localCoffeeRepository.delete(userId, it) }
    }
}
