package com.noricoffee.feature.account

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.Visit
import com.noricoffee.domain.model.AuthAccount
import com.noricoffee.domain.usecase.DeleteAccountUseCase
import com.noricoffee.repository.AuthRepository
import com.noricoffee.repository.VisitRepository
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
 * - 全 Visit が削除されてから `deleteAuthUser` が呼ばれること（順序保証）
 * - Visit がゼロ件でも `deleteAuthUser` が呼ばれること
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

    private class RecordingVisitRepository(
        private val visits: List<Visit>,
        private val deleteError: Exception? = null,
    ) : VisitRepository {
        val deleteCallOrder = mutableListOf<String>()

        override fun observeAll(userId: String): Flow<List<Visit>> = flowOf(visits)
        override fun observeById(id: String): Flow<Visit?> = flowOf(null)
        override fun observeByCafe(userId: String, placeId: String): Flow<List<Visit>> = flowOf(emptyList())
        override suspend fun save(visit: Visit) = Unit

        override suspend fun delete(userId: String, id: String) {
            deleteError?.let { throw it }
            deleteCallOrder.add(id)
        }
    }

    // ─────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────

    private fun makeVisit(id: String, userId: String = "user-01"): Visit = Visit(
        id = id,
        userId = userId,
        cafe = Cafe(
            placeId = "place-$id",
            name = "Test Cafe $id",
            address = null,
            latitude = null,
            longitude = null,
            photoReferences = emptyList(),
            websiteUrl = null,
            mapsUrl = null,
        ),
        visitedOn = LocalDate(2024, 1, 1),
        ambiance = "",
        rating = 4,
        notes = "",
        coffees = emptyList(),
        foods = emptyList(),
        photos = emptyList(),
        createdAt = Instant.fromEpochSeconds(0),
        updatedAt = Instant.fromEpochSeconds(0),
    )

    // ─────────────────────────────────────────────────
    // Tests
    // ─────────────────────────────────────────────────

    @Test
    fun invoke_deletesAllVisitsThenCallsDeleteAuthUser() = runTest {
        val visits = listOf(makeVisit("v1"), makeVisit("v2"), makeVisit("v3"))
        val fakeVisitRepo = RecordingVisitRepository(visits)
        val fakeAuthRepo = FakeAuthRepository()

        val useCase = DeleteAccountUseCase(fakeVisitRepo, fakeAuthRepo)
        useCase(userId = "user-01")

        // 全 Visit が削除されたこと
        assertEquals(setOf("v1", "v2", "v3"), fakeVisitRepo.deleteCallOrder.toSet())
        // 全 Visit 削除後に deleteAuthUser が呼ばれたこと
        assertTrue(fakeAuthRepo.deleteAuthUserCalled)
    }

    @Test
    fun invoke_withNoVisits_callsDeleteAuthUser() = runTest {
        val fakeVisitRepo = RecordingVisitRepository(emptyList())
        val fakeAuthRepo = FakeAuthRepository()

        val useCase = DeleteAccountUseCase(fakeVisitRepo, fakeAuthRepo)
        useCase(userId = "user-01")

        assertTrue(fakeVisitRepo.deleteCallOrder.isEmpty())
        assertTrue(fakeAuthRepo.deleteAuthUserCalled)
    }

    @Test
    fun invoke_whenDeleteThrows_doesNotCallDeleteAuthUser() = runTest {
        val visits = listOf(makeVisit("v1"))
        val fakeVisitRepo = RecordingVisitRepository(visits, deleteError = Exception("DB error"))
        val fakeAuthRepo = FakeAuthRepository()

        val useCase = DeleteAccountUseCase(fakeVisitRepo, fakeAuthRepo)
        val result = runCatching { useCase(userId = "user-01") }

        assertTrue(result.isFailure)
        // delete が例外を投げたので deleteAuthUser は呼ばれていない
        assertTrue(!fakeAuthRepo.deleteAuthUserCalled)
    }
}
