---
name: swift6-migration-diagnostics
description: Swift 6 移行（既定 MainActor 分離）の xcconfig 設定方法、pbxproj と xcconfig の優先順位、診断採取手順、@preconcurrency import SharedLogic の効き方の見分け方
metadata:
  type: project
---

## `SWIFT_VERSION` 等のビルド設定は xcconfig と pbxproj buildSettings が重複すると pbxproj が勝つ

`project.pbxproj` の `XCBuildConfiguration.buildSettings` に直接書かれたキーは、同じキーを `baseConfigurationReference`（xcconfig）に書いても**上書きされない**（pbxproj 側が優先）。xcconfig 側の新しい値を効かせたいときは、pbxproj の該当 `buildSettings` からそのキーの行を先に削除する必要がある。CoffeeVision では Debug/Release 両方の `SWIFT_VERSION = 5.0;` を pbxproj から削除し、`Base.xcconfig` に一本化して移設した（SW6-1、2026-08-07）。

`Base.xcconfig` は末尾で `#include? "Secrets.xcconfig"` している（同一キーは最後の代入が勝つ仕様）ため、新しい設定は必ずこの include より前に書く。

## `xcodebuild` の引数で `SWIFT_STRICT_CONCURRENCY` 等を渡してはいけない（xcconfig 経由にする）

コマンドライン引数（`xcodebuild ... SWIFT_STRICT_CONCURRENCY=complete`）で渡すと SPM 依存パッケージ全体（`FirebaseCoreInternal` 等）に波及してビルドが壊れる（親が実測済み）。必ず `Base.xcconfig` にキーを追加し、アプリターゲットの `buildSettings` にだけ効かせる。

## `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` は診断を減らす方向にも働く

