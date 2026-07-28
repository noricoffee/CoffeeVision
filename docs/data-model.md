# データモデル

CoffeeVision のドメインモデルを **Kotlin（ドメイン）/ SQLDelight（ローカル DB）/ Firestore（クラウド）+ エクスポート JSON（§8）** の 4 表現で定義します。

> **この doc に書くこと / 書かないこと**（2026-07-25 の棚卸しで確定。1246 → 901 行に縮約した際の基準）
> - **書く**: フィールドの一覧・型・null 許容・意味、不変条件、表現間のマッピング規則、決定論的な集計ルール、設計上の決め事（なぜこの形か）
> - **書かない**: ①**ソースの逐語コピー**（SQL クエリ本体 / Rules / 実装コード / 定数リストの中身 — 正本はファイル側。列定義や公開 API の「形」は仕様なので残す）②**経緯・実測値・不採用案**（→ [`implementation_note.md`](./implementation_note.md)）③**UI の見た目**（→ [`ui-ux-guidelines.md`](./ui-ux-guidelines.md)）
> - 新しい表現・経路を足したら §8 の「写る先」と `.claude/rules/kotlin-kmp.md` のチェックリストも更新する（追随漏れ = 無言のデータ欠損。lessons 2026-07-25）
>
> **行数閾値（ストック型 500 行）の例外**（2026-07-27 ユーザー確定）: 本 doc は 700 行台を許容し、行数だけを理由に分割しない。**7 エンティティ × 4 表現の対比が本 doc の機能そのもの**で、表現軸（§1 ドメイン / §2 SQLDelight / §3 Firestore）で切ると 1 エンティティにフィールドを足すとき複数 doc を往復することになり、追随漏れ = 無言のデータ欠損のリスクが上がる。性質で切れる軸は 2026-07-25 に使い切った（永続しない派生集計 = 旧 §1.6〜1.7a を [`analysis-model.md`](./analysis-model.md) へ分離）。`check-file-size.sh` の警告は非ブロッキングで、**この前文が判断の正本**。次に本 doc が大きくなったら、行数ではなく「複製が混ざっていないか」（上記の書かない基準）で棚卸しする。

> **2026-06-19 大改訂**: 「カフェ訪問（`Visit`）主体」から「**コーヒー記録（`CoffeeRecord`）主体**」へ再設計。`Visit` / `CoffeeItem` / `FoodItem` を廃止し、1 杯のコーヒー記録 `CoffeeRecord` を集約ルートにした。カフェは任意（`cafe: Cafe?`、null = セルフ抽出）。クリーンブレイク（データ移行なし）。経緯は [`implementation_note.md`](./implementation_note.md) 2026-06-19 エントリ参照。

エンティティ一覧:

- `CoffeeRecord`（コーヒー記録。集約ルート）
- `Cafe`（カフェ情報。`CoffeeRecord` / `SavedCafe` に埋め込み）
- `Photo`（写真。`CoffeeRecord` の子）
- `BeanProfile`（豆ナレッジ。Firestore グローバルコレクション / サービス管理データ）
- `SavedCafe`（行きたい店。ウィッシュリスト / フェーズ 15-A）
- `CuratedCafe`（都道府県別おすすめカフェ。Firestore グローバルコレクション / サービス管理データ / フェーズ 19）
- `AuthAccount`（アカウント情報 + データ利用同意。`users/{uid}` ルートドキュメントと同期 / §1.11）

---

## エンティティ関連図

```
User (Firebase Auth uid)
  │
  ├── CoffeeRecord (0..N)
  │     ├── Cafe              (0..1, 埋め込み / null = セルフ抽出)
  │     └── Photo             (0..N)
  │
  └── SavedCafe (0..N)         行きたい店（placeId ごとに最大 1 件）
        └── Cafe              (1, 埋め込みスナップショット)
```

---

# 1. Kotlin ドメインモデル

`shared/domain/src/commonMain/kotlin/com/noricoffee/domain/` 配下に配置します。

## 1.1 CoffeeRecord

```kotlin
package com.noricoffee.domain

import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

data class CoffeeRecord(
    val id: String,                       // UUID v4
    val userId: String,                   // Firebase Auth uid
    val cafe: Cafe?,                      // Places 由来のスナップショット。null = セルフ抽出（自宅等）
    val visitedOn: LocalDate,             // 飲んだ日
    val rating: Double?,                  // 0.5..5.0（0.5 刻み）。null = 未評価（2026-07-12 B-4 で 0.0 sentinel を廃止し nullable 化。0.0 は不正値）
    val notes: String,                    // 自由メモ（旧 ambiance / フード等もここに吸収）
    val photos: List<Photo>,
    // --- コーヒー属性（旧 CoffeeItem から昇格）---
    val name: String,                     // コーヒー名（必須）
    val brewMethod: BrewMethod,
    val origin: String?,                  // 産地（国名）。ドロップダウン選択（CoffeeOriginCatalog）。「ブレンド」/「その他で入力した国名」も可。null = 未選択。2026-07-22 に自由入力 → 国ドロップダウン化（§1.3a）
    val region: String?,                  // エリア / 農園（任意自由入力。例「イルガチェフェ」「ウエウエテナンゴ」）。origin から分離（2026-07-22 追加）。表示専用で分析には使わない（analysis-model.md §1）
    val variety: String?,                 // 品種
    val processing: ProcessingMethod?,    // 精製方法
    val roastLevel: RoastLevel?,          // 焙煎度
    val cup: String?,                     // カップの種類 / ブランドメモ
    val brewRecipe: String?,              // 抽出レシピ（豆量 / 湯量 / 湯温 / 時間などの自由メモ）。フェーズ 15-E 追加。セルフ抽出向け
    val tasting: TastingScores?,          // テイスティング 5 要素。null = 未記入。記入する場合は 5 要素すべて必須
    val tags: List<String> = emptyList(), // ユーザー定義タグ（例: "ラテアート" "浅煎り"）。フェーズ 10-D 追加
    // --- メタ ---
    val createdAt: Instant,
    val updatedAt: Instant,
)
```

> **`tasting` の統合**: Blue Bottle「Elements of Coffee Tasting」に基づくテイスティング 5 要素（甘味 / ボディ / 酸味 / 風味 / 後味）を `TastingScores`（§1.1a）として持つ。各要素は **1〜10 の強度**。**テイスティングは任意だが、付ける場合は 5 要素すべて必須**（all-or-nothing）。「付けない」は `tasting = null`。総合評価 `rating`（0.5 刻みハーフスター）とは別軸の **強度スケール**であることに注意。

> **rating / notes の統合**: 旧モデルでは Visit と CoffeeItem の双方に rating / notes があったが、コーヒー主体では 1 杯につき 1 本に統一する。旧 `ambiance`（カフェの雰囲気）と `FoodItem`（フード）は構造化フィールドとして廃止し、必要なら自由メモ `notes` に書く方針。

## 1.1a TastingScores

```kotlin
data class TastingScores(
    val sweetness: Int,                    // 甘味     1..10
    val body: Int,                         // ボディ（コク）
    val acidity: Int,                      // 酸味
    val flavor: Int,                       // 風味
    val aftertaste: Int,                   // 後味
)
```

