package com.noricoffee.feature.account

import com.noricoffee.domain.model.AuthAccount
import com.noricoffee.domain.model.SavedCafe
import com.noricoffee.domain.usecase.DeleteAccountUseCase
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.repository.AuthRepository
import com.noricoffee.repository.CoffeeRepository
import com.noricoffee.repository.SavedCafeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * [AccountViewModel] の状態遷移テスト。
 *
 * - `init` で `observeAccount()` を購読し account が反映される
 * - `onAppleCredentialReceived` — linkWithApple 成功 → isProcessing が false に戻り account 更新
 * - `onAppleCredentialReceived` — linkWithApple 失敗 → error がセットされる
 * - `onSignOutTapped` — 成功 → isProcessing が false に戻る
 * - `onSignOutTapped` — 失敗 → error がセットされる
 * - `onDeleteAccountTapped` — 成功 → isProcessing が false に戻る
 * - `onDeleteAccountTapped` — 失敗 → error がセットされる
 * - `onErrorDismissed` → error が null に戻る
 *
 * ## 完了検知の契約（SR-1、2026-08-08 追加）
 * - 3 アクションとも**呼び出しから戻る時点で** `isProcessing = true` を反映済み
 * - アクション開始時に前回の `error` を同期的にクリアする
 *
 * iOS 側がこれに依存して完了を待つ（[AccountViewModel] の KDoc「完了検知の契約」）。
 */
class AccountViewModelTest {

    // ─────────────────────────────────────────────────
    // Fakes
    // ─────────────────────────────────────────────────

    private class FakeAuthRepository(
        private val initialAccount: AuthAccount? = null,
    ) : AuthRepository {

        var linkWithAppleResult: AuthAccount? = null
        var linkWithAppleError: Exception? = null

        var signOutError: Exception? = null
        var deleteAuthUserError: Exception? = null

        override suspend fun signInAnonymouslyIfNeeded(): String = "fake-uid"

        override fun observeUserId(): Flow<String?> = flowOf("fake-uid")

        // 単一値を emit して完了する Flow で返す。
        // MutableStateFlow（無限 Flow）は runTest の UncompletedCoroutinesError の原因になる。
        override fun observeAccount(): Flow<AuthAccount?> = flowOf(initialAccount)

        override suspend fun linkWithApple(idToken: String, rawNonce: String): AuthAccount {
            linkWithAppleError?.let { throw it }
            return linkWithAppleResult ?: throw IllegalStateException("linkWithAppleResult not set")
        }

        override suspend fun signOut() {
            signOutError?.let { throw it }
        }

        override suspend fun deleteAuthUser() {
            deleteAuthUserError?.let { throw it }
        }

        override suspend fun updateAnalyticsConsent(consent: Boolean) = Unit

        override fun observeAnalyticsConsent(): Flow<Boolean> = flowOf(false)

        override suspend fun deleteUserProfile() = Unit
    }

