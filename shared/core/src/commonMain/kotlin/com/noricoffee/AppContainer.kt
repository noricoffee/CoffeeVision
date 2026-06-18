package com.noricoffee

import app.cash.sqldelight.db.SqlDriver
import com.noricoffee.data.places.createCafeRepository
import com.noricoffee.db.AppDatabase
import com.noricoffee.repository.AuthRepository
import com.noricoffee.repository.CafeRepository
import com.noricoffee.repository.CoffeeRepository
import com.noricoffee.repository.CoffeeRepositoryImpl
import com.noricoffee.repository.LocalCoffeeRepository
import com.noricoffee.repository.RemoteCoffeeDataSource
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
 * Swift から見える初期化シグネチャは
 * `init(sqlDriver:remoteCoffeeDataSource:authRepository:placesApiKey:)` になる。
 *
 * scope を引数で受け取るプライマリコンストラクタは **テスト用途専用**（TestDispatcher の差し替え等）。
 */
class AppContainer(
    sqlDriver: SqlDriver,
    private val remoteCoffeeDataSource: RemoteCoffeeDataSource,
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
     * `init(sqlDriver:remoteCoffeeDataSource:authRepository:placesApiKey:)`
     */
    constructor(
        sqlDriver: SqlDriver,
        remoteCoffeeDataSource: RemoteCoffeeDataSource,
        authRepository: AuthRepository,
        placesApiKey: String,
    ) : this(
        sqlDriver = sqlDriver,
        remoteCoffeeDataSource = remoteCoffeeDataSource,
        authRepository = authRepository,
        placesApiKey = placesApiKey,
        scope = MainScope(),
    )

    private val db: AppDatabase = AppDatabase(sqlDriver)

    private val localCoffeeRepository: LocalCoffeeRepository = LocalCoffeeRepository(db)

    val coffeeRepository: CoffeeRepository = CoffeeRepositoryImpl(
        local = localCoffeeRepository,
        remote = remoteCoffeeDataSource,
    )

    val cafeRepository: CafeRepository = createCafeRepository(apiKey = placesApiKey)

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
        return uid
    }
}
