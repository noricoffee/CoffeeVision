package com.noricoffee.feature.coffeeeditor

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import kotlinx.datetime.Clock

/**
 * draft のバリデーション。エラーメッセージを返す。問題なければ null を返す。
 *
 * - name（コーヒー名）は必須・最大 200 文字
 * - rating は null（未評価。未評価のまま保存可）または 0.5..5.0（0.5 刻み）。
 *   非 null のときのみ範囲・刻みをバリデーションする（2026-07-12 B-4）
 * - notes は最大 2000 文字
 * - brewRecipe は最大 500 文字
 * - cafe は任意（空の場合はセルフ抽出として保存）
 */
internal fun validate(draft: CoffeeEditorViewModel.CoffeeDraft): String? {
    val rating = draft.rating
    return when {
        draft.name.isBlank() -> "コーヒー名を入力してください"
        draft.name.length > 200 -> "コーヒー名は 200 文字以内で入力してください"
        rating != null && (rating < 0.5 || rating > 5.0 || (rating * 2) % 1.0 != 0.0) ->
            "評価を 0.5〜5.0 で入力してください"
        draft.notes.length > 2000 -> "メモは 2000 文字以内で入力してください"
        draft.brewRecipe.length > 500 -> "抽出レシピは 500 文字以内で入力してください"
        else -> null
    }
}

/**
 * draft と [mode] から保存用の [CoffeeRecord] を組み立てる。
 *
 * - cafe は [buildCafe] に委譲する（cafeName が空のとき null = セルフ抽出）
 * - [CoffeeEditorViewModel.Mode.Create] / [CoffeeEditorViewModel.Mode.Duplicate]:
 *   id を新規 UUID で採番し、createdAt / updatedAt を now で設定する
 * - [CoffeeEditorViewModel.Mode.Edit]: [initialRecord] から id / placeId / createdAt を引き継ぎ、
 *   updatedAt を now で更新する
 *
 * @param initialRecord Edit / Duplicate モードで初回ロードした元記録（[CoffeeEditorViewModel] の
 *   `currentInitialRecord`）
 * @param selectedCafe このセッションで Places 選択があったカフェ（[CoffeeEditorViewModel] の `selectedCafe`）
 */
@OptIn(kotlin.uuid.ExperimentalUuidApi::class)
internal fun buildRecord(
    draft: CoffeeEditorViewModel.CoffeeDraft,
    userId: String,
    mode: CoffeeEditorViewModel.Mode,
    initialRecord: CoffeeRecord?,
    selectedCafe: Cafe?,
): CoffeeRecord {
    val now = Clock.System.now()
    val (id, createdAt) = when (mode) {
        is CoffeeEditorViewModel.Mode.Create, is CoffeeEditorViewModel.Mode.Duplicate -> Pair(
            kotlin.uuid.Uuid.random().toString(),
            now,
        )
        is CoffeeEditorViewModel.Mode.Edit -> Pair(
            initialRecord?.id ?: mode.coffeeId,
            initialRecord?.createdAt ?: now,
        )
    }

    val cafe = buildCafe(draft, selectedCafe, initialRecord?.cafe)

    return CoffeeRecord(
        id = id,
        userId = userId,
        cafe = cafe,
        visitedOn = draft.visitedOn,
        rating = draft.rating,
        notes = draft.notes,
        photos = draft.photos,
        name = draft.name,
        brewMethod = draft.brewMethod,
        origin = draft.origin.takeIf { it.isNotBlank() },
        region = draft.region.takeIf { it.isNotBlank() },
        variety = draft.variety.takeIf { it.isNotBlank() },
        processing = draft.processing,
        roastLevel = draft.roastLevel,
        cup = draft.cup.takeIf { it.isNotBlank() },
        brewRecipe = draft.brewRecipe.takeIf { it.isNotBlank() },
        tasting = draft.tasting?.clamped(),
        tags = draft.tags,
        createdAt = createdAt,
        updatedAt = now,
    )
}

/**
 * draft から保存用の [Cafe]（任意）を組み立てる。
 *
 * 優先順位:
 * 1. [draft].cafeName が空 → null（セルフ抽出）
 * 2. このセッションで Places 選択があった（[selectedCafe] が非 null）→
 *    [selectedCafe] の placeId / latitude / longitude / photoReferences を採用
 * 3. 引き継ぎ元 cafe がある（[initialCafe] が非 null。[CoffeeEditorViewModel.Mode.Edit] /
 *    [CoffeeEditorViewModel.Mode.Duplicate] で取得した元記録にカフェが紐づいていた場合）→
 *    その placeId / 座標 / photoReferences を引き継ぐ（Duplicate は複製元の cafe を同一カフェとして扱う）
 * 4. 上記いずれでもない（Create の手入力カフェ、またはセルフ抽出記録（元 cafe = null）の
 *    Edit / Duplicate で手動カフェ名を入力したケース）→ UUID を placeId として新規採番、
 *    座標は null / photoReferences は空
 *
 * cafe 採用の判定は mode ではなく「引き継ぎ元 cafe の有無」の一点に畳める（Create は
 * `onAppear` で `currentInitialRecord` を null にするため、[initialCafe] は自然に null になり 4 に落ちる）。
 * いずれの場合も name / address / websiteUrl / mapsUrl は draft の編集値を採用する。
 */
@OptIn(kotlin.uuid.ExperimentalUuidApi::class)
internal fun buildCafe(
    draft: CoffeeEditorViewModel.CoffeeDraft,
    selectedCafe: Cafe?,
    initialCafe: Cafe?,
): Cafe? {
    if (draft.cafeName.isBlank()) return null

    val (placeId, latitude, longitude, photoReferences) = when {
        selectedCafe != null ->
            CafeSnapshot(selectedCafe.placeId, selectedCafe.latitude, selectedCafe.longitude, selectedCafe.photoReferences)
        initialCafe != null ->
            CafeSnapshot(initialCafe.placeId, initialCafe.latitude, initialCafe.longitude, initialCafe.photoReferences)
        else -> CafeSnapshot(kotlin.uuid.Uuid.random().toString(), null, null, emptyList())
    }

    return Cafe(
        placeId = placeId,
        name = draft.cafeName,
        address = draft.cafeAddress.takeIf { it.isNotBlank() },
        latitude = latitude,
        longitude = longitude,
        photoReferences = photoReferences,
        websiteUrl = draft.cafeWebsiteUrl.takeIf { it.isNotBlank() },
        mapsUrl = draft.cafeMapsUrl.takeIf { it.isNotBlank() },
    )
}

/** [buildCafe] の内部ヘルパ: 引き継ぎ元 cafe の非表示フィールド（placeId / 座標 / photoReferences）。 */
private data class CafeSnapshot(
    val placeId: String,
    val latitude: Double?,
    val longitude: Double?,
    val photoReferences: List<String>,
)