    private class FakeCoffeeRepository(
        private val records: List<CoffeeRecord> = emptyList(),
        private val deleteError: Exception? = null,
    ) : CoffeeRepository {
        val deletedIds = mutableListOf<String>()

        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(records)
        override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)
        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit
        override suspend fun delete(userId: String, id: String) {
            deleteError?.let { throw it }
            deletedIds.add(id)
        }
    }

    private class FakeSavedCafeRepository : SavedCafeRepository {
        override fun observeAll(userId: String): Flow<List<SavedCafe>> = flowOf(emptyList())
        override fun observeByPlaceId(userId: String, placeId: String): Flow<SavedCafe?> = flowOf(null)
        override suspend fun save(savedCafe: SavedCafe) = Unit
        override suspend fun delete(userId: String, placeId: String) = Unit
    }

    private val anonymousAccount = AuthAccount(
        uid = "anon-uid",
        isAnonymous = true,
        providerLabel = null,
        email = null,
    )

    private val appleAccount = AuthAccount(
        uid = "anon-uid",
        isAnonymous = false,
        providerLabel = "apple.com",
        email = "test@example.com",
    )

    // ─────────────────────────────────────────────────
    // Tests
    // ─────────────────────────────────────────────────

    @Test
    fun init_subscribesToObserveAccount_andReflectsInitialAccount() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = anonymousAccount)
        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(FakeCoffeeRepository(), FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertEquals(anonymousAccount, vm.state.value.account)
        assertFalse(vm.state.value.isProcessing)
        assertNull(vm.state.value.error)

        vm.clear()
        testScheduler.advanceUntilIdle()
    }

    @Test
    fun init_reflectsNullAccount_whenNotSignedIn() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = null)
        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(FakeCoffeeRepository(), FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertNull(vm.state.value.account)

        vm.clear()
        testScheduler.advanceUntilIdle()
    }

    @Test
    fun onAppleCredentialReceived_success_updatesAccountAndClearsProcessing() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = anonymousAccount)
        fakeAuth.linkWithAppleResult = appleAccount

        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(FakeCoffeeRepository(), FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )

        vm.onAppleCredentialReceived(idToken = "test-token", rawNonce = "test-nonce")
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertEquals(appleAccount, state.account)
        assertFalse(state.isProcessing)
        assertNull(state.error)

        vm.clear()
        testScheduler.advanceUntilIdle()
    }

    @Test
    fun onAppleCredentialReceived_failure_setsError() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = anonymousAccount)
        fakeAuth.linkWithAppleError = Exception("Link failed")

        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(FakeCoffeeRepository(), FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )

        vm.onAppleCredentialReceived(idToken = "bad-token", rawNonce = "bad-nonce")
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isProcessing)
        assertEquals("Link failed", state.error)
        // account は変化しない（リンク失敗のため匿名のまま）
        assertEquals(anonymousAccount, state.account)

        vm.clear()
        testScheduler.advanceUntilIdle()
    }

    @Test
    fun onSignOutTapped_success_clearsProcessing() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = anonymousAccount)

        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(FakeCoffeeRepository(), FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )

        vm.onSignOutTapped()
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isProcessing)
        assertNull(state.error)

        vm.clear()
        testScheduler.advanceUntilIdle()
    }

    @Test
    fun onSignOutTapped_failure_setsError() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = anonymousAccount)
        fakeAuth.signOutError = Exception("Sign out failed")

        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(FakeCoffeeRepository(), FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )

        vm.onSignOutTapped()
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isProcessing)
        assertEquals("Sign out failed", state.error)

        vm.clear()
        testScheduler.advanceUntilIdle()
    }

    @Test
    fun onDeleteAccountTapped_success_clearsProcessing() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = anonymousAccount)
        val fakeCoffee = FakeCoffeeRepository()

        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(fakeCoffee, FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )

        vm.onDeleteAccountTapped(userId = "anon-uid")
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isProcessing)
        assertNull(state.error)

        vm.clear()
        testScheduler.advanceUntilIdle()
    }

    @Test
    fun onDeleteAccountTapped_failure_setsError() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = anonymousAccount)
        fakeAuth.deleteAuthUserError = Exception("Delete failed")
        val fakeCoffee = FakeCoffeeRepository()

        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(fakeCoffee, FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )

        vm.onDeleteAccountTapped(userId = "anon-uid")
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isProcessing)
        assertEquals("Delete failed", state.error)

        vm.clear()
        testScheduler.advanceUntilIdle()
    }

    // ─────────────────────────────────────────────────
    // 完了検知の契約（AccountViewModel の KDoc「完了検知の契約」）
    //
    // 各アクションは **戻る時点で** isProcessing = true を反映済みであること。
    // iOS 側（AccountViewModelBridge.awaitProcessingCompletion）は呼び出し直後から
    // state を購読して「最初の isProcessing == false」を完了とみなすため、ここが
    // launch の内側だと開始前の false を完了と誤読する。
    //
    // runTest は StandardTestDispatcher なので、advanceUntilIdle を呼ぶまで launch の
    // 中身は走らない。つまり以下は「コルーチンがディスパッチされる前」の観測になる。
    // ─────────────────────────────────────────────────

    @Test
    fun onSignOutTapped_setsProcessingSynchronously_beforeCoroutineRuns() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = anonymousAccount)
        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(FakeCoffeeRepository(), FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )

        vm.onSignOutTapped()

        assertTrue(vm.state.value.isProcessing)

        testScheduler.advanceUntilIdle()
        vm.clear()
        testScheduler.advanceUntilIdle()
    }

    @Test
    fun onDeleteAccountTapped_setsProcessingSynchronously_beforeCoroutineRuns() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = anonymousAccount)
        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(FakeCoffeeRepository(), FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )

        vm.onDeleteAccountTapped(userId = "anon-uid")

        assertTrue(vm.state.value.isProcessing)

        testScheduler.advanceUntilIdle()
        vm.clear()
        testScheduler.advanceUntilIdle()
    }

    @Test
    fun onAppleCredentialReceived_setsProcessingSynchronously_beforeCoroutineRuns() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = anonymousAccount)
        fakeAuth.linkWithAppleResult = appleAccount
        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(FakeCoffeeRepository(), FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )

        vm.onAppleCredentialReceived(idToken = "test-token", rawNonce = "test-nonce")

        assertTrue(vm.state.value.isProcessing)

        testScheduler.advanceUntilIdle()
        vm.clear()
        testScheduler.advanceUntilIdle()
    }

    @Test
    fun actionStart_clearsPreviousError_synchronously() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = anonymousAccount)
        fakeAuth.signOutError = Exception("Sign out failed")
        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(FakeCoffeeRepository(), FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )

        // 1 回目: 失敗させて error を残す
        vm.onSignOutTapped()
        testScheduler.advanceUntilIdle()
        assertNotNull(vm.state.value.error)

        // 2 回目の開始時点で error はクリアされている（前回の失敗を完了と誤読させない）
        fakeAuth.signOutError = null
        vm.onSignOutTapped()

        assertTrue(vm.state.value.isProcessing)
        assertNull(vm.state.value.error)

        testScheduler.advanceUntilIdle()
        vm.clear()
        testScheduler.advanceUntilIdle()
    }

    @Test
    fun onErrorDismissed_clearsError() = runTest {
        val fakeAuth = FakeAuthRepository(initialAccount = anonymousAccount)
        fakeAuth.signOutError = Exception("Sign out failed")

        val vm = AccountViewModel(
            authRepository = fakeAuth,
            deleteAccountUseCase = DeleteAccountUseCase(FakeCoffeeRepository(), FakeSavedCafeRepository(), fakeAuth),
            scope = this,
        )

        vm.onSignOutTapped()
        testScheduler.advanceUntilIdle()
        assertNotNull(vm.state.value.error)

        vm.onErrorDismissed()

        assertNull(vm.state.value.error)

        vm.clear()
        testScheduler.advanceUntilIdle()
    }
}