- 各要素は **1〜10 の整数**（強度スケール。UI はスライダー）。
- **5 要素は不可分（all-or-nothing）**: テイスティングを付ける場合は 5 要素すべて必須。「付けない」は `CoffeeRecord.tasting = null`（§1.1）で表す。**部分入力は型として表現不可能**（各フィールドが非 null）。
- 「良し悪し」ではなく**強度**を表す軸（酸味 10 = 酸が強い、であって優劣ではない）。総合評価 `rating` とは意味が異なる。
- バリデーション: 各値は `1..10`。UI は `+` でデフォルト値（5）の `TastingScores` を生成して 5 スライダーを一度に出し、削除で `null` に戻すため、部分状態は発生しない。

## 1.2 Cafe

```kotlin
data class Cafe(
    val placeId: String,                  // Google Places の place_id
    val name: String,
    val address: String?,
    val latitude: Double?,
    val longitude: Double?,
    val photoReferences: List<String>,    // Places の photo_reference
    val websiteUrl: String?,
    val mapsUrl: String?,
    // --- Places API 取得時のみ利用する表示用フィールド（フェーズ 10-B 追加。永続化しない）---
    val openNow: Boolean? = null,                        // 営業中か（currentOpeningHours.openNow）
    val weekdayDescriptions: List<String> = emptyList(), // 曜日別営業時間の表示文字列
    val phoneNumber: String? = null,                     // 電話番号（nationalPhoneNumber）
    val priceLevel: String? = null,                      // 価格帯（PRICE_LEVEL_* 文字列）
    val googleRating: Double? = null,                    // Google 上の評価
    val userRatingCount: Int? = null,                    // Google 上の評価件数（フェーズ 16 追加）
)
```

> `CoffeeRecord.cafe` が null の場合はカフェに紐づかないセルフ抽出を表す。

> **永続化されるのは先頭 8 フィールドのみ**: フェーズ 10-B で追加した 5 フィールド（`openNow`〜`googleRating`）とフェーズ 16 で追加した `userRatingCount` の計 6 フィールドは Places API（Text / Nearby / Details）のレスポンスから組み立てて**カフェ詳細画面・マップ下部カードの表示にのみ使う揮発値**。`CoffeeRecord.cafe` としてスナップショット保存する際は SQLDelight（§2.1 の `cafe_*` 列）にも Firestore（§3.2 の `cafe` マップ）にも書き出さず、読み戻した `Cafe` では既定値のままになる（営業時間等は鮮度が要るため都度取得が正）。

> **写真について**: Places API の写真は `photo_reference` をキーに **都度取得** する規約。
> ローカルに永続キャッシュしないこと（規約違反になる場合がある）。

## 1.3 enum

いずれも `shared/domain` の単純な enum（表示名は UI 側でローカライズ。永続化は `.name` 文字列 = §2.1 / §3.2）。

| enum | 値（宣言順） |
|---|---|
| `BrewMethod` | `Espresso` / `HandDrip` / `NelDrip` / `FrenchPress` / `AeroPress` / `Syphon` / `ColdBrew` / `Other` |
| `ProcessingMethod` | `Natural` / `Washed` / `Honey` / `Anaerobic` / `Other` |
| `RoastLevel` | `Light` / `Cinnamon` / `Medium` / `High` / `City` / `FullCity` / `French` / `Italian` |

> DB / Firestore からの逆引きは `entries.firstOrNull { it.name == raw }` を使い、`valueOf`（未知値で例外）は使わない（lessons 2026-07-08）。

## 1.3a CoffeeOriginCatalog（産地の国ドロップダウン / 2026-07-22）

`CoffeeRecord.origin` を自由入力から**国ドロップダウン選択**に変更するための、コーヒー生産国の**日本語国名カタログ**。記録入力の手間削減が目的（[`requirements.md`](./requirements.md) 2-1）。

**配置**: `shared/domain/src/commonMain/kotlin/com/noricoffee/domain/CoffeeOriginCatalog.kt`

`object CoffeeOriginCatalog` が `countries: List<String>`（コーヒー生産国 43 か国。**全て日本語表記**）と `BLEND = "ブレンド"`（複数産地。単一国に落とし込めないコーヒー）/ `OTHER = "その他"`（リスト外。UI は選択時に国名の自由入力欄を出す）を持つ。**国名リスト自体はここに複製しない**（正本はソース）。

**`countries` の並び順 = コーヒー生豆の生産量の概算ランキング順**（ICO / FAO ベース。上位は確度が高く、小規模産地の相対順は目安）。UI は先頭に「ブレンド」、末尾に「その他」を添えて出す。

### 設計上の決め事

- **origin は `String?` のまま（enum 化しない）**: 「ブレンド」「その他で入力した国名」「未選択（null）」「クリーンブレイク前の legacy 自由文字列」を型で表現でき、`OriginNormalizer` / `BeanProfile` 突合 / `originRanking`（すべて String ベース）を無改修で流用できる（Simplicity First）。カタログは選択肢の提示元であって格納型の制約ではない
- **正規形との一致（不変条件）**: `countries` の各要素は `OriginNormalizer.normalize` の**正規形（＝ normalize が自身を返す固定点）**であること。日本語表記はシノニム辞書のキー（英語綴り / サブ地域）に含まれず lowercase でも不変のため自然に成立する。**`OriginNormalizer` のシノニム値（RHS）は全て `countries` に含まれる**ことをテストで担保する（`OriginNormalizerTest` に catalog ⊇ synonymValues を追加）。新規追加国には英語綴りシノニム（`vietnam` → `ベトナム` 等）も `OriginNormalizer` へ追加し、カタログと正規化のカバレッジを揃える
- **「その他」で入力した国名の扱い**: literal「その他」を保存せず、ユーザーが入力した実際の国名文字列を `origin` に保存する（データ欠損回避）。「ブレンド」は literal「ブレンド」を保存する（実体が単一国でないため）
- **カタログの真実点は domain**: iOS ピッカーは SKIE ブリッジ経由で `CoffeeOriginCatalog` を読む（[`kmp-bridge.md`](./kmp-bridge.md)）。iOS 側でリストを二重管理しない。**表示順は生産量の概算ランキング順**（ICO/FAO ベース。よく飲まれる産地を上位に置き選択の手間を減らす）。ピッカーは先頭に「ブレンド」、`countries` を生産量順、末尾に「その他」を並べる（`未選択` は任意フィールドの空状態として最上段に残す。2026-07-22 並び替え）
- **`region`（エリア / 農園）は分析非対象**: サブ地域の粒度は交絡分離不能で統計に使えない（[`analysis-model.md`](./analysis-model.md) §1 の confounding 方針）ため、`region` は詳細表示・シェアカード等の**表示専用**。`originRanking` / `FavoriteSignals` は従来どおり `origin`（国）のみを見る

## 1.4 Photo

```kotlin
data class Photo(
    val id: String,
    val fileName: String?,                // Documents 配下の最終ファイル名（例: "{photoId}.jpg"）。Firestore にも保存し、機種変・iCloud Backup 復元時に `photos/{fileName}` で localPath を再構築できる
    val localPath: String?,               // Documents 配下からの相対パス（例: "photos/{photoId}.jpg"）。iOS Documents URL は起動ごとに変わるため絶対パス禁止
    val remoteUrl: String?,               // 将来 Firebase Storage 復活用フィールド。現状は常に null
    val width: Int?,
    val height: Int?,
    val createdAt: Instant,
)
```

