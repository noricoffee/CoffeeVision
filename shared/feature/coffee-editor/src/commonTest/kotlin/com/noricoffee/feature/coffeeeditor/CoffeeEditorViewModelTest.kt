package com.noricoffee.feature.coffeeeditor

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * [CoffeeEditorViewModel] の cafe 座標 / photoReferences 引き継ぎの状態遷移テスト。
 *
 * ## 検証するシナリオ（shared コードレビュー指摘 #2）
 * - Create + Places 選択 → save で選択 Cafe の latitude / longitude / photoReferences が保存される
 * - Create + 手入力カフェ（Places 非選択）→ UUID placeId + 座標 null で保存される
 * - Create + cafeName 空 → cafe = null で保存される
 * - Edit（初期レコードに座標あり・選択なし）→ 座標が引き継がれる
 * - onAppear 再呼び出しで前回の選択状態（selectedCafe / selectedPlaceId）がリセットされる
 *
 * ## スコープ管理
 * [CoffeeEditorViewModel] は `runTest` の `TestScope` を親にした独自 `viewModelScope` を作るため、
 * 各テストの最後に `vm.clear()` を呼ばないと `runTest` が `UncompletedCoroutinesError` を報告する。
 * テンプレート: `try { ... } finally { vm.clear() }` を各テストで使用する。
 */
class CoffeeEditorViewModelTest {

    // ─────────────────────────────────────────────────
    // Fakes
    // ─────────────────────────────────────────────────

    private class FakeCoffeeRepository : CoffeeRepository {

        val savedRecords = mutableListOf<CoffeeRecord>()

        /** [observeById] が返す Flow。Edit モードの初回ロードに使う。 */
        val byIdFlow = MutableStateFlow<CoffeeRecord?>(null)

        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())

        override fun observeById(id: String): Flow<CoffeeRecord?> = byIdFlow

        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> =
            flowOf(emptyList())

        override suspend fun save(record: CoffeeRecord) {
            savedRecords += record
        }

