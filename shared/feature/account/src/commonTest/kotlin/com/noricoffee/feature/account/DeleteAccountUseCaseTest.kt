package com.noricoffee.feature.account

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.model.AuthAccount
import com.noricoffee.domain.model.SavedCafe
import com.noricoffee.domain.usecase.DeleteAccountUseCase
import com.noricoffee.repository.AuthRepository
import com.noricoffee.repository.CoffeeRepository
import com.noricoffee.repository.SavedCafeRepository
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
 * ## 検証する処理順序（[DeleteAccountUseCase] の KDoc 参照）
 * 1. SavedCafe（「行きたい店」）を全削除
 * 2. CoffeeRecord を全削除
 * 3. [AuthRepository.deleteUserProfile]（Firestore `users/{uid}` ルートドキュメント削除）
 * 4. [AuthRepository.deleteAuthUser]（Auth ユーザー本体削除）
 *
 * - 全件削除されてから 3, 4 が順番どおりに呼ばれること
 * - SavedCafe / CoffeeRecord がゼロ件でも後続が実行されること
 * - SavedCafe 削除が例外を投げたとき、以降の一切（coffees / deleteUserProfile / deleteAuthUser）が
 *   呼ばれないこと
 * - [AuthRepository.deleteUserProfile] が例外を投げたとき [AuthRepository.deleteAuthUser] が
 *   呼ばれないこと（ルートドキュメントを消せないまま Auth を消すと永久に孤児化するため）
 */
class DeleteAccountUseCaseTest {

    // ─────────────────────────────────────────────────
    // Fakes（4 者共通の callOrder に記録して順序を検証する）
    // ─────────────────────────────────────────────────

    private class RecordingSavedCafeRepository(
        private val savedCafes: List<SavedCafe>,
        private val deleteError: Exception? = null,
        private val callOrder: MutableList<String>,
    ) : SavedCafeRepository {
        val deletedPlaceIds = mutableListOf<String>()

        override fun observeAll(userId: String): Flow<List<SavedCafe>> = flowOf(savedCafes)
        override fun observeByPlaceId(userId: String, placeId: String): Flow<SavedCafe?> = flowOf(null)
        override suspend fun save(savedCafe: SavedCafe) = Unit

        override suspend fun delete(userId: String, placeId: String) {
            deleteError?.let { throw it }
            deletedPlaceIds.add(placeId)
            callOrder.add("savedCafe:$placeId")
        }
    }

    private class RecordingCoffeeRepository(
        private val records: List<CoffeeRecord>,
        private val deleteError: Exception? = null,
        private val callOrder: MutableList<String>,
    ) : CoffeeRepository {
        val deletedIds = mutableListOf<String>()

        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(records)
        override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)
        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit

