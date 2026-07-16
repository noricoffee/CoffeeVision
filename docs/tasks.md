# CoffeeVision タスク一覧

このファイルは実装タスクのカテゴリ別管理表です。
完了したタスクは `[x]` でチェックし、完了日とコミット / PR を備考列に追記してください。

> 細かい WIP メモは `docs/tasks/lessons.md`（自己改善ループ用）に書き出します。
> **実機 / シミュレータの目視・手動検証（プロダクト QA）は [`docs/tasks/verification-checklist.md`](./tasks/verification-checklist.md) に分離**（2026-07-08）。tasks.md には実装・設計タスクのみを残す。
> **フェーズが完了したら、セクションの中身は「完了サマリ（数行）+ 未完行のみの表」に縮約する**（2026-07-04 運用開始。行単位の作業記録は git 履歴、設計判断は `implementation_note.md` が正）。セクション見出しは他 doc からの参照アンカーのため削除しない。完了時はサブ見出し（15-A / 17-D 等）も本文サマリへ畳み、サブ ID は本文中に残して grep 参照可能性を維持する（2026-07-09 全完了セクションへ適用済み）。
> **2026-07-09 カテゴリ制へ再編**: 時系列の追記順をやめ、「①アプリ機能 / ②設計・アーキテクチャ・コード品質 / ③開発プロセス・ツーリング / ④リリース準備」の 4 カテゴリに整理。各カテゴリ内は未完・バックログを先頭、完了フェーズは番号順（番号なしセクションは日付順）に置く。既存セクションの見出しテキストは他 doc からの名指し参照のため変更していない。新規セクションは該当カテゴリへ追加する。
> **フェーズ番号の採番は終了**（2026-07-09、フェーズ 18 が最後）: 新規セクションは番号を振らず「テーマ名（起票日）」とする。既存のフェーズ番号・サブ ID（15-A / 17-D / B-4 等）は docs・コードコメント・commit メッセージから 270 箇所以上参照されている**不変の参照 ID** として維持する（並び順の意味はもう持たない）。

---

## 凡例

| 記号 | 意味 |
|------|------|
| `[ ]` | 未着手 |
| `[~]` | 進行中 |
| `[x]` | 完了 |
| `[-]` | 取り下げ |

---

## カテゴリ 1: アプリ機能

### 未完・バックログ

#### 広告導入: AdMob ネイティブ広告（2026-07-14 起票）

> 収益化のため AdMob ネイティブ広告を 4 面（カフェ詳細 / マップ検索ドロップダウン / コーヒー記録タブ下部固定 / 分析タブ下部固定）+ ATT フロー（既存同意オンボーディング直後・拒否時 NPA）で導入する。**仕様の正は requirements.md §11**（2026-07-14 grilling で確定）。iosApp View 層完結・KMP 変更なし。本番ユニット発行前は Google 提供のテスト用ユニット ID で実装・検証を進められる。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: Google Mobile Ads SDK + UMP 導入（SPM）、`Info.plist`（`GADApplicationIdentifier` / `NSUserTrackingUsageDescription`）、`Secrets.xcconfig` 注入経路 | 2026-07-14 完了。v13.6.0（UMP は内部依存で自動リンク）。テスト用 ID フォールバックは `Base.xcconfig`、切替手順は `iosApp/Configuration/README.md` |
| [x] | ios-engineer: ATT プレプロンプト（「広告により無料で提供」説明）→ ATT を既存同意オンボーディング直後に接続。拒否時 NPA 設定 | 2026-07-14 完了。既存ユーザーも UserDefaults フラグで 1 回到達（implementation_note 2026-07-14） |
| [x] | ios-engineer: 共通ネイティブ広告コンポーネント 2 種（インライン用 / 下部固定用）。ロード失敗・オフライン時は枠ごと畳む。`maxAdContentRating = G`。「広告」ラベル / AdChoices 表示 | 2026-07-14 完了。`iosApp/iosApp/Ads/`。mediaView 非表示テンプレート（implementation_note 2026-07-14） |
| [x] | ios-engineer: 4 面配線 — カフェ詳細（情報系の後・記録の前）/ 検索ドロップダウン（3 件目の後・結果 3 件未満は非表示）/ コーヒー記録タブ（下部固定、FAB を広告の上へ）/ 分析タブ（下部固定） | 2026-07-14 完了 |
| [x] | 親: 検証（verify-kmp-ios、xcodebuild override 無し）+ Places データをターゲティングに渡していないかレビュー + implementation_note 記録 + commit | 2026-07-14 完了。override 無し BUILD SUCCEEDED + Gradle BUILD SUCCESSFUL 確認。Ads/ に Places 参照なし（コメントのみ）・素の Request + NPA フラグのみ確認 |
| [x] | ios-engineer: **全面バナー化への再実装**（MediaView 必須判明による再編、requirements §11 改訂済み）— NativeAd 系 4 ファイル撤去、下部固定 2 面 = アンカーアダプティブバナー / インライン 2 面 = インラインアダプティブバナー（maxHeight 制限）、テスト用ユニット ID をバナー用に差し替え | 2026-07-14 完了。親再検証済み（build + Places 混入なし）。設計判断は implementation_note 2026-07-14 バナー再実装エントリ |
| [ ] | ユーザー: AdMob アカウント作成・アプリ登録・**バナー**広告ユニット **2 つ**発行（カフェ詳細 / マップ検索）→ `Secrets.xcconfig` へ本番 ID 設定 | コード外の準備。2026-07-16 の 11-3 撤去で 4 → 2 ユニットに縮小 |
| [ ] | ユーザー: AdMob アプリと Firebase プロジェクトのコンソールリンク（任意だが公式強推奨。Analytics に広告収益イベントが流れる） | コード変更不要 |
| [x] | ユーザー: シミュレータでテスト広告の表示確認（4 面 / ATT 許可・拒否の両パス / ロード失敗時に枠が畳まれる） | 2026-07-15 完了。位置調整（記録タブ = リスト先頭インライン / 分析タブ = 高さ 90pt 上限）まで確認済み |

#### 記録・分析タブの広告撤去（2026-07-16 起票）

