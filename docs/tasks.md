# CoffeeVision タスク一覧

このファイルは実装タスクのフェーズ別管理表です。
完了したタスクは `[x]` でチェックし、完了日とコミット / PR を備考列に追記してください。

> 細かい WIP メモは `docs/tasks/lessons.md`（自己改善ループ用）に書き出します。
> **実機 / シミュレータの目視・手動検証（プロダクト QA）は [`docs/tasks/verification-checklist.md`](./verification-checklist.md) に分離**（2026-07-08）。tasks.md には実装・設計タスクのみを残す。
> **フェーズが完了したら、セクションの中身は「完了サマリ（数行）+ 未完行のみの表」に縮約する**（2026-07-04 運用開始。行単位の作業記録は git 履歴、設計判断は `implementation_note.md` が正）。セクション見出しは他 doc からの参照アンカーのため削除しない。

---

## 凡例

| 記号 | 意味 |
|------|------|
| `[ ]` | 未着手 |
| `[~]` | 進行中 |
| `[x]` | 完了 |
| `[-]` | 取り下げ |

---

## フェーズ 0: プロジェクト準備

> 完了分（2026-06-02〜06-04）: KMP スケルトン初期化 / docs 一式整備 / libs.versions.toml 整備 / SKIE 0.10.12 採用 / Firebase 設定ファイルは gitignore + コミットしない方針を確定。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | CI 整備: PR ごとに iOS / Android 両方のビルドを必須チェック化 | 2026-06-03 初回追加、Phase 2.5 PR3 で現行コマンドに差し替え済。**2026-07-08 ユーザーが CI グリーンを確認**（B-5 と同時解消）|
| [x] | `local.properties` での API キー管理を整える（Places / Firebase） | Places 側は Phase 4 スライス 1（2026-06-11）で整備済。CI での Firebase 設定ファイル復元は 2026-07-07 の TestFlight ワークフローで解消（Secrets → `GoogleService-Info.plist` / `Secrets.xcconfig` 復元） |
| [x] | App Store Connect アップロードワークフロー（`release-testflight.yml`）| 2026-07-07 完了。workflow_dispatch 手動起動 / ASC API キー + cloud signing / ビルド番号 = `github.run_number`。判断は implementation_note 2026-07-07 エントリ |
| [ ] | **（ユーザー作業）** TestFlight ワークフローの Secrets 5 件登録 + 初回実行確認 | `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_PRIVATE_KEY`（.p8 の中身・**App Manager 以上のロール必須**）/ `GOOGLE_SERVICE_INFO_PLIST_BASE64` / `PLACES_API_KEY`。登録後 Actions から手動実行し TestFlight にビルドが現れることを確認 |

---

## フェーズ 1: ドメインモデルとローカル DB

> 完了（2026-06-02）: 旧 Visit 系ドメインモデル + SQLDelight スキーマ + DriverFactory（expect/actual）+ Mapper + commonTest。モデルは 2026-06-19 のフェーズ 7 で CoffeeRecord 主体に全面置換済み。

---

## フェーズ 2: 認証と Firestore 接続

> 完了（2026-06-04〜06-07）: Firebase プロジェクト作成・匿名 Auth・Firestore（asia-northeast1）・オフライン永続化・iOS Firebase SPM 導入・`AuthRepository` / remote 合成構成の確立・Security Rules のリポジトリ管理化 + デプロイ・シミュレータでの書き込み実体確認まで。当時の Visit 子コレクション同期は 2026-06-19 の単一ドキュメント化で置換済み。Storage は 2026-06-10 に採用見送り（写真は端末ローカル）。

---

## フェーズ 2.5: モジュール分割 (1) — 基盤レイヤー

> 完了（2026-06-08、PR1〜PR3）: `build-logic/convention`（`kmp.library` / `kmp.feature` / `android.library`）新設 → `shared/{core,domain,data-local,data-firebase}` 切り出し → `shared/framework` umbrella 化 + 旧 `sharedLogic` 完全削除 + CI コマンド差し替え。現行構成は `settings.gradle.kts` と `architecture.md` を真とする。

---

## フェーズ 3: iOS UI（MVP）

> 完了（2026-06-09〜06-11）: AppContainer 起動配線・一覧 / 詳細 / エディタの 3 画面 + Bridge・StarRatingView・写真ピッカー（Documents フラット保存 + メタデータ永続化）・Preview 19 件。画面群は 2026-06-19 のフェーズ 7 で Coffee* 系にリネーム・全面改訂済み。

---

## フェーズ 3.5: モジュール分割 (2) — feature レイヤー & Android 検証

> 完了分（2026-06-08〜06-11）: `shared/framework` 作成・feature モジュール切り出し（visit-list / detail / editor、後の coffee-*）・androidApp での Compose 1 画面検証実装（`CoffeeListScreen`）。

---

## フェーズ 4: Places API（カフェ検索）

> 完了（2026-06-11〜06-15、スライス 1〜7）: `shared/data-places` 新設（Places New v1 / Ktor / DTO / `CafeRepository`）→ iOS 検索 UI + xcconfig キー注入 → CoreLocation + Nearby + Details → Photo Media 都度取得 → `feature/{cafe-search,map,cafe-detail}` 切り出し → TabBar 化 + カフェ詳細統合 → Apple Maps POI タップ動線。設計判断は `implementation_note.md` の 2026-06-11 / 06-15 各エントリ参照。検索 UI・タブ構成はその後 2026-06-30（検索タブ廃止・マップ内検索）で再編済み。

---

## フェーズ 5: 仕上げ

> 完了分（2026-06-16〜06-17）: 設定画面（テーマ / ライセンス）・アカウント機能一式（Apple アップグレード / サインアウト / 削除）・エラートースト共通化・App Icon / Launch Screen・App Store メタデータ下書き（`app-store-metadata.md`）。判断は implementation_note 2026-06-16 / 06-17 エントリ。

---

## フェーズ 5.2: アカウント削除時の Apple トークン失効（E-1）

> 実装完了（2026-06-24）: App Store ガイドライン 5.1.1(v) 対応。削除時に Apple 再サインイン →（authorization code 取得）→ reauthenticate → `revokeToken` → KMP 削除、の順で iOS がオーケストレーション。キャンセル = 無音中断 / revoke 失敗 = 削除中断。詳細は implementation_note 2026-06-17 アカウント機能エントリ。**E-1 フロー全体の動作確認はシミュレータ不可（Apple サインイン制限）→ 実機必須**。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | **（ユーザー作業・revoke 機能の前提）** Apple Developer で ① Sign in with Apple 用 Key（.p8）作成（Key ID / Team ID 控え）② Services ID 作成（Return URL = `https://coffeevision-a54aa.firebaseapp.com/__/auth/handler`）→ Firebase Console の Apple プロバイダ（OAuth コードフロー設定）に **Services ID / Apple Team ID / Key ID / 秘密鍵**の 4 つを登録。Console は 4 項目を 1 セットで検証するため Services ID も必須。**これが無いと `revokeToken` はサーバ側で失敗する** | E-1 の機能成立に必須。App Store 審査前に必ず実施 |

---

## フェーズ 6（任意 / 後続）

| 状態 | タスク | 備考 |
|------|------|------|
| [-] | Android アプリ実装着手（`sharedUI` の Compose Multiplatform 利用） | Phase 3.5 で `feature/visit-list` を Compose 表示する検証実装に置き換えたため取り下げ（Android はリリース対象外） |
| [ ] | 検索（キーワード）の高速化（SQLDelight FTS） | 一覧検索そのものはフェーズ 15-C（まずはメモリ内 filter）。FTS はデータ量で遅くなったら |
| [-] | エクスポート（JSON）機能 | **フェーズ 15-E-2 で実装完了**（2026-07-07、行 350-351）。本行は重複のため取り下げ |
| [ ] | 同一カフェの集計表示 | |
| [x] | エディタ `buildCafe` の Edit/Duplicate 分岐の抜けを修正: 元 cafe が null（セルフ抽出）の記録を編集して手動でカフェ名を入力しても cafe が保存されない（手入力カフェとして新規 UUID を採番すべき） | 2026-07-08 完了（専用セクション「フェーズ 6 既知バグ」参照）。目視のみユーザー待ち。implementation_note 2026-07-08 参照 |
| [ ] | Widget / ホーム画面ショートカット | |

---

## フェーズ 7: コーヒー記録主体への再設計（Visit → CoffeeRecord）

> 完了（2026-06-19）: 集約ルートを `Visit` → `CoffeeRecord` へ転換（クリーンブレイク・データ移行なし）。docs 全面改訂 → KMP（domain / core / data-local / feature リネーム / framework）→ data-firebase Android → iOS UI の 3 段 dispatch で完遂。確定仕様は `data-model.md`、経緯は implementation_note 2026-06-19 エントリ。

