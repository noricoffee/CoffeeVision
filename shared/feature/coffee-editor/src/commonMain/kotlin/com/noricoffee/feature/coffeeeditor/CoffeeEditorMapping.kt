package com.noricoffee.feature.coffeeeditor

import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.TastingScores
import kotlinx.datetime.Clock
import kotlinx.datetime.TimeZone
import kotlinx.datetime.todayIn

// --- record ⇄ draft マッピング ---

/**
 * [CoffeeRecord] を [CoffeeEditorViewModel.CoffeeDraft] に変換する。
 * Edit モードで [com.noricoffee.repository.CoffeeRepository.observeById] から取得した record を
 * draft の初期値として使う。
 */
internal fun CoffeeRecord.toDraft(): CoffeeEditorViewModel.CoffeeDraft =
    CoffeeEditorViewModel.CoffeeDraft(
        cafeName = cafe?.name ?: "",
        cafeAddress = cafe?.address ?: "",
        cafeWebsiteUrl = cafe?.websiteUrl ?: "",
        cafeMapsUrl = cafe?.mapsUrl ?: "",
        visitedOn = visitedOn,
        rating = rating,
        notes = notes,
        photos = photos,
        name = name,
        brewMethod = brewMethod,
        origin = origin ?: "",
        region = region ?: "",
        variety = variety ?: "",
        processing = processing,
        roastLevel = roastLevel,
        cup = cup ?: "",
        brewRecipe = brewRecipe ?: "",
        tasting = tasting,  // all-or-nothing: null = 未入力 / 非 null = 5 要素全セット（edit モードで既存 tasting を反映）
        tags = tags,
    )

/**
 * [CoffeeRecord] を複製（[CoffeeEditorViewModel.Mode.Duplicate]）の初期 draft に変換する。
 *
 * 引き継ぐ: cafe（表示用フィールドのみ。placeId / 座標 / photoReferences は `currentInitialRecord` 経由で
 * [buildCafe] が引き継ぐ）/ name / brewMethod / origin / region / variety / processing /
 * roastLevel / cup / brewRecipe / tags。
 * 引き継がない: rating（null = 未評価）/ notes（空）/ photos（空）/ tasting（null）。
 * `visitedOn` は今日にする（元記録の日付は使わない）。
 */
internal fun CoffeeRecord.toDuplicateDraft(): CoffeeEditorViewModel.CoffeeDraft =
    CoffeeEditorViewModel.CoffeeDraft(
        cafeName = cafe?.name ?: "",
        cafeAddress = cafe?.address ?: "",
        cafeWebsiteUrl = cafe?.websiteUrl ?: "",
        cafeMapsUrl = cafe?.mapsUrl ?: "",
        visitedOn = Clock.System.todayIn(TimeZone.currentSystemDefault()),
        rating = null,
        notes = "",
        photos = emptyList(),
        name = name,
        brewMethod = brewMethod,
        origin = origin ?: "",
        region = region ?: "",
        variety = variety ?: "",
        processing = processing,
        roastLevel = roastLevel,
        cup = cup ?: "",
        brewRecipe = brewRecipe ?: "",
        tasting = null,  // all-or-nothing: 複製では引き継がない（要件 2-10）
        tags = tags,
    )

// --- テイスティングスコアのクランプ ---

/**
 * テイスティングスコアの各要素を `1..10` の範囲にクランプした新しいインスタンスを返す。
 *
 * 各フィールドは非 null（all-or-nothing）。入力範囲外（< 1 または > 10）の値はクランプする。
 * バリデーション規約: `data-model.md` §1.1a
 */
internal fun TastingScores.clamped(): TastingScores = TastingScores(
    sweetness = sweetness.clampTasting(),
    body = body.clampTasting(),
    acidity = acidity.clampTasting(),
    flavor = flavor.clampTasting(),
    aftertaste = aftertaste.clampTasting(),
)

/** `1..10` の範囲にクランプする拡張関数。 */
internal fun Int.clampTasting(): Int = coerceIn(1, 10)