> 現状は `localPath` / `fileName` が常に非 null（端末ローカル保存）、`remoteUrl` は常に null（将来 Storage 復活用にフィールドだけ残置）。写真ファイルは Documents 配下のフラットな `photos/` ディレクトリに置く（recordId 別ディレクトリにしない）。Create モードでも recordId 確定前に写真を保存できる + CoffeeRecord 削除時は `CoffeeRecord.photos` の id を順に物理削除する設計。`localPath` と `fileName` は冗長に見えるが、`localPath` は端末側 DB の即時読み込み用、`fileName` は Firestore メタデータの最小単位として両方持つ。

## 1.5 VisitedCafe（集計モデル）

`shared/domain/src/commonMain/kotlin/com/noricoffee/domain/model/VisitedCafe.kt`

```kotlin
data class VisitedCafe(
    val cafe: Cafe,                       // 最新記録時のカフェスナップショット
    val lastVisitedAt: Instant,           // そのカフェで最後にコーヒーを記録した日
    val visitCount: Int,                  // そのカフェでのコーヒー記録件数
    val averageRating: Double?,           // 記録の平均評価（rating=null の未評価は除外、全て未評価なら null）
)
```

> マップ表示・カフェ集計用。`ObserveVisitedCafesUseCase` が `CoffeeRecord` のうち **`cafe != null` のものだけ** を `cafe.placeId` でグループ化して生成する。セルフ抽出（cafe == null）は集計対象外（座標が無くマップに出せないため）。名前は互換性のため `VisitedCafe` を維持するが、意味は「コーヒー記録のあるカフェ」。

## 1.6〜1.7a → [`analysis-model.md`](./analysis-model.md) へ移動（2026-07-25）

**分析系の派生集計モデルは別 doc に分離した**。永続化しない（SQLDelight / Firestore 表現を持たない）ため、永続エンティティの正本である本 doc とは寿命も更新契機も違う。

| 旧節 | 移動先 |
|---|---|
| §1.6 `CoffeeStats` + 集計ルール + 階層3 インターフェース（`CoffeeInsightProvider` / `CoffeeRecordQuery`） | [`analysis-model.md`](./analysis-model.md) §1 |
| §1.7 `RecommendedCafe` + 一致ルール + 9-6 協調フィルタ | [`analysis-model.md`](./analysis-model.md) §2 |
| §1.7a `UnexploredBeanSuggestion` | [`analysis-model.md`](./analysis-model.md) §3 |

> **§1.8 以降は改番していない**（他 doc / コードコメントから名指しされているため）。本 §1 の採番に 1.6〜1.7a の欠番があるのは意図的。

---

## 1.8 BeanProfile（豆ナレッジ / フェーズ 12-B）

> サービス管理のコーヒー豆知識データ。ユーザーの `CoffeeRecord` と `beanProfileId` では**紐付けしない**。`origin`（`OriginNormalizer` 経由）+ `processings`（enum 名）でファジーマッチし、分析タブの 2 機能に活用する。
>
> **現行の消費先は分析タブのみ**（2026-07-28 確認）: ①「好みの豆の傾向」（`PreferredBeanTraitsUseCase`）②「未経験の豆への探索提案」（`SuggestUnexploredBeansUseCase` / 要件 9-8）。起票時（12-B）にあった**エディタの産地サジェストは 2026-07-22 の産地ドロップダウン化で撤去済み**。その名残で `AppContainer.beanProfileMatchUseCase` と `BeanProfileRepository.getByOrigin` は現在どこからも呼ばれていない（`BeanProfileMatchUseCase` 自体は `SuggestUnexploredBeansUseCase` が内部で合成して使用中）。

**配置**: `shared/domain/src/commonMain/kotlin/com/noricoffee/domain/BeanProfile.kt`（パッケージ `com.noricoffee.domain`）

```kotlin
data class BeanProfile(
    val beanId: String,                        // Firestore ドキュメント ID（ASCII kebab-case）
    val name: String,                          // 豆名（表示用。「エチオピア ゲイシャ ナチュラル」等）
    val origin: String,                        // 産地（「エチオピア」「コロンビア」等。日本語表記 = §3.2 表記規約）
    val variety: String?,                      // 品種（「ゲイシャ」「ブルボン」等）
    val processings: List<ProcessingMethod>,   // 精製方法（複数可）
    val flavorNotes: List<String>,             // フレーバーノート（「チョコレート」「シトラス」等。統一語彙 = §3.2）
    val description: String?,                  // 12-C LLM インプット用説明
)
```

**ファジーマッチロジック**（`BeanProfileMatchUseCase`）:

| フィールド | マッチ方式 | スコア |
|---|---|---|
| `origin` | `OriginNormalizer.normalize`（trim + lowercase + シノニム辞書）後の完全一致 | +2 |
| `origin` | 同正規化後の双方向 contains | +1 |
| `processings` | `ProcessingMethod.name` 完全一致 | +1 |

- score > 0 のもののみ、降順でソートして返す
- `roastLevel` はロースター次第なので除外

**`interface BeanProfileRepository`**（`com.noricoffee.repository`）: `suspend getAll()` / `suspend getByOrigin(origin)`。どちらもメモリキャッシュ前提（Firestore への one-shot get、snapshotListener 不要）。

---

## 1.9 SavedCafe（行きたい店 / フェーズ 15-A）

> 「探す → 保存 → 訪問 → 記録」のループを閉じるウィッシュリスト（[`requirements.md`](./requirements.md) §10）。記録（訪問済み）とは独立した「これから行く店」の管理。

**配置**: `shared/domain/src/commonMain/kotlin/com/noricoffee/domain/model/SavedCafe.kt`

```kotlin
data class SavedCafe(
    val userId: String,                   // Firebase Auth uid
    val cafe: Cafe,                       // Places 由来のスナップショット（保存時点。永続化は 8 フィールドのみ = §1.2 と同じ）
    val note: String,                     // 任意メモ（「◯◯さんおすすめ」等）。空文字可
    val savedAt: Instant,                 // 保存日時（一覧の並び順キー、降順）
)
```

### 設計上の決め事

- **キーは `cafe.placeId`（自然キー。UUID を持たない）**: 同じカフェを二重に「行きたい」登録する意味がないため、`(userId, placeId)` で一意とする。§5 の「ID は UUID v4」ルールの**意図的な例外**（保存/解除がトグルとして冪等になり、二重登録の防御ロジックが不要になる）。Places の place_id は英数字 + `-`/`_` で構成され `/` を含まないため、Firestore ドキュメント ID にそのまま使える
- **記録作成時の自動解除はしない（データは独立）**: 記録保存フローに `SavedCafeRepository` への書き込みを結合させない（Simplicity First / ユーザーの意図しないデータ消失を避ける。「また行きたい」用途でリストに残す使い方も許容）。重複感は**表示側で解決**する:
  - マップのピンは同一 placeId が競合したら **訪問済み（+ 好み一致）> 行きたい > 検索結果 > おすすめ（curated、§1.10）** の優先順位で 1 本だけ出す（フェーズ 19 で curated を末尾に追加。表示切替チップの状態に関わらず適用）
  - 行きたい一覧では、記録が既にある店に「記録あり」バッジを表示し、手動解除を促す
