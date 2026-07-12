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

> 起票 2026-06-29。個人の記録を（同意を得た上で）集合知として活用する基盤。**12-A** データ共有同意フロー（`DataConsentOnboardingView` + Settings トグル + `AuthAccount.analyticsConsent`、implementation_note 2026-06-30。残タスクのプライバシーポリシー更新はカテゴリ 4「リリース前バックログ」へ移管）/ **12-B** コーヒー豆ナレッジベース（`BeanProfile` read-only + origin/processings ファジーマッチ、data-model.md §1.8。seed 投入はカテゴリ 4「BeanProfile 初期データ整備」）/ **12-C** 個人好みとの突合・言語化（`PreferredBeanTraitsUseCase` → 分析タブ、implementation_note 2026-07-01）まで完了。12-D はサーバー側インフラが前提で未着手。

##### 12-D: 協調フィルタリング（B-4 将来版 / 9-6）

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | サーバーサイド基盤設計（GCP Cloud Run / Cloud Functions + Firestore 集計パイプライン） | インフラ選定・コスト見積もりが前提 |
| [ ] | ユーザー間好み類似度計算ロジック設計（コサイン類似度 / ピアソン相関 on `FavoriteSignals` ベクトル） | |
| [ ] | `CafeRecommendationProvider` のサーバーリモート実装（既存ローカル実装と差し替え可能な設計は B-4 で済み）| B-4 の将来 9-6 エントリと連動。フェーズ 8 の将来 9-6 行（implementation_note 2026-06-22 Future Direction）は本行へ統合（2026-07-09） |
| [ ] | iOS: マップ上の好み一致ピン（B-4）を協調フィルタリング結果に差し替え（フラグ制御で A/B 切替可能な設計） | |
| [ ] | 全体データを使った「このカフェを好む人は○○傾向」などのコミュニティ統計を分析タブに追加 | |

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

| 状態 | ID | タスク | 着手目安 / 備考 |
|------|----|------|----------------|
| [ ] | B-1 | マルチデバイス書き込みの競合解決方針を明文化（`updatedAt` での last-writer-wins 等）。現状 remote→local は `INSERT OR REPLACE` で世代比較なし | 複数端末同期（要件 7-3、優先度○）を実装・検証する段階。単一端末では実害なし |
| [ ] | B-2 | ViewModel テスト方針の整理。規約（architecture / coding-conventions）は「VM は runTest でテスト」だが主要 VM が未テスト。規約を実態に合わせるか、テストを足すか決める | CI を本格運用するとき / 新規 VM 追加時 |
| [ ] | B-4 | `rating=0.0`=「未評価」の暗黙 sentinel を仕様化（`CoffeeRecord.rating` を nullable にするか 0 を明記するか）。`VisitedCafe` 集計が 0 を平均除外している | 集計まわりを次に触るとき。現状動作に実害なし。requirements §未決事項にも起票済み |
| [ ] | C-1 | feature ViewModel の「`shared/core` 暫定置き場 → 後で feature module へ git mv」運用の見直し（最初から feature module を作る案） | 次の feature 追加時に再評価 |
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

#### 外部 Skill の導入（2026-07-07）

> 完了（2026-07-07）: [mattpocock/skills](https://github.com/mattpocock/skills)（MIT）から `grilling`（実装前インタビュー）/ `diagnosing-bugs`（診断ループ + HITL）/ `writing-great-skills`（Skill 設計原則）の 3 つを日本語化 + 本プロジェクト調整で `.claude/skills/` に移植し、CLAUDE.md に参照を追記。選定・調整の判断（丸ごと導入不採用の理由含む）は implementation_note 2026-07-07 エントリ。

---

## カテゴリ 4: リリース準備（Firebase / Apple / App Store）

### リリース前バックログ

> 2026-07-09 の再編で新設。App Store 提出前に完了が必須の残タスクを集約する（移管元: 12-A / docs 設計判断バックログ F-1）。提出用の原稿・プライバシー申告・提出前チェックリストは [`app-store-metadata.md`](./app-store-metadata.md) が正。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | プライバシーポリシー更新（記録データをサービス改善に使用する旨の明記） | App Store 提出前に必須 / ユーザー作業。アプリ内リンクの placeholder 差し替えも同時に。12-A から移管（2026-07-09） |
| [ ] | **F-1**: `PrivacyInfo.xcprivacy` のアプリ全体 Required Reason API 網羅監査（File Timestamp / System Boot Time / Disk Space 等）。フェーズ 18 では UserDefaults（`CA92.1`）+ テレメトリ集計データ種別のみ宣言済み | App Store 申請前。Firebase SDK 同梱マニフェストで足りる分を差し引いてアプリ側の残りを確認。設計判断バックログから移管（2026-07-09） |
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
