package com.noricoffee.platform

import android.content.Context
import androidx.sqlite.db.SupportSQLiteDatabase
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import com.noricoffee.db.AppDatabase

actual class DatabaseDriverFactory(private val context: Context) {
    actual fun create(): SqlDriver =
        AndroidSqliteDriver(
            schema = AppDatabase.Schema,
            context = context,
            name = DATABASE_NAME,
            // SQLite の FOREIGN KEY 制約は接続ごとの opt-in（既定 OFF）。
            // onConfigure に置くことで migration 実行中は framework 側が自動的に制約を外す挙動に乗る。
            callback = object : AndroidSqliteDriver.Callback(AppDatabase.Schema) {
                override fun onConfigure(db: SupportSQLiteDatabase) {
                    super.onConfigure(db)
                    db.setForeignKeyConstraintsEnabled(true)
                }
            },
        )

    private companion object {
        const val DATABASE_NAME = "coffeevision.db"
    }
}
