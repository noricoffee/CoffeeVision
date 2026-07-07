package com.noricoffee.repository

import com.noricoffee.db.AppDatabase
import com.noricoffee.db.createInMemoryTestSqlDriver
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.model.SavedCafe
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlin.coroutines.coroutineContext
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/**
 * [SavedCafeRepositoryImpl] の合成挙動を検証する。[CoffeeRepositoryImplTest] と同じパターンで
 * [FakeRemoteSavedCafeDataSource] を差し込み、「ローカル → リモートの順序」と
 * 「リモート変更（reconciliation 含む）がローカル DB に反映される」ことを確認する。
 */
class SavedCafeRepositoryImplTest {

    private lateinit var db: AppDatabase
    private val driver = createInMemoryTestSqlDriver()
    private lateinit var local: LocalSavedCafeRepository
    private lateinit var fakeRemote: FakeRemoteSavedCafeDataSource

    @BeforeTest
    fun setUp() {
        db = AppDatabase(driver)
    }

    @AfterTest
    fun tearDown() {
        driver.close()
    }

    @Test
    fun save_writes_local_then_remote_in_order() = runTest {
        local = LocalSavedCafeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteSavedCafeDataSource()
        val repo = SavedCafeRepositoryImpl(local, fakeRemote)

        val savedCafe = sampleSavedCafe()
        repo.save(savedCafe)

        assertEquals(savedCafe, local.observeByPlaceId(USER_ID, savedCafe.cafe.placeId).first())
        assertEquals(listOf(savedCafe), fakeRemote.uploaded)
    }

    @Test
    fun save_propagates_remote_failure_by_default() = runTest {
        local = LocalSavedCafeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteSavedCafeDataSource(failUpload = true)
        val repo = SavedCafeRepositoryImpl(local, fakeRemote)

        val savedCafe = sampleSavedCafe()

        assertFailsWith<RuntimeException> {
            repo.save(savedCafe)
        }

        // ローカル書き込みは成功している（Source of Truth はローカル）
        assertEquals(savedCafe, local.observeByPlaceId(USER_ID, savedCafe.cafe.placeId).first())
    }

    @Test
    fun save_ignores_remote_failure_when_policy_set() = runTest {
        local = LocalSavedCafeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteSavedCafeDataSource(failUpload = true)
        val repo = SavedCafeRepositoryImpl(
            local = local,
            remote = fakeRemote,
            writePolicy = CoffeeRepositoryImpl.WritePolicy.IgnoreRemoteFailure,
        )

        val savedCafe = sampleSavedCafe()
        repo.save(savedCafe) // 例外を投げない

        assertEquals(savedCafe, local.observeByPlaceId(USER_ID, savedCafe.cafe.placeId).first())
    }

    @Test
    fun delete_removes_local_then_remote_in_order() = runTest {
        local = LocalSavedCafeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteSavedCafeDataSource()
        val repo = SavedCafeRepositoryImpl(local, fakeRemote)

        val savedCafe = sampleSavedCafe()
        repo.save(savedCafe)
        repo.delete(USER_ID, savedCafe.cafe.placeId)

        assertEquals(null, local.observeByPlaceId(USER_ID, savedCafe.cafe.placeId).first())
        assertEquals(listOf(USER_ID to savedCafe.cafe.placeId), fakeRemote.removed)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun start_sync_writes_remote_changes_into_local_db() = runTest {
        local = LocalSavedCafeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteSavedCafeDataSource()
        val repo = SavedCafeRepositoryImpl(local, fakeRemote)

        val scope = CoroutineScope(coroutineContext)
        val job = repo.startSync(USER_ID, scope)
        runCurrent()

        val remoteSaved = sampleSavedCafe(placeId = "place-remote-1")
        fakeRemote.emit(listOf(remoteSaved))
        runCurrent()

        val list = local.observeAll(USER_ID).first()
        assertEquals(listOf("place-remote-1"), list.map { it.cafe.placeId })

        job.cancel()
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun start_sync_reconciles_deletion_of_saved_cafes_missing_from_snapshot() = runTest {
        local = LocalSavedCafeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteSavedCafeDataSource()
        val repo = SavedCafeRepositoryImpl(local, fakeRemote)

        val scope = CoroutineScope(coroutineContext)
        val job = repo.startSync(USER_ID, scope)
        runCurrent()

        val s1 = sampleSavedCafe(placeId = "place-1")
        val s2 = sampleSavedCafe(placeId = "place-2")
        fakeRemote.emit(listOf(s1, s2))
        runCurrent()

        assertEquals(
            setOf("place-1", "place-2"),
            local.observeAll(USER_ID).first().map { it.cafe.placeId }.toSet(),
        )

        // 他端末で place-1 が解除され、次のスナップショットには place-2 のみが含まれる
        fakeRemote.emit(listOf(s2))
        runCurrent()

        assertEquals(listOf("place-2"), local.observeAll(USER_ID).first().map { it.cafe.placeId })

        job.cancel()
    }

    @Test
    fun observe_reads_local_db_only() = runTest {
        local = LocalSavedCafeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteSavedCafeDataSource()
        val repo = SavedCafeRepositoryImpl(local, fakeRemote)

        local.save(sampleSavedCafe(placeId = "local-only"))

        val list = repo.observeAll(USER_ID).first()
        assertEquals(listOf("local-only"), list.map { it.cafe.placeId })
        assertTrue(fakeRemote.uploaded.isEmpty(), "観測経路はリモートを叩かない")
    }

    private class FakeRemoteSavedCafeDataSource(
        private val failUpload: Boolean = false,
        private val failRemove: Boolean = false,
    ) : RemoteSavedCafeDataSource {

        val uploaded = mutableListOf<SavedCafe>()
        val removed = mutableListOf<Pair<String, String>>()
        private val changes = MutableSharedFlow<List<SavedCafe>>(replay = 0, extraBufferCapacity = 8)

        override fun observeChanges(userId: String): Flow<List<SavedCafe>> = changes

        override suspend fun upload(savedCafe: SavedCafe) {
            if (failUpload) throw RuntimeException("remote upload failed")
            uploaded.add(savedCafe)
        }

        override suspend fun remove(userId: String, placeId: String) {
            if (failRemove) throw RuntimeException("remote remove failed")
            removed.add(userId to placeId)
        }

        suspend fun emit(savedCafes: List<SavedCafe>) {
            changes.emit(savedCafes)
        }
    }

    private companion object {
        const val USER_ID = "test-user"

        fun sampleSavedCafe(placeId: String = "place-1"): SavedCafe = SavedCafe(
            userId = USER_ID,
            cafe = Cafe(
                placeId = placeId,
                name = "Blue Bottle 三軒茶屋",
                address = "東京都世田谷区",
                latitude = 35.6448,
                longitude = 139.6694,
                photoReferences = listOf("ref-1"),
                websiteUrl = null,
                mapsUrl = null,
            ),
            note = "",
            savedAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
        )
    }
}
