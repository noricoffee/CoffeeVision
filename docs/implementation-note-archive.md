# 実装ノート アーカイブ（2026-06）

[`implementation_note.md`](./implementation_note.md) から切り出した**凍結済み**の過去分。2026-06 のエントリ（フェーズ 1〜14 相当の完了記録）36 件。

- **ここには追記しない。** 新しいエントリは常に `implementation_note.md` へ書く
- 他 doc やコードコメントの「implementation_note 2026-06-XX エントリ」という参照は**この doc を指す**（参照は日付で引く運用のため、参照側の書き換えは不要）
- 現在生きている方針のサマリは `implementation_note.md` の「現在生きてる方針サマリ」が正本。ここの記述は**当時の判断の記録**であり、現行仕様とは限らない
- 分離の判断は `implementation_note.md` 2026-07-25 エントリ

---

### 2026-06-11: SwiftUI Preview は「戦略 B（ダミー Demo）」+ PreviewSamples 集約

- 関連: `iosApp/iosApp/PreviewSupport/PreviewSamples.swift`

本体 View は `AppState` / Kotlin VM を要求する Bridge に強く依存するため、Preview で本物の Bridge を構築せず、`#Preview` ブロック内に「同等構造のダミー Demo」を書く方針。ダミーデータは `PreviewSamples.swift` に `static let` で集約して Preview 間で共有。本体の構造が変わった際は Preview 側の追従が必要（コード重複は割り切り。`private struct Content` 抽出リファクタで解消可能だが MVP では見送り）。

### 2026-06-11: Phase 4 — Places API (New) v1 採用と API キー注入経路

- 関連: `shared/data-places/**`, `iosApp/Configuration/**`, `androidApp/build.gradle.kts`

- **Places API (New) v1 採用**（`places.googleapis.com/v1/...`、`X-Goog-Api-Key` + `X-Goog-FieldMask` ヘッダ必須）。Legacy 不採用の理由は、新規プロジェクトは New 推奨で料金体系も New に集約、FieldMask で課金対象フィールドを明示できるため
- **API キーは `AppContainer` コンストラクタ注入**。Android = `local.properties` → `buildConfigField` → BuildConfig、iOS = `Secrets.xcconfig`（gitignore 済）→ Info.plist → `Bundle.main`。KMP コアはキーの出所を知らず、テストではダミーキーを渡せる。不採用: KMP から `local.properties` 直読み（runtime から読めない）/ 環境変数（iOS 実機ビルドで効かない）/ ソース hardcode（失効リスク）
- **KMP `internal` は同一 Gradle モジュール内に閉じる**: `internal expect fun createPlacesHttpClient()` は `api` 依存の別モジュールから呼べない。`PlacesModule.kt` に公開ファクトリ `createCafeRepository(apiKey)` を置き、HttpClient のエンジン選択（Darwin / OkHttp）と構築詳細を `data-places` 内に隠蔽する設計を採用
- Ktor を `framework` に export すると `Ktor_httpHttpStatusCode.description` が Swift の `description()` と衝突し SKIE が `description_` にリネームする警告が出る（ビルドは通る。UI から未参照のため放置）
- キー未設定でもビルドは通る（実 API 呼び出しで 401 になるだけ）。CI で実キー不要にする原則

### 2026-06-13: VisitedCafe 集計のトレードオフ

- 関連: `shared/domain/.../usecase/ObserveVisitedCafesUseCase.kt`

マップ / カフェ詳細向けの `VisitedCafe`（placeId 単位の集計モデル）で確定した判断:

- **`cafe` スナップショットは「最新記録勝ち」**: 同 placeId で店名・住所が変わっていた場合、最新記録のものに上書きされる。記録自体には当時のスナップショットが残る
- `lastVisitedAt` は `visitedOn`（LocalDate）を UTC 0:00 の Instant に変換した**ソート専用値**。表示には `visitedOn` を直接使うこと
- `rating == 0` は未評価として `averageRating` 算出から除外（全件 0 なら null）

### 2026-06-15: Places 写真の都度取得（Photo Media API）

- 関連: `shared/data-places/.../PlacesClient.kt`, `iosApp/.../Utilities/PlacePhotoLoader.swift`

- **`skipHttpRedirect=true` で `photoUri`（時限署名 URL）を JSON 取得**し AsyncImage に渡す。不採用: `?key=API_KEY` の 302 リダイレクト方式（キーが画像 URL に埋まりログ等から露出、ヘッダ認証との一貫性も崩れる）
- **永続キャッシュなし**（Places 規約）。AsyncImage 内部の標準 HTTP キャッシュのみ許容、`photoUri` レスポンスも保持しない
- `PlacePhotoLoader` は状態を持たない URL ファクトリ（`@MainActor`、`@Observable` 不要）
- Swift 側の注意: Kotlin `Int?` は `KotlinInt?` で公開（`KotlinInt(int:)` ラップが必要）。`AsyncImagePhase` は struct のため `@unknown default` が必要（`default` 禁止規約の例外）

### 2026-06-16: エラートースト共通コンポーネント（errorToast）

- 関連: `iosApp/iosApp/Components/ErrorToast.swift`

`ui-ux-guidelines.md` の方針（非致命 = トースト / 致命 = alert）を実装。使い分け: 非致命（同期・検索・位置取得・POI lookup 失敗）→ `View.errorToast(message:onDismiss:)`、致命（保存失敗）とアクション可能（位置情報許可拒否 → 設定誘導）→ `.alert` 据え置き。

- **複数エラー源は `activeToast`（優先順位付き単一値）に集約してから 1 つだけ付ける**。`.overlay(alignment: .top)` のため 2 つ付けると衝突する。優先度は ViewModel 由来 > 補助エラー
- 自動消去は `.task(id: message)`（message 変化で前タスク自動キャンセル）。VoiceOver には `AccessibilityNotification.Announcement` を投稿