`SWIFT_STRICT_CONCURRENCY = complete` 単体（Swift 5 言語モード）で出ていた警告のうち、以下は `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + `SWIFT_APPROACHABLE_CONCURRENCY = YES` を追加すると**自然に消える**（クラス全体が既定で MainActor 分離されるため、`Task { }` が生成元の isolation を継承し、closure キャプチャの sending 警告が起きなくなる）:
- `PreviewSamples.swift` の static let（`is not concurrency-safe because non-Sendable...`）系 10 件
- `PhotoFileStore.thumbnailCache` の同型警告
- `CoffeeInsightProviderIosImpl.swift` の `Task { completionHandler(...) }` 3 箇所（`passing closure as a 'sending' parameter`）

逆に、既定 MainActor 化によって**新規に**出る警告もある（`BeanProfileRepositoryIosImpl` / `CuratedCafeRepositoryIosImpl` の `NSObject, XxxRepository` 実装クラス。Obj-C プロトコル要件のメソッドがクラス既定の MainActor 分離と衝突し、`main actor-isolated static method ... in a synchronous nonisolated context` 等が出る）。**2 段階（strict concurrency のみ → MainActor 追加）で計測しないと、どちらの設定がどの診断の原因かが切り分けられない**。

## `@preconcurrency import SharedLogic` が効くかどうかは、警告の発生源で機械的に見分けられる

実地検証（1 ファイルずつ一時的に `@preconcurrency import SharedLogic` を追加 → ビルド → 警告消滅を確認 → 元に戻す、を反復）した結果:

- **消える**: 警告本文に Kotlin/SharedLogic 由来の型名（`AccountViewModel` / `any AuthRepository` / `any CafeRepository` / `AppContainer` 等）が直接現れているもの。`ViewModelBridge` の `deinit { kotlin.clear() }`（`cannot access property 'kotlin' with a non-Sendable type ... from nonisolated deinit`）、`AppState.swift` の `container` 越しの `sending` 警告、`PlacePhotoLoader` の `any CafeRepository` 越しの警告など。**`SettingsView.swift` のように直接 `import SharedLogic` していないファイルでも、`appState.container.xxxUseCase` のように間接参照するだけで同型警告が出ることがある**（型推論経由）ので、ファイル冒頭に `SharedLogic` の import を足せば同様に効く
- **効かない**: 警告の非 Sendable 型が Swift/Apple 側の型（`() -> Void` クロージャ、`CLLocationManager` 等）のもの。`FlowBridge.swift` の `CallbackFlow`/`CallbackFlowOptional` の `deinit { onCancel() }`（`onCancel` は自前の `() -> Void` プロパティで SharedLogic 型ではない）、`LocationManager.swift` の `CLLocationManagerDelegate` 実装（`manager: CLLocationManager` が非 Sendable）は `@preconcurrency import SharedLogic` を足しても消えない。これらは `nonisolated` 指定やクロージャ再設計など個別の対処が要る

判定手順: 警告メッセージ中の型名を見て「`SharedLogic`（Kotlin ⇄ Swift ブリッジ）由来の型か」を確認する。曖昧なときは 1 ファイルだけ `@preconcurrency import SharedLogic` を足して再ビルドし、消えるか確認するのが最も速い（`iosApp` 単体ターゲットの differential ビルドは 1 ファイル変更なら数十秒で終わる。`clean build` は不要、通常の `build` で該当ファイルだけ再コンパイルされる）。

### 訂正（SW6-5, 2026-08-07）: 「ストアドプロパティ経由」の Sendable 警告は `nonisolated(unsafe)` の方が `@preconcurrency` より筋が良い

上記の `PlacePhotoLoader` / `AppState.container` の「`sending self.xxx risks causing data races`」系警告は、実は**ファイル単位の `@preconcurrency import` を使わなくても**、該当ストアドプロパティ 1 個に `nonisolated(unsafe)` を付けるだけで消えることが分かった（SW6-2/SW6-5 で確認）。原理: `@MainActor` クラスの非 `nonisolated` ストアドプロパティは既定でクラスと同じ MainActor 分離を継承するため、それを Kotlin の `suspend` 呼び出し（isolation 不明な callee）に渡すと「MainActor リージョンから非 Sendable 値を送り出す」形になり警告が出る。`nonisolated(unsafe)` を付けるとそのプロパティが最初から MainActor リージョンに属さなくなるため、`.xxx` 経由で派生する値（`container.authRepository` 等、Kotlin 側の子プロパティ）も連鎖して警告が消える。

- **`@preconcurrency import` より優先すべき理由**: `@preconcurrency` はファイル全体の SharedLogic 型すべての Sendable 検査を丸ごと外すため、そのファイルの以降の変更でデータ競合を持ち込んでもコンパイラが黙る。`nonisolated(unsafe)` は該当プロパティ 1 個に絞れるため副作用が小さい
- **適用条件**: そのプロパティが「実質不変」（`init` で 1 度だけ代入され、以後は同一アクター上からしか読まれない）であること。CoffeeVision では `PlacePhotoLoader.repository`（`let`）と `AppState.container`（`private(set) var`、`init` 後は再代入されない）の 2 例で適用し、いずれも警告 0 件を確認
- **`@Observable` マクロとの相性に注意**: `@Observable` が管理する `var` プロパティ（`_container` へのラップが生成される）に `nonisolated(unsafe)` を付けると、`'nonisolated(unsafe)' has no effect on property ..., consider using 'nonisolated'` という誤誘導的な警告が出る。しかし素の `nonisolated`（`unsafe` 無し）に変えると **`'nonisolated' cannot be applied to mutable stored properties`** で明確にビルドエラーになる（`@Observable` の `willSet`/`didSet` 展開が `var` を要求するため）。正解は `nonisolated(unsafe)` を維持しつつ、その前に **`@ObservationIgnored`** を付けてマクロの介入自体を止めること（変更検知が不要なプロパティ = 一度しか代入されない値なら実害なし）。`nonisolated(unsafe)` 単体で出る "has no effect" 警告は `@ObservationIgnored` 併用で消える
- **`@Sendable` closure 型引数に Kotlin 型がそのまま登場するケースは `nonisolated(unsafe)` では塞げない**（プロパティの isolation の話ではなく、関数シグネチャ自体の Sendable 要件のため）。`BeanProfileRepositoryIosImpl.__getAll(completionHandler: @escaping @Sendable ([BeanProfile]?, ...) -> Void)` のように、Kotlin 型が `@Sendable` closure の**引数型**として登場する場合は `@preconcurrency import SharedLogic` が唯一の現実的な手段（Kotlin 側のインターフェースを変えない限り、呼び出し側で個別に回避できない）

## 検証時は `-configuration Debug clean build` を使う（設定変更の反映確認に `build` 単体は不十分なことがある）

`Base.xcconfig` にキーを追加しただけの初回反映確認では `build`（非 clean）でも設定は効くが、**診断の全件採取が目的のときは `clean build` にする**。理由: 既にコンパイル済みのファイルは設定変更後も条件次第で再コンパイルされず（Xcode のビルドシステムがフラグ変更を検知して再コンパイルするのが通常だが）、全ファイルの警告を取りこぼさないための保険として `clean build` が確実。SW6-1 では baseline（`SWIFT_VERSION` 移設のみ）は `build`、Step A / Step B の診断採取は `clean build` を使った。

## `nonisolated deinit` 警告（`cannot access property ... from nonisolated deinit`）は `isolated deinit`（SE-0371, Xcode 27 / Swift 6.4 で使用可）でも `nonisolated final class` でも消える。使い分けはクラスの実際の呼び出しスレッドで決める

SW6-1 の追加検証（2026-08-07）で実物 2 パターンを確認:
- `AccountViewModelBridge`（`@MainActor final class`、SwiftUI/AppState から MainActor 上でのみ生成・保持される）: `deinit { kotlin.clear() }` → `isolated deinit { kotlin.clear() }` に変えるだけで該当 2 件（`AddPreconcurrencyImport` + `nonisolated deinit`）が消える。副作用や新規警告は 0 件
- `FlowBridge.swift` の `CallbackFlow` / `CallbackFlowOptional`（`NSObject, Kotlinx_coroutines_coreFlow` — Kotlin ランタイムが `__collect` を呼び、Kotlin 側の参照カウントが 0 になったときに deinit が走る。**呼び出し元スレッドが MainActor とは限らない**）: `isolated deinit` でも警告は消えるが、これは deinit の実体を MainActor へ非同期にホップさせる（SE-0371）ため、`onCancel()`（Firestore/Auth リスナの `remove()`）の実行が実際の解放タイミングより遅延しうる。**`nonisolated final class` にして plain `deinit` のままにする方が実態と整合し、ホップ無しで警告も消える**（呼び出し元ファイル `AuthRepositoryIosImpl.swift` 等の再コンパイルでも新規警告 0 件を確認済み）

判定軸: そのクラスが「Swift/SwiftUI 側からのみ MainActor 上で保持・破棄される」なら `isolated deinit`、「Kotlin ランタイム等 MainActor 外から破棄されうる」なら `nonisolated` 化が筋が良い（ホップによる解放遅延を避けられる）。`ViewModelBridge` 系（8 ファイル）は前者、`FlowBridge.swift` の 2 クラスは後者に該当する。SW6-2 で実装確定（8 ファイル `isolated deinit`、`FlowBridge` は `nonisolated final class` + plain `deinit`）。

## サンドボックスに GUI Simulator が無いときの `@concurrent` オフロード確認手段（2026-08-21）

タップ操作でアプリの実際の画面を辿れない環境（`sandbox_no_gui_simulator.md` 参照）でも、`@concurrent` が実際にメインスレッドを外れるかは**アプリ本体を経由せず**確認できる。`iosApp` と同じコンパイラフラグ（`Base.xcconfig` の `SWIFT_VERSION = 6.0` + `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + `SWIFT_APPROACHABLE_CONCURRENCY = YES`）を単体の `swiftc` 実行で再現し、`nonisolated async`（`@concurrent` 無し）と `@concurrent` を並べて `Thread.isMainThread` を出力させるだけで挙動差が出る:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun swiftc \
  -swift-version 6 -default-isolation MainActor \
  -enable-upcoming-feature NonisolatedNonsendingByDefault \
  -parse-as-library -o /tmp/test main.swift && /tmp/test
