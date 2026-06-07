package com.noricoffee.platform

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver
import com.noricoffee.db.AppDatabase

actual class DatabaseDriverFactory {
    actual fun create(): SqlDriver =
        NativeSqliteDriver(AppDatabase.Schema, DATABASE_NAME)

    private companion object {
        const val DATABASE_NAME = "coffeevision.db"
    }
}
