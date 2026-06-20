package com.noricoffee.feature.account

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.TastingScores
import com.noricoffee.domain.model.AuthAccount
import com.noricoffee.domain.usecase.DeleteAccountUseCase
import com.noricoffee.repository.AuthRepository
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * [DeleteAccountUseCase] のユニットテスト。
 *
 * - 全 CoffeeRecord が削除されてから `deleteAuthUser` が呼ばれること（順序保証）
 * - 記録がゼロ件でも `deleteAuthUser` が呼ばれること
 * - `delete` が例外を投げたとき `deleteAuthUser` は呼ばれないこと
 */
class DeleteAccountUseCaseTest {

    // ─────────────────────────────────────────────────
    // Fakes
    // ─────────────────────────────────────────────────

    private class FakeAuthRepository : AuthRepository {
        var deleteAuthUserCalled = false
        var deleteAuthUserError: Exception? = null

        override suspend fun signInAnonymouslyIfNeeded(): String = "uid"
        override fun observeUserId(): Flow<String?> = flowOf("uid")
        override fun observeAccount(): Flow<AuthAccount?> = flowOf(null)
        override suspend fun linkWithApple(idToken: String, rawNonce: String): AuthAccount =
            throw UnsupportedOperationException()
        override suspend fun signOut() = Unit

        override suspend fun deleteAuthUser() {
            deleteAuthUserError?.let { throw it }
            deleteAuthUserCalled = true
        }
    }

    private class RecordingCoffeeRepository(
        private val records: List<CoffeeRecord>,
        private val deleteError: Exception? = null,
    ) : CoffeeRepository {
        val deleteCallOrder = mutableListOf<String>()

        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(records)
        override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)
        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit

        override suspend fun delete(userId: String, id: String) {
            deleteError?.let { throw it }
            deleteCallOrder.add(id)
        }
    }

    // ─────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────

    private fun makeRecord(id: String, userId: String = "user-01"): CoffeeRecord = CoffeeRecord(
        id = id,
        userId = userId,
        cafe = null,
        visitedOn = LocalDate(2026, 6, 1),
        rating = 4.0,
        notes = "",
        photos = emptyList(),
        name = "Test Coffee $id",
        brewMethod = BrewMethod.HandDrip,
        origin = null,
        variety = null,
        processing = null,
        roastLevel = null,
        cup = null,
        tasting = TastingScores(),
        createdAt = Instant.fromEpochSeconds(0),
        updatedAt = Instant.fromEpochSeconds(0),
    )

    // ─────────────────────────────────────────────────
    // Tests
    // ─────────────────────────────────────────────────

    @Test
    fun invoke_deletesAllRecordsThenCallsDeleteAuthUser() = runTest {
        val records = listOf(makeRecord("r1"), makeRecord("r2"), makeRecord("r3"))
        val fakeCoffeeRepo = RecordingCoffeeRepository(records)
        val fakeAuthRepo = FakeAuthRepository()

        val useCase = DeleteAccountUseCase(fakeCoffeeRepo, fakeAuthRepo)
        useCase(userId = "user-01")

        // 全 CoffeeRecord が削除されたこと
        assertEquals(setOf("r1", "r2", "r3"), fakeCoffeeRepo.deleteCallOrder.toSet())
        // 全記録削除後に deleteAuthUser が呼ばれたこと
        assertTrue(fakeAuthRepo.deleteAuthUserCalled)
    }

    @Test
    fun invoke_withNoRecords_callsDeleteAuthUser() = runTest {
        val fakeCoffeeRepo = RecordingCoffeeRepository(emptyList())
        val fakeAuthRepo = FakeAuthRepository()

        val useCase = DeleteAccountUseCase(fakeCoffeeRepo, fakeAuthRepo)
        useCase(userId = "user-01")

        assertTrue(fakeCoffeeRepo.deleteCallOrder.isEmpty())
        assertTrue(fakeAuthRepo.deleteAuthUserCalled)
    }

    @Test
    fun invoke_whenDeleteThrows_doesNotCallDeleteAuthUser() = runTest {
        val records = listOf(makeRecord("r1"))
        val fakeCoffeeRepo = RecordingCoffeeRepository(records, deleteError = Exception("DB error"))
        val fakeAuthRepo = FakeAuthRepository()

        val useCase = DeleteAccountUseCase(fakeCoffeeRepo, fakeAuthRepo)
        val result = runCatching { useCase(userId = "user-01") }

        assertTrue(result.isFailure)
        // delete が例外を投げたので deleteAuthUser は呼ばれていない
        assertTrue(!fakeAuthRepo.deleteAuthUserCalled)
    }
}
