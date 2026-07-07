---
name: cafe-volatile-places-field-addition
description: Cafe の揮発フィールド（openNow〜googleRating 系）を追加するときに触るファイル一覧と順序。Places API から取得するが SQLDelight/Firestore には書かない値の配線パターン
metadata:
  type: project
---

## 対象ファイル（`userRatingCount` 追加で実施した例、フェーズ 16）

揮発フィールド（`docs/data-model.md` §1.2）は SQLDelight `.sq` / `Mapper.kt` / Firestore マッパーを
**一切触らない**。触るのは以下のみ:

1. `shared/domain/.../Cafe.kt` — 末尾に `val xxx: Type? = null` を追加（末尾でないと Swift 側の
   positional 初期化が壊れる可能性があるため、既存の揮発フィールドと同じ末尾ルールを踏襲する）
2. `shared/data-places/.../Dto.kt` — `PlaceDto` にフィールド追加
3. `shared/data-places/.../PlacesClientImpl.kt` — 3 箇所:
   - `FIELD_MASK`（`places.` 接頭辞あり、searchText/searchNearby 共通）
   - `DETAILS_FIELD_MASK`（接頭辞なし、getDetails 専用）
   - `PlaceDto.toPlaceSummary()` のマッピング追加
4. `shared/data-places/.../PlaceSummary.kt` — フィールド追加（**デフォルト値なし**。追加のたびに
   既存の commonTest 構築箇所がコンパイルエラーになるので、追加した at 同時に全 test 構築箇所を追随
   させる。[[vm_test_verification_gotchas]] の 2026-07-07 追記参照）
5. `shared/data-places/.../CafeRepositoryImpl.kt` — `toCafe()` のマッピング追加

## commonTest の追随箇所（見落としやすい）

- `CafeRepositoryImplSearchTextTest.kt`（`PlaceSummary(...)` を 2 箇所で構築）
- 新規フィールド用の FieldMask / DTO デコードテストは既存に無かったので、
  `PlacesClientImplXxxTest.kt` のような専用ファイルを新設するのが手っ取り早い
  （MockEngine でヘッダ捕捉 → `X-Goog-FieldMask` の contains assert）

## `CafeDetailViewModel` の条件付き Details リフレッシュパターン（フェーズ 16）

`initialCafe == null || initialCafe.googleRating == null` を「DB スナップショット由来で鮮度が低い」の
判定に使う設計（`googleRating` を鮮度センチネルとして流用）。`latestDetails: Cafe?` という private var を
ViewModel に持たせ、records の Flow collect 側の cafe 採用順を
`latestDetails ?: 最新記録の cafe ?: initialCafe` にすることで、details 到着後の records 再 emit による
巻き戻りを防ぐ。同じパターンが将来「DB スナップショット→API 補完」型の他 ViewModel でも使えそうなら
参考にする。