        override suspend fun delete(userId: String, id: String) {
            savedRecords.removeAll { it.id == id }
        }
    }

    // ─────────────────────────────────────────────────
    // Fixtures
    // ─────────────────────────────────────────────────

    private fun sampleCafe(
        placeId: String = "places-1",
        name: String = "Places カフェ",
        latitude: Double? = 35.658,
        longitude: Double? = 139.701,
        photoReferences: List<String> = listOf("photo-ref-a", "photo-ref-b"),
    ): Cafe = Cafe(
        placeId = placeId,
        name = name,
        address = "東京都渋谷区テスト 1-2-3",
        latitude = latitude,
        longitude = longitude,
        photoReferences = photoReferences,
        websiteUrl = "https://example.com",
        mapsUrl = "https://maps.google.com/?cid=123",
    )

    private fun sampleRecord(
        id: String = "record-1",
        userId: String = "user-1",
        cafe: Cafe? = null,
    ): CoffeeRecord = CoffeeRecord(
        id = id,
        userId = userId,
        cafe = cafe,
        visitedOn = LocalDate(2026, 1, 1),
        rating = 4.0,
        notes = "",
        photos = emptyList(),
        name = "エチオピア ハンドドリップ",
        brewMethod = BrewMethod.HandDrip,
        origin = "Ethiopia",
        variety = null,
        processing = null,
        roastLevel = null,
        cup = null,
        tasting = null,
        tags = emptyList(),
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    // ─────────────────────────────────────────────────
    // Tests — Create + Places 選択
    // ─────────────────────────────────────────────────

    @Test
    fun onSaveTapped_create_withPlacesSelection_persistsSelectedCafeCoordinatesAndPhotoReferences() = runTest {
        val fake = FakeCoffeeRepository()
        val vm = CoffeeEditorViewModel(coffeeRepository = fake, scope = this)
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Create, userId = "user-1")

            val selected = sampleCafe(
                placeId = "places-1",
                latitude = 35.658,
                longitude = 139.701,
                photoReferences = listOf("ref-a", "ref-b"),
            )
            vm.onPlacesCafeSelected(selected)
            vm.onNameChanged("ハンドドリップ")
            vm.onRatingChanged(4.5)

            vm.onSaveTapped()
            testScheduler.advanceUntilIdle()

            val saved = fake.savedRecords.single()
            val cafe = assertNotNull(saved.cafe)
            assertEquals("places-1", cafe.placeId)
            assertEquals(35.658, cafe.latitude)
            assertEquals(139.701, cafe.longitude)
            assertEquals(listOf("ref-a", "ref-b"), cafe.photoReferences)
            assertEquals(selected.name, cafe.name)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — Create + 手入力カフェ（Places 非選択）
    // ─────────────────────────────────────────────────

    @Test
    fun onSaveTapped_create_manualCafeEntry_usesUuidPlaceIdAndNullCoordinates() = runTest {
        val fake = FakeCoffeeRepository()
        val vm = CoffeeEditorViewModel(coffeeRepository = fake, scope = this)
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Create, userId = "user-1")

            vm.onCafeNameChanged("手入力カフェ")
            vm.onNameChanged("コーヒー")
            vm.onRatingChanged(3.5)

            vm.onSaveTapped()
            testScheduler.advanceUntilIdle()

            val saved = fake.savedRecords.single()
            val cafe = assertNotNull(saved.cafe)
            assertEquals("手入力カフェ", cafe.name)
            assertNull(cafe.latitude)
            assertNull(cafe.longitude)
            assertTrue(cafe.photoReferences.isEmpty())
            assertTrue(cafe.placeId.isNotBlank())
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — Create + cafeName 空
    // ─────────────────────────────────────────────────

    @Test
    fun onSaveTapped_create_blankCafeName_savesNullCafe() = runTest {
        val fake = FakeCoffeeRepository()
        val vm = CoffeeEditorViewModel(coffeeRepository = fake, scope = this)
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Create, userId = "user-1")

            vm.onNameChanged("セルフ抽出コーヒー")
            vm.onRatingChanged(3.0)

            vm.onSaveTapped()
            testScheduler.advanceUntilIdle()

            val saved = fake.savedRecords.single()
            assertNull(saved.cafe)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — Edit（初期レコードに座標あり・選択なし）
    // ─────────────────────────────────────────────────

    @Test
    fun onSaveTapped_edit_noSelection_inheritsInitialCafeCoordinates() = runTest {
        val initialCafe = sampleCafe(
            placeId = "initial-place",
            latitude = 35.0,
            longitude = 139.0,
            photoReferences = listOf("ref-x"),
        )
        val initialRecord = sampleRecord(id = "record-1", userId = "user-1", cafe = initialCafe)

        val fake = FakeCoffeeRepository()
        fake.byIdFlow.value = initialRecord

        val vm = CoffeeEditorViewModel(coffeeRepository = fake, scope = this)
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Edit(initialRecord.id), userId = "user-1")
            testScheduler.advanceUntilIdle()

            // Places を再選択せずにカフェ名だけ書き換える
            vm.onCafeNameChanged("リネームしたカフェ")

            vm.onSaveTapped()
            testScheduler.advanceUntilIdle()

            val saved = fake.savedRecords.single()
            val cafe = assertNotNull(saved.cafe)
            assertEquals("initial-place", cafe.placeId)
            assertEquals(35.0, cafe.latitude)
            assertEquals(139.0, cafe.longitude)
            assertEquals(listOf("ref-x"), cafe.photoReferences)
            assertEquals("リネームしたカフェ", cafe.name)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — onAppear 再呼び出しでの選択状態リセット
    // ─────────────────────────────────────────────────

    @Test
    fun onAppear_resetsPreviousSelection() = runTest {
        val fake = FakeCoffeeRepository()
        val vm = CoffeeEditorViewModel(coffeeRepository = fake, scope = this)
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Create, userId = "user-1")

            val selected = sampleCafe(placeId = "places-1", latitude = 35.658, longitude = 139.701)
            vm.onPlacesCafeSelected(selected)

            // 画面が再表示された想定（前回の Places 選択はリセットされるべき）
            vm.onAppear(CoffeeEditorViewModel.Mode.Create, userId = "user-1")
            assertNull(vm.state.value.selectedPlaceId, "onAppear 後は selectedPlaceId がリセットされる")

            vm.onCafeNameChanged("再入力カフェ")
            vm.onNameChanged("コーヒー")
            vm.onRatingChanged(4.0)

            vm.onSaveTapped()
            testScheduler.advanceUntilIdle()

            val saved = fake.savedRecords.single()
            val cafe = assertNotNull(saved.cafe)
            assertNotEquals("places-1", cafe.placeId)
            assertNull(cafe.latitude)
            assertNull(cafe.longitude)
        } finally {
            vm.clear()
        }
    }
}
