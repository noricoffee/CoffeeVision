package com.noricoffee.platform

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver
import com.noricoffee.db.AppDatabase

actual class DatabaseDriverFactory {
    actual fun create(): SqlDriver =
        NativeSqliteDriver(
            schema = AppDatabase.Schema,
            name = DATABASE_NAME,
            // SQLite の FOREIGN KEY 制約は接続ごとの opt-in（既定 OFF）。sqliter の既定も false。
            onConfiguration = { it.copy(extendedConfig = it.extendedConfig.copy(foreignKeyConstraints = true)) },
        )

    private companion object {
        const val DATABASE_NAME = "coffeevision.db"
    }
}
