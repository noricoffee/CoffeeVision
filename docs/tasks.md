# CoffeeVision タスク一覧

このファイルは実装タスクのフェーズ別管理表です。
完了したタスクは `[x]` でチェックし、完了日とコミット / PR を備考列に追記してください。

> 細かい WIP メモは `docs/tasks/lessons.md`（自己改善ループ用）に書き出します。
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
| [~] | CI 整備: PR ごとに iOS / Android 両方のビルドを必須チェック化 | 2026-06-03 初回追加、Phase 2.5 PR3 で現行コマンド（サマリ参照）に差し替え済。ローカル両ジョブ成功確認済。**初回 PR で workflow グリーン確認後 [x]**（バックログ B-5 と同件） |
| [ ] | `local.properties` での API キー管理を整える（Places / Firebase） | Places 側は Phase 4 スライス 1（2026-06-11）で整備済。残は CI での Firebase 設定ファイル復元手段の検討（リリース準備時） |

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

| 状態 | タスク | 備考 |
|------|------|------|
| [~] | Android 側で `data-firebase` の `observe` 経由 Firestore 読み取りが動くことを確認 | 2026-06-11 / `:androidApp:assembleDebug` 成功。**エミュレータ / 実機での実動作 + Firestore Console での読み取り目視確認はユーザー作業** |

---

## フェーズ 4: Places API（カフェ検索）

> 完了（2026-06-11〜06-15、スライス 1〜7）: `shared/data-places` 新設（Places New v1 / Ktor / DTO / `CafeRepository`）→ iOS 検索 UI + xcconfig キー注入 → CoreLocation + Nearby + Details → Photo Media 都度取得 → `feature/{cafe-search,map,cafe-detail}` 切り出し → TabBar 化 + カフェ詳細統合 → Apple Maps POI タップ動線。設計判断は `implementation_note.md` の 2026-06-11 / 06-15 各エントリ参照。検索 UI・タブ構成はその後 2026-06-30（検索タブ廃止・マップ内検索）で再編済み。

---

## フェーズ 5: 仕上げ

> 完了分（2026-06-16〜06-17）: 設定画面（テーマ / ライセンス）・アカウント機能一式（Apple アップグレード / サインアウト / 削除）・エラートースト共通化・App Icon / Launch Screen・App Store メタデータ下書き（`app-store-metadata.md`）。判断は implementation_note 2026-06-16 / 06-17 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | アクセシビリティ通し検証（VoiceOver / Dynamic Type / Reduce Motion） | |

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
| [ ] | エクスポート（JSON）機能 | フェーズ 15-E と同件（7-4 を ○ へ引き上げ済み） |
| [ ] | 同一カフェの集計表示 | |
| [ ] | エディタ `buildCafe` の Edit/Duplicate 分岐の抜けを修正: 元 cafe が null（セルフ抽出）の記録を編集して手動でカフェ名を入力しても cafe が保存されない（手入力カフェとして新規 UUID を採番すべき） | 2026-07-06 の 15-B 実装中に kmp-engineer が発見（既存バグ・15-B スコープ外のため未修正）。次に Edit/Duplicate 周りを触るときに対応。implementation_note 2026-07-06 参照 |
| [ ] | Widget / ホーム画面ショートカット | |

---

## フェーズ 7: コーヒー記録主体への再設計（Visit → CoffeeRecord）

> 完了（2026-06-19）: 集約ルートを `Visit` → `CoffeeRecord` へ転換（クリーンブレイク・データ移行なし）。docs 全面改訂 → KMP（domain / core / data-local / feature リネーム / framework）→ data-firebase Android → iOS UI の 3 段 dispatch で完遂。確定仕様は `data-model.md`、経緯は implementation_note 2026-06-19 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [~] | 検証: シミュレータ手動確認（FAB→セルフ抽出保存→一覧 / カフェ詳細→記録 / マップピン / 詳細編集削除 / Firestore coffees） | 2026-06-19 / `xcodebuild` BUILD SUCCEEDED（親が override フラグ無しで再確認済）。**目視はユーザー作業。DB 作り直しのためアプリ削除→再インストール必須** |

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
| [~] | 検証（A-3 / A-4 / B-2 / B-4 の残り）: シミュレータ目視（タブ / グラフ / 空状態 / 一致ピン / 理由シート / VoiceOver）+ Apple Intelligence 有効実機での要約・Q&A round-trip | ビルドはすべて BUILD SUCCEEDED 済。**目視・実機確認はユーザー作業** |
| [ ] | （将来 9-6）協調フィルタリング: `CafeRecommendationProvider` のサーバ（GCP）リモート実装。横断データ基盤＋同意フローが本体 | Future Direction（implementation_note 2026-06-22）。フェーズ 12-D と同件 |

---

## 開発支援: ダミーデータ Scheme