> ユーザビリティレビュー採用分。定着の核となる記録・振り返り 2 画面のバナーはリテンションを削る割に収益が小さいため**一度撤去**（再導入余地は残す — コンポーネントは git 履歴から復元可能）。広告はカフェ詳細 / マップ検索の 2 面に縮小。**仕様の正は requirements.md §11（11-3 = ✕ 撤去、2026-07-16 改訂済み）**。ATT フローは残存 2 面のため維持。プランは `.claude/plans/agile-knitting-fern.md`。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: 記録タブ（`CoffeeListView`）/ 分析タブ（`AnalysisView`）の広告配線削除 + `AnchoredBannerAdView.swift` 削除（分析タブ専用）+ ユニット ID 2 面分の定義削除（`AdUnitIDs.swift` / `Base.xcconfig` / `Info.plist`） | 2026-07-16 完了。撤去 5 識別子の grep 横断点検で残存なし。Configuration/README も 2 面に追随 |
| [x] | 親: 検証（xcodebuild override 無し）+ implementation_note 記録 + commit | 2026-07-16 完了。親が override 無し BUILD SUCCEEDED を再確認。paid-services.md の面数記述も追随。`Secrets.xcconfig` のみ親から読み取り不可（本番ユニット未発行のため該当キー無しの見込み、ユーザー確認推奨） |
| [ ] | ユーザー: シミュレータで確認（記録・分析タブに広告なし / カフェ詳細・マップ検索は従来どおり / ATT プレプロンプト維持） | |

#### 共有カード画像生成（2026-07-16 起票）

> ユーザビリティレビュー採用分（外向きの共有回路の新設）。記録詳細から 4:5（1080×1350px）のカード画像を生成し share sheet で共有。**仕様の正は requirements.md §2 2-12**（可変レイアウト 1 テンプレート / メモ・タグ非掲載 / ライトテーマ固定、2026-07-16 確定）。既存 `TastingRadarChart` を再利用、ImageRenderer は本リポジトリ初使用。iosApp View 層完結・KMP 変更なし。プランは `.claude/plans/agile-knitting-fern.md`。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: `ShareCard/` 新設（`CoffeeShareCardView` = 360×450pt 可変レイアウト / `ShareCardRenderer` = ImageRenderer scale 3 + ライト固定 + 一時 PNG / `ShareCardSheet` = プレビュー + ShareLink）+ `CoffeeDetailView` ツールバーに独立共有アイコン | 2026-07-16 完了。`TastingRadarChart` / `StarRatingView` / `PhotoFileStore` は無改変で再利用。カードの roastLevel はローカライズ表示（本体 Form と非対称 — implementation_note 2026-07-16） |
| [x] | 親: 検証（xcodebuild override 無し）+ implementation_note 記録 + commit | 2026-07-16 完了。親が override 無し BUILD SUCCEEDED を再確認。設計判断 2 エントリを implementation_note に記録 |
| [ ] | ユーザー: シミュレータで確認（写真あり / なし・テイスティングあり / なし・未評価・セルフ抽出の各記録で崩れない / ダーク端末でもカードはライト配色 / share sheet から画像が渡る） | |

#### 分析タブ「抽出方法の内訳」の横棒化（2026-07-16 起票）

> ユーザー報告「抽出方法の文字列が被って読めない」。`brewMethodSection` が縦棒（x=抽出方法ラベル）のため、方法数が増えると X 軸ラベルが重なる。焙煎度の内訳と同じ横棒（x=件数、y=抽出方法）に変更する。高さは項目数 × 32pt の可変。iosApp View 層完結・KMP 変更なし。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: `AnalysisView.brewMethodSection` を横棒 BarMark 化（焙煎度セクションの軸構成を踏襲） | 2026-07-16 完了。データ順は `byBrewMethod`（件数降順）のまま = 最多の方法が最上段 |
| [x] | 親: 検証（xcodebuild override 無し）+ commit | 2026-07-16 完了。ios-engineer が override 無し xcodebuild BUILD SUCCEEDED（error 0 件）を確認済み |
| [x] | ユーザー: シミュレータで表示確認（ラベル被りなし / 件数軸グリッド） | 2026-07-16 ユーザー確認完了 |

#### 分析タブ「あなたの傾向」の再生成抑止（2026-07-16 起票）

> ユーザー報告「分析タブに遷移するたびに『あなたの傾向』が再計算されてそう。一度計算したらアプリ利用中は保持したい」。原因は `AnalysisViewModel.onAppear()` が無条件に `observeJob` をキャンセル・再購読し、Flow の再 emit で `launchInsightGeneration` が毎回走ること（VM 自体は `AppState` でアプリ生存期間保持されており、購読を張り直す必要がない）。修正は commonMain のみ: ① `onAppear()` は購読中なら no-op、② 同値 stats の再 emit では要約を再生成しない。記録の追加・変更時は従来どおり再生成される。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `AnalysisViewModel.onAppear()` の購読中ガード + 同値 stats での insight 再生成スキップ + commonTest 追加 | 2026-07-16 完了。`AnalysisViewModelInsightRegenerationTest` 3 件新規（計 22 件 green）。公開 API 変更なし・iOS Bridge 追随不要 |
| [x] | 親: verify-kmp-ios 再検証 + commit | 2026-07-16 完了。testAndroidHostTest + iosSimulatorArm64Test（analysis 実行確認）+ assembleSharedLogicXCFramework すべて BUILD SUCCESSFUL。判断は implementation_note 2026-07-16 |
| [x] | ユーザー: シミュレータで確認（タブ往復で「傾向を分析中…」が再表示されない / 記録追加後は再生成される） | 2026-07-16 ユーザー確認完了 |

#### コーヒー記録の削除動線 3 種（2026-07-16 起票）