- **一覧の導線はマップ画面内**: マップのツールバー（またはフィルタチップ列）のブックマークボタン → ハーフシートで `SavedCafe` 一覧（`savedAt` 降順、タップでカフェ詳細 push、スワイプで解除）。**新規 feature モジュールは作らない**（シートはマップ画面の一部。状態は `MapViewModel` に持たせ、1 画面 = 1 モジュール原則のカウント外とする）
- **カフェ詳細のトグル状態**: `CafeDetailViewModel` が `observeByPlaceId` を購読して「行きたい」ボタンの ON/OFF を表示。保存時は表示中の `Cafe`（Places Details 取得済み）からスナップショットを作る
- **スナップショットの鮮度**: 保存時点の 8 フィールドを固定保存。営業時間等の揮発情報はカフェ詳細画面が都度 Places Details を取得する既存挙動（§1.2）に委ねる
- **`note` は v1 では常に空文字**: フィールド・永続化（SQLDelight / Firestore）だけ確保し、入力 UI は用意していない（保存は `CafeDetailViewModel.onSaveToggled` / `MapViewModel` から `note = ""` で行う）。メモ編集は将来の加算的追加

---

## 1.10 CuratedCafe（都道府県別おすすめカフェ / フェーズ 19）

> サービス管理のキュレーション済みおすすめカフェ。マップに専用ピン（通常カフェピンと同アイコンの拡大 + `Color.orange` 高彩度 = Google Maps 風 POI 強調。ズームイン時のみ表示、トグルなし）で強調する。既存の `RecommendedCafe`（[`analysis-model.md`](./analysis-model.md) §2 = ユーザーの味覚プロファイル好み一致）とは**別概念**なので命名を curated で分離。

**配置**: `shared/domain/src/commonMain/kotlin/com/noricoffee/domain/model/CuratedCafe.kt`

```kotlin
data class CuratedCafe(
    val placeId: String,        // Google Places ID（ピンタップ時の詳細解決キー）
    val name: String,           // 表示名
    val latitude: Double,       // 非 null（座標なし候補はシード時に弾く）
    val longitude: Double,
    val prefectureCode: String, // JIS X 0401 の 2 桁ゼロ埋め文字列（"01".."47"）
)
```

### 設計上の決め事

- **保持は最小 5 フィールドのみ（Places 規約対応）**: 評価・営業時間等の揮発データは保存せず、ピンタップ時にカフェ詳細画面が既存の `CafeRepository.getDetails` で解決する。placeId 以外の Places 由来データには 30 日キャッシュ規定があるため、シード再実行による定期リフレッシュを運用で担保する（`scripts/seed/README.md`）
- **都道府県コードは JIS X 0401**: 標準規格でローマ字ゆれ（hyogo/hyougo 等）がなく、文字列ソート = 北から南の自然順、Firestore ドキュメント ID にそのまま使える。47 値の Kotlin enum は作らない（クライアントは全件一括ロードのみで県別ロジックを持たない）。コード → 県名対応はシードスクリプトの定数表と Firestore ドキュメントの `prefectureName` が持つ
- **件数は県ごとの上限 + 人気枠**: 基準上位（評価 4.4 / レビュー 100 件以上）は東京 100 / 他県 30 を上限とし、加えて人気枠（評価 3.7 / レビュー 500 件以上）を上限の枠外で全件採用（2026-07-18 追加。初期スコープは東京のみ）
- **SQLDelight には持たない**: Firestore one-shot get + メモリキャッシュで足りる。オフラインは Firestore 永続化キャッシュに委ねる（アーキテクチャ不変条件どおり独自同期は書かない）

**Repository インターフェース**（`com.noricoffee.repository.CuratedCafeRepository`）:

```kotlin
interface CuratedCafeRepository {
    suspend fun getAll(): List<CuratedCafe>
}
```

`getAll()` はメモリキャッシュ前提（Firestore への one-shot get、snapshotListener 不要 = BeanProfile と同じパターン）。全県分を flatten した 1 本のリストを返す。`MapViewModel` が init で一括ロードし、失敗時はサイレントに空のまま（おすすめは付加情報でありマップ本体を阻害しない）。

> **将来課題**: 47 県フル展開時（約 1,400 件）は iOS 側 Annotation の可視領域フィルタ導入を検討する。

---

## 1.11 AuthAccount（アカウント情報 + データ利用同意）

> Firebase Auth のアカウント状態と、`users/{uid}` ルートドキュメント（§3.2）の同意フラグを 1 つにまとめた読み取り専用モデル。**SQLDelight 表現は持たない**（端末に持つ意味がなく、Auth / Firestore が真）。

**配置**: `shared/domain/src/commonMain/kotlin/com/noricoffee/domain/model/AuthAccount.kt`

```kotlin
data class AuthAccount(
    val uid: String,                          // Firebase Auth uid（匿名 / 実名ともに不変で一意）
    val isAnonymous: Boolean,                 // 匿名アカウントか
    val providerLabel: String?,               // サインインプロバイダ識別子（例: "apple.com"）。匿名は null
    val email: String?,                       // プロバイダ提供のメール。Apple は非公開リレー含め null になりうる
    val analyticsConsent: Boolean = false,    // §3.2 users/{uid}.analyticsConsent と同期。ドキュメント未作成は false
)
```

- **匿名 → Apple アップグレードで `uid` は変わらない**: `isAnonymous` / `providerLabel` / `email` だけが変化する（記録の付け替えは発生しない）
- **同意フラグの出入り口は `AuthRepository`**: `observeAccount(): Flow<AuthAccount?>` / `observeAnalyticsConsent(): Flow<Boolean>` / `updateAnalyticsConsent(consent)`。Firestore 書き込みはプラットフォーム別実装が担う（`RemoteCoffeeDataSource` と同じ非対称性の吸収）
- **`recommendationConsent`（9-6）はまだ本モデルに無い**: §3.2 に定義済みだが未実装。実装時に本 data class へ加算的に追加する

---

# 2. SQLDelight スキーマ

ローカル DB は **検索・オフライン参照の高速化** が目的。Firestore のキャッシュとは別途に持つ。
配置: `shared/data-local/src/commonMain/sqldelight/com/noricoffee/db/`

> **クリーンブレイク**: 旧 `Visit.sq` / `CoffeeItem.sq` / `FoodItem.sq` を削除し、`CoffeeRecord.sq` を新設。`Photo.sq` の FK を `coffee_record` に変更。マイグレーションは書かない（未リリースのため、テスト端末はアプリ削除→再インストール）。

## 2.1 CoffeeRecord.sq

```sql
CREATE TABLE coffee_record (
    id TEXT NOT NULL PRIMARY KEY,
    user_id TEXT NOT NULL,
    -- cafe は任意（全 cafe_* が null = セルフ抽出）
    cafe_place_id TEXT,
    cafe_name TEXT,
    cafe_address TEXT,
    cafe_latitude REAL,
    cafe_longitude REAL,
    cafe_photo_references TEXT,            -- JSON 配列（cafe null のとき null）
    cafe_website_url TEXT,
    cafe_maps_url TEXT,
    -- 記録本体
    visited_on TEXT NOT NULL,              -- ISO-8601 (YYYY-MM-DD)
    rating REAL,                           -- 0.5..5.0（0.5 刻み）。NULL = 未評価（migration 5.sqm で NOT NULL 撤廃 + 既存 0.0 → NULL 変換）
    notes TEXT NOT NULL,
    -- コーヒー属性
    name TEXT NOT NULL,
    brew_method TEXT NOT NULL,             -- enum 文字列
    origin TEXT,                           -- 国名（CoffeeOriginCatalog 選択値 / 「ブレンド」/ legacy 自由文字列）
    region TEXT,                           -- エリア / 農園（自由入力。migration 6.sqm で ALTER TABLE ADD COLUMN。2026-07-22 追加）
    variety TEXT,
    processing TEXT,                       -- enum 文字列
    roast_level TEXT,                      -- enum 文字列
    cup TEXT,
    brew_recipe TEXT,                      -- 抽出レシピ自由メモ（フェーズ 15-E 追加、migration 4.sqm で ALTER TABLE ADD COLUMN）
    -- テイスティング 5 要素（各 1..10）。5 列は all-or-nothing（全列 NULL = tasting なし / 全列セット = tasting あり）
    sweetness INTEGER,
    body INTEGER,
    acidity INTEGER,
    flavor INTEGER,
    aftertaste INTEGER,
    -- ユーザー定義タグ（JSON 配列文字列。空リストは "[]"、マイグレーション前の行は ""）
    tags TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,           -- epoch millis
    updated_at INTEGER NOT NULL
);

CREATE INDEX coffee_record_by_user_visited ON coffee_record (user_id, visited_on DESC);
CREATE INDEX coffee_record_by_cafe ON coffee_record (cafe_place_id);
```