---

## フェーズ 8: 分析タブ（コーヒー傾向分析）

> 完了分（2026-06-19〜06-22）: 3 階層構成（集計は KMP 決定論 / 解釈は iOS Foundation Models）で以下を実装。
>
> - **A-1〜A-4**（06-19）: `CoffeeStats` 集計 + `AnalysisViewModel`（`feature/analysis`）+ Swift Charts UI + Foundation Models 要約（`CoffeeInsightProviderIosImpl`、可否は注入時判定）
> - **B-1〜B-1d**（06-19〜06-22）: `FavoriteSignals` 実体化 → ペルソナ検証で偽陽性を実測（カテゴリ 100% / tasting 40%）→ effect-size δ=0.20 + 相関 floor c=1.97 → n 連動 z ゲート `CATEGORY_Z=2.0` 確定（カテゴリ FP 9.3% まで改善・検出力維持）。統合経緯は implementation_note 2026-06-22 好み判定エントリ
> - **B-2 / B-3**（06-21）: 対話 Q&A v1（digest 注入）+ v2（`SearchCoffeeRecordsTool` → `CoffeeRecordQuery.searchRecords`）。実機での tool round-trip 確認済み
> - **B-4**（06-22）: 味覚一致カフェのマップ強調（`CafeRecommendationProvider` 境界 + 理由シート）

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | （将来 9-6）協調フィルタリング: `CafeRecommendationProvider` のサーバ（GCP）リモート実装。横断データ基盤＋同意フローが本体 | Future Direction（implementation_note 2026-06-22）。フェーズ 12-D と同件 |

---

## 開発支援: ダミーデータ Scheme

> 完了（2026-06-19）: 専用 Scheme「iosApp (Dummy Data)」（env `SEED_DUMMY_DATA=1`）でローカル DB のみに固定 ID 30 件を冪等 seed / 通常 Scheme で clear。設計判断は implementation_note 2026-06-19 エントリ。

---

## フェーズ 9: テイスティング 5 要素（甘味/ボディ/酸味/風味/後味）

> 完了（2026-06-20）: `CoffeeRecord.tasting` を全レイヤー（domain / data-local / core / feature / data-firebase / iOS UI / 分析）に追加。当初の各要素独立 nullable はフェーズ 9.1 で all-or-nothing に即日変更。統合経緯は implementation_note 2026-06-20 エントリ。

---

## フェーズ 9.1: テイスティングを all-or-nothing 化（5 要素必須）

> 完了（2026-06-20）: `TastingScores` の 5 フィールドを非 null 化 + `CoffeeRecord.tasting: TastingScores?` で「型で partial を表現不可能に」。UX は `+` で 5 スライダー一括表示。KMP → iOS の 2 段 dispatch で完遂。仕様は `data-model.md` §1.1a。

---

## フェーズ 10: マップ拡充

> 完了（2026-06-29〜06-30）: **10-A** ピン再設計（36pt + 訪問回数バッジ、3 種ビジュアル体系）/ **10-B** Places 追加フィールド（営業時間・電話・価格帯・評価 → CafeDetail 拡充。永続化なし）/ **10-C** 検索結果のマップオーバーレイ（AppState 経由・明示ボタン方式）/ **10-D** タグフィルター（`CoffeeRecord.tags` + エディタ入力 + マップチップ）。判断は implementation_note 2026-06-29 / 06-30 各エントリ。

---

## フェーズ 11: コーヒー記録テンプレート / カスタムフィールド ※保留

> 起票 2026-06-29、同日**全保留**（11-A 記録テンプレート / 11-B カスタムフィールドの 2 機能）。優先度が上がった時点で再検討する。当時のタスク分解は git 履歴参照（再開時は data-model 設計から仕切り直す想定）。

---

## フェーズ 12: コミュニティ / データ共有基盤

> 起票 2026-06-29。個人の記録を（同意を得た上で）集合知として活用する基盤。12-A（同意）→ 12-B（豆ナレッジ）→ 12-C（突合・言語化）は完了、12-D（協調フィルタリング）はサーバー側インフラが前提で未着手。

### 12-A: データ共有同意フロー（前提）

> 完了分（2026-06-30〜07-01）: `DataConsentOnboardingView`（初回シート）+ Settings トグル、`AuthAccount.analyticsConsent` + `users/{uid}` Firestore 保存、Security Rules 更新・デプロイ済み。判断は implementation_note 2026-06-30 12-A エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | プライバシーポリシー更新（記録データをサービス改善に使用する旨の明記） | App Store 提出前に必須 / ユーザー作業。アプリ内リンクの placeholder 差し替えも同時に |

### 12-B: コーヒー豆ナレッジベース（サーバー管理データ）

> 完了（2026-06-30）: `BeanProfile`（サーバ管理 read-only、ID 紐付けせず origin/processings ファジーマッチ）+ `BeanProfileRepository`（Android Kotlin / iOS Swift、one-shot get + メモリキャッシュ）+ エディタの origin サジェスト UI。仕様は `data-model.md` §1.8。**初期データは seed 整備済み（2026-07-08、`scripts/seed/`。下記「BeanProfile 初期データ整備」）。Firestore への投入実行はユーザー作業**。

### 12-C: 個人好みと豆ナレッジの突合・言語化

> 完了（2026-07-01）: `PreferredBeanTraitsUseCase`（FavoriteSignals × flavorNotes 頻度集計）→ `CoffeeStats.preferredBeanTraits` → 分析タブ「好みの豆の傾向」セクション（FM 言語化 / 非対応端末はタグ表示フォールバック）。判断は implementation_note 2026-07-01 12-C エントリ。**実機確認はユーザー作業（beanProfiles 投入後）**。

### 12-D: 協調フィルタリング（B-4 将来版 / 9-6）

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | サーバーサイド基盤設計（GCP Cloud Run / Cloud Functions + Firestore 集計パイプライン） | インフラ選定・コスト見積もりが前提 |
| [ ] | ユーザー間好み類似度計算ロジック設計（コサイン類似度 / ピアソン相関 on `FavoriteSignals` ベクトル） | |
| [ ] | `CafeRecommendationProvider` のサーバーリモート実装（既存ローカル実装と差し替え可能な設計は B-4 で済み）| B-4 の将来 9-6 エントリと連動 |
| [ ] | iOS: マップ上の好み一致ピン（B-4）を協調フィルタリング結果に差し替え（フラグ制御で A/B 切替可能な設計） | |
| [ ] | 全体データを使った「このカフェを好む人は○○傾向」などのコミュニティ統計を分析タブに追加 | |

---

## フェーズ 13: 自然言語好み検索（逆方向変換応用）

> 完了（2026-06-30）: iOSDC 逆方向 PoC（`TastePreferenceExtractor`）を実用昇格。**13-A** `CoffeeRecordFilter.tastingMin/Max` + `TastePreference→Filter` 変換 / **13-B** Q&A への `SearchByTasteProfileTool` 追加 + 「好みで記録を探す」専用 UI / **13-C** マップの「好みで絞り込む」チップ（非マッチピン半透明化）/ **13-D** 検索バーの ✨ ボタン（`searchKeywords` 補完クエリ）。FM 部分は iOS 限定、非対応端末は導線非表示。判断は implementation_note 2026-06-30 13-x 各エントリ。**実機確認（Apple Intelligence 対応端末）はユーザー作業**。

---

## フェーズ 14: マップ検索の使い勝手改善（表示範囲ピン表示）

> 完了分（2026-07-01）: 「このエリアを検索」ボタン方式（自動再検索なし）+ テキスト検索の全件ピン + 検索モード化（フィルタチップ非表示・結果リストを検索バー直下に統合）。しきい値（中心移動 30% / 半径比 1.5x）等の判断は implementation_note 2026-07-01 フェーズ 14 エントリ。Places New は 1 回最大 20 件の仕様上限あり。

---

## docs 棚卸し（2026-07-02）

> 完了（2026-07-02）: 実装と docs の齟齬 4 件（data-model のフェーズ 10 / 12-C 追随、kmp-bridge の export 記述、app-store-metadata の CoffeeRecord 化、implementation_note サマリ全面更新）+ 旧モデル例文・runCatching 例文の是正 + CLAUDE.md / architecture.md の feature 列挙修正。経緯は implementation_note 2026-07-02 エントリ。
>
> 残りの低優先残件のうち ui-ux-guidelines の Visit 系旧用語は 2026-07-04 に消し込み済み。未着手で残るのは FAB 等の新 UI パターン未記載（ui-ux-guidelines）、backlog ID「B-4」と Phase B-4 の名前衝突など。必要になったら下の設計判断バックログへ起票する。