### 2026-06-16: App Icon / Launch Screen / 表示名

- 関連: `iosApp/scripts/generate_app_icon.swift`, `iosApp/iosApp/Assets.xcassets/`

表示名 = `CoffeeVision`（`CFBundleDisplayName`。bundle ID / `PRODUCT_NAME` は不変）。アイコンは **AppKit + SF Symbol（`cup.and.saucer.fill`）をレンダリングする Swift スクリプト生成**方式。デザイン変更時はリポジトリルートから `swift iosApp/scripts/generate_app_icon.swift` で再生成して PNG を上書きコミット（light / dark / tinted の 3 variant）。Launch Screen は storyboard を使わず Info.plist の `UILaunchScreen` 辞書方式（`INFOPLIST_KEY_UILaunchScreen_Generation` は競合するため削除済み）。ワードマークは文字を焼き込んだ透過 PNG（`UILaunchScreen` はテキストラベルを置けないため）。

### 2026-06-17: アカウント機能 — Apple 連携 / サインアウト / 削除 / トークン失効（revoke）

- 関連: `shared/feature/account/`, `shared/domain/.../{AuthAccount,AuthRepository,DeleteAccountUseCase}.kt`, `iosApp/.../{AccountView,AppleSignInCoordinator,AuthRepositoryIosImpl}.swift`

（2026-06-17 設計 + Dispatch B 追補 + 2026-06-24 E-1 revoke 実装を統合）

- **プロバイダは Sign in with Apple のみ**（Google 見送り: GoogleSignIn SDK 追加回避、Apple は審査上必須で `AuthenticationServices` のみ = 追加依存ゼロ）。資格情報取得と Firebase 操作は iOS Swift、KMP は `AuthRepository` の抽象操作と ViewModel / UseCase のみ
- **アップグレード = `link` で uid 不変**（Firestore / ローカル DB / 写真がそのまま引き継がれ、uid 再配線不要）。匿名のときだけ提示
- **サインアウト / 削除 = uid が変わる → `resetAndRebootstrap()`（新規匿名サインインでブリッジ再構築）に収束**。サインアウト後の既存ローカルデータは uid フィルタで自然に隠れるため残置。削除時のみ実データ消去（`DeleteAccountUseCase` が「全記録削除 → Auth ユーザー削除」の順序を強制。**写真ファイル削除は端末ローカルのため iOS 責務**）
- **`SignInWithAppleButton`（SwiftUI 組み込み）は rawNonce を外部公開しない**ため Firebase の nonce 検証に使えない。`ASAuthorizationController` を async ラップした `AppleSignInCoordinator`（CryptoKit で nonce + SHA256）を自作
- `observeAccount()`（`AuthAccount` を流す）を新設。サインアウト時の nil emit のため `FlowBridge.swift` に `CallbackFlowOptional<T>` を追加
- ネイティブ Apple フローは Web リダイレクトが発生しないため、**コールバック URL / Services ID 登録は「サインインだけなら」不要**（プロバイダ有効化のみで足りる）
- **revoke（E-1、2026-06-24 実装）**: App Store ガイドライン 5.1.1(v) 対応。`revokeToken(withAuthorizationCode:)` に必要な authorization code は一度きり・約 5 分有効・保存禁止のため、**削除時に Apple サインインをやり直して取得** → `reauthenticate`（旧課題 `requiresRecentLogin` も同時解消）→ revoke → KMP 削除、の順で Swift がオーケストレーション。キャンセル = 無音中断、reauth / revoke 失敗 = 削除中断（revoke できないなら削除しない）
- **前提（ユーザー作業・App Store 審査前必須）**: revoke は Firebase がサーバサイドで Apple の revoke エンドポイントを叩くため、Firebase Console → Apple プロバイダに **OAuth コードフロー設定（Services ID / Team ID / Key ID / .p8 秘密鍵）**の登録が必要。未設定だと revoke は常に失敗 → 削除不能になる。Apple プロトコル上 Services ID はネイティブ revoke に不要だが、**Console が 4 項目を 1 セットで検証するため実運用上は Services ID 作成・入力が必須**

### 2026-06-19: マップ現在地 FAB の recenter はフラグ方式

- 関連: `iosApp/.../Features/Map/MapTabView.swift`

FAB タップで `pendingRecenter = true` → `requestLocation()` → `.onChange(of: lastLocation?.latitude)` で 1 回だけセンタリング。`resetLastLocation()`（nil 化）を使わないことで、`lastLocation` を参照する他の経路への副作用をゼロにした。`.denied` / `.restricted` は FAB を `.disabled` + 減光。旧実装の `TabBarFrameReader`（検索タブの幾何検出で FAB を配置する UIKit ハック）は 2026-06-30 の検索タブ廃止で削除済み — 現在は `overlay(alignment: .bottomTrailing)` + padding 固定。

### 2026-06-19: コーヒー記録主体への再設計（Visit → CoffeeRecord、Phase 7）

**集約ルートを `Visit`（カフェ訪問）から `CoffeeRecord`（コーヒー 1 杯）へ転換**。`CoffeeItem` / `FoodItem` を廃止し、旧 `CoffeeItem` の属性（name / brewMethod / origin / variety / processing / roastLevel / cup）を `CoffeeRecord` へ昇格、旧 `Visit` の visitedOn / rating / notes / photos を移管。`ambiance` / `FoodItem` は自由メモ `notes` に吸収。カフェは nullable（null = セルフ抽出）。**クリーンブレイク**（未リリースのため移行コードなし。テスト端末はアプリ削除 → 再インストール）。