クエリは `selectAll`（user_id / visited_on DESC, created_at DESC）/ `selectById` / `selectByCafe` / `upsert`（`INSERT OR REPLACE`、全列）/ `deleteById`。**本体は `.sq` ファイルが正本**なのでここに複製しない。

> `selectByCafe` は `cafe_place_id = ?` の等値マッチのため、cafe null（セルフ抽出）は自然に除外される（意図通り）。

## 2.2 Photo.sq

```sql
CREATE TABLE photo (
    id TEXT NOT NULL PRIMARY KEY,
    record_id TEXT NOT NULL,
    file_name TEXT,
    local_path TEXT,
    remote_url TEXT,
    width INTEGER,
    height INTEGER,
    created_at INTEGER NOT NULL,
    sort_order INTEGER NOT NULL,
    FOREIGN KEY (record_id) REFERENCES coffee_record(id) ON DELETE CASCADE
);

CREATE INDEX photo_by_record ON photo (record_id, sort_order);
```

クエリは `selectByRecord`（sort_order ASC）/ `upsert` / `deleteByRecord` / `deleteById`（本体は `.sq` が正本）。

> **FOREIGN KEY は接続ごとの opt-in（2026-07-03 確定）**: SQLite の外部キー制約は既定で OFF のため、`ON DELETE CASCADE` を機能させるには**本番ドライバ側で明示的に有効化する**必要がある。
> - Android: `AndroidSqliteDriver` の `Callback.onConfigure` で `db.setForeignKeyConstraintsEnabled(true)`（onConfigure に置くことで migration 実行中は framework 側が自動で制約を外す挙動に乗る）
> - iOS: `NativeSqliteDriver` の `onConfiguration` で `extendedConfig.foreignKeyConstraints = true`（sqliter の既定は false）
> - テストドライバ（`TestSqlDriver.*`）も同じ設定に揃える（JVM は `PRAGMA foreign_keys = ON` 済み、iOS は要追随）
>
> 有効化以前に記録削除で発生した孤児 photo 行（`record_id` が `coffee_record` に存在しない行）は migration `2.sqm` で一括削除して掃除する。

## 2.3 マッピング方針

- DB 行 ↔ ドメインモデル変換は `db/Mapper.kt` に集約する
- 子テーブル（photo）は別クエリで取得し、Repository でまとめる（JOIN は使わず、`Flow.combine` で結合）
- 写真の参照配列やタグ（`tags`）など複数値は **JSON 文字列**（`kotlinx.serialization`）で 1 列に格納する。`tags` は空文字（旧行）も空リストとして読む
- `cafe_place_id` が null の行は `cafe = null` で組み立てる。非 null の行のみ `Cafe(...)` を構築する

### migration の履歴と型

| # | 内容 | 方式 |
|---|---|---|
| `2.sqm` | 孤児 photo 行の掃除（FK 有効化以前に発生。§2.2） | `DELETE` |
| `3.sqm` | `saved_cafe` テーブル追加（15-A） | `CREATE TABLE` + `CREATE INDEX` |
| `4.sqm` | `brew_recipe` 列追加（15-E） | `ALTER TABLE ADD COLUMN`（既存行 NULL） |
| `5.sqm` | `rating` の NOT NULL 撤廃（B-4、2026-07-12） | **テーブル再作成**（下記） |
| `6.sqm` | `region` 列追加（2026-07-22） | `ALTER TABLE ADD COLUMN`（既存行 NULL） |

- **nullable 列の追加（4 / 6）**: `ALTER TABLE ADD COLUMN` + `upsert` の列リスト・VALUES にも追加 + Mapper の read/write。他の nullable TEXT 列と同じ扱い
- **`rating` の nullable 化（5）**: SQLite は NOT NULL 撤廃の ALTER を持たないため**テーブル再作成方式**（新テーブル CREATE → `NULLIF(rating, 0.0)` で INSERT SELECT → 旧 DROP → RENAME → インデックス再作成）。photo の FK を壊さないよう `PRAGMA foreign_keys=0` で挟む
- **フェーズ 7 のクリーンブレイク以後は、リリース前でも migration を書く運用**

## 2.4 SavedCafe.sq（フェーズ 15-A）

```sql
CREATE TABLE saved_cafe (
    place_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    -- Cafe スナップショット（place_id 以外の 7 フィールド。coffee_record の cafe_* と同じ直列化規則）
    cafe_name TEXT NOT NULL,
    cafe_address TEXT,
    cafe_latitude REAL,
    cafe_longitude REAL,
    cafe_photo_references TEXT,            -- JSON 配列
    cafe_website_url TEXT,
    cafe_maps_url TEXT,
    note TEXT NOT NULL DEFAULT '',
    saved_at INTEGER NOT NULL,             -- epoch millis
    PRIMARY KEY (place_id, user_id)
);

CREATE INDEX saved_cafe_by_user ON saved_cafe (user_id, saved_at DESC);
```

クエリは `selectAll`（saved_at DESC）/ `selectByPlaceId` / `upsert` / `deleteByPlaceId`（本体は `.sq` が正本）。

> 行 ↔ ドメイン変換は `db/Mapper.kt`。`cafe_*` 列の直列化規則（photo_references の JSON 化等）は `coffee_record` と共通化する（migration は §2.3 の表）。

---

# 3. Firestore スキーマ

## 3.1 コレクション構造

```
users/{uid}                               # ユーザープロフィール（analyticsConsent フラグ等）
  coffees/{coffeeId}                      # CoffeeRecord 本体（Cafe 埋め込み / 評価 / メモ / photos 配列）
  savedCafes/{placeId}                    # 行きたい店（フェーズ 15-A。ドキュメント ID = Places の place_id）

beanProfiles/{beanId}                     # 豆ナレッジベース（サービス管理 / 全認証ユーザーが read-only）
curatedCafes/{prefectureCode}             # 都道府県別おすすめカフェ（サービス管理 / 全認証ユーザーが read-only。フェーズ 19）
```

> **未実装のコレクション**: 9-6 協調フィルタの `sharedTasteProfiles/{uid}`（設計は [`analysis-model.md`](./analysis-model.md) §2「9-6 協調フィルタリング」/ Rules は §3.3 の注記）は**設計確定のみで未作成**。上の構造は現に存在するコレクションだけを列挙している。

> **2026-06-19 改訂**: 旧 `visits` コレクション + サブコレクション（`coffeeItems` / `foodItems` / `photos`）を廃止。`coffees` コレクションの 1 ドキュメントに `cafe`（任意）と `photos`（埋め込み配列）を含める。子サブコレクションは持たない。