---

## iosApp コードレビュー指摘対応（2026-07-03）

> 完了分（2026-07-03）: 高優先 5 件を修正 — #1 CafeDetail の `onDisappear` observation 停止 / #2 アカウント処理完了待ちの二相ポーリング化 / #3 `bootstrap()` 再入ガード / #4 同意オンボーディングの timing バグ（観測される状態の公開を最後に）/ #5 写真物理削除の順序逆転。判断は implementation_note 2026-07-03 iosApp エントリ、教訓は lessons.md 2026-07-03。

---

## shared コードレビュー指摘対応（2026-07-03）

> 完了分（2026-07-03）: 高優先 3 件を修正 — #1 `startSync` のスナップショット reconciliation（リモート削除のローカル伝播）/ #2 エディタの `selectedCafe` 保持（座標・photoReferences 引き継ぎ）/ #3 FOREIGN KEY の本番有効化 + 掃除 migration（iOS テストの赤→緑で実証）。判断は implementation_note 2026-07-03 shared エントリ。

---

## サブエージェント定義の改善（2026-07-04）

> 完了分（2026-07-04）: 両エージェント定義を現行構成に更新 + `memory: project`（`.claude/agent-memory/` git 管理）+ 書き込みスコープの PreToolUse フック強制（`validate-write-scope.sh`、テスト 13 ケース green）+ `skills` プリロード（現行ハーネスでは本文非展開のためフォールバック文残置）。判断は implementation_note 2026-07-04 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | 次回の実 dispatch で観察: メモリ運用（リポジトリ内パスへの追記）が定着すること / ハーネス更新後に `skills` プリロードが効くようになったらフォールバック文を削除 | 運用検証 |

---

## CLAUDE.md のスリム化と .claude/rules/ 分割（2026-07-04）

> 完了分（2026-07-04）: CLAUDE.md 240 → 131 行。言語別規約を `.claude/rules/`（パススコープ規則）へ分割、モジュール表を `settings.gradle.kts` / `architecture.md` 参照に一本化、lessons の親運用ルール 4 件を昇格。rules のサブエージェント遅延注入は実測確認済み。判断は implementation_note 2026-07-04 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | `/memory` でロード確認（CLAUDE.md 常時 + `shared/**` のファイルを開いた際に kotlin-kmp.md が載ること） | **ユーザー作業**（セッション内で `/memory` 実行） |

---

## implementation_note.md の棚卸し・要約（2026-07-04）

> 完了（2026-07-04）: 2160 行 / 297KB → 691 行 / 79KB（約 120 → 64 エントリ）。陳腐化削除・シリーズ統合・冗長圧縮・見出し統一。外部参照 4 系統の生存確認済み。経緯は implementation_note 2026-07-04 棚卸しエントリ。

---

## フェーズ 15: 記録・店探しループの強化（2026-07-06 起票）

> 2026-07-06 のゼロベース設計レビュー（3 条件: 記録できる / おいしい店を探せる / 好みを見つけられる）で洗い出したギャップの採用分。要件は [`requirements.md`](./requirements.md) §10（行きたい店）/ §2 の 2-8〜2-11（記録摩擦低減・月別表示）/ 6-1（一覧検索）/ §9 の 9-7・9-8 / 7-4（エクスポート ○ 昇格）。着手順は **15-A → 15-B → 15-C → 15-D** を推奨（15-E は中期・後回し可）。

### 15-A: 行きたい店リスト（ウィッシュリスト）【要件 10-1〜10-3】

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: `data-model.md` に `SavedCafe` 設計を追加（ドメイン / SQLDelight / Firestore / Repository 2 段構成） | 2026-07-06 完了（`data-model.md` §1.9 / §2.4 / §3 / §4.3）。確定判断: placeId 自然キー（UUID 例外）/ 記録作成時の自動解除なし（ピン優先順位 + バッジで表示解決）/ 一覧はマップ内シート（新 feature モジュール無し）/ migration 3.sqm |
| [x] | kmp-engineer: `SavedCafe` ドメイン + data-local（migration 3.sqm）+ data-firebase（Android）+ Repository 合成（reconciliation 込み）+ `MapViewModel` / `CafeDetailViewModel` への配線 | 2026-07-06 完了。新規テスト 19 件 + 既存追随 7 件 green / `verifySqlDelightMigration` 成功 / `:androidApp:assembleDebug` 成功 / override フラグ不使用。破壊的変更は `AppContainer` コンストラクタへの `remoteSavedCafeDataSource` 追加（iOS 追随は次行）。判断は implementation_note 2026-07-06 |
| [x] | ios-engineer: iOS 側 RemoteDataSource（Swift / Firestore）+ カフェ詳細のブックマークボタン + マップ 4 種目ピン + フィルタチップ + 一覧導線 | 2026-07-06 完了。`RemoteSavedCafeDataSourceIosImpl` + Mapper（Coffee 側ヘルパ再利用）+ Bridge 追随 + ブックマークトグル + indigo/`bookmark.fill` 34pt ピン（dedup 常時適用）+ ハーフシート。クリーンフルビルド BUILD SUCCEEDED（override フラグ不使用）。判断は implementation_note 2026-07-06 |
| [x] | 検証: 保存 → ピン表示 → 解除の round-trip、Firestore コンソール確認、既存ピンとの共存・フィルタ切替、一覧シートのスワイプ解除・記録ありバッジ | 2026-07-06 ユーザーが目視確認済み（migration 3.sqm 含め問題なし） |

### 15-B: 記録摩擦の低減【要件 2-8 / 2-9 / 2-10】

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: エディタ VM に現在地カフェサジェスト状態（Nearby 上位 1〜3 件）+ コーヒー名デフォルト値 + 複製用の初期値生成ロジック | 2026-07-06 完了。`CoffeeEditorViewModel` に `Mode.Duplicate` + `suggestedCafes` + `onLocationAvailable` + `DEFAULT_COFFEE_NAME` を追加。新規テスト 7 件 green・override 不使用。コンストラクタに `cafeRepository` 追加（`AppContainer.makeCoffeeEditorViewModel()` 経由なら iOS 呼び出し側は無変更）。判断は implementation_note 2026-07-06 |
| [x] | ios-engineer: エディタのサジェストチップ UI（位置情報許可 UX 込み）+ 詳細画面「これをもとに記録」導線 | 2026-07-06 完了。許可済みのときだけ one-shot 取得（未許可は無音・ダイアログ抑止を呼び出し側でガード）、チップは cafeSection 直下の横スクロール、詳細ツールバーは Menu 化（編集 / これをもとに記録）。BUILD SUCCEEDED・override 不使用。判断は implementation_note 2026-07-06 |
### 15-C: 記録一覧の検索 + 月別グルーピング【要件 6-1 / 2-11】

**確定仕様（2026-07-06 親確定）**:
- **検索**: クエリを `trim().lowercase()` 正規化し、各 `CoffeeRecord` の `name` / `cafe?.name` / `notes` のいずれかに部分一致（大小無視）でヒット。空クエリ = 全件。フィールドは requirements 6-1 どおり 3 つに限定（産地・品種は含めない）。メモリ内 filter（`observeAll` の結果を private に保持し、クエリ変更で再導出）
- **月別グルーピング**: `visitedOn`（LocalDate）の年月でセクション化。`yearMonth` は `"YYYY-MM"`（ゼロパディング。既存 `CoffeeStats.MonthlyStat` と統一）。**表示文字列（"2026年7月"）は iOS 側で生成**（KMP は yearMonth のみ持つ。既存パターンと統一）。セクションは yearMonth 降順、セクション内は既存 `observeAll` の順序（visited_on DESC, created_at DESC）を維持
- **UIState 変更**: `coffees` を廃止し `sections: List<MonthSection>`（検索適用後・月別・降順）に置換 + `searchQuery: String` を追加。`MonthSection(yearMonth: String, records: List<CoffeeRecord>)`。空状態の出し分け（記録 0 件 vs 検索ヒット 0 件）は iOS 側が `sections.isEmpty` と `searchQuery` の組で判定
- **新規メソッド**: `onSearchQueryChanged(query: String)`

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `CoffeeListViewModel` にキーワードフィルタ + 月別 `MonthSection` モデル（上記確定仕様）+ commonTest | 2026-07-06 完了。commonTest 9 件 green（iosSimulatorArm64Test）/ `:androidApp:assembleDebug` 成功。破壊的変更（`coffees` → `sections`）の波及で `sharedUI/CoffeeListScreen.kt`（Android 検証画面）を親が追随（サブエージェントがセッション上限で中断→親が検証・仕上げ）。implementation_note 2026-07-06 |
| [x] | ios-engineer: 一覧に `.searchable`（`searchQuery` バインド）+ 月別 `Section` ヘッダ（yearMonth → "YYYY年M月" 生成）+ 空状態 2 種の出し分け | 2026-07-06 完了。Bridge の `coffees` → `sections` 全面追随、空 3 分岐（未検索空 / 検索 0 件は `ContentUnavailableView.search` / 一覧）、ヘッダに `.isHeader`。BUILD SUCCEEDED・override 不使用。`.searchable` は Bridge get/set で完結（メモリ内 filter で高速なため `@State` 分離不要と判断）|
### 15-D: 分析タブの空状態プログレス【要件 9-7】

