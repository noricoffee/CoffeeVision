# CoffeeVision タスク一覧

このファイルは実装タスクのフェーズ別管理表です。
完了したタスクは `[x]` でチェックし、完了日とコミット / PR を備考列に追記してください。

> 細かい WIP メモは `docs/tasks/lessons.md`（自己改善ループ用）に書き出します。

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

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | KMP プロジェクトの初期化（`sharedLogic` / `sharedUI` / `iosApp` / `androidApp`） | 既存のスケルトン |
| [x] | ドキュメント整備（CLAUDE.md / docs 一式） | 2026-06-02 |
| [ ] | `gradle/libs.versions.toml` に必要ライブラリを追加（SQLDelight / Firebase / Ktor / kotlinx-datetime / kotlinx-serialization） | |
| [ ] | SKIE の採用判断（採用するなら `sharedLogic` の Gradle に追加） | [`kmp-bridge.md`](./kmp-bridge.md) 参照 |
| [ ] | `local.properties` での API キー管理を整える（Places / Firebase） | リポジトリにコミットしない |
| [ ] | `.gitignore` に `GoogleService-Info.plist` / `google-services.json` を追加するか、Decrypt 運用にするかを決定 | |

---

## フェーズ 1: ドメインモデルとローカル DB

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | `domain/` 配下に Visit / Cafe / CoffeeItem / FoodItem / Photo を実装 | [`data-model.md`](./data-model.md) §1 |
| [ ] | BrewMethod / ProcessingMethod / RoastLevel の enum を実装 | |
| [ ] | SQLDelight プラグインを `sharedLogic/build.gradle.kts` に追加 | |
| [ ] | `commonMain/sqldelight/com/noricoffee/db/` にスキーマファイル（4 つ）を作成 | [`data-model.md`](./data-model.md) §2 |
| [ ] | `DatabaseDriverFactory`（`expect`/`actual`）を実装 | iOS は `NativeSqliteDriver` |
| [ ] | ドメインモデル ⇔ DB 行のマッパを実装 | |
| [ ] | `VisitRepository` の `commonTest` を書く（インメモリドライバ） | |

---

## フェーズ 2: 認証と Firestore 接続

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | Firebase プロジェクト作成・`GoogleService-Info.plist` / `google-services.json` 配置 | |
| [ ] | iOS アプリで Firebase 初期化 | `iOSApp.swift` |
| [ ] | 匿名サインインの実装（起動時自動） | `AuthRepository` |
| [ ] | Firestore のオフライン永続化を有効化 | デフォルト on の確認 |
| [ ] | `VisitRepository` の Firestore 書き込みを実装（ローカル → クラウドの順） | [`architecture.md`](./architecture.md) §「データフロー」 |
| [ ] | Firestore Security Rules を作成・デプロイ | |

---

## フェーズ 3: iOS UI（MVP）

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | `AppContainer`（Kotlin）を実装し、iOS の `iOSApp.swift` から起動 | |
| [ ] | `VisitListViewModel`（Kotlin）と `VisitListViewModelBridge`（Swift）を実装 | |
| [ ] | ホーム画面（VisitListView）を実装 | |
| [ ] | Visit 詳細画面（VisitDetailView）を実装 | |
| [ ] | Visit 作成 / 編集画面（VisitEditorView）を実装 | |
| [ ] | CoffeeItem の追加 / 編集 UI（モーダル） | |
| [ ] | FoodItem の追加 / 編集 UI（モーダル） | |
| [ ] | 星評価入力コンポーネント（StarRatingView）を実装 | |
| [ ] | 写真ピッカー（PhotosPicker）を組み込み | |
| [ ] | ローカル保存後、Storage に非同期アップロードする処理 | |
| [ ] | 各画面のプレビューを実装 | |

---

## フェーズ 4: Places API（カフェ検索）

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | Ktor Client + Kotlinx Serialization のセットアップ | |
| [ ] | `PlacesClient`（Text Search / Nearby Search / Place Details） | |
| [ ] | `CafeRepository` 経由で ViewModel から呼び出せるようにする | |
| [ ] | カフェ検索画面（CafeSearchView） | テキスト検索 |
| [ ] | 現在地検索（CoreLocation 連携。位置情報の利用許可ダイアログ対応） | |
| [ ] | Places API 規約に従い、写真は都度取得する実装にする | キャッシュしない |

---

## フェーズ 5: 仕上げ

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | 設定画面（テーマ切り替え / バージョン表示 / サインアウト） | |
| [ ] | アカウントアップグレード（匿名 → メール / SNS）の UI | |
| [ ] | アカウント削除フロー | |
| [ ] | エラーバナー / トースト共通コンポーネント | |
| [ ] | アクセシビリティ通し検証（VoiceOver / Dynamic Type / Reduce Motion） | |
| [ ] | App Icon / Launch Screen / アプリ表示名の整備 | |
| [ ] | App Store Connect 用メタデータ準備 | |

---

## フェーズ 6（任意 / 後続）

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | Android アプリ実装着手（`sharedUI` の Compose Multiplatform 利用） | |
| [ ] | 検索（キーワード）の高速化（SQLDelight FTS） | |
| [ ] | エクスポート（JSON）機能 | |
| [ ] | 同一カフェの集計表示 | |
| [ ] | Widget / ホーム画面ショートカット | |

---

## レビューセクション（PR / 振り返り用テンプレート）

新しい PR をマージしたら、以下をコピーして追記してください。

```
### YYYY-MM-DD - <タイトル>
- 変更点:
- 動作確認:
- 残課題 / フォローアップ:
```
