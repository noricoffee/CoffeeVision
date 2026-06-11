package com.noricoffee.coffeevision

import android.app.Application
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.PersistentCacheSettings
import com.google.firebase.firestore.firestoreSettings
import com.noricoffee.AppContainer
import com.noricoffee.platform.DatabaseDriverFactory
import com.noricoffee.repository.AuthRepositoryAndroidImpl
import com.noricoffee.repository.RemoteVisitDataSourceAndroidImpl
import kotlinx.coroutines.launch

/**
 * CoffeeVision の Application クラス。
 *
 * ## 責務
 * 1. Firebase の初期化（`FirebaseApp.initializeApp(context)`）
 * 2. Firestore のオフライン永続化設定（`PersistentCacheSettings`）
 * 3. `AppContainer` の構築（`SQLiteDriver` + Android Firebase 実装を注入）
 * 4. 匿名サインイン + 初期同期開始（`startInitialSync()`）
 *
 * ## AppContainer の取得方法
 * `CoffeeVisionApp.appContainer` を Singleton として提供する。
 * `MainActivity` および `VisitListScreen` から参照する。
 *
 * ## トレードオフ
 * `companion object` で Singleton 化するためテストしやすさを犠牲にしているが、
 * Phase 3.5 の検証スライスでは構わない。本格 DI（Hilt / Koin）は Phase 5 以降の課題。
 * （[docs/implementation_note.md] Phase 3.5 Android 検証スライスの事前設計 参照）
 */
class CoffeeVisionApp : Application() {

    companion object {
        lateinit var appContainer: AppContainer
            private set
    }

    override fun onCreate() {
        super.onCreate()

        // 1. Firebase 初期化
        FirebaseApp.initializeApp(this)

        // 2. Firestore オフライン永続化（Firebase BoM 33.7.0 / Firestore 25.x の PersistentCacheSettings）
        FirebaseFirestore.getInstance().firestoreSettings = firestoreSettings {
            setLocalCacheSettings(PersistentCacheSettings.newBuilder().build())
        }

        // 3. AppContainer 構築
        val sqlDriver = DatabaseDriverFactory(this).create()
        appContainer = AppContainer(
            sqlDriver = sqlDriver,
            remoteVisitDataSource = RemoteVisitDataSourceAndroidImpl(),
            authRepository = AuthRepositoryAndroidImpl(),
        )

        // 4. 匿名サインイン + 初期同期開始
        appContainer.scope.launch {
            try {
                val uid = appContainer.startInitialSync()
                android.util.Log.i("CoffeeVisionApp", "Initial sync started. uid=$uid")
            } catch (e: Throwable) {
                android.util.Log.e("CoffeeVisionApp", "Initial sync failed", e)
            }
        }
    }
}
