package com.noricoffee.db

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver

actual fun createInMemoryTestSqlDriver(): SqlDriver {
    val driver = JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY)
    AppDatabase.Schema.create(driver)
    // FOREIGN KEY の ON DELETE CASCADE を有効にする（SQLite のデフォルトは OFF）
    driver.execute(null, "PRAGMA foreign_keys = ON", 0, null)
    return driver
}
