# Lessons（自己改善ループ用メモ）

実装を進める中で気付いた、再発させたくない落とし穴・お作法を蓄積する場所です。
セッション開始時に見直し、関連するルールを再確認してください。

---

## 2026-06-02

### SQLDelight 2.x の命名規則

- `.sq` ファイル内の `CREATE TABLE coffee_item` から生成される Kotlin クラスは **`Coffee_item`**（先頭大文字のみ）になる。`CoffeeItem` にはならない
- カラム名 `cafe_place_id` もそのまま `cafe_place_id` プロパティになる（自動 camelCase 化しない）
- Queries クラスは `.sq` ファイル名から: `Visit.sq` → `VisitQueries`、`CoffeeItem.sq` → `CoffeeItemQueries`。データクラス名と命名が揃わないので注意
- ドメインモデルと生成行クラスの名前衝突は **import alias**（`import com.noricoffee.domain.Visit as DomainVisit`）で解消する

### KMP + SQLDelight のテスト配置

- `sqlite-driver`（JdbcSqliteDriver）は **JVM 専用**。`commonTest` の `dependencies` に入れると iosTest コンパイルで落ちる
- 解決策: 共通テストロジックは `commonTest` に書きつつ、ドライバ生成だけ `expect fun createInMemoryTestSqlDriver(): SqlDriver` で逃がす。actual を `androidHostTest`（JdbcSqliteDriver）と `iosTest`（NativeSqliteDriver の `onConfiguration = { it.copy(inMemory = true) }`）に置く
- `androidHostTest` の Gradle 依存追加は `sourceSets { getByName("androidHostTest").dependencies { ... } }` で行う

### Gradle タスク名（android KMP プラグイン）

- `androidHostTest` という名前のタスクは存在しない。実行タスクは `testAndroidHostTest`
- コンパイル単体は `compileAndroidHostTest`
- iOS テストのコンパイル確認は `compileTestKotlinIosSimulatorArm64`（実機起動なしで通せる）

### `expect class` の Beta 警告

- Kotlin 2.x で `expect class` は Beta 扱いで警告が出る
- `kotlin { compilerOptions { freeCompilerArgs.add("-Xexpect-actual-classes") } }` で抑止
- KMP のレシピでは `expect/actual` クラスは引き続き標準。Beta は警告レベルの話で機能は安定

### SQLDelight トランザクションと Flow の emit タイミング

- `db.transaction { ... }` 内で複数テーブルを upsert しても、`asFlow()` の購読者には **トランザクション commit 後に一度だけ** 通知が届く
- 子テーブル（coffee_item / food_item / photo）だけを更新した場合、`visit` 行を観測している `observeAll` には emit が **来ない**。Phase 1 は常に `save(visit)` で visit 行も更新する設計のため問題なしだが、将来子テーブル単独更新を入れるなら `combine` で複数 Query を束ねる

### ドメインモデルとマッパの責任分担

- バリデーション（rating の 1..5、name の長さ等）は **ViewModel 層に置く** 方針（`data-model.md` §7）
- Mapper は純粋な型変換に徹し、例外を投げる箇所を増やさない
- Enum の DB 表現は `name` 文字列。未知の値が DB に入っていたら `valueOf` が `IllegalArgumentException` を投げるが、これは「マイグレーション漏れ」を即座に検知できるのでむしろ望ましい