> 要件 2-3「CoffeeRecord の削除」の動線整備。リストスワイプ削除は実装済み（確認なし即削除、維持）。追加するのは **リスト長押し contextMenu（編集 + 削除）** と **詳細右上 Menu の削除**。確認ダイアログは詳細・長押しのみ（2026-07-16 ユーザー決定、Undo なし）。詳細からの削除は `CoffeeDetailViewModel.UIState.isDeleted` フラグで pop 通知（`coffee == null` 検知は同期削除の「見つかりません」表示用に温存）。プランは `.claude/plans/starry-greeting-bird.md`。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `CoffeeDetailViewModel` に `onAppear(coffeeId, userId)` / `onDeleteTapped()` / `UIState.isDeleted` 追加 + commonTest 新設 | 2026-07-16 完了。commonTest 5 件 green（Android host + iosSimulatorArm64 は親実行） |
| [x] | ios-engineer: 詳細 Bridge / View（削除 Menu + confirmationDialog + dismiss + 写真物理削除）、リスト contextMenu（編集 sheet + 削除 dialog） | 2026-07-16 完了。swipeActions 無変更 |
| [x] | 親: verify-kmp-ios 再検証 + implementation_note 記録 + commit | 2026-07-16 検証完了。全モジュール 2 ターゲットテスト green + XCFramework link + override 無し xcodebuild BUILD SUCCEEDED を親確認。implementation_note 2026-07-16 記録済み |
| [x] | ユーザー: シミュレータで 3 動線 + スワイプ退行なし確認 | 2026-07-16 ユーザー確認完了 |

#### マップ「好み一致」チップのタップ対応（2026-07-16 起票）

> ユーザー報告「好み一致タグをタップしても何も起きない」。現状は静的凡例チップ（`TagLegendChip`、意図的にインタラクションなし）だが、隣のタップ可能チップと同じ見た目で誤解を招く。**「保存済み」チップと同じ操作体系に変更する**（2026-07-16 ユーザー決定）: タップで強調 ON + 好み一致カフェ一覧シート表示、強調中の再タップは強調解除のみ。行には推薦理由サマリを表示し、行タップでカフェ詳細へ push。iosApp View 層完結・KMP 変更なし。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: 「好み一致」チップを `TagLegendChip` → `TagChip` 化（強調トグル + 一覧シート、保存済みパターン踏襲）+ `RecommendedCafeListSheet` 新設 + 強調中の他ピン減光 | 2026-07-16 完了。`TagChip` に `tint` パラメータ追加（好み一致のみ `.pink`）。保存済み強調と排他 |
| [x] | 親: verify-kmp-ios で再検証 + implementation_note 記録 + commit | 2026-07-16 完了。override 無し xcodebuild BUILD SUCCEEDED を親確認。implementation_note 2026-07-16 + lessons 2026-07-16（型チェッカ誤誘導）記録済み |
| [x] | ユーザー: シミュレータで挙動確認（タップ → シート / 再タップ → 解除 / 行タップ → 詳細 / 減光） | 2026-07-16 ユーザー確認完了 |

#### 分析タブ可視化改善: 焙煎度チャート + テイスティングレーダー（2026-07-13 起票）

> 分析タブの可視化レビューから 2 件を採用（プラン承認済み）。① 焙煎度チャートを件数降順・単色縦棒 → **全 8 段階を焙煎順（浅→深）の横棒 + アクセント基準のブラウン明暗ランプ**に変更（`byRoastLevel` の KMP 契約は件数降順のまま、Swift 側で表示用マージ）。② テイスティング 5 軸の横棒を **カスタムレーダーチャート**（`Canvas`/`Path`、Swift Charts 非対応のため）に置き換え、各軸ラベルに平均値を添える。iOS のみで完結（KMP 変更なし）。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: `roastLevelSection` を全 8 段階・焙煎順横棒 + 浅→深ランプ化 | 2026-07-13 完了。`byRoastLevel` 空ならセクション非表示は従来どおり |
| [x] | ios-engineer: `TastingRadarChart.swift` 新規 + `tastingAveragesSection` 置き換え | 2026-07-13 完了。ドメイン非依存の `RadarChartAxis` 設計 |
| [x] | 親: 検証（xcodebuild override 無し）+ implementation_note 記録 + commit | 2026-07-13 完了。Gradle タスク実行 + BUILD SUCCEEDED を親再検証 |
| [ ] | ユーザー: シミュレータで表示確認（焙煎順 + ランプ / レーダー描画 / ダークモード / VoiceOver） | ビルド成功 ≠ 修正完了 |

#### カフェ詳細 Places 写真の段階読み込み（2026-07-13 起票）

> Photo Media API のコスト削減（paid-services.md）。現状はヘッダー表示で先頭 6 枚を一括読み込み → 初期 3 枚 + 「さらに表示」ボタンで 3 枚ずつ追加、上限 10 枚に変更する。iOS のみ（`CafePhotoHeader.swift`）。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `CafePhotoHeader` を段階読み込み化（初期 3 / +3 ずつ / 上限 10）→ ios-engineer | 2026-07-13 実装完了・override なしビルド成功。自分の記録写真は対象外（従来どおり全件表示） |
| [x] | paid-services.md の Photo Media 行を追随更新（親） | 2026-07-13 完了 |
| [ ] | ユーザー: シミュレータ / 実機で表示確認 | ビルド成功 ≠ 修正完了 |

#### 周辺カフェピンのノイズ除去（名前フィルタ + ネガティブキャッシュ、2026-07-13 起票）

> Apple `.cafe` 誤分類の非カフェ（法人本社・コンカフェ・ガールズバー等）が周辺ピンに混入し、タップしても Places 解決で「該当なし」になる（17-B「表示＝解決可能」原則違反）。対策: ① 除外キーワードによる名前フィルタ（iOS）+ ② 解決「該当なし」POI のローカル記録・非表示化（ネガティブキャッシュ）。後者のため `UIState.poiLookupError` を `PoiLookupError(message, isNotFound)` に型変更（通信エラーはキャッシュ対象外にするための区別）。設計判断は implementation_note 2026-07-13 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `MapViewModel.UIState.poiLookupError` を `PoiLookupError` data class 化 + テスト追随 | 2026-07-13 完了。`shared/feature/map` のみ |
| [x] | 親: `:shared:feature:map:iosSimulatorArm64Test` 再検証 | 2026-07-13 全緑 |
| [x] | ios-engineer: Bridge 追随 + 名前フィルタ + `ApplePoiNegativeCache`（UserDefaults / 30m+名前一致 / 上限 300 FIFO / TTL なし）+ MapTabView 配線 | 2026-07-13 完了。除外キーワード 16 語は `MapTabView.excludedApplePoiNameKeywords` に一元化 |
| [x] | 親: 統合検証（verify-kmp-ios）+ implementation_note 記録 + commit | 2026-07-13 完了。①testAndroidHostTest / iosSimulatorArm64Test 全緑 ②XCFramework 成功 ③xcodebuild override 無しで BUILD SUCCEEDED |
| [ ] | ユーザー: シミュレータ / 実機確認（キーワード POI 非表示 / 該当なしタップ → ピン消滅・再パンでも非表示 / 通信エラーではピンが消えない） | ビルド成功 ≠ 修正完了 |