**確定仕様（2026-07-06 親確定）**:
- **配置**: `AnalysisViewModel.UIState` の**派生フィールド** `readiness: AnalysisReadiness?` として導出（`CoffeeStats` は拡張しない — 「Foundation Models に渡す唯一の入力」を UI メタ情報で汚さないため）。既存の `stats: CoffeeStats?` から純粋導出
- **`AnalysisReadiness`**（`feature/analysis` に定義）:
  - `ratedCount: Int`（= `stats.ratedCount`。rating>=0.5）
  - `tastedCount: Int`（= `stats.tastingAverages.ratedCount`。tasting を持つ記録数。相関母数の近似 — 厳密には rating>0 も要るが動機付け表示なので近似で可、その旨コメント）
  - `categoryThreshold: Int`（= `FavoriteSignals().minSampleSize` を参照。ハードコードしない）
  - `correlationThreshold: Int`（= `BuildCoffeeStatsUseCase.CORRELATION_MIN_SAMPLE` を参照。ハードコードしない）
  - `hasAnySignal: Boolean`（`stats.favoriteSignals` の `bestBrewMethod` / `bestOrigin` / `bestRoastLevel` / `dominantTastingAxis` のいずれかが非 null）
- **導出タイミング**: `readiness` は `stats != null` のとき常に算出（`totalCount==0` でも算出してよい）。null は stats 未取得（ローディング）時のみ
- **文言は約束しすぎない**: 「傾向が見える」ではなく「傾向分析が**始まる**最小ライン」の意味。件数を満たしても z ゲート / 相関 floor で信号が出ないことがあるため（data-model.md §1.6）、UI 文言は「あと N 杯記録すると傾向分析が始まります」等に留める
- **表示文字列は iOS 側で生成**（KMP は件数と閾値のみ。既存の "KMP 数値 / iOS 文字列" パターン踏襲）

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `AnalysisViewModel.UIState` に `readiness: AnalysisReadiness?` を派生追加（上記確定仕様）+ commonTest | 2026-07-06 完了。新規 6 件 + QaTest 追随。**iOS テストが当初 16 件全滅（Native の cancel drain 漏れ）→ 親が `vm.clear()` 後の `advanceUntilIdle()` で修正、iOS/Android とも 16/0 green**。QaTest の fake 追随漏れ（12-C `summarizeBeanTraits`）も修正。教訓は lessons 2026-07-06、判断は implementation_note 2026-07-06。閾値は既存定数参照で二重定義なし |
| [x] | ios-engineer: データ不足時のプログレス表示 UI（`hasAnySignal==false && totalCount>0` のとき「あと N 杯記録すると傾向分析が始まります」）。カテゴリ track を主表示、テイスティング相関 track は任意で補足 | 2026-07-06 完了。`AnalysisReadinessProgressCard`（`ProgressView` + 残り件数で文言出し分け + 相関 track は補足キャプション）。BUILD SUCCEEDED・override 不使用。判断は implementation_note 2026-07-06 || [x] | （軽微・後回し可）`favoriteSignalsSection` の `hasAnySignal` 相当判定を iOS 側再計算から `viewModel.readiness.hasAnySignal` 参照に寄せて単一ソース化 | 2026-07-09 完了。`AnalysisView.swift:201` の 4 フィールド再計算を削除し `readiness.hasAnySignal` に一本化（`readinessProgressSection` の非表示条件と対称・単一ソース）。`stats != nil` 分岐内でのみ到達＝readiness 必ず導出済みで挙動不変。Preview 用 `AnalysisViewPreviewContent`（viewModel 無し）は対象外。override 無し `** BUILD SUCCEEDED **`（iPhone 17 sim）|

### 15-E: 中期（後回し可）【要件 9-8 / 抽出レシピ / 7-4】

3 機能とも独立。着手順は **15-E-1（抽出レシピ）→ 15-E-2（エクスポート）→ 15-E-3（探索提案）**。

#### 15-E-1: 抽出レシピフィールド【requirements §2 フィールド表 / 2-10】

> **確定仕様（2026-07-06 親確定）**: 構造化せず**単一フリーテキスト `brewRecipe: String?`**（△ なので Simplicity-First。将来構造化が要れば別途）。data-model.md §1.1 / §2.1（migration 4.sqm）/ §3.2 に反映済み。複製（2-10）の引き継ぎ対象に含める。バリデーション: 最大 500 文字（ViewModel 層）。エディタではコーヒー属性セクションに配置、詳細画面は非 null のとき表示。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `CoffeeRecord.brewRecipe` + SQLDelight（migration 4.sqm + upsert 追加）+ Mapper + Android Firestore mapper + エディタ VM（入力状態 + 複製引き継ぎ + 500 文字バリデーション）| 2026-07-07 完了。全レイヤー追加 + DummyData 2 件。iOS テスト green（data-local 39件 / coffee-editor 16件）+ verifySqlDelightMigration OK + androidApp:assembleDebug OK。落とし穴: `Mapper.toRow()` だけでなく `LocalCoffeeRepository` の `queries.upsert(...)` named 引数にも追加要（lessons 2026-07-07）。既存バグ 2 件を発見（下記バックログ）|
| [x] | ios-engineer: iOS Firestore mapper 追随 + エディタの入力 UI + 詳細画面表示 | 2026-07-07 完了。cup に対称な追加（Firestore mapper / Bridge `onBrewRecipeChanged` / エディタ TextField 複数行 / 詳細 LabeledContent）+ Preview 追随。BUILD SUCCEEDED・override 不使用 |
#### 15-E-2: データエクスポート（JSON）【要件 7-4】

> **確定仕様（2026-07-06 親確定）**: KMP で全 `CoffeeRecord` を JSON 文字列化する `ExportCoffeeRecordsUseCase`（`kotlinx.serialization`）。永続化フィールドのみ（写真はメタデータのみ・バイナリ含めない）。iOS は設定画面から `ShareLink` で共有シート。フェーズ 6 の「エクスポート（JSON）」項目と同件（そちらは本項目に統合）。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `ExportCoffeeRecordsUseCase`（`observeAll(uid).first()` → `@Serializable` DTO → JSON 文字列。`kotlinx-datetime` は ISO 文字列化）+ commonTest | 2026-07-07 完了。export 専用 DTO（`domain/export/`）+ `{exportedAt, version:1, records[]}` 包み + `encodeDefaults=true`。`AppContainer.exportCoffeeRecordsUseCase` 公開。iOS テスト 4/0 green（B-6 解消後に実証）。Swift 呼び出しは `.invoke(userId:)`（SKIE は operator invoke を callAsFunction 化しない）|
| [x] | ios-engineer: 設定画面に「データをエクスポート」→ JSON 生成 → `ShareLink` / share sheet | 2026-07-07 完了。2 フェーズ UI（Button → ProgressView → `ShareLink(item:)`）、`coffeevision-export-yyyyMMdd.json` を temporaryDirectory 書き出し。BUILD SUCCEEDED・override 不使用。軽微な後続候補: ①生成完了後もう 1 タップで共有の 2 タップ導線（自動提示にするなら `UIActivityViewController`）②`.ready` 後の再エクスポート導線なし（「作り直す」ボタン）|
#### 15-E-3: 未経験の豆への探索提案【要件 9-8（△）】