トレードオフ / 影響:
- **`VisitedCafe` は名前を維持**し集計元だけ変更（iOS 参照が広く、意味変更のみに留めた。改名は将来の任意タスク）
- **Firestore は `coffees` 単一ドキュメント + `photos` 埋め込み配列**（旧: 子サブコレクション 3 種）。observe の子 N+1 取得と WriteBatch 差分 delete が消え、両プラットフォームの Remote 実装が大幅簡素化。大量写真の要件が出たらサブコレクションへ戻す
- **feature モジュールをリネーム**（`visit-*` → `coffee-*`）。`shared/framework` の `export(...)` と `api(...)` の**両方**を更新する必要あり（片方だと型が Swift に出ない）
- null cafe の扱い: `selectByCafe` は SQL 等値マッチで自然除外（セルフ抽出はマップ / カフェ詳細に出ない = 意図通り）。`ObserveVisitedCafesUseCase` は明示 `cafe != null` フィルタ

### 2026-06-19: コーヒー評価を 0.5 刻み Double に（ハーフスター）

`CoffeeRecord.rating` を `Int`(1..5) → `Double`(0.5..5.0、0.0 = 未評価) に変更。0.5 の倍数は IEEE 754 で厳密表現できるため DB(REAL) / Firestore(number) 往復と等値判定が安全。バリデーションは `rating < 0.5 || rating > 5.0 || (rating * 2) % 1.0 != 0.0`。Firestore の旧 Int 保存ドキュメントは Android = `(Number).toDouble()`、iOS = `Double ?? NSNumber.doubleValue` で受けて後方互換。iOS 入力は星を左右 2 分割した透明タップ領域（`StarTapCell`）で 0.5 刻み、`accessibilityAdjustableAction` 対応。

### 2026-06-19: 分析機能の設計（3 階層分離 / insightStatus / iOS UI / FM 要約）

- 関連: `docs/requirements.md` §9, `docs/analysis-model.md` §1, `shared/feature/analysis/.../AnalysisViewModel.kt`, `shared/core/.../AppContainer.kt`, `iosApp/.../Features/Analysis/`

（A-1〜A-4 の 4 エントリを統合。最終仕様は analysis-model.md §1 が正）

**核となる原則 — 集計は KMP、解釈は LLM**。階層1（記述統計）/ 階層2（傾向抽出）は KMP 共通層で決定論的に算出（`CoffeeStats` / `BuildCoffeeStatsUseCase`）、階層3（自然言語の要約・Q&A）だけ iOS Foundation Models で、**入力は集約済み `CoffeeStats` のみ**（生レコードは渡さない）。理由: ①正確性（平均を LLM に計算させない）②オンデバイス LLM のコンテキスト窓 ③再現性・テスト容易性 ④3 ロール体制に綺麗に割れる。

- **プラットフォーム非対称は `CoffeeInsightProvider` interface（domain）で吸収**: iOS = `LanguageModelSession` 実装、Android = null 注入（分析タブ非表示）。Apple Intelligence 非対応端末も同じ null フォールバック
- **可否判定は注入時 1 回**: `makeIfAvailable()` が `SystemLanguageModel.default.availability == .available` のときだけ実装を返す。nil → `InsightStatus.Unsupported` → 要約カード非表示（**KMP 変更ゼロで graceful degradation**）
- **統計と要約は独立ロード状態**: 統計は Flow で即時反映、要約は後追い。要約が失敗・非対応でも統計画面は完全機能する。`InsightStatus` は `sealed interface` + `data object`（Unsupported / Idle / Loading / Loaded / Failed）で、SKIE SealedInterop 経由で Swift の `is` 分岐になる
- **`AppContainer` コンストラクタが 3 系統**（プライマリ = テスト用 scope 注入 / セカンダリ A = iOS・provider 注入 / セカンダリ B = Android・provider null）なのは、SKIE がデフォルト引数を Swift に出さない制約への対処（scope 隠蔽パターンの踏襲）
- **iOS 実装は SKIE protocol witness**（`__summarize(stats:completionHandler:)` の completion handler 形式）。`@Generable` の構造化出力 `CoffeeInsightOutput(headline, body)` は **SwiftUI `View.body` との名前競合を避けるため private struct に閉じる**。session はリクエストごと生成（ステートレス）
- iOS UI は `ScrollView` + `LazyVStack` のカード方式。`CoffeeStats` 系の `Identifiable` 適合は **`id: Int32`**（KMP `Int` = Swift `Int32`）。空状態は `ContentUnavailableView`（グラフ種別の改訂は 2026-07-13 エントリ、空状態プログレスは 2026-07-06 15-D で更新）
- follow-up（実害小・未対応）: availability の動的再チェック / unavailable 理由別の案内 UI

### 2026-06-19: ダミーデータ Scheme（開発支援）

- 関連: `shared/core/.../dev/DummyCoffeeData.kt`, `iosApp/iosApp.xcodeproj/xcshareddata/xcschemes/`

専用 Xcode Scheme（`iosApp (Dummy Data)`、env `SEED_DUMMY_DATA=1`）で起動したときだけ約 30 件のダミー `CoffeeRecord` を投入。

- **投入先はローカル DB のみ**（private `localCoffeeRepository` 経由。Firestore に流さない。`startSync` は remote→local upsert のみでローカルのダミーは消えない）
- **固定 ID（`dummy-0001`..`0030`）で冪等**。通常 Scheme 起動時は clear（実データ = UUID には触れない）。Release ビルドは seed / clear とも無効
- `visitedOn` は今日基準の動的算出（常に直近 12 ヶ月で月次グラフが映える）。rating=0.0 を 2 件含め未評価除外パスも確認可能
- seed / clear の失敗は `print` のみ（通常起動毎に clear が走るためユーザー可視エラーにしない）