        override suspend fun delete(userId: String, id: String) {
            deleteError?.let { throw it }
            deletedIds.add(id)
            callOrder.add("coffee:$id")
        }
    }

    private class RecordingAuthRepository(
        private val deleteUserProfileError: Exception? = null,
        private val deleteAuthUserError: Exception? = null,
        private val callOrder: MutableList<String>,
    ) : AuthRepository {
        var deleteUserProfileCalled = false
        var deleteAuthUserCalled = false

        override suspend fun signInAnonymouslyIfNeeded(): String = "uid"
        override fun observeUserId(): Flow<String?> = flowOf("uid")
        override fun observeAccount(): Flow<AuthAccount?> = flowOf(null)
        override suspend fun linkWithApple(idToken: String, rawNonce: String): AuthAccount =
            throw UnsupportedOperationException()
        override suspend fun signOut() = Unit

        override suspend fun deleteUserProfile() {
            deleteUserProfileError?.let { throw it }
            deleteUserProfileCalled = true
            callOrder.add("deleteUserProfile")
        }

        override suspend fun deleteAuthUser() {
            deleteAuthUserError?.let { throw it }
            deleteAuthUserCalled = true
            callOrder.add("deleteAuthUser")
        }

        override suspend fun updateAnalyticsConsent(consent: Boolean) = Unit
        override fun observeAnalyticsConsent(): Flow<Boolean> = flowOf(false)
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
        region = null,
        variety = null,
        processing = null,
        roastLevel = null,
        cup = null,
        brewRecipe = null,
        tasting = null,
        createdAt = Instant.fromEpochSeconds(0),
        updatedAt = Instant.fromEpochSeconds(0),
    )

    private fun makeCafe(placeId: String): Cafe = Cafe(
        placeId = placeId,
        name = "Test Cafe $placeId",
        address = null,
        latitude = null,
        longitude = null,
        photoReferences = emptyList(),
        websiteUrl = null,
        mapsUrl = null,
    )

    private fun makeSavedCafe(placeId: String, userId: String = "user-01"): SavedCafe = SavedCafe(
        userId = userId,
        cafe = makeCafe(placeId),
        note = "",
        savedAt = Instant.fromEpochSeconds(0),
    )

    // ─────────────────────────────────────────────────
    // Tests
    // ─────────────────────────────────────────────────

    @Test
    fun invoke_deletesAllSavedCafesAndRecords_thenCallsDeleteUserProfileThenDeleteAuthUser() = runTest {
        val callOrder = mutableListOf<String>()
        val savedCafes = listOf(makeSavedCafe("p1"), makeSavedCafe("p2"))
        val records = listOf(makeRecord("r1"), makeRecord("r2"), makeRecord("r3"))
        val fakeSavedCafeRepo = RecordingSavedCafeRepository(savedCafes, callOrder = callOrder)
        val fakeCoffeeRepo = RecordingCoffeeRepository(records, callOrder = callOrder)
        val fakeAuthRepo = RecordingAuthRepository(callOrder = callOrder)

        val useCase = DeleteAccountUseCase(fakeCoffeeRepo, fakeSavedCafeRepo, fakeAuthRepo)
        useCase(userId = "user-01")

        // 全 SavedCafe / CoffeeRecord が削除されたこと
        assertEquals(setOf("p1", "p2"), fakeSavedCafeRepo.deletedPlaceIds.toSet())
        assertEquals(setOf("r1", "r2", "r3"), fakeCoffeeRepo.deletedIds.toSet())
        // deleteUserProfile / deleteAuthUser が呼ばれたこと
        assertTrue(fakeAuthRepo.deleteUserProfileCalled)
        assertTrue(fakeAuthRepo.deleteAuthUserCalled)

        // 呼び出し順序: savedCafe 群 → coffee 群 → deleteUserProfile → deleteAuthUser
        val savedCafeEndIndex = callOrder.indexOfLast { it.startsWith("savedCafe:") }
        val coffeeStartIndex = callOrder.indexOfFirst { it.startsWith("coffee:") }
        val coffeeEndIndex = callOrder.indexOfLast { it.startsWith("coffee:") }
        val deleteUserProfileIndex = callOrder.indexOf("deleteUserProfile")
        val deleteAuthUserIndex = callOrder.indexOf("deleteAuthUser")

        assertTrue(savedCafeEndIndex < coffeeStartIndex)
        assertTrue(coffeeEndIndex < deleteUserProfileIndex)
        assertTrue(deleteUserProfileIndex < deleteAuthUserIndex)
    }

    @Test
    fun invoke_withNoSavedCafesOrRecords_stillCallsDeleteUserProfileAndDeleteAuthUser() = runTest {
        val callOrder = mutableListOf<String>()
        val fakeSavedCafeRepo = RecordingSavedCafeRepository(emptyList(), callOrder = callOrder)
        val fakeCoffeeRepo = RecordingCoffeeRepository(emptyList(), callOrder = callOrder)
        val fakeAuthRepo = RecordingAuthRepository(callOrder = callOrder)

        val useCase = DeleteAccountUseCase(fakeCoffeeRepo, fakeSavedCafeRepo, fakeAuthRepo)
        useCase(userId = "user-01")

        assertTrue(fakeSavedCafeRepo.deletedPlaceIds.isEmpty())
        assertTrue(fakeCoffeeRepo.deletedIds.isEmpty())
        assertTrue(fakeAuthRepo.deleteUserProfileCalled)
        assertTrue(fakeAuthRepo.deleteAuthUserCalled)
    }

    @Test
    fun invoke_whenSavedCafeDeleteThrows_doesNotDeleteCoffeesOrCallAuthMethods() = runTest {
        val callOrder = mutableListOf<String>()
        val savedCafes = listOf(makeSavedCafe("p1"))
        val records = listOf(makeRecord("r1"))
        val fakeSavedCafeRepo = RecordingSavedCafeRepository(
            savedCafes,
            deleteError = Exception("SavedCafe delete error"),
            callOrder = callOrder,
        )
        val fakeCoffeeRepo = RecordingCoffeeRepository(records, callOrder = callOrder)
        val fakeAuthRepo = RecordingAuthRepository(callOrder = callOrder)

        val useCase = DeleteAccountUseCase(fakeCoffeeRepo, fakeSavedCafeRepo, fakeAuthRepo)
        val result = runCatching { useCase(userId = "user-01") }

        assertTrue(result.isFailure)
        assertTrue(fakeCoffeeRepo.deletedIds.isEmpty())
        assertTrue(!fakeAuthRepo.deleteUserProfileCalled)
        assertTrue(!fakeAuthRepo.deleteAuthUserCalled)
    }

    @Test
    fun invoke_whenCoffeeDeleteThrows_doesNotCallAuthMethods() = runTest {
        val callOrder = mutableListOf<String>()
        val savedCafes = listOf(makeSavedCafe("p1"))
        val records = listOf(makeRecord("r1"))
        val fakeSavedCafeRepo = RecordingSavedCafeRepository(savedCafes, callOrder = callOrder)
        val fakeCoffeeRepo = RecordingCoffeeRepository(
            records,
            deleteError = Exception("Coffee delete error"),
            callOrder = callOrder,
        )
        val fakeAuthRepo = RecordingAuthRepository(callOrder = callOrder)

        val useCase = DeleteAccountUseCase(fakeCoffeeRepo, fakeSavedCafeRepo, fakeAuthRepo)
        val result = runCatching { useCase(userId = "user-01") }

        assertTrue(result.isFailure)
        // SavedCafe は先に削除完了しているが coffee で止まる
        assertEquals(setOf("p1"), fakeSavedCafeRepo.deletedPlaceIds.toSet())
        assertTrue(!fakeAuthRepo.deleteUserProfileCalled)
        assertTrue(!fakeAuthRepo.deleteAuthUserCalled)
    }

    @Test
    fun invoke_whenDeleteUserProfileThrows_doesNotCallDeleteAuthUser() = runTest {
        val callOrder = mutableListOf<String>()
        val savedCafes = listOf(makeSavedCafe("p1"))
        val records = listOf(makeRecord("r1"))
        val fakeSavedCafeRepo = RecordingSavedCafeRepository(savedCafes, callOrder = callOrder)
        val fakeCoffeeRepo = RecordingCoffeeRepository(records, callOrder = callOrder)
        val fakeAuthRepo = RecordingAuthRepository(
            deleteUserProfileError = Exception("deleteUserProfile error"),
            callOrder = callOrder,
        )

        val useCase = DeleteAccountUseCase(fakeCoffeeRepo, fakeSavedCafeRepo, fakeAuthRepo)
        val result = runCatching { useCase(userId = "user-01") }

        assertTrue(result.isFailure)
        // サブコレクションは削除済みだが、ルートドキュメントが消せなかったので Auth ユーザーは残す
        assertEquals(setOf("p1"), fakeSavedCafeRepo.deletedPlaceIds.toSet())
        assertEquals(setOf("r1"), fakeCoffeeRepo.deletedIds.toSet())
        assertTrue(!fakeAuthRepo.deleteAuthUserCalled)
    }
}
