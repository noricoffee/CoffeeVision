# データモデル

CoffeeVision のドメインモデルを **Kotlin（ドメイン）/ SQLDelight（ローカル DB）/ Firestore（クラウド）** の 3 表現で定義します。

エンティティ一覧:

- `Visit`（訪問記録）
- `Cafe`（カフェ情報。`Visit` に埋め込み）
- `CoffeeItem`（コーヒー記録。`Visit` の子）
- `FoodItem`（フード記録。`Visit` の子）
- `Photo`（写真。`Visit` の子）

---

## エンティティ関連図

```
User (Firebase Auth uid)
  │
  └── Visit (1..N)
        ├── Cafe              (1, 埋め込み)
        ├── Photo             (0..N)
        ├── CoffeeItem        (0..N)
        └── FoodItem          (0..N)
```

---

# 1. Kotlin ドメインモデル

`shared/domain/src/commonMain/kotlin/com/noricoffee/domain/` 配下に配置します。

## 1.1 Visit

```kotlin
package com.noricoffee.domain

import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

data class Visit(
    val id: String,                       // UUID v4
    val userId: String,                   // Firebase Auth uid
    val cafe: Cafe,                       // Places API 由来のスナップショット
    val visitedOn: LocalDate,             // 訪問日
    val ambiance: String,                 // 内装の雰囲気（自由入力）
    val rating: Int,                      // 1..5（総合評価）
    val notes: String,                    // 自由メモ
    val photos: List<Photo>,
    val coffees: List<CoffeeItem>,
    val foods: List<FoodItem>,
    val createdAt: Instant,
    val updatedAt: Instant,
)
```

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
)
```

> **写真について**: Places API の写真は `photo_reference` をキーに **都度取得** する規約。
> ローカルに永続キャッシュしないこと（規約違反になる場合がある）。

## 1.3 CoffeeItem

```kotlin
data class CoffeeItem(
    val id: String,
    val name: String,                     // メニュー名
    val brewMethod: BrewMethod,
    val origin: String?,                  // 産地（国 / エリア）
    val variety: String?,                 // 品種
    val processing: ProcessingMethod?,    // 精製方法
    val roastLevel: RoastLevel?,          // 焙煎度
    val cup: String?,                     // カップの種類 / ブランドメモ
    val rating: Int,                      // 1..5
    val notes: String?,                   // 風味・所感
)

enum class BrewMethod {
    Espresso,
    HandDrip,
    NelDrip,
    FrenchPress,
    AeroPress,
    Syphon,
    ColdBrew,
    Other,
}

enum class ProcessingMethod {
    Natural,
    Washed,
    Honey,
    Anaerobic,
    Other,
}

enum class RoastLevel {
    Light,
    Cinnamon,
    Medium,
    High,
    City,
    FullCity,
    French,
    Italian,
}
```

## 1.4 FoodItem

```kotlin
data class FoodItem(
    val id: String,
    val name: String,
    val rating: Int,                      // 1..5
    val notes: String?,
)
```

## 1.5 Photo

```kotlin
data class Photo(
    val id: String,
    val localPath: String?,               // Documents 配下からの相対ファイル名（例: "visits/{visitId}/{photoId}.jpg"）。iOS Documents URL は起動ごとに変わるため絶対パス禁止
    val remoteUrl: String?,               // 将来 Firebase Storage 復活用フィールド。現状は常に null
    val width: Int?,
    val height: Int?,
    val createdAt: Instant,
)
```

> 現状は `localPath` が常に非 null（端末ローカル保存）、`remoteUrl` は常に null（将来 Storage 復活用にフィールドだけ残置）。

---

# 2. SQLDelight スキーマ

ローカル DB は **検索・オフライン参照の高速化** が目的。Firestore のキャッシュとは別途に持つ。
配置: `shared/data-local/src/commonMain/sqldelight/com/noricoffee/db/`

## 2.1 Visit.sq

```sql
CREATE TABLE visit (
    id TEXT NOT NULL PRIMARY KEY,
    user_id TEXT NOT NULL,
    cafe_place_id TEXT NOT NULL,
    cafe_name TEXT NOT NULL,
    cafe_address TEXT,
    cafe_latitude REAL,
    cafe_longitude REAL,
    cafe_photo_references TEXT NOT NULL,  -- JSON 配列
    cafe_website_url TEXT,
    cafe_maps_url TEXT,
    visited_on TEXT NOT NULL,              -- ISO-8601 (YYYY-MM-DD)
    ambiance TEXT NOT NULL,
    rating INTEGER NOT NULL,
    notes TEXT NOT NULL,
    created_at INTEGER NOT NULL,           -- epoch millis
    updated_at INTEGER NOT NULL
);