#### 名前フィルタの Remote Config 外部注入（2026-07-13 起票）

> 上記ノイズ除去の除外キーワード 16 語（`MapTabView.excludedApplePoiNameKeywords` ハードコード）を Firebase Remote Config で配信し、リリースなしで追加・削除できるようにする。キー `map_poi_excluded_name_keywords`（JSON 文字列配列）。**remote はハードコードのデフォルトを置き換える**（和集合ではない — コンソールの見た目と実挙動を一致させる）。remote 未取得・parse 失敗時は bundled デフォルトにフォールバック（現行挙動と同一）。Remote Config は無料でコスト構造は不変。iOS のみで完結（KMP 変更なし）。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: SPM に FirebaseRemoteConfig 追加 + キーワードプロバイダ実装 + `MapTabView` 参照差し替え + 起動時 fetchAndActivate | 2026-07-13 完了。`ApplePoiFilterConfig`。空配列は成功扱い（フィルタ一時無効化に使える） |
| [x] | 親: 検証（xcodebuild override 無し）+ docs 更新（implementation_note / paid-services 棚卸し行）+ commit | 2026-07-13 完了。PrivacyInfo は SDK 同梱マニフェスト確認でアプリ側変更不要、app-store-metadata 6.3 に SDK 行追加 |
| [ ] | ユーザー: Firebase コンソールで `map_poi_excluded_name_keywords` パラメータ作成 → コンソール変更が次回起動で反映されることを実機確認 | パラメータ未作成でも bundled デフォルトで動作する |

#### フェーズ 6（任意 / 後続）

> 旧行の縮約（2026-07-09）: Android 実装は取り下げ（リリース対象外）/ エクスポートは 15-E-2 へ統合 / buildCafe バグは専用セクション「フェーズ 6 既知バグ」で解消済み。詳細は git 履歴。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | 検索（キーワード）の高速化（SQLDelight FTS） | 一覧検索そのものはフェーズ 15-C（まずはメモリ内 filter）。FTS はデータ量で遅くなったら |
| [ ] | 同一カフェの集計表示 | |
| [ ] | Widget / ホーム画面ショートカット | |

#### フェーズ 11: コーヒー記録テンプレート / カスタムフィールド ※保留

> 起票 2026-06-29、同日**全保留**（11-A 記録テンプレート / 11-B カスタムフィールドの 2 機能）。優先度が上がった時点で再検討する。当時のタスク分解は git 履歴参照（再開時は data-model 設計から仕切り直す想定）。

#### フェーズ 12: コミュニティ / データ共有基盤

> 起票 2026-06-29。個人の記録を（同意を得た上で）集合知として活用する基盤。**12-A** データ共有同意フロー（`DataConsentOnboardingView` + Settings トグル + `AuthAccount.analyticsConsent`、implementation_note 2026-06-30。残タスクのプライバシーポリシー更新はカテゴリ 4「リリース前バックログ」へ移管）/ **12-B** コーヒー豆ナレッジベース（`BeanProfile` read-only + origin/processings ファジーマッチ、data-model.md §1.8。seed 投入はカテゴリ 4「BeanProfile 初期データ整備」）/ **12-C** 個人好みとの突合・言語化（`PreferredBeanTraitsUseCase` → 分析タブ、implementation_note 2026-07-01）まで完了。12-D はサーバー側インフラが前提で保留（下記）。

##### 12-D: 協調フィルタリング（B-4 将来版 / 9-6）

> **保留（2026-07-12 縮約）**: サーバーサイド基盤（インフラ選定・コスト見積もり）が前提で未着手。設計方針の正は requirements.md 9-6（✕ 将来）/ implementation_note 2026-06-22 Future Direction。`CafeRecommendationProvider` をリモート実装で差し替え可能な設計は B-4 で済み。フェーズ 8 の将来 9-6 行は本セクションへ統合済み（2026-07-09）。当時のタスク分解は git 履歴参照 — 優先度が上がったらインフラ選定から仕切り直す。

### 完了（フェーズ番号 → 日付順）

#### フェーズ 1: ドメインモデルとローカル DB

> 完了（2026-06-02）: 旧 Visit 系ドメインモデル + SQLDelight スキーマ + DriverFactory（expect/actual）+ Mapper + commonTest。モデルは 2026-06-19 のフェーズ 7 で CoffeeRecord 主体に全面置換済み。

#### フェーズ 2: 認証と Firestore 接続

> 完了（2026-06-04〜06-07）: Firebase プロジェクト作成・匿名 Auth・Firestore（asia-northeast1）・オフライン永続化・iOS Firebase SPM 導入・`AuthRepository` / remote 合成構成の確立・Security Rules のリポジトリ管理化 + デプロイ・シミュレータでの書き込み実体確認まで。当時の Visit 子コレクション同期は 2026-06-19 の単一ドキュメント化で置換済み。Storage は 2026-06-10 に採用見送り（写真は端末ローカル）。

#### フェーズ 3: iOS UI（MVP）

> 完了（2026-06-09〜06-11）: AppContainer 起動配線・一覧 / 詳細 / エディタの 3 画面 + Bridge・StarRatingView・写真ピッカー（Documents フラット保存 + メタデータ永続化）・Preview 19 件。画面群は 2026-06-19 のフェーズ 7 で Coffee* 系にリネーム・全面改訂済み。

#### フェーズ 3.5: モジュール分割 (2) — feature レイヤー & Android 検証

> 完了分（2026-06-08〜06-11）: `shared/framework` 作成・feature モジュール切り出し（visit-list / detail / editor、後の coffee-*）・androidApp での Compose 1 画面検証実装（`CoffeeListScreen`）。

#### フェーズ 4: Places API（カフェ検索）

