package com.noricoffee.db

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver

actual fun createInMemoryTestSqlDriver(): SqlDriver =
    NativeSqliteDriver(
        schema = AppDatabase.Schema,
        name = "coffeevision-test.db",
        onConfiguration = {
            it.copy(
                inMemory = true,
                // 本番ドライバと同じく FOREIGN KEY 制約を有効化し、ON DELETE CASCADE をテストで検証できるようにする。
                extendedConfig = it.extendedConfig.copy(foreignKeyConstraints = true),
            )
        },
    )