CREATE INDEX visit_by_user_visited ON visit (user_id, visited_on DESC);
CREATE INDEX visit_by_cafe ON visit (cafe_place_id);

selectAll:
SELECT * FROM visit WHERE user_id = ? ORDER BY visited_on DESC, created_at DESC;

selectById:
SELECT * FROM visit WHERE id = ?;

selectByCafe:
SELECT * FROM visit WHERE user_id = ? AND cafe_place_id = ? ORDER BY visited_on DESC;

upsert:
INSERT OR REPLACE INTO visit (
    id, user_id, cafe_place_id, cafe_name, cafe_address,
    cafe_latitude, cafe_longitude, cafe_photo_references,
    cafe_website_url, cafe_maps_url,
    visited_on, ambiance, rating, notes,
    created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

deleteById:
DELETE FROM visit WHERE id = ?;
```

## 2.2 CoffeeItem.sq

```sql
CREATE TABLE coffee_item (
    id TEXT NOT NULL PRIMARY KEY,
    visit_id TEXT NOT NULL,
    name TEXT NOT NULL,
    brew_method TEXT NOT NULL,             -- enum 文字列
    origin TEXT,
    variety TEXT,
    processing TEXT,                       -- enum 文字列
    roast_level TEXT,                      -- enum 文字列
    cup TEXT,
    rating INTEGER NOT NULL,
    notes TEXT,
    sort_order INTEGER NOT NULL,
    FOREIGN KEY (visit_id) REFERENCES visit(id) ON DELETE CASCADE
);

CREATE INDEX coffee_item_by_visit ON coffee_item (visit_id, sort_order);

selectByVisit:
SELECT * FROM coffee_item WHERE visit_id = ? ORDER BY sort_order ASC;

upsert:
INSERT OR REPLACE INTO coffee_item (
    id, visit_id, name, brew_method, origin, variety, processing,
    roast_level, cup, rating, notes, sort_order
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

deleteByVisit:
DELETE FROM coffee_item WHERE visit_id = ?;

deleteById:
DELETE FROM coffee_item WHERE id = ?;
```

## 2.3 FoodItem.sq

```sql
CREATE TABLE food_item (
    id TEXT NOT NULL PRIMARY KEY,
    visit_id TEXT NOT NULL,
    name TEXT NOT NULL,
    rating INTEGER NOT NULL,
    notes TEXT,
    sort_order INTEGER NOT NULL,
    FOREIGN KEY (visit_id) REFERENCES visit(id) ON DELETE CASCADE
);

CREATE INDEX food_item_by_visit ON food_item (visit_id, sort_order);

selectByVisit:
SELECT * FROM food_item WHERE visit_id = ? ORDER BY sort_order ASC;

upsert:
INSERT OR REPLACE INTO food_item (
    id, visit_id, name, rating, notes, sort_order
) VALUES (?, ?, ?, ?, ?, ?);

deleteByVisit:
DELETE FROM food_item WHERE visit_id = ?;

deleteById:
DELETE FROM food_item WHERE id = ?;
```

## 2.4 Photo.sq

```sql
CREATE TABLE photo (
    id TEXT NOT NULL PRIMARY KEY,
    visit_id TEXT NOT NULL,
    local_path TEXT,
    remote_url TEXT,
    width INTEGER,
    height INTEGER,
    created_at INTEGER NOT NULL,
    sort_order INTEGER NOT NULL,
    FOREIGN KEY (visit_id) REFERENCES visit(id) ON DELETE CASCADE
);

CREATE INDEX photo_by_visit ON photo (visit_id, sort_order);

selectByVisit:
SELECT * FROM photo WHERE visit_id = ? ORDER BY sort_order ASC;

upsert:
INSERT OR REPLACE INTO photo (
    id, visit_id, local_path, remote_url, width, height, created_at, sort_order
) VALUES (?, ?, ?, ?, ?, ?, ?, ?);

deleteByVisit:
DELETE FROM photo WHERE visit_id = ?;

deleteById:
DELETE FROM photo WHERE id = ?;
```

## 2.5 マッピング方針

- DB 行 ↔ ドメインモデル変換は `db/Mapper.kt` に集約する
- 子テーブルは別クエリで取得し、Repository でまとめる（JOIN は使わず、`Flow.combine` で結合）
- 写真の参照配列など複数値は **JSON 文字列**（`kotlinx.serialization`）で 1 列に格納する

---

# 3. Firestore スキーマ

## 3.1 コレクション構造

```
users/{uid}
  visits/{visitId}                       # Visit 本体（Cafe / 評価 / メモ）
    coffeeItems/{coffeeItemId}           # サブコレクション
    foodItems/{foodItemId}               # サブコレクション
    photos/{photoId}                     # サブコレクション（メタ情報のみ。写真本体は端末ローカル）
```

写真本体は Firestore / Storage に同期せず、端末の Documents 配下にのみ保存します（[`requirements.md`](./requirements.md) §7-2）。

### なぜサブコレクションか

- 1 Visit に紐づく子要素が数十個になり得る → 単一ドキュメントの 1MB 上限を回避
- 子要素を個別に更新したい（写真の進捗・コーヒーの並び替え等）
- 子要素単位のリッスンが可能になる

---

## 3.2 ドキュメント定義

### `users/{uid}/visits/{visitId}`

```json
{
  "id": "uuid-v4",
  "userId": "firebase-auth-uid",
  "cafe": {
    "placeId": "ChIJ...",
    "name": "Blue Bottle 三軒茶屋",
    "address": "東京都世田谷区...",
    "latitude": 35.6448,
    "longitude": 139.6694,
    "photoReferences": ["AcJnMu..."],
    "websiteUrl": "https://bluebottlecoffee.jp/",
    "mapsUrl": "https://maps.google.com/?cid=..."
  },
  "visitedOn": "2026-06-02",
  "ambiance": "落ち着いた木質の内装、奥に大きな焙煎機",
  "rating": 4,
  "notes": "店員さんが品種を教えてくれた",
  "createdAt": <Timestamp>,
  "updatedAt": <Timestamp>
}
```

### `.../coffeeItems/{coffeeItemId}`

```json
{
  "id": "uuid-v4",
  "name": "本日のコーヒー（ケニア カグモイニ）",
  "brewMethod": "HandDrip",
  "origin": "ケニア",
  "variety": "SL28",
  "processing": "Washed",
  "roastLevel": "Medium",
  "cup": "ノリタケ",
  "rating": 5,
  "notes": "ベリー系の華やかな酸味",
  "sortOrder": 0
}
```

### `.../foodItems/{foodItemId}`

```json
{
  "id": "uuid-v4",
  "name": "バナナブレッド",
  "rating": 4,
  "notes": null,
  "sortOrder": 0
}
```

### `.../photos/{photoId}`

```json
{
  "id": "uuid-v4",
  "width": 1920,
  "height": 1080,
  "createdAt": <Timestamp>,
  "sortOrder": 0
}
```

- `localPath` は Firestore には保存しません（端末ごとの値のため。ローカル DB のみが持つメタデータ）
- `remoteUrl` も Firestore には書きません（Storage 採用見送りのため常に null。Kotlin / SQLDelight スキーマ上のフィールドは将来復活用に残置）

---

## 3.3 Security Rules（概略）

```
service cloud.firestore {
  match /databases/{db}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == uid;
    }
  }
}
```

---

# 4. Repository 設計

インターフェース定義は `shared/domain/src/commonMain/kotlin/com/noricoffee/repository/`、合成実装（`VisitRepositoryImpl` / `LocalVisitRepository`）は `shared/core/src/commonMain/kotlin/com/noricoffee/repository/` および `shared/data-local/src/commonMain/kotlin/com/noricoffee/repository/` に配置。

## 4.1 インターフェース例

```kotlin
interface VisitRepository {
    fun observeAll(userId: String): Flow<List<Visit>>
    fun observeById(id: String): Flow<Visit?>
    fun observeByCafe(userId: String, placeId: String): Flow<List<Visit>>