> 完了（2026-06-11〜06-15、スライス 1〜7）: `shared/data-places` 新設（Places New v1 / Ktor / DTO / `CafeRepository`）→ iOS 検索 UI + xcconfig キー注入 → CoreLocation + Nearby + Details → Photo Media 都度取得 → `feature/{cafe-search,map,cafe-detail}` 切り出し → TabBar 化 + カフェ詳細統合 → Apple Maps POI タップ動線。設計判断は `implementation_note.md` の 2026-06-11 / 06-15 各エントリ参照。検索 UI・タブ構成はその後 2026-06-30（検索タブ廃止・マップ内検索）で再編済み。

#### フェーズ 5: 仕上げ

> 完了分（2026-06-16〜06-17）: 設定画面（テーマ / ライセンス）・アカウント機能一式（Apple アップグレード / サインアウト / 削除）・エラートースト共通化・App Icon / Launch Screen・App Store メタデータ下書き（`app-store-metadata.md`）。判断は implementation_note 2026-06-16 / 06-17 エントリ。

#### フェーズ 8: 分析タブ（コーヒー傾向分析）

> 完了分（2026-06-19〜06-22）: 3 階層構成（集計 = KMP 決定論 / 解釈 = iOS Foundation Models）。**A-1〜A-4** `CoffeeStats` 集計 + `AnalysisViewModel` + Swift Charts + FM 要約 / **B-1〜B-1d** `FavoriteSignals` 実体化（ペルソナ検証で偽陽性を実測 → effect-size δ=0.20 + n 連動 z ゲートでカテゴリ FP 9.3% まで改善、implementation_note 2026-06-22）/ **B-2 / B-3** 対話 Q&A v1・v2（`SearchCoffeeRecordsTool`、実機 round-trip 確認済み）/ **B-4** 味覚一致カフェのマップ強調（`CafeRecommendationProvider` 境界）。将来 9-6（協調フィルタリング）は 12-D へ統合（2026-07-09）。

#### フェーズ 9: テイスティング 5 要素（甘味/ボディ/酸味/風味/後味）

> 完了（2026-06-20）: `CoffeeRecord.tasting` を全レイヤー（domain / data-local / core / feature / data-firebase / iOS UI / 分析）に追加。当初の各要素独立 nullable はフェーズ 9.1 で all-or-nothing に即日変更。統合経緯は implementation_note 2026-06-20 エントリ。

#### フェーズ 9.1: テイスティングを all-or-nothing 化（5 要素必須）

> 完了（2026-06-20）: `TastingScores` の 5 フィールドを非 null 化 + `CoffeeRecord.tasting: TastingScores?` で「型で partial を表現不可能に」。UX は `+` で 5 スライダー一括表示。KMP → iOS の 2 段 dispatch で完遂。仕様は `data-model.md` §1.1a。

#### フェーズ 10: マップ拡充

> 完了（2026-06-29〜06-30）: **10-A** ピン再設計（36pt + 訪問回数バッジ、3 種ビジュアル体系）/ **10-B** Places 追加フィールド（営業時間・電話・価格帯・評価 → CafeDetail 拡充。永続化なし）/ **10-C** 検索結果のマップオーバーレイ（AppState 経由・明示ボタン方式）/ **10-D** タグフィルター（`CoffeeRecord.tags` + エディタ入力 + マップチップ）。判断は implementation_note 2026-06-29 / 06-30 各エントリ。

#### フェーズ 13: 自然言語好み検索（逆方向変換応用）

> 完了（2026-06-30）: iOSDC 逆方向 PoC（`TastePreferenceExtractor`）を実用昇格。**13-A** `CoffeeRecordFilter.tastingMin/Max` + `TastePreference→Filter` 変換 / **13-B** Q&A への `SearchByTasteProfileTool` 追加 + 「好みで記録を探す」専用 UI / **13-C** マップの「好みで絞り込む」チップ（非マッチピン半透明化）/ **13-D** 検索バーの ✨ ボタン（`searchKeywords` 補完クエリ）。FM 部分は iOS 限定、非対応端末は導線非表示。判断は implementation_note 2026-06-30 13-x 各エントリ。**実機確認（Apple Intelligence 対応端末）はユーザー作業**。

#### フェーズ 14: マップ検索の使い勝手改善（表示範囲ピン表示）

> 完了分（2026-07-01）: 「このエリアを検索」ボタン方式（自動再検索なし）+ テキスト検索の全件ピン + 検索モード化（フィルタチップ非表示・結果リストを検索バー直下に統合）。しきい値（中心移動 30% / 半径比 1.5x）等の判断は implementation_note 2026-07-01 フェーズ 14 エントリ。Places New は 1 回最大 20 件の仕様上限あり。

#### フェーズ 15: 記録・店探しループの強化（2026-07-06 起票）

> 完了（2026-07-06〜07-09）: ゼロベース設計レビュー（記録できる / おいしい店を探せる / 好みを見つけられる、の 3 条件）で洗い出したギャップの採用分。要件は requirements.md §10 / §2 2-8〜2-11 / 6-1 / §9 9-7・9-8 / 7-4。
>
> - **15-A** 行きたい店リスト: `SavedCafe`（placeId 自然キー、data-model.md §1.9 / §2.4 / §4.3、migration 3.sqm）+ マップ 4 種目ピン（indigo）+ 一覧ハーフシート。2026-07-06 ユーザー目視確認済み
> - **15-B** 記録摩擦の低減: エディタの現在地カフェサジェスト（許可済みのみ one-shot）+ コーヒー名デフォルト値 + `Mode.Duplicate`（詳細画面「これをもとに記録」）
> - **15-C** 一覧検索 + 月別グルーピング: UIState を `sections: List<MonthSection>` に置換（name / cafe.name / notes のメモリ内 filter + `.searchable`、表示文字列は iOS 生成）
> - **15-D** 分析空状態プログレス: `AnalysisReadiness` 派生フィールド（閾値は既存定数参照・ハードコードなし）+ プログレスカード。`hasAnySignal` の単一ソース化まで完了（2026-07-09）
> - **15-E-1** 抽出レシピ `brewRecipe: String?`（migration 4.sqm、data-model.md §1.1）/ **15-E-2** JSON エクスポート（`ExportCoffeeRecordsUseCase` + `ShareLink`。フェーズ 6 旧行を統合）/ **15-E-3** 未経験豆の探索提案（`SuggestUnexploredBeansUseCase`、data-model.md §1.7a）
>
> 判断は implementation_note 2026-07-06〜07-07 の 15-x 各エントリ、テスト教訓（Native cancel drain / UIState 破壊的変更の波及）は lessons 2026-07-06〜07-07。