```

`Thread.isMainThread` は `NS_SWIFT_UNAVAILABLE_FROM_ASYNC` なので、`async` 関数内から直接呼ぶとコンパイルエラーになる（`nonisolated func currentThreadIsMain() -> Bool { Thread.isMainThread }` という同期ラッパーを挟めば呼べる）。実測（2026-08-21, ShareCardRenderer.writeToTemporaryFile 検証時）:

```
[caller]            isMainThread=true
[withoutConcurrent] isMainThread=true   // @concurrent 無し → 呼び出し元アクター（MainActor）のまま
[withConcurrent]    isMainThread=false  // @concurrent あり → グローバル並行実行コンテキストへ退避
```

これは `.claude/rules/swift-ios.md` / `docs/coding-conventions.md` §2.5 に書かれている「`@concurrent` 無しの `nonisolated async` は呼び出し元アクター上で実行される」という記述の直接的な実測裏取りになる。アプリ本体の該当関数を個別に実機/シミュレータで確認できないときの代替手段として使える。

## `UIImage` はこのプロジェクトの SDK では actor 境界を越えて渡せる（Sendable 扱い）

`ImageDownsampler.downsampledJPEG` / `downsampledImage`（`@concurrent`）は `UIImage` を戻り値として MainActor 呼び出し元へ返しており、これは既に警告なしでビルドが通っている実例。`ShareCardRenderer.writeToTemporaryFile(_ image: UIImage)`（`@concurrent`、`UIImage` を引数として MainActor から渡す）も同じ前提で警告 0 件だった（2026-08-21）。`UIImage` を境界越しに渡すこと自体を疑って `nonisolated(unsafe)` 等で包む必要はない。

## `@concurrent` は enclosing 型を `nonisolated` にしなくても付けられる（関数単位で完結）

`nonisolated enum PhotoFileStore` は型ごと `nonisolated` だが、`ImageDownsampler`（`enum ImageDownsampler`、型注釈なし）の `@concurrent static func` は型を `nonisolated` にせずに成立している。`ShareCardRenderer`（`@MainActor` 相当の既定分離のまま）に `@concurrent private static func writeToTemporaryFile` を追加したケースでも同様に、型全体を書き換えずに該当関数だけ `@concurrent` を付ければ足りた。既定 MainActor 分離の enum に「CPU バウンドな処理だけ 1 関数だけ逃がしたい」ときは、型ごと `nonisolated` にする前にまず関数単体の `@concurrent` を試す。

## Kotlin interface 実装クラスを `nonisolated` にすると、内部で使う private ヘルパ（enum の static func 等）も連鎖して `nonisolated` にする必要がある（SW6-2, 2026-08-07）

`RemoteCoffeeDataSourceIosImpl` / `RemoteSavedCafeDataSourceIosImpl`（Kotlin interface 実装、Kotlin ランタイムが任意スレッドから呼ぶため `nonisolated` にした）は、内部で `CoffeeFirestoreMapper.fromDocument` / `SavedCafeFirestoreMapper.toDocument` という**別ファイルの top-level enum**を呼んでいた。この enum 自体は既定 MainActor 分離のままだったため、`nonisolated` にしたクラスから呼ぶと `call to main actor-isolated static method ... in a synchronous nonisolated context` が新規発生する。**呼び出し元だけでなく、呼び出し先のヘルパ型も一緒に `nonisolated` 化する**必要がある（ステートレスな純粋変換関数なら安全）。同じパターンが `BeanProfileRepositoryIosImpl` の private enum `BeanProfileIosMapper` でも発生した（SW6-1 の検証時点で先に対処済み）。

## `NSObject, KotlinProtocol` 実装クラスを `nonisolated` にすると、`var` の可変キャッシュが未保護になる（`OSAllocatedUnfairLock` + `@unchecked Sendable` で対処、SW6-2）

Firestore の completion handler は既定で main queue から呼ばれる一方、Kotlin interface 実装（`__getAll` 等）の呼び出し元スレッドは Kotlin ランタイム次第で不定（`docs/kmp-bridge.md` の呼び出し方向の議論）。`nonisolated` 化前は既定 MainActor 分離のおかげで**偶然**両方が MainActor 上で揃っていたが、`nonisolated` にすると素の `var cache: [T]?` は無保護の共有可変状態になる。修正パターン:

```swift
import os
nonisolated final class XxxRepositoryIosImpl: NSObject, XxxRepository, @unchecked Sendable {
    private let cache = OSAllocatedUnfairLock<[T]?>(initialState: nil)
    func __getAll(completionHandler: @escaping @Sendable ([T]?, (any Error)?) -> Void) {
        if let cached = cache.withLock({ $0 }) { completionHandler(cached, nil); return }
        // ... Firestore fetch ...
        self?.cache.withLock { $0 = fetched }
    }
}
```

`OSAllocatedUnfairLock<State>`（`import os`、iOS 16+）は `State: Sendable` を要求せず、ロックが唯一のアクセス経路であることをコンパイラに伝える（`@unchecked Sendable` はクラス全体に必要 — `NSObject` は自動 Sendable にならないため）。`BeanProfileRepositoryIosImpl` / `CuratedCafeRepositoryIosImpl` / `CoffeeInsightProviderIosImpl`（`recordQuery` フィールド）で採用。**構築後に一度も再代入されないフィールド**（`CoffeeInsightProviderIosImpl.tasteExtractor` — `makeIfAvailable()` 内でインスタンス公開前に 1 度だけ設定）はロック不要（safe publication）。

## `@concurrent` は「nonisolated async が呼び出し元アクターで走ってしまう」問題の直接的な解決策（SW6-3, 2026-08-07）

`NonisolatedNonsendingByDefault`（Swift 6 モードで既定）下では、`nonisolated` な `async` 関数は**呼び出し元のアクター上で**実行される（従来の「nonisolated async は勝手にバックグラウンドへ逃げる」という直感は Swift 6 では成立しない）。CPU 負荷の高い処理（JPEG デコード等）を持つ `nonisolated async` 関数には `@concurrent` を明示し、グローバル並行実行コンテキストへ強制的に逃がす必要がある（`PhotoFileStore.loadThumbnail` で適用）。

- `@concurrent` を付けると、その関数からアクセスする**既定 MainActor 分離のグローバル/static プロパティ**へのアクセスがすべて `main actor-isolated ... cannot be accessed from outside of the actor` エラーになる。関数を含む型ごと `nonisolated`（またはプロパティ個別に `nonisolated`/`nonisolated(unsafe)`）にする必要がある
- `NSCache` のような「ドキュメント上スレッドセーフだが Swift の Sendable 注釈がない」型の static let は `nonisolated(unsafe)` が正解（`@preconcurrency` はここでは無関係 — SharedLogic 由来ではないため効かない）
- **横断確認の結果**（2026-08-07）: `iosApp` 全体で `async` 関数を grep した結果、この「nonisolated async が重い同期処理を inline に持つ」パターンは `PhotoFileStore.loadThumbnail` のみ。他の `async` 関数（`AdConsentCoordinator.run` / `ReviewPrompt.requestIfFirstSignalReached` は明示 `@MainActor` で UI 操作が本題、`RemoteConfigBootstrap.fetchAndActivate` は Firebase SDK の非同期ネットワーク呼び出しで inline の重い同期処理なし）は該当しない。**関連するが対象外の類似パターン**として、`ImageDownsampler.downsampledJPEG`（同期関数、`CoffeeEditorView`（`@MainActor` View）から直接呼ばれ main thread でデコードする）と `PhotoThumbnailCell` の `PhotoFileStore.loadImage`（同期フルデコード、View body 内）があるが、どちらも `async` ではなく本タスク（nonisolated async の暗黙バックグラウンド実行問題）のスコープ外