    suspend fun save(visit: Visit)        // 新規・更新 共通
    suspend fun delete(id: String)
}
```

## 4.2 実装方針

- **読み取り** は **SQLDelight の Flow を Single Source として返す**
  - Firestore の更新は別途リスナで購読し、SQLDelight に書き戻す
  - UI からは SQLDelight のみを見る（書き戻しが完了次第、Flow が emit する）
- **書き込み** は **SQLDelight → Firestore の順** で実施
  - SQLDelight の書き込み完了で即座に UI 更新
  - Firestore への書き込みは並行で投げ、失敗時は SDK のオフラインキューに任せる
- **写真** は端末ローカル（Documents 配下）にのみ保存する。Firestore の `photos` サブコレクションには `fileName` / `width` / `height` / `createdAt` などメタデータのみを書き出し、`remoteUrl` は常に null（Storage 採用見送りのため）

```kotlin
class VisitRepositoryImpl(
    private val db: AppDatabase,
    private val firestore: Firestore,
    private val scope: CoroutineScope,
) : VisitRepository {

    override fun observeAll(userId: String): Flow<List<Visit>> =
        db.visitQueries.selectAll(userId)
            .asFlow()
            .mapToList(Dispatchers.Default)
            .combineWithChildren(db)   // coffee/food/photo を結合

    override suspend fun save(visit: Visit) {
        db.transaction {
            db.visitQueries.upsert(visit.toRow())
            db.coffeeItemQueries.deleteByVisit(visit.id)
            visit.coffees.forEachIndexed { i, c ->
                db.coffeeItemQueries.upsert(c.toRow(visit.id, sortOrder = i))
            }
            // food / photo も同様
        }

        scope.launch {
            runCatching {
                firestore.collection("users").document(visit.userId)
                    .collection("visits").document(visit.id)
                    .set(visit.toFirestoreMap())
                // 子サブコレクションも同様に書く
            }.onFailure {
                // SDK の永続化キューが再送するので、UI には出さない
            }
        }
    }

    override suspend fun delete(id: String) { ... }
}
```

> Firestore のリッスンと SQLDelight との突き合わせは **後続フェーズ** で実装する。
> MVP では「同一端末のローカル更新 + バックグラウンド送信」のみで十分動作する。

---

# 5. ID 採番

- すべてのエンティティ ID は **クライアント側で UUID v4 を採番** する
- Firestore のドキュメント ID もこの UUID を使う（auto-id は使わない）
- 端末オフラインでも採番できる、複数端末間で衝突しない、SQLDelight と Firestore で同じ ID を使えるメリットがある

---

# 6. 日時の扱い

- `kotlinx-datetime` を使う
- `visitedOn`: `LocalDate`（タイムゾーン非依存。ユーザーが「いつ訪れたか」を表現）
- `createdAt` / `updatedAt`: `Instant`（UTC エポック millis）
- Firestore では `Timestamp` 型として保存し、ドメインモデルに戻す時に `Instant` へ変換

---

# 7. バリデーション

- `rating` は 1..5 の範囲
- `name` / `ambiance` は最大 200 文字（SQLite の現実的な上限）
- `notes` は最大 2000 文字
- バリデーションは **ViewModel 層で行う**（ドメインモデル自体は値を信用する）

---

## 参考リンク

- [SQLDelight](https://sqldelight.github.io/sqldelight/)
- [Firebase Kotlin SDK](https://github.com/GitLiveApp/firebase-kotlin-sdk)
- [Firestore — データモデル](https://firebase.google.com/docs/firestore/data-model)
- [Firestore — オフライン永続化](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
- [Google Places API](https://developers.google.com/maps/documentation/places/web-service)
- [アーキテクチャ方針](./architecture.md)