### 2026-06-20: テイスティング 5 要素は all-or-nothing（`TastingScores?`）

- 関連: `docs/data-model.md` §1.1a / `docs/analysis-model.md` §1

Blue Bottle「Elements of Coffee Tasting」由来の**甘味 / ボディ / 酸味 / 風味 / 後味**を `CoffeeRecord.tasting` として追加。スケールは 1〜10 の**強度**（良し悪しではない。総合評価 `rating` とは別軸）。

- **型で partial を表現不可能に**: `TastingScores` の 5 フィールドは非 null `Int`、`CoffeeRecord.tasting` が `TastingScores?`。「null = 未記入 / 非 null = 5 要素すべてあり」を型が保証し、バリデーションのエラー経路が不要
- 経緯: 当初は各要素独立 nullable で実装したが、テイスティングは 5 軸セットで初めて比較・平均できるため all-or-nothing に即日変更（クリーンブレイクで作り直し）
- SQLDelight は 5 列 nullable のまま（Mapper が all-set のときだけ組み立て）。Firestore は非 null のとき 5 要素マップ、null は省略
- UX: `+` ボタンで `TastingScores(5,5,5,5,5)` を生成し 5 スライダーを一括表示。削除で null に戻す
- **転換点メモ**: TestFlight 配布開始後は DB 列変更すべてに SQLDelight マイグレーションが必須になる

### 2026-06-21: 対話 Q&A の段階設計（v1 = digest 注入 / v2 = tool calling）

（v1 / v2 の 2 エントリを統合。最終仕様は analysis-model.md §1「対話 Q&A v1 / v2」が正）

`CoffeeInsightProvider` に `@Throws suspend fun answer(question, stats): String` を 1 本追加するだけの加算的変更。可否ゲートは要約と共有。

- **あえて削ったもの**: チャットスレッド型（履歴 + session ライフサイクル管理が重い）→ 1 問 1 答・ステートレス / tool・生レコード参照 → v2 へ / 逐次表示（`Flow<String>` は「Swift 側で Flow を作る」ハードパスになる）→ suspend 一発
- instructions でグラウンディング（統計の範囲でのみ答える / 不明は「記録からは分かりません」/ 再計算しない）
- `QaStatus` sealed（Unsupported / Idle / Asking / Answered / Failed）は insight と同じ状態機械パターン。`suggestedQuestions` は `Array(companion.SUGGESTED_QUESTIONS)` で取得（`as? [String]` は warning）
- `error` フィールドを insight 系と共用するため同時発火時に上書きされうる（稀・状態で判別可能なので許容）

**v2（tool calling / 生レコード参照、9-4b）**:

- 関連: `shared/domain/.../model/CoffeeRecordQuery.kt`, `iosApp/.../Features/Analysis/SearchCoffeeRecordsTool.swift`

- **既存 interface / VM / UI は不変の加算的変更**: `answer(question, stats)` のシグネチャ据え置きで、iOS 実装が内部で tool を登録するだけ（v1 の状態機械を再利用）
- **単一の柔軟な検索 tool** `CoffeeRecordQuery.searchRecords(filter)` 1 本。filter は全 String / Double / Int（enum なし）で、LLM 生成文字列を KMP 側で寛容マッチ。limit は不正値を clamp（既定 10 / 上限 100）
- **userId は KMP 実装が内部解決**（Swift tool は意識しない）。ブリッジ方向は v1 と逆の Swift→Kotlin（SKIE が `async throws` を生成、witness 不要）
- **遅延アタッチ**: provider は container より先に生成され container 引数になるため、`coffeeRecordQuery` は `attachRecordQuery(_:)` で構築後に後付け（依存サイクル解消。詳細は kmp-bridge.md）
- **実機デバッグの結論**（試行錯誤は git 履歴参照）: ①モデルが digest を「全記録の網羅リスト」と誤認して tool を呼ばない → instructions を命令形にし「digest は非網羅の要約 / 記録の有無は tool 結果のみで判断」を明示 ②固有名詞のフィールド誤分類（カフェ名を `origin` に入れて 0 件）→ KMP 側で `origin` / `cafeName` を**フィールド横断 free-text term 化**（公開 API 不変で解決。analysis-model §1 反映済）
- Swift 側注意: Kotlin `Double?` は `KotlinDouble?`（ラップ必要）。`localizedBrewMethod` 等が 3 ファイルに重複（`CoffeeLocalizer` 共通化候補）

### 2026-06-21: CI Android ジョブでダミー google-services.json を生成

- 関連: `.github/workflows/ci.yml`

`googleServices` プラグイン導入で `:androidApp:assembleDebug` が `google-services.json`（gitignore 済）を必須化し CI が失敗。Android はリリース対象外の検証ターゲットで実 Firebase 接続は不要のため、CI 内でゼロ埋めダミーを生成して通す（**GitHub Secrets 管理を不要にした**）。実接続テストが将来必要になったら別途仕組みを作る。

### 2026-06-22: 好み判定（FavoriteSignals）の統計設計 — 収縮平均 + n 連動ゲート

- 関連: `shared/domain/.../usecase/BuildCoffeeStatsUseCase.kt`, `FavoriteSignalsPersonaTest.kt`, `docs/analysis-model.md` §1

（B-1 / B-1b / B-1c / B-1d の 5 エントリを統合。最終仕様は analysis-model §1 が正）

**設計原則**: 生平均ランキングは n=1 の 5.0 が n=20 の 4.2 に勝つ罠があるため、①件数ガード ②経験ベイズ収縮 `shrunkMean = (n·mean + k·globalMean)/(n+k)`（k=5）で抑える。正方向のみ信号化。テイスティング軸はピアソン相関（符号付き。r<0 =「低いほど高評価」も返す）。**交絡は計算しない**（「産地が好き」か「その産地の店が好き」かは個人データでは分離不能。「言える範囲を計算で確定し、LLM はその範囲でしか言わない」= グラウンディングの土台）。