#### フェーズ 16: マップ / タブ UI/UX 改善（2026-07-07 起票）

> 完了（2026-07-07、ユーザー目視確認済み）: ユーザー指摘 3 課題（保存済み導線が遠い / タグの統一感なし / カフェ情報が弱い）への対応。保存済み導線のフィルタチップ統合 / マップ下部カード + `CafeDetailView` の情報強化（写真帯・評価・`Cafe.userRatingCount` 揮発フィールド追加 = data-model.md §1.2）/ 共通 `TagChip` + 色セマンティクス体系化（AccentColor #8B5A2B。**色表の正は ui-ux-guidelines.md**）/ `CafeDetailViewModel` の条件付き Places Details リフレッシュ / `MapViewModel.onCafeSaveToggled`。判断（保存強調を UIState に置かない・pink 化対象の線引き等）は implementation_note 2026-07-07 フェーズ 16 エントリ。

#### フェーズ 17: 周辺カフェを自前ピン化（Apple 検索由来・ズーム依存の解消）

> 完了（2026-07-07〜07-08、commit `c6b0e90` / `db4cee3` / `cbe3032` / `0fca1af` / `e087980`）: Apple 標準 POI ラベル（表示密度がズームで内部決定・制御不能）への依存をやめ、`MKLocalPointsOfInterestRequest` で表示範囲のカフェを常時見える自前低強調ピンとして描画（Places 課金なし。デバウンス + ズームゲート 3000m + 座標近接 40m 重複排除、標準 cafe ラベルは `.excluding` で非表示）。タップ解決は目視で発覚した誤同定 3 件を経て最終形へ:
>
> - **17-B** 表示と解決の対象集合ズレ（cafe 型フィルタ × 名前テキスト検索）→ 座標アンカー `searchNearby` へ
> - **17-C** 最近傍が別店を拾う → 名前一致優先 + 最近傍フォールバック
> - **17-D** 真因 = Google 型フィルタそのもの（Apple の cafe 分類と食い違い候補にすら入らない）→ **型フィルタなし `searchByNameNear`（名前 + 位置バイアス）→ タップ座標最近傍（名前一致優先）、見つからなければ「該当なし」**
>
> 判断は implementation_note 2026-07-07 フェーズ 17 エントリ、教訓（表示⇄解決の集合ズレ / 同系統 2 回失敗で再計画）は lessons 2026-07-08。最終目視は verification-checklist.md「マップ / カフェ探索」。

#### フェーズ 6 既知バグ: エディタ buildCafe の Edit/Duplicate 分岐（2026-07-08 着手）

> 完了（2026-07-08）: セルフ抽出記録（元 cafe = null）の編集 / 複製で手入力カフェ名が無言で捨てられるバグ（`CoffeeEditorViewModel.buildCafe`）を、cafe 採用の状態ベース 3 段判定への一本化（mode 分岐削除・手入力は新規 UUID 採番）で修正 + 簡素化。回帰テスト 2 件追加、iOS / Android green。判断は implementation_note / lessons 2026-07-08。

#### 産地シノニム正規化 OriginNormalizer（2026-07-08 着手）

> 完了（2026-07-08）: 「Ethiopia」「イルガチェフェ」→「エチオピア」の名寄せを `object OriginNormalizer`（trim → lowercase → シノニム辞書完全一致、辞書外は素通し）で決定論のまま実現し、全 origin 正規化ポイント 5 箇所に適用（ベクトル検索は過剰と判断し見送り）。domain 170 件 green（iOS / Android）+ 統合ビルド成功。仕様反映は data-model.md §1.6〜§1.8、経緯は implementation_note 2026-07-08、複合語×辞書のすれ違いは lessons 2026-07-08。

---

## カテゴリ 2: 設計・アーキテクチャ / コード品質

### 未完・バックログ

#### docs / 設計判断バックログ（後回し可）

> 2026-06-16 の docs 全体精査で洗い出した中・低優先の項目。いずれも今すぐ直さないと害が出る種類ではない。必要になったフェーズで着手する（経緯は [`tasks/lessons.md`](./tasks/lessons.md) 2026-06-16 エントリ）。
> 完了済み（2026-07-09 縮約）: B-3（07-01 requirements の API キー記述修正）/ B-5（07-08 CI グリーン確認）/ B-6（07-07 Persona テストの Native `.format` 置換で domain iOS テスト回復）/ B-7（07-09 `AccountViewModelTest` の `vm.clear()` + drain）/ D-2（07-04 architecture 書き込みフロー現行化）/ E-1（07-09 フェーズ 5.2 で成立）。F-1 はカテゴリ 4「リリース前バックログ」へ移管。詳細は git 履歴 / lessons。
> 追記（2026-07-12 実態突き合わせで解消確認）: B-2（「主要 VM が未テスト」が陳腐化 — 8 VM 中 7 つに commonTest あり、規約と実態の乖離は解消。未テストは `CoffeeDetailViewModel` のみ）/ C-1（「core 暫定置き場」運用は消滅 — 全 VM が最初から `shared/feature/*` 配下に配置済み）。

| 状態 | ID | タスク | 着手目安 / 備考 |
|------|----|------|----------------|
| [ ] | B-1 | マルチデバイス書き込みの競合解決方針を明文化（`updatedAt` での last-writer-wins 等）。現状 remote→local は `INSERT OR REPLACE` で世代比較なし | 複数端末同期（要件 7-3、優先度○）を実装・検証する段階。単一端末では実害なし |
| [x] | B-4 | `rating=0.0`=「未評価」の暗黙 sentinel を解消し、`CoffeeRecord.rating` を **nullable 化する**（2026-07-12 ユーザー決定） | 2026-07-13 完了。あわせて未評価のまま保存可に変更（従来はエディタで評価必須 = requirements と矛盾していた）。migration 5（0.0→NULL、JVM / NativeSqliteDriver 両方でテスト実証）+ Firestore は読み側で legacy 0.0 正規化。requirements §未決事項も消し込み済み。判断は implementation_note 2026-07-12、SQLDelight migrate の off-by-one は lessons 2026-07-13。**シミュレータ目視（未評価保存 → 表示 → 分析除外 → 既存 DB の migration）はユーザー作業** |
| [ ] | D-1 | `ui-ux-guidelines.md` の写真サムネ記述に「Places 写真は永続キャッシュ禁止（規約）、ローカル写真とは読み込み方針が違う」旨を補足 | 任意 |

