package com.noricoffee.db

import app.cash.sqldelight.db.SqlDriver

expect fun createInMemoryTestSqlDriver(): SqlDriver