**ペルソナ検証（B-1b）で偽陽性を実測**: 検出力用ペルソナ P1〜P4・P7（仕込んだ好みを拾えるか）+ null ペルソナ P5（好みが無いとき黙れるか）を固定シードで生成し、150 シードで偽陽性率を集計。結果: **カテゴリ信号 100% / tasting 軸 40%**（5 軸 max|r| の winner's curse）。「最大群が globalMean を超えたら信号化」はほぼ恒真で、ゲートになっていなかった。

**対策の変遷と確定値**:
- B-1c: effect-size 閾値 `CATEGORY_MIN_EFFECT = 0.20` + tasting |r| 下限を n 連動化 `max(0.3, 1.97/√n)` → tasting 40%→22%。**カテゴリは固定 δ では下がらない**（winner's curse の幅は σ/√n に比例して膨らむため。不均等分布の実測でも 86.7%）
- B-1d: カテゴリにも n 連動 z ゲート **`mean - globalMean > CATEGORY_Z(=2.0) · globalStd / √n` AND δ** を導入 → カテゴリ FP 100%→**9.3%**（heavy-skew）、検出力は全工程で維持。z=2.5/3.0 は FP ほぼ 0% にできるが実データの弱い好みを弾きすぎるため不採用。選定キーは shrunkMean のまま（n=1 外れ値に頑健）
- 公開 API は companion 定数の追加のみ（`SHRINKAGE_PRIOR_WEIGHT=5` / `CORRELATION_MIN_SAMPLE=5` / `CORRELATION_ABS_FLOOR_C=1.97` / `CATEGORY_MIN_EFFECT=0.20` / `CATEGORY_Z=2.0`）。iOS 追随不要
- iOS 側は `buildPrompt` に好み信号を「弱い傾向 + 件数の但し書き」で渡し、instructions で断定を禁止

### 2026-06-22: 味覚一致カフェのマップ連携（B-4 v1・コンテンツベース推薦）

- 関連: `docs/analysis-model.md` §2, `shared/domain/.../{RecommendedCafe.kt,ObserveTasteMatchedCafesUseCase.kt}`, `iosApp/.../Features/Map/`

（設計確定 + KMP 実装 + iOS 追随の 3 エントリを統合）

- **一致定義**: `rating >= 4.0` かつ `FavoriteSignals` のカテゴリ好み（bestOrigin / RoastLevel / BrewMethod）いずれかに一致する記録が 1 件以上。`dominantTastingAxis`（相関軸）は per-record の categorical 一致に変換できないため v1 では使わない（ユーザー合意済み）
- **将来移行を見据えた境界**: 推薦は `CafeRecommendationProvider`（interface）の裏。v1 = ローカル決定論実装、将来 9-6 = サーバ実装への**差し替えだけ**で UI / VM / FM 言語化層は不変。理由は `sealed RecommendationReason`（種類追加可能）、`RecommendedCafe.cafe` は `Cafe` のみ保持（未訪問カフェ推薦に拡張可能な契約）
- 実装メモ: UseCase は `BuildCoffeeStatsUseCase` 全体を実行（重複排除優先、重くなったら分離）。`PreferenceMatchAxis` の Swift case 名は camelCase（`.origin` / `.roastLevel` / `.brewMethod`。`.swiftinterface` で実地確認済み）
- iOS UX: 一致ピンは heart.fill 38pt。タップで**理由シート → 詳細の 2 タップ**（"なぜおすすめか" を先に見せる。callout での 1 タップ化は v2 余地）

### 2026-06-22: Future Direction — 協調フィルタリング推薦（9-6）と FoundationModel の住み分け

- 関連: requirements 9-6・analysis-model §2 `CafeRecommendationProvider`

将来像（ユーザー意向）: 複数ユーザーが好みを登録し、**好みが近い他ユーザーの高評価カフェを提案**する（協調フィルタリング）。「今は作らないが設計の北極星」として残す。

- **方式の住み分け**: v1（9-5）= コンテンツベース。9-6 = 協調フィルタで、v1 に**追加**で載る（content → collaborative は典型的な発展経路）
- **味覚の類似度は LLM 不要・決定論**: 好みは既に構造化数値（`tastingAverages` 5 軸 + カテゴリ別評価分布）= そのまま特徴ベクトル。cosine 等で決定論的に計算でき、テキスト埋め込み学習は不要。**FM の役割は将来も「計算済みの推薦結果を一言で言語化」一点**
- **横断ベクトル計算はサーバ側（GCP 等）**。右サイズ重要 — 5〜10 次元・中規模なら Firestore のベクトル KNN or Cloud Function の総当たり cosine で十分
- **本体の難所は計算でなく基盤**: ①プロファイルのサーバ集約（現状 per-user・path-uid のみ）②明示同意 / オプトイン ③カフェ識別子は placeId で共有可能 = item キーに好都合 ④コールドスタート（だから v1 content-based が先、が正しい順序）

### 2026-06-23: Places 疎通トラブルシュート（xcconfig 上書き / エラー握り潰し / bundle ID ヘッダ）

- 関連: `iosApp/Configuration/Base.xcconfig`, `shared/data-places/.../{PlacesClientImpl.kt,PlacesHttpClient.ios.kt}`

「アプリ上で検索が空結果」の切り分けで、**3 つの独立した問題**が重なっていたことが判明（統合エントリ）:

