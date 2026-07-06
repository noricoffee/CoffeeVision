package com.noricoffee

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.framework.makeCoffeeListViewModel

/**
 * Android 検証用のコーヒー記録一覧画面。
 *
 * ## 目的
 * `CoffeeListViewModel` が Android でも動くこと + Firestore observe が Android-Android で
 * 往復することを **1 画面で証明する最小実装**。
 * 削除 / 編集 / 詳細遷移は Android 検証スコープ外として実装しない。
 *
 * ## 二重 startInitialSync について
 * `CoffeeVisionApp.onCreate()` でも既に `startInitialSync()` が呼ばれている。
 * `LaunchedEffect` 側でも呼ぶが、`signInAnonymouslyIfNeeded()` は既存 uid をそのまま返し、
 * `startSync()` は新しい同期 Job を起動するだけなので二重呼び出しで実害はない。
 */
@Composable
fun CoffeeListScreen(appContainer: AppContainer) {
    val viewModel = remember { appContainer.makeCoffeeListViewModel() }
    val state by viewModel.state.collectAsState()

    LaunchedEffect(Unit) {
        runCatching { appContainer.startInitialSync() }
            .onSuccess { uid -> viewModel.onAppear(uid) }
            // エラーは state.error 経由で UI に表示する。Log は commonMain では使えない
    }

    Surface(modifier = Modifier.fillMaxSize()) {
        when {
            state.isLoading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator()
                }
            }

            state.error != null -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Error: ${state.error}",
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.padding(16.dp),
                    )
                }
            }

            state.sections.isEmpty() -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "(no records)",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }

            else -> {
                LazyColumn(modifier = Modifier.fillMaxSize()) {
                    state.sections.forEach { section ->
                        item(key = "header-${section.yearMonth}") {
                            Text(
                                text = section.yearMonth,
                                style = MaterialTheme.typography.titleSmall,
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                            )
                        }
                        items(section.records, key = { it.id }) { record ->
                            CoffeeRecordRow(record)
                            HorizontalDivider()
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CoffeeRecordRow(record: CoffeeRecord) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Text(
            text = record.name,
            style = MaterialTheme.typography.titleMedium,
        )
        Text(
            text = record.cafe?.name ?: "(セルフ抽出)",
            style = MaterialTheme.typography.bodySmall,
        )
        Text(
            text = record.visitedOn.toString(),
            style = MaterialTheme.typography.bodySmall,
        )
        Text(
            text = "★ ${record.rating}",
            style = MaterialTheme.typography.bodySmall,
        )
    }
}