> **確定仕様（2026-07-06 親確定）**: KMP 決定論の `SuggestUnexploredBeansUseCase`。入力 = ユーザーの記録（記録済み `origin`/`variety` 集合）+ `BeanProfileRepository.getAll()` + `FavoriteSignals`。出力 = 好み信号（`bestOrigin` 等）に合致するが**ユーザーが未記録**の `BeanProfile` 上位数件。FM 不要（決定論。言語化は将来）。`beanProfiles` 未投入 / 信号なしなら空。分析タブに「試してみては」セクションでフレーバータグ付き表示。9-5（既訪問店の再訪）に対する新規開拓ナッジ。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `SuggestUnexploredBeansUseCase` + `CoffeeStats.unexploredBeanSuggestions` + commonTest | 2026-07-07 完了。UIState でなく `CoffeeStats` に格納（`preferredBeanTraits`=12-C と同型。ドメイン実質派生値・`BuildCoffeeStatsUseCase` が records+beanProfiles を既に持つため配線最小）。未経験判定 =(origin,variety) ペア、好み合致は `BeanProfileMatchUseCase` 再利用。iOS 9/0 green + XCFramework link OK。LLM 非混入も親確認済（buildPrompt は選択読み）。data-model.md §1.7a 反映 |
| [x] | ios-engineer: 分析タブに探索提案セクション（BeanProfile 名 + flavorNotes チップ） | 2026-07-07 完了。`UnexploredBeanSuggestionsCard`/`Row`（豆名 + variety + 理由文言 + flavorNotes チップ、空なら非表示）を「好みの豆の傾向」直後に配置。`buildPrompt` 未改変（LLM 非混入遵守）。BUILD SUCCEEDED・override 不使用 |
---

## 外部 Skill の導入（2026-07-07）