1. **（真因）API キーの空上書き**: `Base.xcconfig` がフォールバック宣言 `PLACES_API_KEY =` を `#include? "Secrets.xcconfig"` の**後ろ**に書いており、xcconfig は最後の代入が勝つため実キーが空文字で上書きされていた。→ フォールバックを include の**前**へ移動（サマリの xcconfig 3 段構造ルール参照）
2. **API エラーの握り潰し**: `places = emptyList()` デフォルト + Ktor 既定 `expectSuccess=false` により、403 のエラー JSON が「結果 0 件」に化けて発覚を遅らせた。→ `expectSuccess=true` + `HttpResponseValidator` で本文付き `PlacesApiException` を投げる
3. **iOS バンドル ID 制限ヘッダ**: API キーの iOS バンドル ID 制限は `X-Ios-Bundle-Identifier` ヘッダで判定されるが、自動付与するのは公式 GMS SDK のみで Ktor 生 REST では未付与 → `403 API_KEY_IOS_APP_BLOCKED`。→ `iosMain` の `actual createPlacesHttpClient()` で `NSBundle.mainBundle.bundleIdentifier` を `defaultRequest` ヘッダに付与。**iOS 固有制約は `iosMain` の actual に閉じ、`commonMain` は不変**（Android に漏らさない）。`HttpClient.config` は元設定を引き継ぐため `PlacesClientImpl` 側の再構成でも伝播する（Ktor 3.0.3 ソース確認済）

切り分けは curl 実証（ヘッダ有無で 403/200）+ `.app/Info.plist` の実値確認 + バイナリ `grep -a` の 3 点。

### 2026-06-23: 周辺カフェ検索の精度修正（encodeDefaults + includedPrimaryTypes）

- 関連: `shared/data-places/.../PlacesClientImpl.kt`

周辺検索に駅・ホテル等の非カフェが混ざった 2 要因: ①kotlinx.serialization の既定 `encodeDefaults=false` で `includedTypes` 等のデフォルト値フィールドが JSON に載らず、型フィルタ無しの searchNearby になっていた → `encodeDefaults=true`（`explicitNulls=false` 併用で null 省略は維持）②`includedTypes`（cafe を副次に含む場所）+ prominence 順では大型店が上位に来る → **`includedPrimaryTypes=["cafe","coffee_shop"]` + `rankPreference="DISTANCE"`** に変更（`coffee_shop` 併記はチェーン店の分類対策）。

### 2026-06-23: CafeSearch — 「該当なし」は検索確定後のみ表示（UIState.hasSearched）

「`results` が空である理由」を「未検索」と「検索したが 0 件」に区別するため `UIState.hasSearched` を追加（真実の源は ViewModel）。`onQueryChanged` で false、検索の**成功完了時のみ** true。入力中は初期プロンプト維持、確定して 0 件のときだけ「該当なし」。

### 2026-06-23: PlacesClientImpl.searchText — 地名クエリへのカフェ語補完

`includedType="cafe"` 付きの Text Search に地名のみ（「渋谷」等）を渡すと locality 型に一致して 0 件になる（curl 実測）。ユーザーのテキスト検索経路（バイアスなし `searchText(query)`）に限り、カフェ語（カフェ / cafe / café / コーヒー / 珈琲 / coffee）を含まないクエリ末尾へ `" カフェ"` を補完。POI タップの placeId 解決経路（bias あり）と `searchNearby` は対象外。「カテゴリ + 地域を textQuery で表現」は Google 推奨の自然言語パターンであり、idiomatic な対応。

### 2026-06-23: SwiftUI Map の Legal オーナメントは `safeAreaPadding` に追随しない

`Map` を `.ignoresSafeArea()`（全辺）にすると内部 `MKMapView` の Legal 表記が TabBar 裏に隠れる。`safeAreaPadding` は Map 内部のオーナメント配置レイヤーに伝播しない（固定大値でも動かないことを確認）。**`.ignoresSafeArea(.container, edges: [.top, .horizontal])` に変更**し、下辺だけセーフエリアを残して Legal を TabBar 上に出す。下辺のフルブリード感は喪失するが法的要件を優先。

### 2026-06-24: コルーチン規約の確定（runCatching 禁止 / 所有 viewModelScope + clear()）— 昇格記録

`kotlin-coroutines-flows` Skill 観点の横断レビューで確定し、**2026-07-02 に `coding-conventions.md` §1.2 / §1.6 / §1.7 へ昇格済み**。経緯の要点のみ残す:

- **`runCatching` は `CancellationException` も握りつぶす**ため、画面破棄・サインアウト時のキャンセルがエラー扱いになり協調キャンセルを遮断していた → `CancellationException` 先行 catch + 再スロー、`Exception` でエラー表示のパターンへ全 VM 置換
- **全 VM が app-wide `MainScope` を共有**し、push/pop 画面の collector が破棄後も残る増殖リークがあった → 注入 scope の Job を親にした所有 `viewModelScope`（`SupervisorJob(parentJob)` 子スコープ）+ `clear()` を導入し、Bridge の **`deinit`**（`onDisappear` ではなく）から呼ぶ。`clear()` はスコープ畳みのみに留めること（deinit は Main スレッドとは限らない）
- 同レビューの周辺整理: `LocalCoffeeRepository` の context 名 `ioContext` → `queryContext` 改名（実体は `Dispatchers.Default`。`Dispatchers.IO` は commonMain 不可）
- **同レビューで surfacing した未解決の申し送り**（未修正のまま生きているもの）: ①`AccountView` / `MapTabView` の 0.1s ポーリング → `.task(id:)` パターンへの置換候補 ②`CoffeeEditorView` の `Photo_` 直接組み立て（Bridge にファクトリを足せば解消する軽微な規約逸脱）③`ContentView.swift` は未使用のデモ残骸（削除候補・要ユーザー確認）

