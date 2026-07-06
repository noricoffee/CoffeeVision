package com.noricoffee.feature.coffeeeditor

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.LocationBias
import com.noricoffee.domain.Photo
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.TastingScores
import com.noricoffee.repository.CafeRepository
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.todayIn
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
        rating: Double = 4.0,
        notes: String = "",
        photos: List<Photo> = emptyList(),
        variety: String? = null,
        processing: ProcessingMethod? = null,
        roastLevel: RoastLevel? = null,
        cup: String? = null,
        tasting: TastingScores? = null,
        tags: List<String> = emptyList(),
    ): CoffeeRecord = CoffeeRecord(
        id = id,
        userId = userId,
        cafe = cafe,
        visitedOn = LocalDate(2026, 1, 1),
        rating = rating,
        notes = notes,
        photos = photos,
        name = "エチオピア ハンドドリップ",
        brewMethod = BrewMethod.HandDrip,
        origin = "Ethiopia",
        variety = variety,
        processing = processing,
        roastLevel = roastLevel,
        cup = cup,
        tasting = tasting,
        tags = tags,
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    /** [CafeRepository.searchNearby] を検証するための最小フェイク。 */
    private class FakeCafeRepository : CafeRepository {

        var nearbyResult: List<Cafe> = emptyList()
        var nearbyError: Exception? = null
        var lastNearbyLatitude: Double? = null
        var lastNearbyLongitude: Double? = null

        override suspend fun searchText(query: String): List<Cafe> = emptyList()

        override suspend fun searchText(query: String, locationBias: LocationBias): List<Cafe> = emptyList()

        override suspend fun searchNearby(
            latitude: Double,
            longitude: Double,
            radiusMeters: Double,
        ): List<Cafe> {
            lastNearbyLatitude = latitude
            lastNearbyLongitude = longitude
            nearbyError?.let { throw it }
            return nearbyResult
        }

        override suspend fun getDetails(placeId: String): Cafe = Cafe(
            placeId = placeId,
            name = "Fake Cafe",
            address = null,
            latitude = null,
            longitude = null,
            photoReferences = emptyList(),
            websiteUrl = null,
            mapsUrl = null,
        )

        override suspend fun photoMediaUrl(
            photoName: String,
            maxWidthPx: Int?,
            maxHeightPx: Int?,
        ): String = "https://example.com/$photoName"
    }

    // ─────────────────────────────────────────────────
    // Tests — Create + Places 選択
    // ─────────────────────────────────────────────────

    @Test
    fun onSaveTapped_create_withPlacesSelection_persistsSelectedCafeCoordinatesAndPhotoReferences() = runTest {
        val fake = FakeCoffeeRepository()
        val vm = CoffeeEditorViewModel(coffeeRepository = fake, cafeRepository = FakeCafeRepository(), scope = this)
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
        val vm = CoffeeEditorViewModel(coffeeRepository = fake, cafeRepository = FakeCafeRepository(), scope = this)
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
        val vm = CoffeeEditorViewModel(coffeeRepository = fake, cafeRepository = FakeCafeRepository(), scope = this)
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

        val vm = CoffeeEditorViewModel(coffeeRepository = fake, cafeRepository = FakeCafeRepository(), scope = this)
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
        val vm = CoffeeEditorViewModel(coffeeRepository = fake, cafeRepository = FakeCafeRepository(), scope = this)
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

    // ─────────────────────────────────────────────────
    // Tests — 2-9 コーヒー名デフォルト値
    // ─────────────────────────────────────────────────

    @Test
    fun onAppear_create_defaultsNameToTodaysCoffee() = runTest {
        val fake = FakeCoffeeRepository()
        val vm = CoffeeEditorViewModel(coffeeRepository = fake, cafeRepository = FakeCafeRepository(), scope = this)
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Create, userId = "user-1")

            assertEquals("本日のコーヒー", vm.state.value.draft.name)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — 2-10 複製（テンプレート初期値）
    // ─────────────────────────────────────────────────

    @Test
    fun onAppear_duplicate_carriesOverBeanAndCafeAttributesButNotExperienceFields() = runTest {
        val sourceCafe = sampleCafe(
            placeId = "source-place",
            name = "元記録のカフェ",
            latitude = 35.1,
            longitude = 139.1,
            photoReferences = listOf("ref-source"),
        )
        val sourcePhoto = Photo(
            id = "photo-1",
            fileName = "a.jpg",
            localPath = "/tmp/a.jpg",
            remoteUrl = null,
            width = 100,
            height = 100,
            createdAt = Instant.fromEpochMilliseconds(0),
        )
        val sourceRecord = sampleRecord(
            id = "source-record",
            cafe = sourceCafe,
            rating = 4.5,
            notes = "元のメモ",
            photos = listOf(sourcePhoto),
            variety = "ゲイシャ",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Light,
            cup = "紙コップ",
            tasting = TastingScores(7, 6, 8, 5, 4),
            tags = listOf("ラテアート", "浅煎り"),
        )

        val fake = FakeCoffeeRepository()
        fake.byIdFlow.value = sourceRecord

        val vm = CoffeeEditorViewModel(coffeeRepository = fake, cafeRepository = FakeCafeRepository(), scope = this)
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Duplicate(sourceCoffeeId = sourceRecord.id), userId = "user-1")
            testScheduler.advanceUntilIdle()

            val draft = vm.state.value.draft
            val today = Clock.System.todayIn(TimeZone.currentSystemDefault())

            // 引き継ぐ 9 項目
            assertEquals(sourceCafe.name, draft.cafeName)
            assertEquals(sourceRecord.name, draft.name)
            assertEquals(sourceRecord.brewMethod, draft.brewMethod)
            assertEquals(sourceRecord.origin, draft.origin)
            assertEquals(sourceRecord.variety, draft.variety)
            assertEquals(sourceRecord.processing, draft.processing)
            assertEquals(sourceRecord.roastLevel, draft.roastLevel)
            assertEquals(sourceRecord.cup, draft.cup)
            assertEquals(sourceRecord.tags, draft.tags)

            // 引き継がない 4 項目
            assertEquals(0.0, draft.rating)
            assertEquals("", draft.notes)
            assertTrue(draft.photos.isEmpty())
            assertNull(draft.tasting)

            // visitedOn = 今日
            assertEquals(today, draft.visitedOn)

            // 保存すると新規 id が採番され、cafe の座標 / photoReferences も引き継がれる
            vm.onRatingChanged(3.0)
            vm.onSaveTapped()
            testScheduler.advanceUntilIdle()

            val saved = fake.savedRecords.single()
            assertNotEquals(sourceRecord.id, saved.id)
            val savedCafe = assertNotNull(saved.cafe)
            assertEquals(sourceCafe.placeId, savedCafe.placeId)
            assertEquals(sourceCafe.latitude, savedCafe.latitude)
            assertEquals(sourceCafe.longitude, savedCafe.longitude)
            assertEquals(sourceCafe.photoReferences, savedCafe.photoReferences)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onAppear_duplicate_selfExtractedSource_hasBlankCafeName() = runTest {
        val sourceRecord = sampleRecord(id = "source-record", cafe = null)
        val fake = FakeCoffeeRepository()
        fake.byIdFlow.value = sourceRecord

        val vm = CoffeeEditorViewModel(coffeeRepository = fake, cafeRepository = FakeCafeRepository(), scope = this)
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Duplicate(sourceCoffeeId = sourceRecord.id), userId = "user-1")
            testScheduler.advanceUntilIdle()

            assertEquals("", vm.state.value.draft.cafeName)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — 2-8 現在地カフェサジェスト
    // ─────────────────────────────────────────────────

    @Test
    fun onLocationAvailable_create_noCafeSelected_populatesSuggestedCafesUpToThree() = runTest {
        val fakeCafe = FakeCafeRepository()
        fakeCafe.nearbyResult = listOf(
            sampleCafe(placeId = "p1"),
            sampleCafe(placeId = "p2"),
            sampleCafe(placeId = "p3"),
            sampleCafe(placeId = "p4"),
        )
        val vm = CoffeeEditorViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            cafeRepository = fakeCafe,
            scope = this,
        )
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Create, userId = "user-1")

            vm.onLocationAvailable(latitude = 35.0, longitude = 139.0)
            testScheduler.advanceUntilIdle()

            assertEquals(3, vm.state.value.suggestedCafes.size)
            assertEquals(listOf("p1", "p2", "p3"), vm.state.value.suggestedCafes.map { it.placeId })
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onSuggestedCafeSelected_clearsSuggestedCafesAndAppliesSelection() = runTest {
        val fakeCafe = FakeCafeRepository()
        val suggestion = sampleCafe(placeId = "p1", name = "サジェストされたカフェ")
        fakeCafe.nearbyResult = listOf(suggestion)
        val vm = CoffeeEditorViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            cafeRepository = fakeCafe,
            scope = this,
        )
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Create, userId = "user-1")
            vm.onLocationAvailable(latitude = 35.0, longitude = 139.0)
            testScheduler.advanceUntilIdle()
            assertEquals(1, vm.state.value.suggestedCafes.size)

            vm.onSuggestedCafeSelected(suggestion)

            assertTrue(vm.state.value.suggestedCafes.isEmpty())
            assertEquals(suggestion.name, vm.state.value.draft.cafeName)
            assertEquals(suggestion.placeId, vm.state.value.selectedPlaceId)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onLocationAvailable_cafeAlreadySelected_doesNotPopulateSuggestions() = runTest {
        val fakeCafe = FakeCafeRepository()
        fakeCafe.nearbyResult = listOf(sampleCafe(placeId = "p1"))
        val vm = CoffeeEditorViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            cafeRepository = fakeCafe,
            scope = this,
        )
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Create, userId = "user-1")
            vm.onCafeNameChanged("手入力カフェ")

            vm.onLocationAvailable(latitude = 35.0, longitude = 139.0)
            testScheduler.advanceUntilIdle()

            assertTrue(vm.state.value.suggestedCafes.isEmpty())
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onLocationAvailable_editMode_doesNotPopulateSuggestions() = runTest {
        val initialRecord = sampleRecord(id = "record-1")
        val fake = FakeCoffeeRepository()
        fake.byIdFlow.value = initialRecord
        val fakeCafe = FakeCafeRepository()
        fakeCafe.nearbyResult = listOf(sampleCafe(placeId = "p1"))
        val vm = CoffeeEditorViewModel(coffeeRepository = fake, cafeRepository = fakeCafe, scope = this)
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Edit(initialRecord.id), userId = "user-1")
            testScheduler.advanceUntilIdle()

            vm.onLocationAvailable(latitude = 35.0, longitude = 139.0)
            testScheduler.advanceUntilIdle()

            assertTrue(vm.state.value.suggestedCafes.isEmpty())
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onLocationAvailable_nearbyFailure_isSilentAndDoesNotSetError() = runTest {
        val fakeCafe = FakeCafeRepository()
        fakeCafe.nearbyError = RuntimeException("network error")
        val vm = CoffeeEditorViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            cafeRepository = fakeCafe,
            scope = this,
        )
        try {
            vm.onAppear(CoffeeEditorViewModel.Mode.Create, userId = "user-1")

            vm.onLocationAvailable(latitude = 35.0, longitude = 139.0)
            testScheduler.advanceUntilIdle()

            assertTrue(vm.state.value.suggestedCafes.isEmpty())
            assertNull(vm.state.value.error)
        } finally {
            vm.clear()
        }
    }
}