> [mattpocock/skills](https://github.com/mattpocock/skills)（MIT）から 3 Skill を選定し、日本語化 + 本プロジェクト調整で `.claude/skills/` に移植する。選定・調整の判断は implementation_note 2026-07-07 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `grilling` 移植（実装前の 1 問ずつ徹底インタビュー） | 2026-07-07 完了。Plan Mode Default を補完 |
| [x] | `diagnosing-bugs` 移植（フィードバックループ先行のバグ診断ループ + HITL テンプレート） | 2026-07-07 完了。Phase 6 を record-lesson に接続 |
| [x] | `writing-great-skills` 移植（Skill 設計原則リファレンス。GLOSSARY.md は原文同梱） | 2026-07-07 完了。model-invoked に変更（原典は user-invoked） |
| [x] | CLAUDE.md への最小追記（grilling / diagnosing-bugs の参照）+ implementation_note 記録 | 2026-07-07 完了 |

---

## フェーズ 16: マップ / タブ UI/UX 改善（2026-07-07 起票）

> **確定仕様（2026-07-07 親確定・ユーザー合意済み）**: ユーザー指摘 3 課題（保存済みボタンが右上で遠い / タグの統一感なし / カフェ情報が弱く決定感に欠ける）への対応。方針 = ①保存済み導線をフィルタチップ行に統合（右上 `savedCafesSheetButton` 廃止、チップタップでピン強調 + 一覧シート）、②マップ下部カード + `CafeDetailView` の両方で写真・評価・営業状態の表示強化、③共通 `TagChip` 新設 + 色セマンティクス体系化 + AccentColor #8B5A2B 設定、④追加: `userRatingCount`（評価件数）/ 記録写真を詳細写真帯に混在表示 / 詳細の保存ボタンを目立たせる。スコープ外: 営業状態インジケータ共通化・ボトムシート常駐化。

### 16 インターフェース合意書（commonMain 公開 API 変更）

- **`Cafe`**: 末尾に `val userRatingCount: Int? = null` を追加。**揮発フィールド（6 個目）** — SQLDelight / Firestore には書かない（§1.2 の 8 フィールド永続化原則を維持。マイグレーション不要）
- **`CafeDetailViewModel`**: コンストラクタに `cafeRepository: CafeRepository` を追加（`AppContainer` factory 内で配線、Swift から見た factory シグネチャ不変）。init で条件付き Places Details リフレッシュ:
  - 発火条件 = `initialCafe == null || initialCafe.googleRating == null`（DB スナップショット由来のみ。検索 / POI 由来の新鮮な Cafe では API を叩かない）
  - `latestDetails: Cafe?` を保持し、cafe 採用順 = `latestDetails ?: 最新記録の cafe ?: initialCafe`（records 再 emit による巻き戻り防止）
  - 失敗時はサイレントフォールバック（スナップショット表示維持、`error` は汚さない。`CancellationException` は再スロー）
  - **UIState 型は不変**
- **`MapViewModel`**: `fun onCafeSaveToggled(cafe: Cafe)` を追加（`savedCafes` に placeId があれば delete、なければ `save(SavedCafe(userId, cafe, "", now))`。エラーは既存 `error` へ）。**UIState 不変** — 保存済み「強調」は純プレゼンテーション状態のため iOS ローカル `@State savedEmphasisActive` で管理する。`showVisited`（UIState）との非対称は意味の違い: 訪問済みは表示 ON/OFF のドメイン設定、保存済み強調は一時的なプレゼンテーション状態（保存済みピン自体は常時表示に変更）

### 16 色セマンティクス（ui-ux-guidelines.md へ反映済みが正）

| 概念 | 色 | 使用箇所 |
|------|----|---------|
| ブランド / 訪問済み | AccentColor **#8B5A2B**（dark: #C08552 目安） | visitedCafePin（brown→accent）、TagChip 選択フィル、tint 全般 |
| 保存済み（行きたい） | `Color.indigo`（維持） | savedCafePin、保存ボタン / バッジ |
| 好み一致 | `Color.pink`（accentColor 参照から**明示変更** — AccentColor 茶色化の必須随伴修正） | recommendedCafePin、凡例チップ |
| 検索結果 | `Color.blue`（維持） | searchResultPin、検索 UI |

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `Cafe.userRatingCount`（揮発）+ Places FieldMask / DTO / マッピング + `CafeDetailViewModel` details リフレッシュ + `MapViewModel.onCafeSaveToggled` + commonTest | 2026-07-07 完了。JVM 全 green + 新規テスト（FieldMask 5 / DetailsRefresh 5 / SaveToggle 追加）。既存テスト負債 2 件も同時解消（stdlib assert / PlaceSummary 未追随 → lessons 2026-07-07）|
| [x] | 親: iosSimulatorArm64Test 中間検証 | 2026-07-07 完了。4 モジュール green + XCFramework assemble OK |
| [x] | ios-engineer: Swift `Cafe` 呼び出し修正 + AccentColor 設定 + `Components/TagChip.swift` + MapTabView（チップ統合・ピン色・下部カード刷新）+ CafeDetailView（写真帯・視覚ヘッダー・保存ボタン移設） | 2026-07-07 完了。BUILD SUCCEEDED・override 不使用。accentColor 全数目視済（TasteMapFilterSheet 系は「好み一致」と別概念のため pink 化対象外 → implementation_note）。後続候補: SavedCafeListSheet「記録あり」バッジの brown 孤立 |
| [x] | 親: verify-kmp-ios + docs 反映（data-model §1.2 / ui-ux-guidelines 色表 / implementation_note）+ commit | 2026-07-07 完了。親再検証: testAndroidHostTest（B-7 既知負債除き green）/ xcodebuild override 無し BUILD SUCCEEDED / 全モジュール compileTestKotlinIosSimulatorArm64 sweep green |
| [x] | 検証: シミュレータ目視（下部カード / 詳細写真帯 / 保存済みチップ強調 / 保存トグル双方向 / 機内モード / ダークモード） | 2026-07-07 ユーザー確認済み。フェーズ 16 完了 |

---

## フェーズ 17: 周辺カフェを自前ピン化（Apple 検索由来・ズーム依存の解消）

**背景**: マップが Apple 標準 POI ラベルのタップに依存しており、そのラベル密度は MapKit のレンダリングエンジンがズームレベルで内部決定するため公開 API では制御不能（`MapStyle` / `MKMapView` いずれにも密度・閾値ノブ無し）。「かなりズームしないとカフェ POI が出てこない」というユーザー体験の根本原因。

**方針**（ユーザー承認済み 2026-07-07）: Apple 標準 POI ラベル頼みをやめ、`MKLocalPointsOfInterestRequest`（`MKLocalSearch` 経由）で表示範囲内のカフェを **Apple 地図データ**から取得し、**常時見える自前ピン**として描く。Google Places 課金なし（Apple Maps quota）。ピンタップは既存の `onPoiTapped(name:latitude:longitude:)` → Places ルックアップ → 詳細 push フローをそのまま再利用（KMP 変更ゼロ）。iOS 単独で完結。

### インターフェース合意書（KMP 変更なし）

- 追加も変更もしない。`MapViewModelBridge.onPoiTapped(name:latitude:longitude:)` / `poiLookupResult` / `isLookingUpPoi` / `poiLookupError` を現状のまま流用する。Apple 検索由来ピンは iOS ローカルの純プレゼンテーション状態（ドメイン化しない）。

### 仕様（ios-engineer 向け）

- **取得**: `MKLocalPointsOfInterestRequest(center:radius:)` + `pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe, .bakery])` を `MKLocalSearch` で実行。既存 `.onMapCameraChange(frequency: .onEnd)` で算出済みの region/radius を再利用してトリガする。
- **デバウンス / キャンセル**: 直近の fetch Task を `@State` で保持し、camera settle ごとに前回をキャンセル → 300ms 程度スリープしてから実行（連続パンの合体）。
- **ズームゲート**: 可視半径がしきい値（既定 3000m、定数で調整可）を超えたら fetch せず既存の Apple 検索ピンを **クリア**（都市スケールでの氾濫防止）。しきい値以下では全ズーム域でピンが出る＝ユーザーの不満（ズームしないと出ない）を解消。
- **重複排除**（優先順位: 訪問済み > 保存済み > 検索結果 > Apple 検索由来）: Apple 由来カフェは placeId を持たないため座標近接（約 40m 以内）で既存 4 種ピンのいずれかと重なるものを除外する。名前一致はローカライズで不安定なため使わない。
- **ピン意匠**: 既存 4 種（訪問済み=accent / 保存済み=indigo / 検索結果=blue / 好み一致=pink）より明確に低強調。小さめ（≤30px）+ ミュートしたセカンダリ系配色 + `cup.and.saucer` SF Symbol。「まだ記録も保存もしていない周辺の店」を示す。`savedEmphasisActive` 時は 0.4、テイストフィルタ有効時（`!tasteMatchedPlaceIds.isEmpty`、Apple 由来は常に非マッチ）は 0.25 に減光。アクセシビリティラベル必須。
- **タップ**: `bridge.onPoiTapped(name:latitude:longitude:)` を呼ぶ（ローディングは既存 `isLookingUpPoi` オーバーレイ、結果 push は既存 `.onChange(of: bridge.poiLookupResult)`、失敗は既存 `poiLookupError` トーストで処理済み）。
- **標準 POI ラベルと `MapFeature` 選択の扱い**: `.mapStyle` を `.standard(pointsOfInterest: .excluding([.cafe, .bakery]))` に変更し、Apple の cafe/bakery ラベルを消して自前ピンとの二重表示を防ぐ（他カテゴリの地図コンテキストは残す）。これにより cafe/bakery の `MapFeature` は発火しなくなるため、`selection: $mapFeatureSelection` / `mapFeatureSelection` State / `poiSelectionChanged` / `.onChange(of: mapFeatureSelection)` の cafe 用 POI 選択機構は死にコード化する → 一式除去する（Simplicity）。`onPoiTapped` の呼び出し元が自前ピンに置き換わるだけで、下流フローは不変。

### タスク

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: Apple 検索ピン層の追加（fetch/デバウンス/ゲート/重複排除/意匠/タップ）+ `.mapStyle` excluding 化 + `mapFeatureSelection` 機構の除去 + ビルド検証 | 2026-07-07 完了。`MapTabView.swift` のみ。override 不使用で BUILD SUCCEEDED。意匠: 24pt + `.secondaryLabel` + `cup.and.saucer`（非塗り）。重複排除 40m 測地距離。ゲート 3000m。KMP 変更なし |
| [x] | 親: override 無し再検証 | 2026-07-07 完了。`xcodebuild ... -destination iPhone 17` override 無しで `** BUILD SUCCEEDED **`、`No such module 'SharedLogic'` は framework 未インデックス時の SourceKit 誤検知（フルビルドで解消）|
| [x] | 親: シミュレータ目視促し + docs 反映 + commit | commit `c6b0e90`（自前ピン化）+ `db4cee3`（標準 POI 非表示）+ `cbe3032`（視認性向上）。ユーザー目視で「見えるのにタップで該当なし」等が判明 → 17-B/C/D の後続修正を駆動（＝目視は実施済み）。17-D 修正後の最終目視のみ行 481 [~] で継続 |

### 17-B: 「見えるのにタップで『該当カフェなし』」不整合の修正（目視で発覚）

**症状**: 自前ピンは正しく出るが、タップすると `poiLookupError`「該当するカフェが見つかりませんでした」になる。

**原因**: 表示（Apple `[.cafe, .bakery]`）と解決（`MapViewModel.onPoiTapped` → `CafeRepository.searchText(name, LocationBias 500m)` は `includedType=cafe` ハードフィルタ付きの**名前テキスト検索**）で対象集合が食い違う。①`coffee_shop` 型（スタバ・ブルーボトル等チェーンの多く）が `cafe` フィルタで除外 ②ベーカリーは `cafe` に不一致で常に 0 件 ③Apple 表示名↔Google テキストマッチのズレ。座標が正確に分かっている POI 解決に名前テキスト検索を使うのが誤り（この不整合はフェーズ 16 以前から潜在。POI が滅多に出なかったため露見していなかった）。

**方針**: 座標アンカー解決へ切替。名前テキスト検索をやめ、既存 `CafeRepository.searchNearby(lat, lng, radiusMeters)`（`includedPrimaryTypes=[cafe, coffee_shop]` + `rankPreference=DISTANCE`）を使い最近傍を採る（①③根治）。②はベーカリーを iOS 取得対象から外し「表示＝解決可能」を揃える。KMP API シグネチャ変更なし（`searchNearby` 再利用、`onPoiTapped` の bridge シグネチャも不変）。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `MapViewModel.onPoiTapped` の解決を `searchText(name, bias)` → `searchNearby(lat, lng, 150m)` に変更。`.first()` 採用（DISTANCE ランク済）。空→既存エラー / 例外ハンドリング維持。`name` 引数は bridge 安定のため残すが query には未使用（KDoc に理由記載）。`MapViewModelPoiLookupTest` を `searchNearby` スタブへ更新 | 2026-07-07 完了。JVM test green。公開 API 不変。親が `PlacesClientImpl.kt:81` の陳腐化コメント（POI タップはもう searchText 不使用）も同時修正 |
| [x] | ios-engineer: Apple POI 取得フィルタを `[.cafe, .bakery]` → `[.cafe]` に変更（表示＝解決可能を揃える）。関連コメント追随 | 2026-07-07 完了。override 無し BUILD SUCCEEDED。`.mapStyle` の excluding は cafe/bakery 両方のまま維持（標準ラベル二重表示防止） |
| [x] | 親: iosSimulatorArm64Test（override 無し）+ ビルド再検証 | 2026-07-07 完了。`:shared:feature:map:iosSimulatorArm64Test` override 無し BUILD SUCCESSFUL / 統合 xcodebuild override 無し `** BUILD SUCCEEDED **`（framework linkDebug UP-TO-DATE = KMP 変更取り込み済） |
| [x] | 親: 目視促し + commit | 2026-07-07 完了。commit `c6b0e90`。後続で `db4cee3`（標準 POI ラベル全非表示 `.excludingAll`）/ `cbe3032`（自前ピン視認性向上）も対応 |

### 17-C: タップが「近くの別店」に解決される不具合の修正（目視で発覚）

**症状**: 自前ピンをタップすると、たまにタップした店ではなく近くの別のカフェの詳細が開く。

**原因**: `MapViewModel.onPoiTapped` が `searchNearby(lat, lng, 150m)` の結果を**距離順の先頭（最近傍）で採る**だけで、タップした POI の `name` を使っていない。Apple の POI 座標が Google の同一店座標と数十 m ズレる / 150m 内に複数カフェがある場合、最近傍＝別店を拾う。17-B で `name` を「bridge 安定のため残すが query 未使用」としたが、位置で候補を絞った後の**曖昧性解消（disambiguation）**には name が有効（名前を主クエリにするテキスト検索とは別問題）。

**方針**: `searchNearby` で近傍候補を取得 → **タップ名と一致する候補を優先**、無ければ最近傍にフォールバック（＝現行挙動）。名前正規化は commonMain 完結（`lowercase()` + 空白除去）で双方向 `contains`。正規化後のタップ名が短すぎる（< 2 文字）場合は名前一致をスキップして最近傍。API シグネチャ・iOS 変更なし。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `onPoiTapped` に name 曖昧性解消を実装（近傍候補 → 名前一致優先 → 無ければ最近傍）。KDoc 更新。`MapViewModelPoiLookupTest` に「最近傍と別の名前一致候補を選ぶ / 一致なしは最近傍」ケース追加 | 2026-07-07 完了。`MapViewModel.kt` + `MapViewModelPoiLookupTest.kt` のみ。JVM test green（9/9）。`namesMatch` = 正規化（lowercase+空白除去）双方向 contains、タップ名 2 文字未満はスキップ。公開 API 不変 |
| [x] | 親: iosSimulatorArm64Test（override 無し）| 2026-07-07 完了。`:shared:feature:map:iosSimulatorArm64Test` override 無し BUILD SUCCESSFUL（新規 2 含む 9/9）|
| [x] | 親: iosSimulatorArm64Test（override 無し）+ 目視促し + commit | commit `0fca1af`。→ ただし目視で 17-D の別真因が発覚（下記） |

### 17-D: タップが全部同じ店になる不具合の真因修正（Apple↔Google 型分類の食い違い）

**症状（ユーザー目視・スクショ）**: 「夢やカフェ」「ふわランドリー&カフェ」「ごはんカフェ くるま」の 3 ピンが、どれをタップしても「夢やカフェ」の詳細を開く。

**真因**: 17-B/17-C の解決は `searchNearby(includedPrimaryTypes=[cafe, coffee_shop])` に依存。しかし Apple が cafe 分類する店（ランドリー併設・食事カフェ等）は **Google では `cafe`/`coffee_shop` 型でない**ことがあり、その場合**近傍候補にすら入らない** → 近傍で唯一の cafe 型「夢やカフェ」に全部フォールバックする（名前一致も候補に無いので効かない）。前 2 回は「cafe 型候補の中の選択」という同系統の調整で、真因は**型フィルタそのもの**（同系統 2 回失敗 → プランモードで再調査、lessons 参照）。

**方針**: 型フィルタを外し、**名前 + 位置バイアスのテキスト検索**（`includedType` 省略）で候補を取得 → タップ座標に**最も近いもの**を採る（名前一致を優先。同名チェーンは距離で解消）。見つからなければ「該当なし」（近傍の別店を自信満々に開く旧挙動を排除）。JSON は `explicitNulls=false`+`encodeDefaults=true` のため `includedType: String? = "cafe"` に変え null 渡しで省略可能。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | (1) data-places 型フィルタなし検索追加 `searchByNameNear`（`includedType` nullable 化 + null 省略）(2) `onPoiTapped` を `searchByNameNear(name, bias 200m)` → タップ座標最近傍（名前一致優先）へ (3) 全 `CafeRepository` 実装/Fake 追随（6 Fake + 1 PlacesClient Fake）(4) テスト更新 | 2026-07-08 親が直接実装（kmp-engineer がセッション上限で中断のため引き継ぎ）。domain + data-places + feature/map 横断。距離解決の新テスト 2 件追加 |
| [x] | 親: JVM test（全影響モジュール）+ iosSimulatorArm64Test + 統合ビルド再検証（override 無し）| 2026-07-08 完了。JVM: data-places/map/cafe-search/cafe-detail/coffee-editor 全 green。`:shared:feature:map:iosSimulatorArm64Test` green（新規距離テスト含む）。統合 xcodebuild override 無し `** BUILD SUCCEEDED **` |
| [x] | 親: 目視促し + commit + lesson 記録 | 2026-07-08: commit `e087980` / lessons（「表示と解決で対象集合がズレると誤同定」）記録済み。**目視は verification-checklist.md「マップ / カフェ探索」に移管**。波及メモ: 型フィルタ解除で bakery も解決可能に → iOS `.cafe` 限定と `MapTabView.swift:1383` コメントは再検討候補（据え置き）|

---

## コードレビュー指摘対応（2026-07-08）

> 完了（2026-07-08、commit `f6a322b`）: コードレビューで検出した高優先 2 件を修正 — ① iOS `CoffeeFirestoreMapper.toDocument` が `tags` を書き出さず、iOS で付けたタグが同期で永久消失（Kotlin 側は書き込み・両側 `fromDocument` は読む非対称）→ Swift 側 doc 辞書に `tags` 追加で対称化。② ローカル DB `Coffee_record.toDomain` が enum 復元に `valueOf` を使い、未知 enum 文字列を含む行が 1 件でもあると `observeAll` Flow 全体が全損（リスト/マップ/分析が同時に死ぬ）→ `entries.firstOrNull` + フォールバック（brewMethod→Other、processing/roastLevel→null）に変更、回帰テスト 3 本追加。両パターンと横断点検は lessons.md 2026-07-08 に記録。

---

## フェーズ 6 既知バグ: エディタ buildCafe の Edit/Duplicate 分岐（2026-07-08 着手）

> セルフ抽出記録（元 cafe = null）を編集/複製して手動でカフェ名を入力しても、`buildCafe` の `currentInitialRecord?.cafe ?: return null`（`CoffeeEditorViewModel.kt:744`）で null 返却され、入力したカフェ名が無言で捨てられていた。`Mode.Create` は `currentInitialRecord = null` を明示設定するため、mode 分岐を「引き継ぎ元 cafe の有無」の一点に畳んでバグ修正 + 簡素化を同時に達成（commonMain 完結・公開 API 変更なし）。フェーズ 6 バックログの当該行と同件。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `buildCafe` の Edit/Duplicate self-extract 分岐を修正（引き継ぎ元 cafe なし → 手入力カフェとして新規 UUID 採番）+ mode 分岐の畳み込み + commonTest | 2026-07-08 完了。cafe 採用を状態ベース 3 段判定に一本化し `mode` 引数削除。回帰テスト 2 件追加。`testAndroidHostTest` 20 件 green / 親が `iosSimulatorArm64Test` を override 無しで green。implementation_note / lessons 2026-07-08 記録 |
---

## BeanProfile 初期データ整備（2026-07-08）

> **確定仕様（grilling 2026-07-08 親確定）**: 現行スキーマのまま（拡張なし）/ 主要産地網羅 38 件 / **日本語表記に統一**（`processings` は enum 名、`beanId` は ASCII kebab-case）/ `flavorNotes` は統一語彙 42 語（正本 `data-model.md` §3.2）/ seed JSON + Admin SDK スクリプト（`scripts/seed/`）で冪等 upsert。SCAJ カッピング評価観点（酸の質 / 甘さ / 質感 / クリーンカップ / 余韻 / 調和）は description の記述観点と語彙に反映、Blue Bottle 等ロースターはラインナップ参考のみ（description は自作・転載禁止）。経緯は implementation_note 2026-07-08 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: seed データ `scripts/seed/bean-profiles.json`（38 件）+ 投入スクリプト `seed-bean-profiles.mjs`（バリデーション + 冪等 upsert）+ README + .gitignore（サービスアカウント鍵） | 2026-07-08 完了。`--dry-run` でバリデーション 38 件全通過 |
| [x] | 親: docs 反映（data-model.md §1.8 / §3.2 の日本語表記規約 + flavorNotes 語彙リスト + seed 手順参照、implementation_note 経緯記録） | 2026-07-08 完了 |
| [ ] | ユーザー: サービスアカウント鍵取得 → `node seed-bean-profiles.mjs` で本番投入（`coffeevision-a54aa`）→ 実機確認（分析タブ「好みの豆の傾向」/「試してみては」/ エディタ産地サジェスト。verification-checklist 15-E-3） | 手順は `scripts/seed/README.md`。投入後はアプリ再起動（メモリキャッシュのため） |
---

## 産地シノニム正規化 OriginNormalizer（2026-07-08 着手）

> **確定仕様（2026-07-08 親確定）**: 「Ethiopia」「イルガチェフェ」→「エチオピア」の名寄せを決定論のまま実現する（ベクトル検索は現アーキテクチャに過剰と判断し見送り）。`shared/domain` にトップレベル `object OriginNormalizer`（`normalize = trim → lowercase → シノニム辞書完全キー一致、辞書外は素通し`。辞書の正本はコード）。適用範囲は**全 origin 正規化ポイント**（BeanProfile 突合 3 UseCase + 統計グルーピング 2 箇所 + 9-5）。free-text 検索（`CoffeeRecordQuery`）と `getByOrigin`（本番呼び出し元ゼロ）は対象外。data-model.md 集計ルールの「表記ゆれの完全名寄せは将来課題」の解消。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `OriginNormalizer` 新設 + 5 箇所置換（BeanProfileMatch / BuildCoffeeStats ×2 / ObserveTasteMatchedCafes / PreferredBeanTraits / SuggestUnexploredBeans）+ commonTest | 2026-07-08 完了。エージェントがセッション上限で中断したため、複合語 contains 既存テスト 2 件の再構成（辞書外の語で維持）+ 名寄せ回帰テスト 1 件は親が引き継ぎ。`:shared:domain:testAndroidHostTest` 170 件 green。複合語×辞書のすれ違いは lessons 2026-07-08 に記録・sweep 済み |
| [x] | 親: iosSimulatorArm64Test + 統合ビルド再検証 | 2026-07-08 完了。`:shared:domain:iosSimulatorArm64Test` 170 件 green（XML で実走確認）/ `assembleSharedLogicXCFramework` 成功 / xcodebuild override 無し `** BUILD SUCCEEDED **`。JVM 全モジュールは account の既知負債 B-7（9 件）以外 green |
| [x] | 親: docs 反映（data-model.md 正規化記述の改訂・将来課題消し込み、implementation_note 経緯）+ commit | 2026-07-08 完了。data-model.md §1.6/§1.7/§1.7a/§1.8 を OriginNormalizer 準拠に改訂、implementation_note（ベクトル検索見送りの経緯）、lessons（辞書×contains のすれ違い + sweep）記録 |
---

## フェーズ 18: Firebase テレメトリ導入（Crashlytics / Analytics / Performance、2026-07-08 起票）

> **確定仕様（2026-07-08 親確定）**: iOS のみ（Android 配線なし）。**Crashlytics + Performance = 常時収集（同意不要）**、**Analytics = `analyticsConsent` 同意時のみ**。Analytics は IDFA 非依存の `FirebaseAnalyticsWithoutAdIdSupport`（ATT 不要を維持）。イベントは自動収集 + `screen_view` のみ（カスタムイベントは後続）。`Info.plist` で Analytics 自動収集を起動時 OFF → `AppState.applyTelemetryConsent` が consent 確定/変更時に Analytics だけ有効化。経緯・トレードオフは implementation_note 2026-07-08 エントリ、プライバシー申告は app-store-metadata.md 6.1/6.3。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: docs 反映（app-store-metadata プライバシー申告 6.1/6.3 + 変更履歴、implementation_note エントリ + 方針サマリ、本フェーズ起票） | 2026-07-08 完了 |
| [x] | ios-engineer: SPM 3 プロダクト追加（`FirebaseCrashlytics` / `FirebaseAnalytics` / `FirebasePerformance`）+ `Info.plist` の `FIREBASE_ANALYTICS_COLLECTION_ENABLED=NO` | 2026-07-08 完了。pbxproj 手編集で完結（Xcode UI 不要）。**`FirebaseAnalyticsWithoutAdIdSupport` は現行 SDK 12.14.0 で廃止 → 素の `FirebaseAnalytics` が既定 IDFA 非依存**のため名称変更（結論不変） |
| [x] | ios-engineer: `iOSApp.swift` で Crashlytics 明示有効化 + `AppState.applyTelemetryConsent(_:)` 新設（`analyticsConsent` の `didSet` で一元発火 → `Analytics.setAnalyticsCollectionEnabled`）| 2026-07-08 完了。Performance/Crashlytics は触らない（常時 ON） |
| [x] | ios-engineer: Crashlytics dSYM アップロード用 run-script build phase 追加 | 2026-07-08 完了（`Upload dSYM to Crashlytics`）。Release/TestFlight でのシンボリケーション用 |
| [x] | ios-engineer: `.trackScreen("name")` view modifier 実装 + 4 タブ + 主要画面に付与 | 2026-07-08 完了。`AnalyticsScreenTracking.swift`。map_tab/coffee_list/analysis/settings + coffee_detail/cafe_detail/coffee_editor/cafe_search/account |
| [x] | ios-engineer: `PrivacyInfo.xcprivacy` の集計データ種別（Crash/Performance/Product Interaction）+ UserDefaults 必須理由 API 宣言 | 2026-07-08 完了。全体の Required Reason API 網羅監査は別タスク（下記 F-1）|
| [x] | 親: ビルド再検証（override 無し）+ docs のプロダクト名実態訂正 | 2026-07-08 完了。`OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED=NO` で `** BUILD SUCCEEDED **`。SourceKit の No such module は IDE インデックス偽陽性 |
| [ ] | ユーザー: 実機/シミュレータで実挙動確認（Crashlytics テストクラッシュ送出 / Analytics DebugView で consent トグル ON→OFF / Performance トレース / `screen_view` 発火）+ 親が commit | ビルド成功 ≠ 動作確認完了 |

---

## docs / 設計判断バックログ（後回し可）

> 2026-06-16 の docs 全体精査で洗い出した中・低優先の項目。いずれも今すぐ直さないと害が出る種類ではない（最優先 A-1〜A-3 / 整合 A-4〜A-7 はコミット済 `34ec607` / `7c86ab5`）。必要になったフェーズで着手する。判断経緯は精査結果と [`tasks/lessons.md`](./tasks/lessons.md) 2026-06-16 エントリを参照。

| 状態 | ID | タスク | 着手目安 / 備考 |
|------|----|------|----------------|
| [ ] | B-1 | マルチデバイス書き込みの競合解決方針を明文化（`updatedAt` での last-writer-wins 等）。現状 remote→local は `INSERT OR REPLACE` で世代比較なし | 複数端末同期（要件 7-3、優先度○）を実装・検証する段階。単一端末では実害なし |
| [ ] | B-2 | ViewModel テスト方針の整理。規約（architecture / coding-conventions）は「VM は runTest でテスト」だが主要 VM が未テスト。規約を実態に合わせるか、テストを足すか決める | CI を本格運用するとき / 新規 VM 追加時 |
| [x] | B-3 | `requirements.md` の「API キーは難読化」を実態（Google Cloud 側のキー制限ベース。Info.plist / BuildConfig は平文）に修正 | 2026-07-01 完了。requirements→CoffeeRecord 全面改訂と同時に非機能要件の記述を修正 |
| [ ] | B-4 | `rating=0.0`=「未評価」の暗黙 sentinel を仕様化（`CoffeeRecord.rating` を nullable にするか 0 を明記するか）。`VisitedCafe` 集計が 0 を平均除外している | 集計まわりを次に触るとき。現状動作に実害なし。requirements §未決事項にも起票済み |
| [x] | B-5 | CI（GitHub Actions）を実際の PR でグリーン確認し `tasks.md` フェーズ 0 の `[~]` を `[x]` 化 | 2026-07-08 完了。ユーザーが CI グリーン確認 → フェーズ 0 CI 行も `[x]` 化 |
| [x] | B-6 | **既存テスト負債①**: `shared/domain` の `FavoriteSignalsPersonaTest.kt` が `"%.4f".format(...)`（JVM 専用 API）を多数使用し、Kotlin/Native で `Unresolved reference 'format'` → domain の `iosSimulatorArm64Test` がコンパイル不能だった。→ **2026-07-07 解消**（親が Native 安全な `Double.fmt(digits)` ヘルパに全 44 箇所置換）。domain の iOS テスト全 green（Persona 11 件含む failures=0）。15-E-2 検証がブロックされていたため親が対応 |
| [x] | B-7 | **既存テスト負債②**: `shared/feature/account` の `AccountViewModelTest`（9 件）が `vm.clear()` を呼ばず `UncompletedCoroutinesError`。2026-07-07 の 15-E-1 で発覚（clean tree 再現、android/iOS 双方）。→ **2026-07-09 解消**（親が 9 テスト全てに `vm.clear()` + `testScheduler.advanceUntilIdle()` drain を追加、lessons 2026-07-06 パターン踏襲）。`testAndroidHostTest` BUILD SUCCESSFUL / `iosSimulatorArm64Test` 9 件 failures=0 errors=0（XML 実走確認、override 無し）。B-5 で CI グリーン確認済みのため対応タイミングに到達 |
| [ ] | C-1 | feature ViewModel の「`shared/core` 暫定置き場 → 後で feature module へ git mv」運用の見直し（最初から feature module を作る案） | 次の feature 追加時に再評価 |
| [ ] | D-1 | `ui-ux-guidelines.md` の写真サムネ記述に「Places 写真は永続キャッシュ禁止（規約）、ローカル写真とは読み込み方針が違う」旨を補足 | 任意 |
| [x] | D-2 | `architecture.md`「データフロー（書き込み）」節が旧 Visit モデル / 旧構成（プラットフォーム別 VisitRepository 実装）のまま。現行の CoffeeRepositoryImpl 合成構成に書き直す（読み取り側は 2026-07-03 の shared レビュー対応で修正済） | 2026-07-04 完了。architecture.md 現行化（Visit 残骸消し込み・例コードの実体化）と同時に対応。詳細は implementation_note 2026-07-04 |
| [~] | E-1 | アカウント削除時の Apple トークン失効（revoke）。App Store ガイドライン 5.1.1(v) 対応。**2026-06-24 着手 → 専用セクション「フェーズ 5.2」に移管**。詳細は [`implementation_note.md`](./implementation_note.md) 2026-06-17 アカウント機能エントリ | App Store 申請前。現状の `deleteAuthUser` は Firebase ユーザー + Firestore データのみ削除 |
| [ ] | F-1 | `PrivacyInfo.xcprivacy` のアプリ全体 Required Reason API 網羅監査（File Timestamp / System Boot Time / Disk Space 等）。フェーズ 18 では UserDefaults（`CA92.1`）+ テレメトリ集計データ種別のみ宣言済み | App Store 申請前。Firebase SDK 同梱マニフェストで足りる分を差し引いてアプリ側の残りを確認 |
