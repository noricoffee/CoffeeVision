package com.noricoffee.repository

import com.noricoffee.db.AppDatabase
import com.noricoffee.db.createInMemoryTestSqlDriver
import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeItem
import com.noricoffee.domain.FoodItem
import com.noricoffee.domain.Photo
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.Visit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.coroutines.coroutineContext
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/**
 * `VisitRepositoryImpl` の合成挙動を検証する。Firestore SDK 自体は触らず、
 * `FakeRemoteVisitDataSource` を差し込むことで「ローカル → リモートの順序」と
 * 「リモート変更がローカル DB に反映される」ことを確認する。
 */
class VisitRepositoryImplTest {

    private lateinit var db: AppDatabase
    private val driver = createInMemoryTestSqlDriver()
    private lateinit var local: LocalVisitRepository
    private lateinit var fakeRemote: FakeRemoteVisitDataSource

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
        local = LocalVisitRepository(db, coroutineContext)
        fakeRemote = FakeRemoteVisitDataSource()
        val repo = VisitRepositoryImpl(local, fakeRemote)

        val visit = sampleVisit()
        repo.save(visit)

        // ローカルに保存されている
        assertEquals(visit, local.observeById(visit.id).first())

        // リモートにも upload された（順序は upload 呼び出し時にローカルから読めるため
        // ローカル先行が保証される）
        assertEquals(listOf(visit), fakeRemote.uploaded)
    }

    @Test
    fun save_propagates_remote_failure_by_default() = runTest {
        local = LocalVisitRepository(db, coroutineContext)
        fakeRemote = FakeRemoteVisitDataSource(failUpload = true)
        val repo = VisitRepositoryImpl(local, fakeRemote)

        val visit = sampleVisit()

        assertFailsWith<RuntimeException> {
            repo.save(visit)
        }

        // ローカル書き込みは成功している（既定ポリシーはローカルを Source of Truth として保つ）
        assertEquals(visit, local.observeById(visit.id).first())
    }

    @Test
    fun save_ignores_remote_failure_when_policy_set() = runTest {
        local = LocalVisitRepository(db, coroutineContext)
        fakeRemote = FakeRemoteVisitDataSource(failUpload = true)
        val repo = VisitRepositoryImpl(
            local = local,
            remote = fakeRemote,
            writePolicy = VisitRepositoryImpl.WritePolicy.IgnoreRemoteFailure,
        )

        val visit = sampleVisit()
        repo.save(visit) // 例外を投げない

        assertEquals(visit, local.observeById(visit.id).first())
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun start_sync_writes_remote_changes_into_local_db() = runTest {
        local = LocalVisitRepository(db, coroutineContext)
        fakeRemote = FakeRemoteVisitDataSource()
        val repo = VisitRepositoryImpl(local, fakeRemote)

        val scope = CoroutineScope(coroutineContext)
        val job = repo.startSync(USER_ID, scope)

        // collect が確立するまで進める
        runCurrent()

        val v1 = sampleVisit(id = "v-remote-1")
        fakeRemote.emit(listOf(v1))
        runCurrent()

        val list = local.observeAll(USER_ID).first()
        assertEquals(listOf(v1.id), list.map { it.id })

        job.cancel()
    }

    @Test
    fun observe_reads_local_db_only() = runTest {
        local = LocalVisitRepository(db, coroutineContext)
        fakeRemote = FakeRemoteVisitDataSource()
        val repo = VisitRepositoryImpl(local, fakeRemote)

        // リモートには直接書かず、ローカルにのみ書く
        local.save(sampleVisit(id = "local-only"))

        val list = repo.observeAll(USER_ID).first()
        assertEquals(listOf("local-only"), list.map { it.id })
        assertTrue(fakeRemote.uploaded.isEmpty(), "観測経路はリモートを叩かない")
    }

    @Test
    fun delete_removes_local_then_remote_in_order() = runTest {
        local = LocalVisitRepository(db, coroutineContext)
        fakeRemote = FakeRemoteVisitDataSource()
        val repo = VisitRepositoryImpl(local, fakeRemote)

        val visit = sampleVisit()
        repo.save(visit)
        repo.delete(USER_ID, visit.id)

        // ローカルから削除されている
        val loaded = local.observeById(visit.id).first()
        assertTrue(loaded == null, "ローカルから削除されているはず")

        // リモートにも remove が記録されている
        assertEquals(listOf(USER_ID to visit.id), fakeRemote.removed)
    }

    @Test
    fun delete_propagates_remote_failure_by_default() = runTest {
        local = LocalVisitRepository(db, coroutineContext)
        fakeRemote = FakeRemoteVisitDataSource(failRemove = true)
        val repo = VisitRepositoryImpl(local, fakeRemote)

        val visit = sampleVisit()
        repo.save(visit)

        assertFailsWith<RuntimeException> {
            repo.delete(USER_ID, visit.id)
        }

        // ローカルは既に削除されている（Source of Truth はローカル）
        val loaded = local.observeById(visit.id).first()
        assertTrue(loaded == null, "ローカルは削除済みのはず")
    }

    private class FakeRemoteVisitDataSource(
        private val failUpload: Boolean = false,
        private val failRemove: Boolean = false,
    ) : RemoteVisitDataSource {

        val uploaded = mutableListOf<Visit>()
        val removed = mutableListOf<Pair<String, String>>()
        private val changes = MutableSharedFlow<List<Visit>>(replay = 0, extraBufferCapacity = 8)

        override fun observeChanges(userId: String): Flow<List<Visit>> = changes

        override suspend fun upload(visit: Visit) {
            if (failUpload) throw RuntimeException("remote upload failed")
            uploaded.add(visit)
        }

        override suspend fun remove(userId: String, id: String) {
            if (failRemove) throw RuntimeException("remote remove failed")
            removed.add(userId to id)
        }

        suspend fun emit(visits: List<Visit>) {
            changes.emit(visits)
        }
    }

    private companion object {
        const val USER_ID = "test-user"

        fun sampleVisit(
            id: String = "visit-1",
            placeId: String = "place-1",
            visitedOn: LocalDate = LocalDate(2026, 6, 2),
        ): Visit = Visit(
            id = id,
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
            visitedOn = visitedOn,
            ambiance = "",
            rating = 4,
            notes = "",
            photos = listOf(
                Photo(
                    id = "p1",
                    fileName = "p1.jpg",
                    localPath = "visits/visit-1/p1.jpg",
                    remoteUrl = null,
                    width = 1920,
                    height = 1080,
                    createdAt = Instant.fromEpochMilliseconds(1_700_000_000_000),
                ),
            ),
            coffees = listOf(
                CoffeeItem(
                    id = "c1",
                    name = "ケニア",
                    brewMethod = BrewMethod.HandDrip,
                    origin = "ケニア",
                    variety = "SL28",
                    processing = ProcessingMethod.Washed,
                    roastLevel = RoastLevel.Medium,
                    cup = null,
                    rating = 5,
                    notes = null,
                ),
            ),
            foods = listOf(
                FoodItem(id = "f1", name = "バナナブレッド", rating = 4, notes = null),
            ),
            createdAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
            updatedAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
        )
    }
}