### 完了

#### フェーズ 2.5: モジュール分割 (1) — 基盤レイヤー

> 完了（2026-06-08、PR1〜PR3）: `build-logic/convention`（`kmp.library` / `kmp.feature` / `android.library`）新設 → `shared/{core,domain,data-local,data-firebase}` 切り出し → `shared/framework` umbrella 化 + 旧 `sharedLogic` 完全削除 + CI コマンド差し替え。現行構成は `settings.gradle.kts` と `architecture.md` を真とする。

#### フェーズ 7: コーヒー記録主体への再設計（Visit → CoffeeRecord）

> 完了（2026-06-19）: 集約ルートを `Visit` → `CoffeeRecord` へ転換（クリーンブレイク・データ移行なし）。docs 全面改訂 → KMP（domain / core / data-local / feature リネーム / framework）→ data-firebase Android → iOS UI の 3 段 dispatch で完遂。確定仕様は `data-model.md`、経緯は implementation_note 2026-06-19 エントリ。

#### docs 棚卸し（2026-07-02）

> 完了（2026-07-02）: 実装と docs の齟齬 4 件（data-model のフェーズ 10 / 12-C 追随、kmp-bridge の export 記述、app-store-metadata の CoffeeRecord 化、implementation_note サマリ全面更新）+ 旧モデル例文・runCatching 例文の是正 + CLAUDE.md / architecture.md の feature 列挙修正。経緯は implementation_note 2026-07-02 エントリ。
>
> 残りの低優先残件のうち ui-ux-guidelines の Visit 系旧用語は 2026-07-04 に消し込み済み。未着手で残るのは FAB 等の新 UI パターン未記載（ui-ux-guidelines）、backlog ID「B-4」と Phase B-4 の名前衝突など。必要になったら設計判断バックログへ起票する。

#### iosApp コードレビュー指摘対応（2026-07-03）

> 完了分（2026-07-03）: 高優先 5 件を修正 — #1 CafeDetail の `onDisappear` observation 停止 / #2 アカウント処理完了待ちの二相ポーリング化 / #3 `bootstrap()` 再入ガード / #4 同意オンボーディングの timing バグ（観測される状態の公開を最後に）/ #5 写真物理削除の順序逆転。判断は implementation_note 2026-07-03 iosApp エントリ、教訓は lessons.md 2026-07-03。

#### shared コードレビュー指摘対応（2026-07-03）

> 完了分（2026-07-03）: 高優先 3 件を修正 — #1 `startSync` のスナップショット reconciliation（リモート削除のローカル伝播）/ #2 エディタの `selectedCafe` 保持（座標・photoReferences 引き継ぎ）/ #3 FOREIGN KEY の本番有効化 + 掃除 migration（iOS テストの赤→緑で実証）。判断は implementation_note 2026-07-03 shared エントリ。

#### implementation_note.md の棚卸し・要約（2026-07-04）

> 完了（2026-07-04）: 2160 行 / 297KB → 691 行 / 79KB（約 120 → 64 エントリ）。陳腐化削除・シリーズ統合・冗長圧縮・見出し統一。外部参照 4 系統の生存確認済み。経緯は implementation_note 2026-07-04 棚卸しエントリ。

#### コードレビュー指摘対応（2026-07-08）

> 完了（2026-07-08、commit `f6a322b`）: 高優先 2 件を修正 — ① iOS `CoffeeFirestoreMapper.toDocument` の `tags` 書き出し漏れ（iOS 発のタグが同期で永久消失）→ 対称化。② ローカル DB の enum 復元 `valueOf` が未知文字列 1 行で `observeAll` Flow 全損 → `entries.firstOrNull` + フォールバックに変更、回帰テスト 3 本。両パターンと横断点検は lessons.md 2026-07-08。

---

## カテゴリ 3: 開発プロセス・ツーリング

### 未完あり

#### サブエージェント定義の改善（2026-07-04）

> 完了分（2026-07-04）: 両エージェント定義を現行構成に更新 + `memory: project`（`.claude/agent-memory/` git 管理）+ 書き込みスコープの PreToolUse フック強制（`validate-write-scope.sh`、テスト 13 ケース green）+ `skills` プリロード（現行ハーネスでは本文非展開のためフォールバック文残置）。判断は implementation_note 2026-07-04 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | 次回の実 dispatch で観察: メモリ運用（リポジトリ内パスへの追記）が定着すること / ハーネス更新後に `skills` プリロードが効くようになったらフォールバック文を削除 | 運用検証 |

#### CLAUDE.md のスリム化と .claude/rules/ 分割（2026-07-04）

> 完了分（2026-07-04）: CLAUDE.md 240 → 131 行。言語別規約を `.claude/rules/`（パススコープ規則）へ分割、モジュール表を `settings.gradle.kts` / `architecture.md` 参照に一本化、lessons の親運用ルール 4 件を昇格。rules のサブエージェント遅延注入は実測確認済み。判断は implementation_note 2026-07-04 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | `/memory` でロード確認（CLAUDE.md 常時 + `shared/**` のファイルを開いた際に kotlin-kmp.md が載ること） | **ユーザー作業**（セッション内で `/memory` 実行） |

### 完了

#### 開発支援: ダミーデータ Scheme

> 完了（2026-06-19）: 専用 Scheme「iosApp (Dummy Data)」（env `SEED_DUMMY_DATA=1`）でローカル DB のみに固定 ID 30 件を冪等 seed / 通常 Scheme で clear。設計判断は implementation_note 2026-06-19 エントリ。

#### 開発支援: エクスポート JSON の Firestore 投入スクリプト（2026-07-13）

> 完了（2026-07-13）: アプリのエクスポート JSON（envelope v1）を `users/{uid}/coffees` へ冪等 upsert する `scripts/seed/seed-coffees.mjs`（開発用）。バリデーション + Firestore 直列化規則への変換（null キー省略 / Timestamp 化 / photos 空化 / userId を `--uid` で付け替え）。`--dry-run` で正常系・異常系とも検証済み。投入の実行はユーザー作業（手順は `scripts/seed/README.md`）。判断は implementation_note 2026-07-13 エントリ。