> **2026-06-30 追記（フェーズ 12-A）**: `users/{uid}` ルートドキュメント（`coffees` の親）にユーザープロフィールフィールドを追加。現在は `analyticsConsent: Boolean` のみ。ドキュメントが存在しない（新規ユーザー）場合は `analyticsConsent = false` と同義に扱う。

写真本体は Firestore / Storage に同期せず、端末の Documents 配下にのみ保存します（[`requirements.md`](./requirements.md) §7-2）。

### なぜ photos を埋め込み配列にしたか

- `CoffeeRecord` は 1 杯単位なので photos は数枚程度。Firestore の 1MB ドキュメント上限に十分収まる（photo はメタデータのみ、画像本体は端末ローカル）
- 子取得の N+1（record ごとに `getDocuments` を並列発行）と WriteBatch の差分 delete が不要になり、Android / iOS のリモート実装が大幅に簡素化される
- 子要素単位のリッスンは不要（1 杯のコーヒーをまとめて読み書きするため）

---

## 3.2 ドキュメント定義

### `users/{uid}`（ユーザープロフィール）

```json
{
  "analyticsConsent": false,
  "recommendationConsent": false
}
```

- **analyticsConsent**: ユーザーが記録データをサービス改善目的での集計に同意したか否か。初回起動オンボーディングで取得。後から設定画面のトグルで変更可能。ドキュメント自体が存在しない場合（未オンボーディングユーザー）は `false` として扱う。
- **recommendationConsent**（フェーズ 12-D / 9-6・設計確定 2026-07-21・未実装）: 味覚プロファイルを協調フィルタ推薦の材料として共有することへの同意。`analyticsConsent`（Firebase Analytics 集計）とは**目的が別**の独立フラグ。オプトイン・既定 false（未設定は false 扱い）。ON のとき自プロファイルを `sharedTasteProfiles/{uid}` へ upsert、OFF で削除。
- フィールドは今後増える可能性がある。

### `beanProfiles/{beanId}`（豆ナレッジ）

```json
{
  "beanId": "ethiopia-geisha-natural",
  "name": "エチオピア ゲイシャ ナチュラル",
  "origin": "エチオピア",
  "variety": "ゲイシャ",
  "processings": ["Natural"],
  "flavorNotes": ["ジャスミン", "ライチ", "ピーチ", "ローズ"],
  "description": "ゲイシャ種発祥の地エチオピアのナチュラル精製。華やかな香りとライチのようなみずみずしい甘さが際立つ。"
}
```

**表記規約（2026-07-08 確定）**:

- **日本語表記に統一**: `name` / `origin`（「エチオピア」）/ `variety`（「ゲイシャ」）/ `flavorNotes`（「ジャスミン」）/ `description` は日本語。好み突合（12-C）はユーザーが記録に入力した産地文字列との trim + lowercase 部分一致のため、日本語 UI の手入力・サジェスト表示と表記を揃える
- **`processings` は `ProcessingMethod.name`（`"Washed"` / `"Natural"` / `"Honey"` / `"Anaerobic"` / `"Other"`）の配列**: 表示文字列ではなく enum 識別子。Mapper が enum 名で逆引きするため日本語化しない
- **`beanId` は ASCII kebab-case**（例: `ethiopia-geisha-natural`）: Firestore ドキュメント ID として安全な形を維持
- **`flavorNotes` は下記の統一語彙から選ぶ（自由記述禁止）**: `PreferredBeanTraitsUseCase` の頻度集計（top-5）が表記ゆれで割れるのを防ぐ。語彙は SCA フレーバーホイール + SCAJ カッピング評価語彙由来の日本語 42 語。機械検証は seed スクリプトのバリデーションが行う

  > ジャスミン / ローズ / フローラル / シトラス / ベルガモット / レモン / オレンジ / グレープフルーツ / アップル / 洋梨 / ピーチ / アプリコット / チェリー / ストロベリー / ブルーベリー / ラズベリー / カシス / ライチ / マンゴー / パッションフルーツ / パイナップル / トロピカルフルーツ / レーズン / プルーン / ハチミツ / キャラメル / ブラウンシュガー / 黒糖 / バニラ / メープルシロップ / チョコレート / ダークチョコレート / アーモンド / ヘーゼルナッツ / ナッツ / シナモン / スパイス / 紅茶 / ワイン / ハーブ / アーシー / スモーキー

- **`description` は自作テキスト**（ロースター各社サイトからの転載禁止）。SCAJ カッピングの評価観点（酸の質 / 甘さ / 質感 / クリーンカップ / 余韻 / 調和）を記述観点に使う
- サービス管理データのため、ユーザーは read-only。write は Admin SDK または Firebase Console から
- **初期データ**: `scripts/seed/bean-profiles.json`（主要産地網羅 38 件）を `scripts/seed/seed-bean-profiles.mjs`（Admin SDK / ドキュメント ID = beanId の冪等 upsert / 投入前バリデーション）で投入する。手順は `scripts/seed/README.md`。実行はユーザー作業（サービスアカウント鍵が必要、鍵は非コミット）

### `users/{uid}/coffees/{coffeeId}`

フィールドは §1.1 の `CoffeeRecord` と同名・同順（enum は `.name` 文字列）。Firestore 固有の構造は 3 つのネストだけ:

```json
{
  "id": "uuid-v4", "userId": "firebase-auth-uid",
  "visitedOn": "2026-06-02", "rating": 4.5, "notes": "...",
  "name": "本日のコーヒー（ケニア カグモイニ）", "brewMethod": "HandDrip",
  "origin": "ケニア", "region": "ニエリ", "variety": "SL28",
  "processing": "Washed", "roastLevel": "Medium",
  "cup": "ノリタケ", "brewRecipe": "豆 15g / 湯 240ml / 92℃ / 2:30",
  "tags": ["ラテアート", "浅煎り"],

  "cafe":    { "placeId": "ChIJ...", "name": "...", "...": "§1.2 の永続 8 フィールド" },
  "tasting": { "sweetness": 7, "body": 5, "acidity": 9, "flavor": 7, "aftertaste": 6 },
  "photos":  [ { "id": "uuid-v4", "fileName": "{photoId}.jpg", "width": 1920, "height": 1080,
                 "createdAt": "<Timestamp>", "sortOrder": 0 } ],

  "createdAt": "<Timestamp>", "updatedAt": "<Timestamp>"
}
```

- **cafe**: セルフ抽出（`cafe == null`）の場合は `cafe` キーごと省略する。decode 時にキーが欠如していたら `cafe = null`
- **rating**（2026-07-12 B-4 で nullable 化）: `rating == null`（未評価）なら他の nullable フィールドと同じく**キーごと省略**。decode 時は **キー欠如 / null / `0.0`（nullable 化以前の legacy sentinel）をすべて `null` に正規化**する（iOS / Android 対称。リモートの既存 0.0 ドキュメントは migration せず読み側で吸収）
- **nullable なコーヒー属性**（origin / region / variety / processing / roastLevel / cup / brewRecipe）: null の場合はキーごと省略。`brewRecipe` はフェーズ 15-E 追加、`region` は 2026-07-22 追加（いずれも decode 時にキー欠如は null 扱い）
- **tasting**: `tasting != null` のとき 5 要素すべてを持つマップを書き出す。`tasting == null`（未記入）なら `tasting` マップごと省略。decode 時、`tasting` マップが存在し 5 要素揃っていれば `TastingScores`、欠如していれば `null`（防御的に、いずれかキー欠如も `null` 扱い）。SQLDelight も同様に **5 列全セット → `TastingScores` / それ以外 → `null`**
- **tags**: 文字列配列。空でも配列として書き出す。decode 時にキーが欠如している（フェーズ 10-D 以前の）ドキュメントは空リスト扱い
- **cafe** に書くのはスナップショット 8 フィールドのみ（§1.2 の注記参照。`openNow` 等の表示用フィールドは書かない）
- **photos**: 埋め込み配列。`localPath` は端末固有値のため Firestore には書かない。`remoteUrl` も書かない（Storage 採用見送り）。`sortOrder` は配列 index を upload 時に採番、decode 時はソート用途で破棄
- `visitedOn` は `"YYYY-MM-DD"` 文字列、`createdAt` / `updatedAt` は Firestore `Timestamp`