### 2026-06-25: カフェ検索 — テキスト検索にマップ中心の位置バイアスを適用

- 関連: `shared/feature/cafe-search/.../CafeSearchViewModel.kt`, `iosApp/.../AppState.swift`

テキスト検索を「マップで見ているエリア寄り」にするため、マップタブのカメラ中心を `AppState.mapSearchCenter` でタブ間共有し、`onSearchTapped(latitude:longitude:radiusMeters:)`（オーバーロード追加）でバイアス付き検索する。3 案（エリア検索ボタン / 検索タブに小地図 / 位置バイアス）からユーザー選択。

- radius は `region.span` から緯度・経度方向のメートル換算の**大きい方**を採用し 1〜50,000m にクランプ。Places の locationBias は soft bias のため「広め側に倒す」
- `mapSearchCenter == nil`（マップ未表示）はバイアスなしにフォールバック
- 検索本体は `launchSearch(errorMessage, producer)` に共通化（Job キャンセル → 状態遷移 → CancellationException 先行 catch）
- 余談: 所有 viewModelScope を持つ VM の `runTest` テストは `finally { vm.clear() }` が必要（`UncompletedCoroutinesError`。lessons 参照。他 feature への横展開は別タスク）

### 2026-06-26: iOSDC LT — 逆方向変換 PoC（言葉→数値）を Foundation Models で実装

- 関連: `TastePreferenceExtractor.swift`, `TastePreferenceConversionView.swift`

LT テーマ「数値⇄言葉の双方向変換」の逆方向（自由文 → 構造化データ）を PoC 実装。順方向と同じ availability ガード + ステートレス session を踏襲し、`@Generable struct TastePreference`（5 軸 Int + roast + summary）を `respond(to:generating:)` で抽出。**`@Generable` に 5 軸が「ある / ない」が変換の向きを表す**（LT の対比ネタの実体）。

- `@Generable` マクロは `Equatable` を自動合成しないため `==` を手書き（将来サポートされたら削除可）
- 言及のない軸は 5（中庸）とする instructions 設計。抽出結果を検索につなぐ処理は未実装（口頭説明）

### 2026-06-26: 冗長な可用性ガード除去 + 逆変換 PoC 導線の表示方針

`IPHONEOS_DEPLOYMENT_TARGET = 26.0`（iOS 26 専用）かつ未リリースのため、`@available(iOS 26.0, *)` / `if #available` / PoC を隠す `#if DEBUG` はすべて冗長としてユーザー方針で sweep（lessons 2026-06-26）。意図的に残した `#if DEBUG` は ①Preview 補助（リリースバイナリ除外）②`seedOrClearDummyData`（RELEASE で毎起動 clear が走る破壊的副作用の防止）。

- 逆変換 PoC 導線（分析タブ最下部の `TastePreferenceConversionView`）の本番可否判断は 2026-07-12 に**本番採用**で確定（同日エントリ参照）

### 2026-06-29: フェーズ 10-A/B — マップピン再設計 + Places API 追加フィールド

- **10-A**: 訪問済みピンを 36pt + shadow に拡大し、訪問 2 回以上で回数バッジ（9+ 上限）。3 種ビジュアル体系: 訪問済み（36pt 茶）/ 好み一致（38pt アクセント + ハート）/ Apple 標準 POI
- **10-B**: `Cafe` に表示用 5 フィールド（`openNow` / `weekdayDescriptions` / `phoneNumber` / `priceLevel` / `googleRating`）をデフォルト値付きで追加し FieldMask 拡張。**SQLDelight スキーマは変更なし**（スナップショットには含めず Places API 結果のみで利用）。CafeDetail に営業状態・評価・価格帯・電話・外部リンク・営業時間を追加
- `foregroundStyle(.accentColor)` はコンパイルエラー（`ShapeStyle` にメンバなし）。`Color.accentColor` を明示
- **クラスタリングは将来課題**: SwiftUI `Map` にネイティブ API がなく `MKMapView` ラッパが必要になるため、密集が実問題になった時点で再検討

### 2026-06-29: フェーズ 10-C — 検索結果マップオーバーレイ

検索結果を「マップに表示」明示ボタンでマップへ流す（自動反映なし）。経路は AppState 経由（`mapSearchCenter` と同じタブ間バスパターン。ViewModel 間直結や共有リポジトリは避ける）→ `MapViewModel.UIState.searchResultPlaces`。クエリ変化時に前回結果を自動クリア、タブ離脱ではクリアしない（意図的に表示した結果を保持）。ピンは青 32pt の第 4 種。

### 2026-06-30: マップ内検索バー（検索タブ廃止・Google Maps スタイル）

**iOS 27 で `Tab(role: .search)` の右端固定動作が廃止**されたため、検索タブを削除して 3 タブ + マップ上部常時表示の検索バーに移行（検索実行 → ドロップダウンリスト → 選択でカメラ移動 + 下部カード → 詳細 push）。

- KMP 変更なし: `CafeSearchViewModelBridge` を MapTabView 内 `@State` で再利用
- `TabBarFrameReader`（検索タブ幾何検出ハック）を削除し、FAB は `overlay(alignment: .bottomTrailing)` 固定に
- `CafeSearchView` はエディタ用コールバックモード（`init(appState:onCafeSelected:)`）のみ残しルートモードを削除
- 上部コントロール高さ 120pt 固定 Spacer は Dynamic Type 最大で不足の可能性（実機確認後に動的計測へ差し替え検討）→ フェーズ 14 の検索モード化で構造ごと解消済み

### 2026-06-30: フェーズ 10-D — タグフィルター（ドメインモデル変更 + UI）