#### 外部 Skill の導入（2026-07-07）

> 完了（2026-07-07）: [mattpocock/skills](https://github.com/mattpocock/skills)（MIT）から `grilling`（実装前インタビュー）/ `diagnosing-bugs`（診断ループ + HITL）/ `writing-great-skills`（Skill 設計原則）の 3 つを日本語化 + 本プロジェクト調整で `.claude/skills/` に移植し、CLAUDE.md に参照を追記。選定・調整の判断（丸ごと導入不採用の理由含む）は implementation_note 2026-07-07 エントリ。

---

## カテゴリ 4: リリース準備（Firebase / Apple / App Store）

### リリース前バックログ

> 2026-07-09 の再編で新設。App Store 提出前に完了が必須の残タスクを集約する（移管元: 12-A / docs 設計判断バックログ F-1）。提出用の原稿・プライバシー申告・提出前チェックリストは [`app-store-metadata.md`](./app-store-metadata.md) が正。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | プライバシーポリシー更新（記録データをサービス改善に使用する旨の明記） | App Store 提出前に必須 / ユーザー作業。アプリ内リンクの placeholder 差し替えも同時に。12-A から移管（2026-07-09） |
| [x] | **F-1**: `PrivacyInfo.xcprivacy` のアプリ全体 Required Reason API 網羅監査（File Timestamp / System Boot Time / Disk Space 等）。フェーズ 18 では UserDefaults（`CA92.1`）+ テレメトリ集計データ種別のみ宣言済み | 2026-07-12 完了。Swift 側 = UserDefaults のみ（宣言済み）。**`SharedLogic`（K/N ランタイム）が stat 系 6 シンボルをリンク**（`nm -u` 実測）→ FileTimestamp **C617.1** を追加宣言。Boot Time / Disk Space / Keyboard 該当なし、Firebase は SDK 同梱マニフェストで自己申告済み。`plutil -lint` OK。判断は implementation_note 2026-07-12 |
| [x] | 逆変換 PoC 導線（分析タブ最下部の `TastePreferenceConversionView` への NavLink）を本番に含めるか判断する（含める / 設定の開発者向けへ移動 / 削除） | 2026-07-12 ユーザー決定: **本番に含める**。FM 非対応端末では `makeIfAvailable()` ガードで導線非表示をコード確認済み（`AnalysisView.swift`）→ 追加実装なし。判断は implementation_note 2026-07-12 |

### 未完あり

#### BeanProfile 初期データ整備（2026-07-08）

> 完了分（2026-07-08）: seed データ `scripts/seed/bean-profiles.json`（主要産地 38 件・日本語表記統一・flavorNotes 統一語彙 42 語 = data-model.md §3.2）+ 冪等 upsert スクリプト `seed-bean-profiles.mjs` + README。`--dry-run` バリデーション全通過。確定仕様（grilling で親確定）と経緯は implementation_note 2026-07-08 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | ユーザー: サービスアカウント鍵取得 → `node seed-bean-profiles.mjs` で本番投入（`coffeevision-a54aa`）→ 実機確認（分析タブ「好みの豆の傾向」/「試してみては」/ エディタ産地サジェスト。verification-checklist 15-E-3） | 手順は `scripts/seed/README.md`。投入後はアプリ再起動（メモリキャッシュのため） |

#### フェーズ 18: Firebase テレメトリ導入（Crashlytics / Analytics / Performance、2026-07-08 起票）

> 実装完了（2026-07-08）: iOS のみ。**Crashlytics + Performance = 常時収集（同意不要）、Analytics = `analyticsConsent` 同意時のみ**（`Info.plist` で起動時 OFF → `AppState.applyTelemetryConsent` で有効化。IDFA 非依存で ATT 不要を維持）。SPM 3 プロダクト追加 + dSYM アップロード build phase + `.trackScreen` modifier（4 タブ + 主要画面）+ `PrivacyInfo.xcprivacy` 宣言まで実装済み、override 無しビルド成功。全体の Required Reason API 監査は「リリース前バックログ」の F-1。経緯は implementation_note 2026-07-08、プライバシー申告は app-store-metadata.md 6.1/6.3。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | ユーザー: 実機/シミュレータで実挙動確認（Crashlytics テストクラッシュ送出 / Analytics DebugView で consent トグル ON→OFF / Performance トレース / `screen_view` 発火）+ 親が commit | ビルド成功 ≠ 動作確認完了 |

### 完了

#### フェーズ 0: プロジェクト準備

> 完了（2026-06-02〜2026-07-09）: KMP スケルトン初期化 / docs 一式整備 / libs.versions.toml / SKIE 0.10.12 採用 / Firebase 設定ファイル非コミット方針 / CI 整備（PR ごと iOS + Android 必須チェック、2026-07-08 ユーザーがグリーン確認）/ API キー管理（xcconfig + CI の Secrets 復元）/ TestFlight ワークフロー `release-testflight.yml`（workflow_dispatch / ASC API キー + cloud signing、implementation_note 2026-07-07）。**Secrets 5 件（`ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_PRIVATE_KEY`＝App Manager 以上 / `GOOGLE_SERVICE_INFO_PLIST_BASE64` / `PLACES_API_KEY`）の登録 + 初回実行で TestFlight 反映を 2026-07-09 ユーザー確認済み**。

#### フェーズ 5.2: アカウント削除時の Apple トークン失効（E-1）

> 完了（実装 2026-06-24 / 設定 2026-07-09）: App Store ガイドライン 5.1.1(v) 対応。削除時に Apple 再サインイン →（authorization code 取得）→ reauthenticate → `revokeToken` → KMP 削除を iOS がオーケストレーション（キャンセル = 無音中断 / revoke 失敗 = 削除中断。詳細は implementation_note 2026-06-17 アカウント機能エントリ）。前提のユーザー作業（Apple Developer で Sign in with Apple Key（.p8）+ Services ID 作成 → Firebase Apple プロバイダに Services ID / Team ID / Key ID / 秘密鍵の 4 項目登録）も 2026-07-09 完了。実機での削除完走 + revoke 確認は verification-checklist.md（**シミュレータ不可・実機必須**）。
