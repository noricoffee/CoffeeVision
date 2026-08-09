package com.noricoffee.repository

import com.noricoffee.db.AppDatabase
import com.noricoffee.db.createInMemoryTestSqlDriver
import com.noricoffee.dev.DummyCoffeeData
import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.Photo
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.isActive
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
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
 * [CoffeeRepositoryImpl] の合成挙動を検証する。Firestore SDK 自体は触らず、
 * [FakeRemoteCoffeeDataSource] を差し込むことで「ローカル → リモートの順序」と
 * 「リモート変更がローカル DB に反映される」ことを確認する。
 */
class CoffeeRepositoryImplTest {

    private lateinit var db: AppDatabase
    private val driver = createInMemoryTestSqlDriver()
    private lateinit var local: LocalCoffeeRepository
    private lateinit var fakeRemote: FakeRemoteCoffeeDataSource

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
        local = LocalCoffeeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteCoffeeDataSource()
        val repo = CoffeeRepositoryImpl(local, fakeRemote)

        val record = sampleRecord()
        repo.save(record)

        // ローカルに保存されている
        assertEquals(record, local.observeById(record.id).first())

        // リモートにも upload された
        assertEquals(listOf(record), fakeRemote.uploaded)
    }

    @Test
    fun save_propagates_remote_failure_by_default() = runTest {
        local = LocalCoffeeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteCoffeeDataSource(failUpload = true)
        val repo = CoffeeRepositoryImpl(local, fakeRemote)

        val record = sampleRecord()

        assertFailsWith<RuntimeException> {
            repo.save(record)
        }

        // ローカル書き込みは成功している（Source of Truth はローカル）
        assertEquals(record, local.observeById(record.id).first())
    }

    @Test
    fun save_ignores_remote_failure_when_policy_set() = runTest {
        local = LocalCoffeeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteCoffeeDataSource(failUpload = true)
        val repo = CoffeeRepositoryImpl(
            local = local,
            remote = fakeRemote,
            writePolicy = CoffeeRepositoryImpl.WritePolicy.IgnoreRemoteFailure,
        )

        val record = sampleRecord()
        repo.save(record) // 例外を投げない

        assertEquals(record, local.observeById(record.id).first())
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun start_sync_writes_remote_changes_into_local_db() = runTest {
        local = LocalCoffeeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteCoffeeDataSource()
        val repo = CoffeeRepositoryImpl(local, fakeRemote)

        val scope = CoroutineScope(coroutineContext)
        val job = repo.startSync(USER_ID, scope)

        // collect が確立するまで進める
        runCurrent()

        val r1 = sampleRecord(id = "r-remote-1")
        fakeRemote.emit(listOf(r1))
        runCurrent()

        val list = local.observeAll(USER_ID).first()
        assertEquals(listOf(r1.id), list.map { it.id })

        job.cancel()
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun start_sync_reconciles_deletion_of_records_missing_from_snapshot() = runTest {
        local = LocalCoffeeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteCoffeeDataSource()
        val repo = CoffeeRepositoryImpl(local, fakeRemote)

        val scope = CoroutineScope(coroutineContext)
        val job = repo.startSync(USER_ID, scope)
        runCurrent()

        // photos を含む 2 件のレコードがまず同期される
        val r1 = sampleRecord(id = "r-remote-1")
        val r2 = sampleRecord(id = "r-remote-2")
        fakeRemote.emit(listOf(r1, r2))
        runCurrent()

        assertEquals(
            setOf("r-remote-1", "r-remote-2"),
            local.observeAll(USER_ID).first().map { it.id }.toSet(),
        )

        // 他端末で r-remote-1 が削除され、次のスナップショットには r-remote-2 のみが含まれる
        fakeRemote.emit(listOf(r2))
        runCurrent()

        assertEquals(listOf("r-remote-2"), local.observeAll(USER_ID).first().map { it.id })

        job.cancel()
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun start_sync_does_not_delete_dummy_coffee_data_missing_from_snapshot() = runTest {
        local = LocalCoffeeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteCoffeeDataSource()
        val repo = CoffeeRepositoryImpl(local, fakeRemote)

        // dev ダミーデータはローカル DB 限定（Firestore には流さない設計）のため、
        // ここではローカルにだけ事前投入してその状況を再現する
        val dummyId = DummyCoffeeData.ids.first()
        local.save(sampleRecord(id = dummyId))

        val scope = CoroutineScope(coroutineContext)
        val job = repo.startSync(USER_ID, scope)
        runCurrent()

        // スナップショットにはダミー id を含まない別レコードのみ届く
        fakeRemote.emit(listOf(sampleRecord(id = "r-remote-1")))
        runCurrent()

        val ids = local.observeAll(USER_ID).first().map { it.id }.toSet()
        assertTrue(dummyId in ids, "DummyCoffeeData.ids はスナップショットに無くても削除されない")
        assertTrue("r-remote-1" in ids)

        job.cancel()
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun start_sync_stops_quietly_when_remote_flow_fails_without_killing_the_scope() = runTest {
        local = LocalCoffeeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteCoffeeDataSource()
        val repo = CoffeeRepositoryImpl(local, fakeRemote)

        val scope = CoroutineScope(coroutineContext)
        val job = repo.startSync(USER_ID, scope)
        runCurrent()

        // 失敗前に届いたスナップショットは通常どおり反映される
        fakeRemote.emit(listOf(sampleRecord(id = "r-remote-1")))
        runCurrent()
        assertEquals(listOf("r-remote-1"), local.observeAll(USER_ID).first().map { it.id })

        // 上流が回復不能な失敗（Firestore の permission-denied 相当）で Flow を例外終了させる
        fakeRemote.fail(RuntimeException("PERMISSION_DENIED"))
        runCurrent()

        // 例外は startSync の中で受け止められ、scope へは漏れない
        assertTrue(job.isCompleted, "Flow の例外終了で Job は完了する（宙吊りにならない）")
        assertTrue(!job.isCancelled, "例外は catch されるので Job は失敗扱いにならない")
        assertTrue(scope.isActive, "同期が止まっても呼び出し元スコープは生き続ける")

        // ローカル DB は Single Source of Truth なので、同期停止後も読み書きは動く
        repo.save(sampleRecord(id = "after-failure"))
        val ids = local.observeAll(USER_ID).first().map { it.id }.toSet()
        assertEquals(setOf("r-remote-1", "after-failure"), ids)
    }

    @Test
    fun observe_reads_local_db_only() = runTest {
        local = LocalCoffeeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteCoffeeDataSource()
        val repo = CoffeeRepositoryImpl(local, fakeRemote)

        // リモートには直接書かず、ローカルにのみ書く
        local.save(sampleRecord(id = "local-only"))

        val list = repo.observeAll(USER_ID).first()
        assertEquals(listOf("local-only"), list.map { it.id })
        assertTrue(fakeRemote.uploaded.isEmpty(), "観測経路はリモートを叩かない")
    }

    @Test
    fun delete_removes_local_then_remote_in_order() = runTest {
        local = LocalCoffeeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteCoffeeDataSource()
        val repo = CoffeeRepositoryImpl(local, fakeRemote)

        val record = sampleRecord()
        repo.save(record)
        repo.delete(USER_ID, record.id)

        // ローカルから削除されている
        val loaded = local.observeById(record.id).first()
        assertTrue(loaded == null, "ローカルから削除されているはず")

        // リモートにも remove が記録されている
        assertEquals(listOf(USER_ID to record.id), fakeRemote.removed)
    }

    @Test
    fun delete_propagates_remote_failure_by_default() = runTest {
        local = LocalCoffeeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteCoffeeDataSource(failRemove = true)
        val repo = CoffeeRepositoryImpl(local, fakeRemote)

        val record = sampleRecord()
        repo.save(record)

        assertFailsWith<RuntimeException> {
            repo.delete(USER_ID, record.id)
        }

        // ローカルは既に削除されている（Source of Truth はローカル）
        val loaded = local.observeById(record.id).first()
        assertTrue(loaded == null, "ローカルは削除済みのはず")
    }

    // --- cafe が null のレコードの合成挙動テスト ---

    @Test
    fun save_and_sync_work_with_null_cafe_record() = runTest {
        local = LocalCoffeeRepository(db, coroutineContext)
        fakeRemote = FakeRemoteCoffeeDataSource()
        val repo = CoffeeRepositoryImpl(local, fakeRemote)

        val selfExtract = sampleRecord(id = "self", cafe = null)
        repo.save(selfExtract)

        val loaded = local.observeById(selfExtract.id).first()
        assertEquals(selfExtract, loaded)
        assertEquals(listOf(selfExtract), fakeRemote.uploaded)
    }

    private class FakeRemoteCoffeeDataSource(
        private val failUpload: Boolean = false,
        private val failRemove: Boolean = false,
    ) : RemoteCoffeeDataSource {

        /**
         * `observeChanges` が流す信号。スナップショットだけでなく
         * **回復不能な失敗による Flow の例外終了**（[RemoteCoffeeDataSource.observeChanges]
         * のエラー契約）も再現できるようにするための sealed。
         */
        private sealed interface Signal {
            data class Snapshot(val records: List<CoffeeRecord>) : Signal
            data class Failure(val error: Throwable) : Signal
        }

        val uploaded = mutableListOf<CoffeeRecord>()
        val removed = mutableListOf<Pair<String, String>>()
        private val changes = MutableSharedFlow<Signal>(replay = 0, extraBufferCapacity = 8)

        override fun observeChanges(userId: String): Flow<List<CoffeeRecord>> = flow {
            changes.collect { signal ->
                when (signal) {
                    is Signal.Snapshot -> emit(signal.records)
                    is Signal.Failure -> throw signal.error
                }
            }
        }

        override suspend fun upload(record: CoffeeRecord) {
            if (failUpload) throw RuntimeException("remote upload failed")
            uploaded.add(record)
        }

        override suspend fun remove(userId: String, id: String) {
            if (failRemove) throw RuntimeException("remote remove failed")
            removed.add(userId to id)
        }

        suspend fun emit(records: List<CoffeeRecord>) {
            changes.emit(Signal.Snapshot(records))
        }

        /** 上流が回復不能な失敗をして Flow が例外終了する状況を再現する。 */
        suspend fun fail(error: Throwable) {
            changes.emit(Signal.Failure(error))
        }
    }

    private companion object {
        const val USER_ID = "test-user"

        fun sampleRecord(
            id: String = "record-1",
            placeId: String = "place-1",
            visitedOn: LocalDate = LocalDate(2026, 6, 2),
            cafe: Cafe? = Cafe(
                placeId = placeId,
                name = "Blue Bottle 三軒茶屋",
                address = "東京都世田谷区",
                latitude = 35.6448,
                longitude = 139.6694,
                photoReferences = listOf("ref-1"),
                websiteUrl = null,
                mapsUrl = null,
            ),
        ): CoffeeRecord = CoffeeRecord(
            id = id,
            userId = USER_ID,
            cafe = cafe,
            visitedOn = visitedOn,
            rating = 4.0,
            notes = "",
            photos = listOf(
                Photo(
                    id = "p1",
                    fileName = "p1.jpg",
                    localPath = "photos/p1.jpg",
                    remoteUrl = null,
                    width = 1920,
                    height = 1080,
                    createdAt = Instant.fromEpochMilliseconds(1_700_000_000_000),
                ),
            ),
            name = "ケニア",
            brewMethod = BrewMethod.HandDrip,
            origin = "ケニア",
            region = null,
            variety = "SL28",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = null,
            brewRecipe = null,
            tasting = null,
            createdAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
            updatedAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
        )
    }
}