### `users/{uid}/savedCafes/{placeId}`（行きたい店 / フェーズ 15-A）

フィールドは `cafe`（マップ）/ `note`（String、空文字可）/ `savedAt`（`Timestamp`）の 3 つだけ。

- ドキュメント ID = `cafe.placeId`（§1.9 の自然キー方針）。保存 = `set`（上書き）、解除 = `delete` の冪等トグル
- `cafe` マップは **`coffees` の `cafe` と完全に同形**（スナップショット 8 フィールドのみ・揮発フィールドは書かない・nullable は null 時キー省略）。JSON 例は上の `coffees` を参照
- Security Rules は既存の `users/{uid}` 配下ワイルドカード（`match /{document=**}`）でカバーされるため**変更不要**

### `curatedCafes/{prefectureCode}`（都道府県別おすすめカフェ / フェーズ 19）

```json
{
  "prefectureCode": "13",
  "prefectureName": "東京都",
  "cafes": [
    {
      "placeId": "ChIJ...",
      "name": "コーヒー清澄白河",
      "latitude": 35.681,
      "longitude": 139.799
    }
  ],
  "updatedAt": "<Timestamp>"
}
```

- **1 都道府県 = 1 ドキュメント + カフェ埋め込み配列**: 全県読んでも最大 47 reads / 起動 1 回（メモリキャッシュ）。東京 100 件でも約 15KB で 1MB 上限に余裕
- ドキュメント ID = `prefectureCode`（JIS X 0401、§1.10）
- `cafes` 要素は placeId / name / latitude / longitude の 4 フィールドのみ（評価等の揮発データは書かない = Places 規約対応、§1.10）。必須フィールド欠落要素は decode 時に skip
- `updatedAt` は最終シード日時（Places 規約のリフレッシュ判断用）
- サービス管理データのため、ユーザーは read-only。write は Admin SDK のみ
- **初期データ**: `scripts/seed/generate-curated-cafes.mjs`（Places Text Search で候補生成）→ 人手レビュー → `seed-curated-cafes.mjs`（ドキュメント ID = prefectureCode の冪等 upsert / 投入前バリデーション）の 2 段構成。手順は `scripts/seed/README.md`。実行はユーザー作業

---

## 3.3 Security Rules

**正本はリポジトリルートの `firestore.rules`**（ここに複製しない）。設計方針は 2 つだけ:

- **ユーザーデータ（`users/{uid}` とその配下すべて）**: 本人のみ read/write（`request.auth.uid == uid`）。ルートドキュメント（同意フラグ）とサブコレクションを `match /{document=**}` の 2 段でカバーする
- **サービス管理のグローバルコレクション（`beanProfiles` / `curatedCafes`）**: 認証済みユーザーは read-only、`allow write: if false`（write は Admin SDK のみ）

> `firebase deploy --only firestore:rules` はユーザー作業。
>
> **9-6 で追加予定（設計確定 2026-07-21・未実装 / `firestore.rules` には未投入）**: `sharedTasteProfiles/{uid}` は本人のみ read/write。他ユーザー横断 read は Cloud Function（Admin SDK）が Rules バイパスで行うため、**Rules 側に横断 read の穴は開けない**。

---

# 4. Repository 設計

`commonMain` から Firestore SDK は直接呼べない（公式 SDK はプラットフォーム別 = iOS Swift / Android Kotlin）。そこで **2 段構成** にして、合成ロジックを共通層に 1 度だけ書く（詳細は [`kmp-bridge.md`](./kmp-bridge.md) §Repository 合成パターン）。

- `CoffeeRepository`（interface, `shared/domain`） — UI から見える唯一の API
- `RemoteCoffeeDataSource`（interface, `shared/domain`） — Firestore リスナを `Flow` で公開し、`upload(record)` / `remove(userId, id)` を持つ**薄いアダプタ**。実装はプラットフォーム別（Android = `shared/data-firebase/androidMain`、iOS = `iosApp` 側 Swift）
- `LocalCoffeeRepository`（class, `shared/data-local`） — SQLDelight のみの単体実装
- `CoffeeRepositoryImpl`（class, `shared/core`） — `LocalCoffeeRepository` と `RemoteCoffeeDataSource` を合成し、`CoffeeRepository` を満たす

各プラットフォームが書くのは `RemoteCoffeeDataSource` の実装のみ。書き込み順序（ローカル → リモート）や `startSync` はこの合成クラスに集約される。

## 4.1 インターフェース

- **`CoffeeRepository`**（UI から見える API）: `observeAll(userId)` / `observeById(id)` / `observeByCafe(userId, placeId)` の 3 つの `Flow` + `suspend save(record)`（新規・更新 共通）/ `suspend delete(userId, id)`
- **`RemoteCoffeeDataSource`**（プラットフォーム別に実装する薄いアダプタ）: `observeChanges(userId): Flow<List<CoffeeRecord>>` / `suspend upload(record)` / `suspend remove(userId, id)`

## 4.2 実装方針

- **読み取り** は **SQLDelight の Flow を Single Source として返す**
  - Firestore の更新は `RemoteCoffeeDataSource.observeChanges` を `startSync` で購読し、SQLDelight に書き戻す
  - UI からは SQLDelight のみを見る（書き戻しが完了次第、Flow が emit する）
  - **スナップショット reconciliation（2026-07-03 確定）**: `observeChanges` は指定 userId の**全件スナップショット**を返す契約のため、`startSync` は upsert だけでなく「スナップショットに存在しない id のローカル行の削除」も行う。これが無いと他端末での削除がローカル DB に永久に伝播しない
    - **除外**: dev ダミーデータ（`DummyCoffeeData.ids`）はローカル DB 限定で Firestore に流さない設計のため、reconciliation の削除対象から除外する
    - **既知の許容トレードオフ**: `save`（ローカル書き込み）から `upload` 完了までの間に「新規レコードを含まないスナップショット」が届くと、そのレコードが一瞬ローカルから消えて upload 後のリスナ echo で復活しうる。Firestore リスナは pending writes を含むため窓は極小であり、MVP では許容する（競合解決の本格化は backlog B-1）
- **書き込み** は **ローカル（SQLDelight）→ リモート（Firestore）の順** で実施
  - ローカル書き込み完了で即座に UI 更新
  - リモート書き込みの失敗扱いは `WritePolicy` で切り替え可能（既定 `PropagateRemoteFailure` = 呼び出し元に伝播 / `IgnoreRemoteFailure` = SDK のオフライン永続化の再送に委ねる）