- **`CoffeeRecord.tags: List<String>`** をデフォルト値付きで追加。SQLDelight は `tags TEXT NOT NULL DEFAULT ''`（JSON 配列文字列、`photoRefsSerializer` 流用）。クリーンブレイク（アプリ削除 → 再インストール）。カフェ粒度でなく**記録粒度**でタグ付けする設計
- `MapViewModel` に `selectedTags` / `availableTags` + トグル API。**`combine` に `MutableStateFlow` を含めると `runTest` がタイムアウト**するため、キャッシュ変数 + `applyTagFilter()` 直接呼びのパターンを採用

### 2026-06-30: フェーズ 12-A — データ共有同意フロー

（設計 + flatMapLatest + iOS 実装の 3 エントリを統合）

- **consent は Firestore `users/{uid}` ルートの `analyticsConsent: Boolean`**。理由: ①将来の Rules で「同意済みユーザーの集計コレクション書き込み」を条件化するには Firestore 側に必要 ②デバイス間で同意状態を共有（買い替え時に再同意不要）③`UserDefaults` 管理は Rules と乖離する。`users/{uid}` ルートは今回が初利用（Rules は `{document=**}` と別に `match /users/{uid}` の明示が必要）
- **初回オンボーディング判断 = ドキュメント不在**。`analyticsConsent: false` が明示的に書かれていれば「非同意済み」として表示しない。`@AppStorage` 補助は使わない（Firestore が権威ソース）
- **`observeAccount()` は `flatMapLatest` 合成**: `combine` 案は未サインイン時に consent 側 Flow の `close()` で合成 Flow ごと終了してしまう。`flatMapLatest(observeFirebaseUser())` で auth 変化時に Firestore リスナを自動切替。両メソッド同時購読でリスナが 2 本立つ点は現状許容（`shareIn` ホット化は将来候補）
- iOS: オンボーディング判断は `getDocument()` 一発（Flow 購読は過剰）。sheet は `interactiveDismissDisabled()` でボタン閉じのみ。`makeAuthAccount` の `analyticsConsent:` は常に false（Auth state 監視で Firestore を二重購読しない）
- プライバシーポリシー URL は placeholder（App Store 申請前に差し替え。`app-store-metadata.md` チェックリスト明記済み）

### 2026-06-30: CoffeeRecordFilter.tastingMin/Max の tasting=null レコードの扱い（Phase 13-A-2）

`tastingMin` / `tastingMax` のいずれかが指定されている場合、`tasting == null`（未記録）のレコードは除外する（`rating=0.0` を評価範囲から除外するのと同じ「未記録を誤ヒットさせない」思想）。各軸は独立評価（全 5 軸がそれぞれ範囲内であること）。13-A-3 で iOS が `TastePreference` → filter 変換時に `axis ± margin(=2)` の範囲を渡す。

### 2026-06-30: MapViewModel テイストプロファイルフィルタの設計（Phase 13-C）〜 2026-07-21 撤去

**2026-07-21 撤去済み**: マップの「好みで絞り込む」チップ（`TasteMapFilterSheet` / `MapViewModel.onTasteProfileChanged` / `tasteMatchedPlaceIds` / `activeTastingMin`・`activeTastingMax` / `applyTasteFilter` / `latestAllRecords`）は「訪問済みの中を味覚スコアでさらに絞り込むだけで用途が薄い」とのユーザー判断で機能ごと削除。「好み一致」自動推薦（`recommendedCafes` / `ObserveTasteMatchedCafesUseCase`）と「テイストで探す」検索バー ✨（`TasteSearchSheet`）は別機能として存続。以下は撤去前の設計メモ（履歴）。

`tasteMatchedPlaceIds` は `selectedTags`（ピン絞り込み）とは**独立の別軸**として管理していた（iOS 側で非マッチピンの半透明化に使用）。`latestAllRecords` キャッシュ + 即時 `applyTasteFilter()` はタグフィルタと同じパターン。`combine` の変換式は `Pair<Triple, List>` 返し（撤去時に素の `Triple` へ単純化）。

### 2026-06-30: Phase 12-B の実装判断 3 件（サジェスト UI / DI の null 許容 / Firestore Task キャンセル）

- 関連: `shared/data-firebase/src/androidMain/.../BeanProfileRepositoryAndroidImpl.kt`, `iosApp/.../CoffeeEditorView`

- **`Form` 内サジェストは VStack 行内展開**（ZStack 非採用）: SwiftUI の `Form`（内部 List）は行単位クリッピングのため、ZStack で下に伸ばしても他行を覆うフローティング表示にならない。フローティングが要るなら `NavigationStack` の `.overlay` にパネルを乗せる方式を検討する
- **`BeanProfileRepository` は非 null で注入**（`coffeeInsightProvider: CoffeeInsightProvider?` と非対称）: iOS / Android とも Firestore 実装が必ず要るため、プラットフォーム非対称を持ち込む理由がない
- **Firestore の `get()` Task はキャンセル不可**: `suspendCancellableCoroutine` の `invokeOnCancellation` は空にし、キャンセル後のコールバック到達は「キャンセル済みコルーチンへの resume は idempotent」という kotlinx.coroutines の仕様に委ねる（`RemoteCoffeeDataSourceAndroidImpl.awaitTask` も同方針）

### 2026-06-30: TastePreference.searchKeywords によるカフェ検索補完（Phase 13-D）

`TastePreference` の 5 軸ベクトルを日本語キーワード（"フルーティ 浅煎り 酸味" 等）へ変換する `searchKeywords` を追加（スコア 7 以上 =「高い特徴」、body のみ 4 以下 =「低い特徴」）。全スコア中間 + roast unknown は空文字を返し呼び出し元でエラー表示。Places はカフェのテイスティング詳細を持たないため精度は限定的 — 「新しいカフェを発見する」補助機能として位置付ける。
