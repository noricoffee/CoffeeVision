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
import com.noricoffee.domain.Visit
import com.noricoffee.framework.makeVisitListViewModel

/**
 * Android 検証用の Visit 一覧画面。
 *
 * ## 目的
 * `VisitListViewModel` が Android でも動くこと + Firestore observe が Android-Android で
 * 往復することを **1 画面で証明する最小実装**。
 * 削除 / 編集 / 詳細遷移は Phase 3.5 検証スコープ外として実装しない。
 *
 * ## 二重 startInitialSync について
 * `CoffeeVisionApp.onCreate()` でも既に `startInitialSync()` が呼ばれている。
 * `LaunchedEffect` 側でも呼ぶが、`signInAnonymouslyIfNeeded()` は既存 uid をそのまま返し、
 * `startSync()` は新しい同期 Job を起動するだけなので二重呼び出しで実害はない。
 * Application 起動後の uid 確定タイミングとスクリーン表示のタイミングに差があり得るため、
 * ViewModel に onAppear(uid) を確実に届けるために VisitListScreen 側でも呼ぶ設計を採る。
 * （[docs/implementation_note.md] Phase 3.5 Android 検証スライスの事前設計 参照）
 *
 * ## commonMain での Android 専用 API
 * `android.util.Log` 等は使えない。エラーは [com.noricoffee.feature.visitlist.VisitListViewModel.UIState.error]
 * を通じて UI に表示するのみ。
 */
@Composable
fun VisitListScreen(appContainer: AppContainer) {
    val viewModel = remember { appContainer.makeVisitListViewModel() }
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

            state.visits.isEmpty() -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "(no visits)",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }

            else -> {
                LazyColumn(modifier = Modifier.fillMaxSize()) {
                    items(state.visits, key = { it.id }) { visit ->
                        VisitRow(visit)
                        HorizontalDivider()
                    }
                }
            }
        }
    }
}

@Composable
private fun VisitRow(visit: Visit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Text(
            text = visit.cafe.name,
            style = MaterialTheme.typography.titleMedium,
        )
        Text(
            text = visit.visitedOn.toString(),
            style = MaterialTheme.typography.bodySmall,
        )
        Text(
            text = "★ ${visit.rating}",
            style = MaterialTheme.typography.bodySmall,
        )
    }
}