- **写真** は端末ローカル（Documents 配下）にのみ保存する。Firestore の `coffees/{id}.photos` 配列には `fileName` / `width` / `height` / `createdAt` などメタデータのみを書き出し、`remoteUrl` は常に null（Storage 採用見送りのため）

実装は `shared/core/.../repository/CoffeeRepositoryImpl.kt`（ここにコードを複製しない）。`WritePolicy` はその nested enum。`runRemote` が `IgnoreRemoteFailure` 時に `CancellationException` を先行 catch で再スローする点は [`coding-conventions.md`](./coding-conventions.md) §1.7 の要請。

> iOS / Android が実装するのは `RemoteCoffeeDataSource`（Firestore SDK 直叩き）だけ。photos を埋め込み配列にしたため、observe は `coffees` リスナ 1 本で完結（子の都度取得は不要）、upload は単一ドキュメント `set`、remove は単一ドキュメント `delete` で済む。

## 4.3 SavedCafeRepository（フェーズ 15-A）

`CoffeeRepository` と同じ 2 段構成をそのまま踏襲する（新パターンは持ち込まない）。

- `SavedCafeRepository`（`shared/domain`、UI から見える API）: `observeAll(userId)`（マップピン / 一覧シート用）/ `observeByPlaceId(userId, placeId)`（カフェ詳細のトグル状態用）/ `save(savedCafe)`（同一 placeId は上書き）/ `delete(userId, placeId)`
- `RemoteSavedCafeDataSource`（`shared/domain`、プラットフォーム別実装）: `RemoteCoffeeDataSource` と完全に同型（`observeChanges` / `upload` / `remove`。キーが id → placeId になるだけ）
- 合成クラス `SavedCafeRepositoryImpl`（`shared/core`）: 読み取りは SQLDelight を Single Source、書き込みはローカル → リモート順、`WritePolicy` 共用、`startSync` は **coffees と同じスナップショット reconciliation**（スナップショットに無い place_id のローカル行を削除。dev ダミーデータのような除外対象は無し）
- 実装先: Android = `shared/data-firebase/androidMain`、iOS = `iosApp` 側 Swift（`FirebaseRepositories/` の既存 `RemoteCoffeeDataSource` 実装と同居）
- ViewModel 配線（公開 API は加算的変更のみ）: `MapViewModel` に `savedCafes` の購読 + ピン用状態 + 一覧シート状態、`CafeDetailViewModel` に `isSaved` トグル状態と save/delete アクション

---

# 5. ID 採番

- すべてのエンティティ ID は **クライアント側で UUID v4 を採番** する
- Firestore のドキュメント ID もこの UUID を使う（auto-id は使わない）
- 端末オフラインでも採番できる、複数端末間で衝突しない、SQLDelight と Firestore で同じ ID を使えるメリットがある
- **例外: `SavedCafe` は `cafe.placeId` を自然キーにする**（§1.9。同一カフェの二重登録を型レベルで防ぎ、保存 / 解除を冪等トグルにするため。UUID は持たない）

---

# 6. 日時の扱い

- `kotlinx-datetime` を使う
- `visitedOn`: `LocalDate`（タイムゾーン非依存。ユーザーが「いつ飲んだか」を表現）
- `createdAt` / `updatedAt`: `Instant`（UTC エポック millis）
- Firestore では `Timestamp` 型として保存し、ドメインモデルに戻す時に `Instant` へ変換

---

# 7. バリデーション

- `rating` は null（未評価）または 0.5..5.0 の範囲（0.5 刻み）。**未評価のままの保存を許可する**（2026-07-12 B-4。「まず記録、あとで評価」を可能に）。非 null 時のみ 0.5..5.0 かつ 0.5 刻みをバリデーション
- `name`（コーヒー名）は必須・最大 200 文字（SQLite の現実的な上限）
- `notes` は最大 2000 文字
- `cafe` は任意（未選択でもセルフ抽出として保存可能）
- バリデーションは **ViewModel 層で行う**（ドメインモデル自体は値を信用する）

---

# 8. エクスポート JSON（envelope v1）

Kotlin / SQLDelight / Firestore に続く **第 4 の表現＝外部向けフォーマット**（[`requirements.md`](./requirements.md) §7-4）。ユーザーへのデータ持ち出し手段であり、開発用インポートスクリプトが読む**外部契約**でもあるため、正本をここに置く。

- **生成**: `ExportCoffeeRecordsUseCase`（`shared/domain/.../usecase/`、`suspend operator fun invoke(userId): String`）。`observeAll(userId).first()` の全件を DTO 化して 1 本の JSON 文字列にする（ファイル書き出し・共有シートは iOS 側）
- **DTO は export 専用**（`shared/domain/.../domain/export/`）: ドメインモデルに `@Serializable` を付けず `CoffeeRecordExportDto` / `CafeExportDto` / `PhotoExportDto` / `TastingScoresExportDto` に変換する（ドメイン層に kotlinx-serialization を持ち込まない）
- **`Json` 設定は `prettyPrint = true` + `encodeDefaults = true`**: `version` や空 `tags` / `photos` がキーごと省略されるのを防ぐ。結果として **null フィールドもキーとして出力される**（Firestore 側の「null はキー省略」とはここだけ非対称）
- **フィールド規則は Firestore（§3.2）を踏襲**: enum は `.name` 文字列 / `visitedOn` は `"YYYY-MM-DD"` / `createdAt` `updatedAt` は ISO-8601 文字列 / `cafe` は永続 8 フィールドのみ（§1.2 の揮発フィールドは含めない）/ `photos` はメタデータのみ（`localPath` は端末固有値のため除外、画像バイナリは対象外）

```json
{
  "exportedAt": "<ISO-8601>",
  "version": 1,
  "records": [ /* CoffeeRecordExportDto */ ]
}
```

- **`version` は互換性の契約**: 現在 1 固定。既存キーの意味変更・削除を伴う変更ではインクリメントし、下記の消費側も追随させる
- **消費側**: `scripts/seed/seed-coffees.mjs`（開発用の Firestore 投入。envelope v1 をそのまま受け、null キー省略 / `Timestamp` 化 / `photos` 空化 / `userId` 付け替えの差分だけ吸収する）。**`toDocument` は明示的なキー allowlist なので、フィールド追加時はここも追随が必要**（未知キーは素通しされず落ちる）。**アプリ内のインポート機能は意図的に非対応**（復元は Firestore 同期 7-3 + iCloud Backup 7-2 が担う。経緯は [`implementation_note.md`](./implementation_note.md) 2026-07-13）
- **`CoffeeRecord` にフィールドを追加したら DTO + Mapper も同時に更新する**（独立した `data class` の手写しなのでコンパイラが検出せず、追随漏れは無言のデータ欠損になる）。2026-07-22 に追加した `region` が唯一の追随漏れで、2026-07-25 に修正済み。恒久策として `CoffeeRecordExportMapperTest.fullyPopulatedRecord_allFieldsMapToExportDto` が `CoffeeRecord` 全フィールドと DTO を 1 対 1 で突き合わせる（教訓と 5 経路の点検手順は [`tasks/lessons.md`](./tasks/lessons.md) 2026-07-25）

---

## 参考リンク

- [SQLDelight](https://sqldelight.github.io/sqldelight/)
- [Firestore — データモデル](https://firebase.google.com/docs/firestore/data-model)
- [Firestore — オフライン永続化](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
- [Google Places API](https://developers.google.com/maps/documentation/places/web-service)
- [アーキテクチャ方針](./architecture.md)