> 完了（2026-06-19）: 専用 Scheme「iosApp (Dummy Data)」（env `SEED_DUMMY_DATA=1`）でローカル DB のみに固定 ID 30 件を冪等 seed / 通常 Scheme で clear。設計判断は implementation_note 2026-06-19 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [~] | 検証: ダミー Scheme で 30 件・通常 Scheme で 0 件のシミュレータ目視 | 2026-06-19 / 両 Scheme とも BUILD SUCCEEDED。**目視はユーザー作業** |

---

## フェーズ 9: テイスティング 5 要素（甘味/ボディ/酸味/風味/後味）

> 完了（2026-06-20）: `CoffeeRecord.tasting` を全レイヤー（domain / data-local / core / feature / data-firebase / iOS UI / 分析）に追加。当初の各要素独立 nullable はフェーズ 9.1 で all-or-nothing に即日変更。統合経緯は implementation_note 2026-06-20 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [~] | 検証: シミュレータ目視（入力 / 追加・削除切替 / 詳細 / 分析グラフ / round-trip / VoiceOver） | 2026-06-20 / BUILD SUCCEEDED。**目視はユーザー作業。DB 列追加のためアプリ削除→再インストール必須** |

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

> 完了（2026-06-30）: `BeanProfile`（サーバ管理 read-only、ID 紐付けせず origin/processings ファジーマッチ）+ `BeanProfileRepository`（Android Kotlin / iOS Swift、one-shot get + メモリキャッシュ）+ エディタの origin サジェスト UI。仕様は `data-model.md` §1.8。**Firestore `beanProfiles` への初期データ投入はユーザー作業**。

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

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | 実機/シミュレータで「このエリアを検索」→ 複数ピン、パン後のボタン再出現、テキスト検索の全件ピン + リストを目視確認 | **ユーザー作業**（実 Places API キー必要） |

---

## docs 棚卸し（2026-07-02）

> 完了（2026-07-02）: 実装と docs の齟齬 4 件（data-model のフェーズ 10 / 12-C 追随、kmp-bridge の export 記述、app-store-metadata の CoffeeRecord 化、implementation_note サマリ全面更新）+ 旧モデル例文・runCatching 例文の是正 + CLAUDE.md / architecture.md の feature 列挙修正。経緯は implementation_note 2026-07-02 エントリ。
>
> 残りの低優先残件のうち ui-ux-guidelines の Visit 系旧用語は 2026-07-04 に消し込み済み。未着手で残るのは FAB 等の新 UI パターン未記載（ui-ux-guidelines）、backlog ID「B-4」と Phase B-4 の名前衝突など。必要になったら下の設計判断バックログへ起票する。

---

## iosApp コードレビュー指摘対応（2026-07-03）

> 完了分（2026-07-03）: 高優先 5 件を修正 — #1 CafeDetail の `onDisappear` observation 停止 / #2 アカウント処理完了待ちの二相ポーリング化 / #3 `bootstrap()` 再入ガード / #4 同意オンボーディングの timing バグ（観測される状態の公開を最後に）/ #5 写真物理削除の順序逆転。判断は implementation_note 2026-07-03 iosApp エントリ、教訓は lessons.md 2026-07-03。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | 実機 / シミュレータで目視確認: CafeDetail push→pop 後の一覧更新、サインアウト/削除時のオーバーレイと完了処理、初回同意シート表示、スワイプ削除失敗時の写真残存 | **ユーザー作業**。ビルドは 2026-07-03 に BUILD SUCCEEDED 済（新規 warning ゼロ） |

---

## shared コードレビュー指摘対応（2026-07-03）

> 完了分（2026-07-03）: 高優先 3 件を修正 — #1 `startSync` のスナップショット reconciliation（リモート削除のローカル伝播）/ #2 エディタの `selectedCafe` 保持（座標・photoReferences 引き継ぎ）/ #3 FOREIGN KEY の本番有効化 + 掃除 migration（iOS テストの赤→緑で実証）。判断は implementation_note 2026-07-03 shared エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | シミュレータ / 実機で目視確認: 記録作成 → マップに訪問済みピンが立つ / Firestore コンソールで記録削除 → ローカル一覧から消える | **ユーザー作業** |

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
| [~] | 検証: ① 位置情報未許可でエディタを開いてもチップ・ダイアログが出ない ② 許可済みで新規作成を開くと近隣カフェがチップ表示 → タップで選択・チップ消去 ③ FAB → サジェストタップ → 星 + 写真だけで保存の最短パス ④ 詳細「…」メニュー → 「これをもとに記録」で複製初期値（引き継ぎ 9 項目 / rating・notes・photos・tasting 空 / visitedOn = 今日）⑤ 新規作成の name 初期値「本日のコーヒー」 | ② は 2026-07-06 ユーザー確認済み（チップ非表示の初報はシミュレータの Features > Location 未設定が原因。Custom Location 設定で表示）。**①③④⑤ の目視はユーザー作業**。シミュレータ検証時は Location 設定が前提（下記 lessons 参照） |

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
| [ ] | 検証: 検索ヒット / 記録 0 件 / 検索ヒット 0 件の 3 状態、月跨ぎのセクション表示、検索中の FAB 挙動、VoiceOver でのヘッダ読み上げ | **シミュレータ目視はユーザー作業**。Location 前提は不要（位置情報非依存） |

### 15-D: 分析タブの空状態プログレス【要件 9-7】

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | kmp-engineer: 傾向信号までの残り件数の導出を KMP 側に追加（`CoffeeStats` 拡張 or `AnalysisViewModel`） | 閾値は `FavoriteSignals.minSampleSize`（3）/ `CORRELATION_MIN_SAMPLE`（5）を参照し二重定義しない |
| [ ] | ios-engineer: 空状態 / データ不足時のプログレス表示 UI（「あと N 杯記録すると傾向が見えます」） | |

### 15-E: 中期（後回し可）【要件 9-8 / 抽出レシピ / 7-4】

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | 未経験の豆への探索提案（`FavoriteSignals` × `BeanProfile`、分析タブ） | 要件 9-8（△）。12-C 突合の応用でサーバー不要 |
| [ ] | 抽出レシピフィールド（セルフ抽出向け） | requirements §2 フィールド表（△）。構造化 or 自由メモは着手時に判断 |
| [ ] | データエクスポート（JSON） | 要件 7-4（○ へ引き上げ済み）。フェーズ 6 の既存項目と同件 |

---

## docs / 設計判断バックログ（後回し可）

> 2026-06-16 の docs 全体精査で洗い出した中・低優先の項目。いずれも今すぐ直さないと害が出る種類ではない（最優先 A-1〜A-3 / 整合 A-4〜A-7 はコミット済 `34ec607` / `7c86ab5`）。必要になったフェーズで着手する。判断経緯は精査結果と [`tasks/lessons.md`](./tasks/lessons.md) 2026-06-16 エントリを参照。

| 状態 | ID | タスク | 着手目安 / 備考 |
|------|----|------|----------------|
| [ ] | B-1 | マルチデバイス書き込みの競合解決方針を明文化（`updatedAt` での last-writer-wins 等）。現状 remote→local は `INSERT OR REPLACE` で世代比較なし | 複数端末同期（要件 7-3、優先度○）を実装・検証する段階。単一端末では実害なし |
| [ ] | B-2 | ViewModel テスト方針の整理。規約（architecture / coding-conventions）は「VM は runTest でテスト」だが主要 VM が未テスト。規約を実態に合わせるか、テストを足すか決める | CI を本格運用するとき / 新規 VM 追加時 |
| [x] | B-3 | `requirements.md` の「API キーは難読化」を実態（Google Cloud 側のキー制限ベース。Info.plist / BuildConfig は平文）に修正 | 2026-07-01 完了。requirements→CoffeeRecord 全面改訂と同時に非機能要件の記述を修正 |
| [ ] | B-4 | `rating=0.0`=「未評価」の暗黙 sentinel を仕様化（`CoffeeRecord.rating` を nullable にするか 0 を明記するか）。`VisitedCafe` 集計が 0 を平均除外している | 集計まわりを次に触るとき。現状動作に実害なし。requirements §未決事項にも起票済み |
| [ ] | B-5 | CI（GitHub Actions）を実際の PR でグリーン確認し `tasks.md` フェーズ 0 の `[~]` を `[x]` 化 | 最初の PR を出すタイミングで自然解消 |
| [ ] | C-1 | feature ViewModel の「`shared/core` 暫定置き場 → 後で feature module へ git mv」運用の見直し（最初から feature module を作る案） | 次の feature 追加時に再評価 |
| [ ] | D-1 | `ui-ux-guidelines.md` の写真サムネ記述に「Places 写真は永続キャッシュ禁止（規約）、ローカル写真とは読み込み方針が違う」旨を補足 | 任意 |
| [x] | D-2 | `architecture.md`「データフロー（書き込み）」節が旧 Visit モデル / 旧構成（プラットフォーム別 VisitRepository 実装）のまま。現行の CoffeeRepositoryImpl 合成構成に書き直す（読み取り側は 2026-07-03 の shared レビュー対応で修正済） | 2026-07-04 完了。architecture.md 現行化（Visit 残骸消し込み・例コードの実体化）と同時に対応。詳細は implementation_note 2026-07-04 |
| [~] | E-1 | アカウント削除時の Apple トークン失効（revoke）。App Store ガイドライン 5.1.1(v) 対応。**2026-06-24 着手 → 専用セクション「フェーズ 5.2」に移管**。詳細は [`implementation_note.md`](./implementation_note.md) 2026-06-17 アカウント機能エントリ | App Store 申請前。現状の `deleteAuthUser` は Firebase ユーザー + Firestore データのみ削除 |
