# CoffeeVision タスク一覧

このファイルは実装タスクのカテゴリ別管理表です。
完了したタスクは `[x]` でチェックし、完了日とコミット / PR を備考列に追記してください。

> 細かい WIP メモは `docs/tasks/lessons.md`（自己改善ループ用）に書き出します。
> **実機 / シミュレータの目視・手動検証（プロダクト QA）は [`docs/tasks/verification-checklist.md`](./tasks/verification-checklist.md) に集約する**（2026-07-08 分離 / 2026-07-25 に完全移送）。**tasks.md に「ユーザー: シミュレータで目視」行を作らない** — 実装が終わって残るのが目視だけになったら、その時点で checklist へ 1 項目として移し、こちらはフェーズサマリで触れるだけにする。完了した目視行を `[x]` で残すのも禁止（確認済みの事実だけが溜まって読み飛ばす行が増える。記録が要る内容は implementation_note へ）。
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

#### Swift コードレビューの是正（2026-08-08 起票）

> `iosApp/**` 全体（90 ファイル / 16,504 行）のレビューで 20 件を指摘。**ユーザーが選んだものだけを順次起票する**（残りは着手が決まった時点で起票する。UI/UX 敵対的レビューと同じ運用）。
>
> **SR-1**（レビュー #3）は「サインアウト / アカウント削除の完了検知が取りこぼされうる」。`AccountViewModelBridge.awaitProcessingCompletion()` が `isProcessing` を **ポーリング**して完了を待つ一方、`AccountView` が `.onDisappear` で observation を cancel するため、**完了前に画面を離れると `isKmpProcessing` が凍結し、300 周スピンして `false` を返す** → `onResetRequested()` が呼ばれず、**Firebase はサインアウト済みなのに `AppState` は古い uid とブリッジを保持したまま**になる。
>
> **修正範囲はユーザーが「KMP 1 行 + Swift 全面」を選択**（2026-08-08）。Swift 側だけの緩和（退出封じ + observation 維持）では 30 秒タイムアウト経路が残り、記録が多いユーザーのアカウント削除（全 Visit の Firestore 削除）はこれを超えうるため。
>
> **SR-2**（レビュー #4）は「ローカライズ変換ヘルパが 18 箇所に手写しされている」。着手して分かった要点は**直し漏れのリスクより先に「ヘルパがあるのに使われていない」形で既に発現していた**こと（記録エディタ / 記録詳細の精製方法・焙煎度が英語のまま）。教訓は lessons 2026-08-08 に記録し `.claude/rules/swift-ios.md` へ昇格済み。
>
> **SR-3**（レビュー #5）は「共有カードの写真が body 評価ごとにフルデコードされる」。**前日 SW6-A で「対象外（意図的）」と判断済みの箇所**で、その判断は解像度については正しく、回数の観点だけが抜けていた。「除外の記録は、除外した理由の適用範囲まで書いて初めて再検討可能になる」が教訓（lessons 2026-08-08）。

| 状態 | ID | タスク | 備考 |
|------|----|------|------|
| [x] | SR-1 | **サインアウト / 削除の完了検知をポーリングから StateFlow 直接 await へ** → **2026-08-08 完了**（テスト 4 件追加 / iOS・Android 18 件 PASS / フラグ無し `** BUILD SUCCEEDED **`。経緯は implementation_note 2026-08-08）。①KMP: `AccountViewModel` の 3 メソッド（`onAppleCredentialReceived` / `onSignOutTapped` / `onDeleteAccountTapped`）で `isProcessing = true` を `launch` の**外**（同期）へ出す ②Swift: `awaitProcessingCompletion()` の 340 周ポーリングを `kotlin.state` の直接 collect に置換（observation task から独立するため `onDisappear` の影響を受けない）③Swift: `AccountView` の `.onDisappear` を削除し bridge の `deinit` に委ねる（`CafeDetailView` と同じ判断）④「完了」ボタンを処理中は無効化 `shared/feature/account` + `iosApp`。**①では `catch (CancellationException)` の `isProcessing = false` も外す必要があった** — cancel は必ず「次のアクション開始」とセットなので、残すと直後に立てた `true` を非同期に打ち消すレースになる。**④は「完了」ボタンの無効化のみ**（`AccountView` は sheet ではなく **push** なので `interactiveDismissDisabled` が効かない。戻るボタンの封じは入れ子 `NavigationStack` の解消が前提でスコープ外 = **残務**）|
| [x] | SR-2 | **ドメイン enum の日本語ラベルを `Utilities/DomainLabels.swift` へ集約**（レビュー #4）。18 定義（roast 6 / brew 7 / tasting 4 / processing 1）を削除し、型の extension（`localizedLabel` / `static localizedLabel(forName:)`）へ統一。`switch` から `default` を外し、Kotlin の enum ケース追加がコンパイルエラーになるようにした → **2026-08-08 完了**（`** BUILD SUCCEEDED **` + シミュレータ目視確認済み。経緯は implementation_note 2026-08-08）| iosApp 完結。**重複が「使われていなかった」ことが本体**: 記録エディタ / 記録詳細の「精製方法」「焙煎度」が `.name` 直表示で英語（`Anaerobic` / `FullCity`）だった。**うち詳細 2 件は横断点検で初めて出た**（当初対象はエディタ 2 件のみ）。`TastePreferenceConversionView.localizedRoast` は LLM 出力の変換で定義域が違うため**意図的に集約対象外**。教訓は lessons 2026-08-08 → `.claude/rules/swift-ios.md` へ昇格済み |
| [x] | SR-3 | **共有カードの写真デコードを body 評価ごとから `init` 1 回へ**（レビュー #5）。`CoffeeShareCardView.loadedPhoto` を computed property → `init` 解決の stored property に。**解像度（フルデコード）は維持し回数だけ削減** → **2026-08-08 完了**（`** BUILD SUCCEEDED **`。経緯は implementation_note 2026-08-08）| iosApp 完結。前日 SW6-A で「対象外（意図的）」とした同じ箇所で、**その判断は解像度については正しく回数の観点だけが抜けていた**（implementation_note 1350 行付近に追記で是正）。**レイアウトは変わらない**（`bandHeight` の判定は同値）。**#6（`render` の `pngData()` / 書き込みがメインスレッド）は未着手**で、修正後も 1 回のフルデコードはメイン上に残る。教訓は lessons 2026-08-08 |

#### UI/UX 敵対的レビューの是正（2026-08-07 起票）

> `screenshots/6.9/` の主要 6 画面（マップ / 分析サマリ / 分析サジェスト / 記録リスト / 記録エディタ / カフェ詳細）をレビューし、ユーザーが対処対象と順序を確定させたもの。**指摘の全件ではなく、ユーザーが選んだ 8 件のみ**を以下に起こす（採用しなかった指摘は起票しない）。コミットは 1 項目 = 1 コミットで分ける。
>
> **2026-08-07 に 8 件すべて決着**（完了 5 / 取り下げ 3）。取り下げは UX-2（ピン重なり = 実測で間引きが情報の 84% を捨てると判明）/ UX-5（閉店の赤 = Google マップの慣習に従う）/ UX-6（評価分布のビン欠落 = ユーザー判断で不要）。その後 **UX-9**（UX-1 の意匠を概念ピン 4 種へ拡張）を追加で実施。**残務が 3 件ある**: ①App Store スクショ `04-record-list.png` の再撮影（FAB 廃止 + サムネイル追加で現物と不一致。`01-map.png` も UX-1 / UX-9 でピン意匠が変わったため要再撮影）②営業状態の文言割れ（`CafeDetailView`「営業時間外」/ `CafeSelectionCard`「終了」）③`MKLocalSearch` が 50 件で頭打ちな件と、名前ヒューリスティック / ネガティブキャッシュが渋谷で 1 件も除去していない件（いずれも UX-2 の計測で判明。未調査）。
>
> レビュー時に**取り下げた指摘が 1 件**: 「ピンの視覚語彙が凡例なしで崩壊している」は、`docs/ui-ux-guidelines.md`「ピンの意匠ルール（2026-07-27 確定）」に色・サイズの序列が意図的に定義済みで、言い過ぎだった。凡例の追加も「マップの慣習で読めるはず。凡例が要る意匠は意匠側の失敗」というユーザー判断で不採用。実在した問題は**カップアイコン 3 種（訪問済み / おすすめ / 周辺）を色相差 6〜8° で区別させていた**点に絞られる。

| 状態 | タスク | 備考 |
|------|--------|------|
| [x] | UX-1 | ~~**おすすめピンを★バッジで差別化**~~ → **2026-08-07 完了**（`afd9efa`、シミュレータ目視確認済み）。`cup.and.saucer.fill` を共有したまま右上に `star.fill` の白地バッジを乗せ、サイズ 34 → 32。色相実測と不採用案（`.teal` 化 / 凡例追加）の根拠は ui-ux-guidelines「おすすめピンを色で区別しない理由」 | iosApp 完結。`MapPins.swift` の `CuratedCafePin` |
| [-] | UX-2 | ~~**マップのピン重なり対策**~~ → **2026-08-07 取り下げ（実装は revert 済み）**。間引き・クラスタリングとも実装しない。**重なりは許容する**。実測で「重なりゼロ」の間引きが情報の 84% を捨てると判明したため（下記）。ラベル衝突も未対処のまま残す | 再提案する前に implementation_note 2026-08-07「ピンの重なり — 間引きもクラスタリングも採らない」を読むこと |
| [x] | UX-3 | **追加アクションの位置を統一**。記録リストの右下 FAB を廃し、カフェ詳細と同じ `ToolbarItem(.topBarTrailing)` の `plus` へ寄せる。規則は ui-ux-guidelines「追加アクションの配置」 | **`04-record-list.png` の再撮影が必要**（app-store-metadata に警告済み）。空状態の「右下の + ボタンか…」の文言も追随が要る |
| [x] | UX-4 | **カフェ詳細の未保存「保存する」がグレーで無効に見える**。原因は `.bordered` に `.tint` が無く `accentColor`（茶）を継承していたこと。`.tint(.indigo)` を付けて色セマンティクス表に合わせる。**塗りの有無で状態を表す設計（保存済み = 塗り）は維持**（アイコンの `bookmark` / `bookmark.fill` と同じ「塗り = ON」の語彙。強調を反転する案はユーザー判断で不採用） | `CafeDetailView.swift:178-205`。**横断点検で `MapFilterChipRow` の「保存済み」チップにも同型の tint 漏れ**（バッジと選択時の塗りが茶）を発見し同時に修正。パターンは lessons 2026-08-07 + `.claude/rules/swift-ios.md` へ昇格済み |
| [-] | UX-5 | ~~**「営業時間外」の赤を外す**~~ → **2026-08-07 取り下げ（現状維持）**。Google マップが閉店中を赤で出しており、マップの慣習から外れていないためユーザー判断でスルー。`.red` が「危険操作」と意味を共有する点は認識のうえで許容する | **未解決で残すもの**: 同じ状態の文言が `CafeDetailView`「営業時間外」/ `CafeSelectionCard`「終了」で割れている（配色とは別問題。未着手） |
| [-] | UX-6 | ~~**評価分布ヒストグラムのビン欠落**~~ → **2026-08-07 ユーザー判断で不要**（取り下げ）。x 軸が 3 / 3.5 / 4 / 4.5 / 5 のみで 1〜2.5 が省かれる件は現状維持 | `AnalysisView+Statistics.swift` |
| [x] | UX-7 | **記録リストに写真サムネイルを足す**。1 枚目を 56pt 角丸で行の左に置く。**写真が無い記録でも枠は常に確保**しプレースホルダ（薄いグレー地 + `cup.and.saucer`）を出す（`if` で枠ごと消すと兄弟がシフトする。rules/swift-ios）。**既存の `PhotoFileStore.loadImage` はフルデコード同期 API なのでリストでは使えない** — ファイル URL からの縮小デコード + メモリキャッシュ + 非同期の経路が要る | `CoffeeListView.swift` / `Utilities/PhotoFileStore.swift`。UX-8 と同じ行を触るため 1 コミットにまとめる |
| [x] | UX-8 | **記録リストでコーヒー名を読めるようにする**。**主従は入れ替えない**（カフェ名 `.headline` のまま）。コーヒー名を `.subheadline`/`.secondary` → `.body`/`.primary` に上げて同格に近づける（2026-08-07 ユーザー判断）。入れ替え案はコーヒー名が「本日のコーヒー」等の一般名のとき情報量が落ちるため不採用 | 日付の短縮（`2026/08/06` → `6日`）は**今回対応しない**（月セクションと重複するが判断はユーザーが保留） |
| [x] | UX-9 | **UX-1 の「カテゴリアイコン + 意味バッジ」構成をマップ概念ピン 4 種に拡張**（2026-08-07 ユーザー指示）。保存済み / 好み一致も本体を `cup.and.saucer.fill` に統一し、概念は右上バッジ（`bookmark.fill` / `heart.fill`、シンボル色 = 概念色）で表す。**サイズは据え置き** — おすすめの 34 → 32 は「バッジ持ちがおすすめだけ」だった時期の相殺で、4 種すべてが持つ今は不要。一律 -2 すると 好み一致 = 訪問済み（36）、保存済み = おすすめ（32）でサイズ序列が潰れる。バッジは `MapPinBadge<Content>` に共通化（訪問回数の `Text` も含む 4 箇所） → **2026-08-07 完了**（`5c769ea`、4 種とも目視確認済み）。`MapPins.swift`。仕様は ui-ux-guidelines「『カテゴリアイコン + 意味バッジ』を全概念ピンの構成とする」 |
| [x] | UX-10 | **好み一致ピンのタップをカフェ詳細へ直行させ、推薦理由をカフェ詳細のセクションへ移す**（2026-08-07 ユーザー報告「シートのせいでカフェ詳細に辿り着けない / 直感的ではない」）。`RecommendationMatchSheet` 廃止。**遷移バグではなかった**（ピン経由・チップ経由とも実機で遷移することをユーザーが確認）— 問題は「同じ見た目のピンで 1 種だけ行き先が違う」構成。移設の主目的は、**マップ以外の経路で店を開いても理由が見えるようにする**こと | KMP（`CafeDetailViewModel.UIState.matches` 追加、`iosSimulatorArm64Test` 12 件 PASS）+ iOS（`Components/PreferenceMatchViews.swift` 新設 / `MapTabView.swift` 804→771 行）。仕様は ui-ux-guidelines「ピンのタップは全種カフェ詳細へ直行する」、経緯は implementation_note 2026-08-07。**2026-08-07 完了**（`1761435`、目視確認済み） |

#### 写真の保存時リサイズ + 枚数上限（2026-08-01 起票）

> ASO-6 ①「写真が機種変更で消える」の対策コスト試算の過程で、**写真が一切リサイズされずに保存されていた**ことが判明（`CoffeeEditorView+Photos.swift` が `jpegData(compressionQuality: 0.85)` のみ）。用途の最大は共有カード 1080×1350px なのに、フル解像度をそのまま保存していた。**実測: 12MP HEIC が 4.39MB → 1.31MB**（HEIC はフル解像度 JPEG 再エンコードで ×1.64 に膨張していた）、年間 約 1.6GB → 約 0.4GB。**確定値: 長辺 2048px / JPEG q0.8 / 1 記録 10 枚**（2026-08-01 ユーザー決定）。requirements 未決事項「写真の最大枚数 / サイズ上限」を両半分とも消し込む。iosApp 完結・KMP 変更なし。プランは `.claude/plans/streamed-humming-lighthouse.md`、経緯は implementation_note 2026-08-01。
>
> 課金以外の含意 2 つ: ①requirements 7-2 が写真のバックアップを iCloud Backup に委ねているが **iCloud 無料枠は 5GB** で、旧ペースはバックアップ失敗を招き ASO-6 ①の実発生確率を自ら押し上げていた ②将来 Storage を復活させる場合のコストが約 1/3.4 になる（paid-services §2 に実測表）。**写真をクラウドに置くか自体は今回の判断対象外** — Firebase Storage と CloudKit（private database はユーザーの iCloud 容量を消費するので開発者課金ゼロ）の比較は、置くと決めた段階で行う。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: docs 確定（requirements 未決事項 + §2 写真行 / data-model §1.4 / paid-services §2 + §3 / implementation_note / ui-ux-guidelines 写真対比表） | 2026-08-01 完了。**`paid-services` は当初「更新不要」と誤判断しユーザー指摘で是正** → CLAUDE.md へ不作為分を昇格 + lessons 2026-08-01。その sweep で `ui-ux-guidelines.md:286`「表示枚数 = 制限なし（全件）」の誤読リスクも検出・是正 |
| [x] | ios-engineer: `ImageDownsampler.swift` 新設（ImageIO `CGImageSourceCreateThumbnailAtIndex`）+ `handlePickerSelection` 差し替え + `photosSection` の枚数ガード | 2026-08-01 完了。上限は `CoffeeEditorView.maxPhotoCount`（両 extension から参照）。`maxSelectionCount` は `max(remaining, 1)` + `.disabled` で **0 = 無制限**の罠を回避。ImageIO 採用理由は `UIImage(data:)` の 48MP≒190MB メモリピーク回避 |
| [x] | 親: フラグ無しビルド再検証 + 実測値の確認 | 2026-08-01 完了。親がフラグ無しで `** BUILD SUCCEEDED **` を独立再確認（`OVERRIDE_KOTLIN_*` が環境に 0 件であることも確認）。**プランの推定「約 1/7」は楽観的で、実測は約 1.6〜5 倍の削減**だったため docs の数値を実測へ差し替え（implementation_note 参照）。膨張側の見立て（HEIC ×1.64）は方向・桁とも一致 |
| [ ] | **ユーザー: シミュレータ / 実機で目視**（verification-checklist「写真の保存時リサイズ + 枚数上限」へ移送済み） | サンドボックスから PhotosPicker をタップ操作できず、UI 経由の `<Documents>/photos/*.jpg` 実測は未取得。**筆頭は縦向き写真が横倒しにならないこと**（EXIF transform） |

#### 過去に使ったタグのサジェスト（要件 2-13 / 2026-07-26 起票）

> ユーザー要望: タグが自由入力のみで毎回打ち直しになる。エディタのタグ入力欄の**下**に、過去の全記録から集めたタグを横スクロールのチップで出す（要件 2-8 のカフェサジェストと同じ操作感）。**仕様の正は requirements.md 2-13**（使用回数降順・同数昇順 / 最大 10 件 / 入力中は部分一致で**絞り込んでから**上限適用 / 付与済み除外 / 0 件時は行ごと非表示）。ロジックは `commonMain`（Android 実装時の二重化回避）。データモデルは不変。設計判断は implementation_note 2026-07-26、プランは `.claude/plans/soft-fluttering-thompson.md`。
>
> **公開 API 差分（合意書）**: `CoffeeEditorViewModel.UIState` に `tagInput: String` / `suggestedTags: List<String>` を追加、`fun onTagInputChanged(text: String)` を追加。`onTagAdded` / `onTagRemoved` はシグネチャ不変（内部で再計算 + `tagInput` クリア）。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: requirements 2-13 + implementation_note を確定（公開 API 差分の固定） | 2026-07-26 完了 |
| [x] | kmp-engineer: `UIState` 2 プロパティ + `onTagInputChanged` + `recomputeSuggestedTags` + `onAppear` での `observeAll` 継続購読 + commonTest（順位 / 上限 / 絞り込み後の 11 位以下 / 付与済み除外 / 0 件） | 2026-07-26 完了。上限は `private const val MAX_SUGGESTED_TAGS = 10`（public companion は Swift 公開 API になるため private）。**再計算の起点は設計時の 3 つではなく 4 つ**だった — カタログ購読と記録ロードの起動順序レースで Edit/Duplicate の付与済み除外が効かない事象を実装中に発見し、初回ロード完了時の再計算を追加（implementation_note 追記済み）|
| [x] | 親: 公開 API 差分の確認 + `iosSimulatorArm64Test` を override フラグ無しで再検証 | 2026-07-26 完了。親がフラグ無しで `iosSimulatorArm64Test` 29/29 green（`tests="29" failures="0"`）を独立確認 |
| [x] | ios-engineer: Bridge 追随（`tagInput` / `suggestedTags` / `onTagInputChanged`）+ `tagsSection` にサジェストチップ行 + `@State newTagText` 撤去 | 2026-07-26 完了。2-8 カフェサジェストと同一構造（`ScrollView(.horizontal)` + `.bordered` + `Label(tag, systemImage: "tag")`）。Swift 側でのソート / フィルタ / prefix は無し（KMP 適用済みをそのまま表示）|
| [x] | 親: 統合検証（verify-kmp-ios / override 無し xcodebuild）+ commit + 目視項目を verification-checklist へ移送 | 2026-07-26 完了。親がフラグ無し `xcodebuild ... ** BUILD SUCCEEDED **` を独立再確認（`No such module 'SharedLogic'` は xcframework 未インデックスの SourceKit 偽陽性）。差分レビューで見つけた挙動差（重複タグ手入力時に入力欄が残る）は許容と判断し implementation_note に記録 |

#### 星評価のクリアボタンで星がずれる（2026-07-26 起票）

> ユーザー報告: コーヒー記録エディタで星を入れると右側に「評価を未評価に戻す」バツボタンが現れ、その分だけ星の位置が左にずれる。原因は `StarRatingView.editableStars` がボタンを `if rating != nil` で**条件的に生成**していること（`Components/StarRatingView.swift`）。`LabeledContent` の右寄せレイアウトなので、ボタンの幅（44pt）が出入りするたびに星がシフトする。**仕様: バツボタンのスペースを常時確保し、未評価時は不可視・タップ不可・VoiceOver 非読み上げにする**（レイアウトを rating に依存させない）。編集モードの利用箇所は `CoffeeEditorView+Sections.swift:394` の 1 箇所のみで、read-only 経路（一覧 / 詳細 / シェアカード / カフェ詳細）は無影響。iosApp 完結・KMP 変更なし。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: `StarRatingView.editableStars` のクリアボタンを常時レイアウトに含め、`rating == nil` のとき不可視 + `.disabled` + アクセシビリティ非公開にする。編集モード Preview に未評価↔評価済みの並びを足してずれないことを確認 | 2026-07-26 完了。`.opacity(rating != nil ? 1 : 0)` + `.disabled(rating == nil)` + `.accessibilityHidden(rating == nil)` の 3 点セット。Preview に未評価 / 3.5 星を縦並びした位置比較セクションを追加 |
| [x] | 親: レポート評価 + override 無しビルド再検証 + commit + 目視項目を verification-checklist へ移送 | 2026-07-26 完了。親がフラグ無し `xcodebuild ... ** BUILD SUCCEEDED **` を独立再確認（`#Preview` マクロの SourceKit 診断は `PreviewsMacros` プラグイン未検出の IDE 偽陽性）。lessons 2026-07-26 記録 + 44pt 要素 31 箇所の sweep 済み（同型 2 件はいずれも実害なし）→ `.claude/rules/swift-ios.md` へ昇格。目視は verification-checklist「星評価のレイアウト固定」へ移送 |

#### 産地を国ドロップダウン + 任意エリアに刷新（記録の手間削減 / 2026-07-22 起票）

> `CoffeeRecord.origin` を自由入力 → `CoffeeOriginCatalog`（コーヒー生産国 ~43 か国 + 「ブレンド」/「その他」）の国ドロップダウン選択に。粒度は新フィールド `region`（エリア/農園・任意自由入力）で保持。origin は `String?` のまま（`OriginNormalizer`/`BeanProfile`突合/分析を無改修流用）、region は表示専用で分析非対象。iOS の BeanProfile 産地サジェストは撤去。未リリースのためクリーンブレイク。仕様は data-model §1.3a / requirements 2-1 / kmp-bridge「定数カタログの共有」/ implementation_note 2026-07-22。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: docs 確定（data-model §1.1/§1.3a/§1.6/§2.1/§2.3/§3.2 / requirements 2-1・2-10・画面一覧・未決・変更履歴 / kmp-bridge / implementation_note） | 2026-07-22 完了 |
| [x] | kmp-engineer: `CoffeeRecord.region` 追加 / `CoffeeOriginCatalog` 新設 / `OriginNormalizer` を ~43 か国へ拡張（英語綴りシノニム含む）+ カタログ ⊇ シノニム値のテスト / data-local（migration 6 で `region` 列 + `CoffeeRecord.sq` upsert + `Mapper`）/ data-firebase Mapper / feature-coffee-editor（`CoffeeDraft.region`/`onRegionChanged`/build/toDraft/toDuplicate）/ `DummyCoffeeData` の混在産地を国+エリアに分割 / commonTest 更新 | 2026-07-22 完了。DummyData は origin が全て単一英語国名で混在文字列なし → region は null 据え置き。migration5 テストは head スキーマ基準のため v4 DDL に region 追加 + migrate(5→7) 追随 |
| [x] | 親: KMP 公開 API 差分確認 + `:shared:*` テスト override 無し再検証（`iosSimulatorArm64Test` 含む） | 2026-07-22 完了。親が override 無しで `verifySqlDelightMigration` + `OriginNormalizer` テスト + `:shared:domain`/`data-local`/`coffee-editor` の `iosSimulatorArm64Test` を独立に BUILD SUCCESSFUL 再確認 |
| [x] | ios-engineer: `CoffeeEditorView` の産地 UI を国 Picker + エリア TextField に置換（BeanProfile 産地サジェスト撤去 / 「その他」で国名自由入力欄）/ カタログをブリッジ受領 / `CoffeeFirestoreMapper.swift` に region / 詳細・シェアカードの産地表示に region 連結 / ローカライズ | 2026-07-22 完了。legacy origin は Picker 選択肢に動的追加でフォールバック。「その他」選択時は onOriginChanged("") で一旦空に。`CoffeeRecordDisplay.swift`（`originDisplayText`）新設で連結表示を共通化 |
| [x] | 親: 2 レポート統合 + 統合検証（verify-kmp-ios / xcodebuild override 無し）+ commit | 2026-07-22 完了。親が override 無し `xcodebuild ... ** BUILD SUCCEEDED **` を独立再確認。SourceKit の `No such module` は xcframework 未インデックスの IDE 偽陽性。commit `d72f76f` |
| [x] | 追加: 産地ドロップダウンを生産量ランキング順（ICO/FAO 概算）に並び替え（ブレンド → 生産量順 → その他、未選択は最上段維持）| 2026-07-22 完了。KMP = `countries` 並び替え / iOS = Picker で「ブレンド」を国リスト直前へ移動。data-model §1.3a 追随。commit `254a026` |

#### マップ検索結果を「マップ主体 + 下部ドラッグシート」に刷新（2026-07-22 起票）

> 検索結果の位置がマップで見えづらい問題を解消。上部ドロップダウンを廃し、結果一覧を下部の自前ドラッグシート（2 detent）へ移設。テキスト検索完了時のみ全結果ピンにカメラ自動フィット。行/ピンタップは既存 `cafeSelectionCard` と排他表示（未選択=シート/選択=カード）。選択ピンを scale 1.3 で強調。iosApp `MapTabView.swift` 完結（KMP 変更なし）。native `.sheet` は ✨ `TasteSearchSheet` と競合するため不採用。仕様は ui-ux-guidelines「マップ検索結果の提示」・requirements §11-2/§5・プラン `.claude/plans/shiny-brewing-dongarra.md`。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: docs 確定更新（ui-ux-guidelines / requirements §11-2・§5 / implementation_note / app-store-metadata の「ドロップダウン」表記追随） | 2026-07-22 完了 |
| [x] | ios-engineer: `MapTabView.swift` 実装（上部ドロップダウン撤去 / 自前下部ドラッグシート / カメラ自動フィット（テキスト検索のみ）/ 選択ピン強調 / 広告は結果シート内 3 件目後） | 2026-07-22 完了。peek 180pt / expanded = container 高さ 60%。ハンドル行に `.simultaneousGesture`（Button タップ + ドラッグ両立）、タップで detent トグル（VoiceOver 代替）。FAB は `searchSheetFABBottomInset` でシート高に追従 |
| [x] | 親: レポート評価 + ビルド検証（override 無し再検証）+ 回帰確認 | 2026-07-22 完了。親が override 無し `xcodebuild ... BUILD SUCCEEDED` を独立再確認。差分レビュー: 排他条件（sheet=未選択/card=選択）・`showingSearchResults` 転用・カメラフィット span×1.3 いずれも整合。SourceKit の `No such module` 系は xcframework 未インデックスの IDE 偽陽性 |
| [x] | ios-engineer: 広告非表示の回帰修正（ユーザー報告）| 2026-07-22 完了。原因: `InlineBannerAdView` の自己 `.task` が `LazyVStack` の fold 下（peek 180pt）で発火せず未ロード。修正: CafeDetail と同型でシートのルート VStack `.background(GeometryReader).task` から先読みロード。lessons 2026-07-22 記録 + sweep 済み |

#### 好み一致の作り込み: 精製方法軸の追加 + ダミー人格再設計（2026-07-20 起票）

> 「好み一致」（`ObserveTasteMatchedCafesUseCase` → `RecommendedCafe`）のマッチ軸を **3 軸（産地/焙煎/抽出）→ 4 軸（+ 精製方法）** に拡張。ダミーデータが全 enum 分散設計のため 2σ z ゲートに届かず焙煎度 Light しか信号化しない問題を、**人格中心の再設計**で解消（人格 = 産地ブラジル勝ち・焙煎 City・抽出 NelDrip・精製 Natural / ケニアは二番手）。`bestProcessing` はマップの好み一致と分析タブ「好みの傾向」カードの両方に出す。仕様は data-model.md §1.6/§1.7・requirements 9-5、プランは `.claude/plans/inherited-coalescing-eich.md`。テイスティング軸の一致は per-record 変換が非自明のため今回対象外（別途）。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: data-model.md §1.6/§1.7 + requirements 9-5 に精製方法軸を追記（合意書固定） | 2026-07-20 完了 |
| [x] | kmp-engineer: `FavoriteSignals.bestProcessing` + `PreferenceMatchAxis.Processing` 追加 / `buildFavoriteSignals` + `ObserveTasteMatchedCafesUseCase` に processing 軸 / `DummyCoffeeData` 人格再設計 / commonTest（processing 一致 + 人格固定テスト） | 2026-07-20 完了。横断点検で `AnalysisViewModel.hasAnySignal()` の回帰も修正。人格固定テスト（`DummyCoffeeDataPersonaTest`、`shared/core` に commonTest 初設置）green。実測: 4 軸すべて Brazil/City/NelDrip/Natural で信号化・cafe1/2/3 が 4 軸一致 |
| [x] | 親: KMP 公開 API 差分確認 + `:shared:domain`/`:shared:core` の 2 ターゲットテスト再検証 | 2026-07-20 完了。Android host + iosSimulatorArm64Test 全 green + XCFramework link 完走 + SKIE enum に `.processing` 生成確認 |
| [x] | ios-engineer: 網羅 switch 追随（`preferenceMatchAxisLabel`/`axisIcon`）+ 分析カードに精製行 + `localizedProcessingStatic` + `FavoriteSignals` 構築 2 箇所修正 | 2026-07-20 完了。axisIcon = `leaf.fill`。`RecommendedCafeListSheet` は自動追随（無改修） |
| [x] | 親: 統合検証（verify-kmp-ios、xcodebuild override 無し）+ implementation_note 記録 + commit | 2026-07-20 完了。親が override 無し BUILD SUCCEEDED を再確認 |

#### カフェ検索の補完語を「カフェ」→「コーヒー」に変更（2026-07-21 起票）

> カフェ検索タブ（位置バイアスなし `searchText(query)`）で「フルーティー」等の味覚語を入れるとパフェ等のデザート店がヒットする。原因は `ensureCafeKeyword` の補完語「 カフェ」が業態フィルタを満たすだけでコーヒー方向へ寄せないこと。補完語を **「 コーヒー」に置換**して地名のみ問題を維持しつつコーヒー方向へバイアスする（ユーザー確定 2026-07-21）。`shared/data-places` 完結。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `ensureCafeKeyword` の補完語を「 カフェ」→「 コーヒー」に置換 + KDoc 追随 + `PlacesClientImplSearchTextKeywordTest` の期待値更新 + テスト実行 | 2026-07-21 完了。includedType=cafe / CAFE_KEYWORDS / locationBias 経路は不変 |
| [x] | 親: テスト再検証（`iosSimulatorArm64Test` override 無し green）+ implementation_note 記録 | 2026-07-21 完了 |

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
| [x] | ユーザー: AdMob アカウント作成・アプリ登録・**バナー**広告ユニット **2 つ**発行（カフェ詳細 / マップ検索）→ `Secrets.xcconfig` へ本番 ID 設定 | コード外の準備。2026-07-16 の 11-3 撤去で 4 → 2 ユニットに縮小。**発行済み**（App ID + ユニット 2 件、値は `docs/admob-setup-todo.md` = git 非追跡）。`Secrets.xcconfig` には 3 行を**コメントアウトで記載**し、日常の開発・検証はデモ ID にフォールバックさせる運用（本番 ID の自己タップによる無効トラフィック回避）。リリースビルドへの供給は CI 経由（下記「CI リリースへの本番 AdMob ID 注入」） |
| [x] | ユーザー: AdMob アプリと Firebase プロジェクトのコンソールリンク（任意だが公式強推奨。Analytics に広告収益イベントが流れる） | コード変更不要。リンク済み |

#### 広告 no-fill 診断: Ad Inspector 導入（2026-07-22 起票）

> ユーザー報告: カフェ詳細 / マップ検索の 2 面で 3 日ほど前から広告が出ない（`Error Code=1 "No ad to show."` = サーバー no-fill）。調査の結果、広告リクエスト経路（`BannerAdLoader` / `iOSApp.swift` の SDK 初期化 / `Base.xcconfig` の ID / SDK v13.6.0）は直近 1 週間**無変更**。App ID・広告ユニットとも Google デモ ID のまま（ユーザー確認済み = 本番未上書き）でアカウント非依存。両環境（シミュレータ・実機）・3 日継続からレート制限/一時抑制では説明が弱く、**Google 側のデモ広告抑制（開発中の過剰トラフィック起因、自然回復見込み）が最有力**。確定のため Ad Inspector を導入し no-fill の実理由を可視化する。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: `#if DEBUG` 限定で `MobileAds.shared.presentAdInspector(from:)` を起動する導線を追加（設定画面のデバッグ行 等、リリースビルドに出さない）。ビルド検証まで | 2026-07-22 完了。`SettingsView` に DEBUG 限定「デバッグ」セクション + 「Ad Inspector を開く」ボタン。`RootViewControllerProvider` 再利用 |
| [x] | 親: 検証（override 無し build）+ commit | 2026-07-22 完了。フラグ無し `xcodebuild ... BUILD SUCCEEDED` を親が再確認（SettingsView の SourceKit 診断は macOS SDK インデックス誤りで実害なし）。commit 514acaf |

#### SKAdNetwork 識別子の整備（広告収益最適化 / 2026-07-22 起票）

> 起動ログの `49 required SKAdNetwork identifier(s) missing from Info.plist` 警告への対応。現状 `SKAdNetworkItems` は Google 自身の 1 件（`cstr6suwn9.skadnetwork`）のみ。SKAdNetwork は ATT 後のプライバシー保護型インストール計測基盤で、AdMob メディエーション各社の ID を列挙しておくと、ATT 拒否ユーザーの広告成果も計測でき fill 率・eCPM が上がる（機能面の不具合ではなく収益最適化）。Google 公式 Privacy strategies ページの全 50 件を反映する。no-fill（本ページ別項）とは無関係。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: `Info.plist` の `SKAdNetworkItems` を Google 公式の全 50 件に差し替え（既存 `cstr6suwn9` 含む）。plist 妥当性検証 | 2026-07-22 完了。純粋追加（他キー無変更）。一覧は時々更新されるため、本番リリース前に再取得推奨。出典: developers.google.com/admob/ios/ios14 |
| [x] | 親: 検証 + commit | 2026-07-22 完了。親が `plutil -lint`=OK / 識別子 50 件 / 重複なし / 196 insertions・0 deletions を再確認。commit で反映 |

#### CI リリースへの本番 AdMob ID 注入（2026-07-22 起票）

> `Secrets.xcconfig` は gitignore 済みで CI 追跡外。`release-testflight.yml` の「Restore secret files」は従来 `PLACES_API_KEY` しか書き出しておらず、**本番 AdMob ID を発行しても TestFlight ビルドは Base.xcconfig のデモ ID のまま出荷される**地雷があった（発見: 2026-07-22 のユーザー質問）。**本番 ID は発行済み**（「広告導入」セクション参照。値は git 非追跡の `docs/admob-setup-todo.md`）。ただし `Secrets.xcconfig` では 3 行をコメントアウトしてデモ ID にフォールバックさせる運用のため、**ローカル・CI とも実行時はデモ ID**。書き出し漏れでリリースがデモ ID のまま出荷される事故を防ぐため CI 側を配線した。残るのは GitHub Secrets への登録（下記）のみ。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | 親: `release-testflight.yml` の「Restore secret files」を拡張。`ADMOB_APP_ID` / `ADMOB_BANNER_AD_UNIT_ID_CAFE_DETAIL` / `ADMOB_BANNER_AD_UNIT_ID_MAP_SEARCH` を env 追加し `Secrets.xcconfig` へ書き出し。**リリースは本番 ID 必須（未設定なら fail-fast）** + 非空担保後に書く（空文字で Base のデモ ID を上書きしてクラッシュ/403 になる罠を回避） | 2026-07-22 完了。YAML 妥当性（ruby）+ guard ロジック dry-run（未設定→fail / 全設定→4 行書き出し）を親が検証。commit で反映 |
| [x] | **ユーザー: GitHub リポジトリに Secrets 3 件を登録** — `ADMOB_APP_ID` / `ADMOB_BANNER_AD_UNIT_ID_CAFE_DETAIL` / `ADMOB_BANNER_AD_UNIT_ID_MAP_SEARCH`（本番 AdMob コンソールの値） | 2026-07-26 ユーザー登録完了。以降 TestFlight リリースは本番 ID で出荷される（未設定なら fail-fast する guard は維持） |

#### 記録・分析タブの広告撤去（2026-07-16 起票）

> ユーザビリティレビュー採用分。定着の核となる記録・振り返り 2 画面のバナーはリテンションを削る割に収益が小さいため**一度撤去**（再導入余地は残す — コンポーネントは git 履歴から復元可能）。広告はカフェ詳細 / マップ検索の 2 面に縮小。**仕様の正は requirements.md §11（11-3 = ✕ 撤去、2026-07-16 改訂済み）**。ATT フローは残存 2 面のため維持。プランは `.claude/plans/agile-knitting-fern.md`。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: 記録タブ（`CoffeeListView`）/ 分析タブ（`AnalysisView`）の広告配線削除 + `AnchoredBannerAdView.swift` 削除（分析タブ専用）+ ユニット ID 2 面分の定義削除（`AdUnitIDs.swift` / `Base.xcconfig` / `Info.plist`） | 2026-07-16 完了。撤去 5 識別子の grep 横断点検で残存なし。Configuration/README も 2 面に追随 |
| [x] | 親: 検証（xcodebuild override 無し）+ implementation_note 記録 + commit | 2026-07-16 完了。親が override 無し BUILD SUCCEEDED を再確認。paid-services.md の面数記述も追随。`Secrets.xcconfig` のみ親から読み取り不可（本番ユニット未発行のため該当キー無しの見込み、ユーザー確認推奨） |

#### 共有カード画像生成（2026-07-16 起票）

> ユーザビリティレビュー採用分（外向きの共有回路の新設）。記録詳細から 4:5（1080×1350px）のカード画像を生成し share sheet で共有。**仕様の正は requirements.md §2 2-12**（可変レイアウト 1 テンプレート / メモ・タグ非掲載 / ライトテーマ固定、2026-07-16 確定）。既存 `TastingRadarChart` を再利用、ImageRenderer は本リポジトリ初使用。iosApp View 層完結・KMP 変更なし。プランは `.claude/plans/agile-knitting-fern.md`。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: `ShareCard/` 新設（`CoffeeShareCardView` = 360×450pt 可変レイアウト / `ShareCardRenderer` = ImageRenderer scale 3 + ライト固定 + 一時 PNG / `ShareCardSheet` = プレビュー + ShareLink）+ `CoffeeDetailView` ツールバーに独立共有アイコン | 2026-07-16 完了。`TastingRadarChart` / `StarRatingView` / `PhotoFileStore` は無改変で再利用。カードの roastLevel はローカライズ表示（本体 Form と非対称 — implementation_note 2026-07-16） |
| [x] | 親: 検証（xcodebuild override 無し）+ implementation_note 記録 + commit | 2026-07-16 完了。親が override 無し BUILD SUCCEEDED を再確認。設計判断 2 エントリを implementation_note に記録 |

#### 分析タブ「抽出方法の内訳」の横棒化（2026-07-16 起票）

> ユーザー報告「抽出方法の文字列が被って読めない」。`brewMethodSection` が縦棒（x=抽出方法ラベル）のため、方法数が増えると X 軸ラベルが重なる。焙煎度の内訳と同じ横棒（x=件数、y=抽出方法）に変更する。高さは項目数 × 32pt の可変。iosApp View 層完結・KMP 変更なし。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: `AnalysisView.brewMethodSection` を横棒 BarMark 化（焙煎度セクションの軸構成を踏襲） | 2026-07-16 完了。データ順は `byBrewMethod`（件数降順）のまま = 最多の方法が最上段 |
| [x] | 親: 検証（xcodebuild override 無し）+ commit | 2026-07-16 完了。ios-engineer が override 無し xcodebuild BUILD SUCCEEDED（error 0 件）を確認済み |

#### 分析タブ「あなたの傾向」の再生成抑止（2026-07-16 起票）

> ユーザー報告「分析タブに遷移するたびに『あなたの傾向』が再計算されてそう。一度計算したらアプリ利用中は保持したい」。原因は `AnalysisViewModel.onAppear()` が無条件に `observeJob` をキャンセル・再購読し、Flow の再 emit で `launchInsightGeneration` が毎回走ること（VM 自体は `AppState` でアプリ生存期間保持されており、購読を張り直す必要がない）。修正は commonMain のみ: ① `onAppear()` は購読中なら no-op、② 同値 stats の再 emit では要約を再生成しない。記録の追加・変更時は従来どおり再生成される。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `AnalysisViewModel.onAppear()` の購読中ガード + 同値 stats での insight 再生成スキップ + commonTest 追加 | 2026-07-16 完了。`AnalysisViewModelInsightRegenerationTest` 3 件新規（計 22 件 green）。公開 API 変更なし・iOS Bridge 追随不要 |
| [x] | 親: verify-kmp-ios 再検証 + commit | 2026-07-16 完了。testAndroidHostTest + iosSimulatorArm64Test（analysis 実行確認）+ assembleSharedLogicXCFramework すべて BUILD SUCCESSFUL。判断は implementation_note 2026-07-16 |

#### コーヒー記録の削除動線 3 種（2026-07-16 起票）

> 要件 2-3「CoffeeRecord の削除」の動線整備。リストスワイプ削除は実装済み（確認なし即削除、維持）。追加するのは **リスト長押し contextMenu（編集 + 削除）** と **詳細右上 Menu の削除**。確認ダイアログは詳細・長押しのみ（2026-07-16 ユーザー決定、Undo なし）。詳細からの削除は `CoffeeDetailViewModel.UIState.isDeleted` フラグで pop 通知（`coffee == null` 検知は同期削除の「見つかりません」表示用に温存）。プランは `.claude/plans/starry-greeting-bird.md`。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `CoffeeDetailViewModel` に `onAppear(coffeeId, userId)` / `onDeleteTapped()` / `UIState.isDeleted` 追加 + commonTest 新設 | 2026-07-16 完了。commonTest 5 件 green（Android host + iosSimulatorArm64 は親実行） |
| [x] | ios-engineer: 詳細 Bridge / View（削除 Menu + confirmationDialog + dismiss + 写真物理削除）、リスト contextMenu（編集 sheet + 削除 dialog） | 2026-07-16 完了。swipeActions 無変更 |
| [x] | 親: verify-kmp-ios 再検証 + implementation_note 記録 + commit | 2026-07-16 検証完了。全モジュール 2 ターゲットテスト green + XCFramework link + override 無し xcodebuild BUILD SUCCEEDED を親確認。implementation_note 2026-07-16 記録済み |

#### マップ「好み一致」チップのタップ対応（2026-07-16 起票）

> ユーザー報告「好み一致タグをタップしても何も起きない」。現状は静的凡例チップ（`TagLegendChip`、意図的にインタラクションなし）だが、隣のタップ可能チップと同じ見た目で誤解を招く。**「保存済み」チップと同じ操作体系に変更する**（2026-07-16 ユーザー決定）: タップで強調 ON + 好み一致カフェ一覧シート表示、強調中の再タップは強調解除のみ。行には推薦理由サマリを表示し、行タップでカフェ詳細へ push。iosApp View 層完結・KMP 変更なし。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: 「好み一致」チップを `TagLegendChip` → `TagChip` 化（強調トグル + 一覧シート、保存済みパターン踏襲）+ `RecommendedCafeListSheet` 新設 + 強調中の他ピン減光 | 2026-07-16 完了。`TagChip` に `tint` パラメータ追加（好み一致のみ `.pink`）。保存済み強調と排他 |
| [x] | 親: verify-kmp-ios で再検証 + implementation_note 記録 + commit | 2026-07-16 完了。override 無し xcodebuild BUILD SUCCEEDED を親確認。implementation_note 2026-07-16 + lessons 2026-07-16（型チェッカ誤誘導）記録済み |

#### 分析タブ可視化改善: 焙煎度チャート + テイスティングレーダー（2026-07-13 起票）

> 分析タブの可視化レビューから 2 件を採用（プラン承認済み）。① 焙煎度チャートを件数降順・単色縦棒 → **全 8 段階を焙煎順（浅→深）の横棒 + アクセント基準のブラウン明暗ランプ**に変更（`byRoastLevel` の KMP 契約は件数降順のまま、Swift 側で表示用マージ）。② テイスティング 5 軸の横棒を **カスタムレーダーチャート**（`Canvas`/`Path`、Swift Charts 非対応のため）に置き換え、各軸ラベルに平均値を添える。iOS のみで完結（KMP 変更なし）。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: `roastLevelSection` を全 8 段階・焙煎順横棒 + 浅→深ランプ化 | 2026-07-13 完了。`byRoastLevel` 空ならセクション非表示は従来どおり |
| [x] | ios-engineer: `TastingRadarChart.swift` 新規 + `tastingAveragesSection` 置き換え | 2026-07-13 完了。ドメイン非依存の `RadarChartAxis` 設計 |
| [x] | 親: 検証（xcodebuild override 無し）+ implementation_note 記録 + commit | 2026-07-13 完了。Gradle タスク実行 + BUILD SUCCEEDED を親再検証 |

#### カフェ詳細 Places 写真の段階読み込み（2026-07-13 起票）

> Photo Media API のコスト削減（paid-services.md）。現状はヘッダー表示で先頭 6 枚を一括読み込み → 初期 3 枚 + 「さらに表示」ボタンで 3 枚ずつ追加、上限 10 枚に変更する。iOS のみ（`CafePhotoHeader.swift`）。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | `CafePhotoHeader` を段階読み込み化（初期 3 / +3 ずつ / 上限 10）→ ios-engineer | 2026-07-13 実装完了・override なしビルド成功。自分の記録写真は対象外（従来どおり全件表示） |
| [x] | paid-services.md の Photo Media 行を追随更新（親） | 2026-07-13 完了 |

#### 周辺カフェピンのノイズ除去（名前フィルタ + ネガティブキャッシュ、2026-07-13 起票）

> Apple `.cafe` 誤分類の非カフェ（法人本社・コンカフェ・ガールズバー等）が周辺ピンに混入し、タップしても Places 解決で「該当なし」になる（17-B「表示＝解決可能」原則違反）。対策: ① 除外キーワードによる名前フィルタ（iOS）+ ② 解決「該当なし」POI のローカル記録・非表示化（ネガティブキャッシュ）。後者のため `UIState.poiLookupError` を `PoiLookupError(message, isNotFound)` に型変更（通信エラーはキャッシュ対象外にするための区別）。設計判断は implementation_note 2026-07-13 エントリ。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `MapViewModel.UIState.poiLookupError` を `PoiLookupError` data class 化 + テスト追随 | 2026-07-13 完了。`shared/feature/map` のみ |
| [x] | 親: `:shared:feature:map:iosSimulatorArm64Test` 再検証 | 2026-07-13 全緑 |
| [x] | ios-engineer: Bridge 追随 + 名前フィルタ + `ApplePoiNegativeCache`（UserDefaults / 30m+名前一致 / 上限 300 FIFO / TTL なし）+ MapTabView 配線 | 2026-07-13 完了。除外キーワード 16 語は `MapTabView.excludedApplePoiNameKeywords` に一元化 |
| [x] | 親: 統合検証（verify-kmp-ios）+ implementation_note 記録 + commit | 2026-07-13 完了。①testAndroidHostTest / iosSimulatorArm64Test 全緑 ②XCFramework 成功 ③xcodebuild override 無しで BUILD SUCCEEDED |

#### 名前フィルタの Remote Config 外部注入（2026-07-13 起票）

> 上記ノイズ除去の除外キーワード 16 語（`MapTabView.excludedApplePoiNameKeywords` ハードコード）を Firebase Remote Config で配信し、リリースなしで追加・削除できるようにする。キー `map_poi_excluded_name_keywords`（JSON 文字列配列）。**remote はハードコードのデフォルトを置き換える**（和集合ではない — コンソールの見た目と実挙動を一致させる）。remote 未取得・parse 失敗時は bundled デフォルトにフォールバック（現行挙動と同一）。Remote Config は無料でコスト構造は不変。iOS のみで完結（KMP 変更なし）。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: SPM に FirebaseRemoteConfig 追加 + キーワードプロバイダ実装 + `MapTabView` 参照差し替え + 起動時 fetchAndActivate | 2026-07-13 完了。`ApplePoiFilterConfig`。空配列は成功扱い（フィルタ一時無効化に使える） |
| [x] | 親: 検証（xcodebuild override 無し）+ docs 更新（implementation_note / paid-services 棚卸し行）+ commit | 2026-07-13 完了。PrivacyInfo は SDK 同梱マニフェスト確認でアプリ側変更不要、app-store-metadata 6.3 に SDK 行追加 |

#### 周辺カフェピンのスロットリング耐性（2026-07-18 起票）

> 長時間のパン・ズームで `MKLocalSearch` が Apple 側にスロットリングされると（`MKError.loadingThrottled`）、`fetchAppleNearbyCafes` の catch が一律 `appleNearbyCafes = []` するため周辺カフェピンが一斉に消える（ユーザー報告 2026-07-18: 「しばらく使うと POI が表示されないことが 1 回だけあった」）。修正方針: **throttled のときだけ直前の結果を保持**する（古いピンが残る方が空白より自然。それ以外のエラーは現行どおりクリア）。iosApp 1 ファイル完結・KMP 変更なし。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: `MapTabView.fetchAppleNearbyCafes` の catch で `MKError.loadingThrottled` を判別し、その場合は `appleNearbyCafes` を保持（クリアしない） | 2026-07-18 完了。`mkError.code == .loadingThrottled` で判別（`MKError.Code` の落とし穴は ios-engineer メモリに記録済み） |
| [x] | 親: 検証（xcodebuild override 無し）+ implementation_note 記録 + commit | 2026-07-18 完了。親が override 無し BUILD SUCCEEDED + Gradle `:shared:framework:` タスク実行を確認 |

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

> **設計確定・段階タスク化（2026-07-21 grilling）**: 6 意思決定を確定（同意分離 / Cloud Function 特権 read / 5 軸 cosine + カテゴリ補助 / 未訪問+地理制約 / `RecommendationReason.SimilarUsers` 同型・視覚区別 / 今回は設計固定まで）。確定仕様の正は requirements 9-6 / analysis-model §2 / data-model §3.2・§3.3 / implementation_note 2026-07-21。`CafeRecommendationProvider` をリモート実装で差し替え可能な設計は B-4 で済み。実装は未着手で、以下 3 段に分解して段階 dispatch する（前段が後段の前提）。

| 状態 | タスク | 備考 |
|------|------|------|
| [ ] | ①同意 + 共有プロファイル書き込み基盤（`recommendationConsent` トグル + `sharedTasteProfiles/{uid}` upsert/削除 + Security Rules）。**サーバー不要・クライアント完結**で先行可 | 最初の一歩 |
| [ ] | ②Cloud Function 計算基盤（インフラ選定 → callable 実装 → 近傍 cosine + 未訪問/地理フィルタ）。**インフラ選定が 12-D 再開の起点** | 未決: 総当たり vs Firestore ネイティブ KNN |
| [ ] | ③`CafeRecommendationProvider` リモート実装 + `RecommendationReason.SimilarUsers` UI（マップ視覚区別・理由文） | ②の後 |

> 未決: 閾値定数（近傍 K / 自己記録 N / 半径 R）は実装時 sweep。FM 言語化を v1 に含めるかは実装フェーズ判断。プライバシーポリシー更新（協調フィルタのデータ利用記載）はカテゴリ 4「リリース前バックログ」。

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

> 完了（2026-06-30）: iOSDC 逆方向 PoC（`TastePreferenceExtractor`）を実用昇格。**13-A** `CoffeeRecordFilter.tastingMin/Max` + `TastePreference→Filter` 変換 / **13-B** Q&A への `SearchByTasteProfileTool` 追加 + 「好みで記録を探す」専用 UI / **13-C** マップの「好みで絞り込む」チップ（非マッチピン半透明化）〔2026-07-21 撤去: 訪問済みを味覚スコアで再絞り込むだけで用途が薄いとのユーザー判断。implementation_note 13-C エントリ参照〕/ **13-D** 検索バーの ✨ ボタン（`searchKeywords` 補完クエリ）。FM 部分は iOS 限定、非対応端末は導線非表示。判断は implementation_note 2026-06-30 13-x 各エントリ。**実機確認（Apple Intelligence 対応端末）はユーザー作業**。

#### フェーズ 14: マップ検索の使い勝手改善（表示範囲ピン表示）

> 完了分（2026-07-01）: 「このエリアを検索」ボタン方式（自動再検索なし）+ テキスト検索の全件ピン + 検索モード化（フィルタチップ非表示・結果リストを検索バー直下に統合）。しきい値（中心移動 30% / 半径比 1.5x）等の判断は implementation_note 2026-07-01 フェーズ 14 エントリ。Places New は 1 回最大 20 件の仕様上限あり。

#### フェーズ 15: 記録・店探しループの強化（2026-07-06 起票）

> 完了（2026-07-06〜07-09）: ゼロベース設計レビュー（記録できる / おいしい店を探せる / 好みを見つけられる、の 3 条件）で洗い出したギャップの採用分。要件は requirements.md §10 / §2 2-8〜2-11 / 6-1 / §9 9-7・9-8 / 7-4。
>
> - **15-A** 行きたい店リスト: `SavedCafe`（placeId 自然キー、data-model.md §1.9 / §2.4 / §4.3、migration 3.sqm）+ マップ 4 種目ピン（indigo）+ 一覧ハーフシート。2026-07-06 ユーザー目視確認済み
> - **15-B** 記録摩擦の低減: エディタの現在地カフェサジェスト（許可済みのみ one-shot）+ コーヒー名デフォルト値 + `Mode.Duplicate`（詳細画面「これをもとに記録」）
> - **15-C** 一覧検索 + 月別グルーピング: UIState を `sections: List<MonthSection>` に置換（name / cafe.name / notes のメモリ内 filter + `.searchable`、表示文字列は iOS 生成）
> - **15-D** 分析空状態プログレス: `AnalysisReadiness` 派生フィールド（閾値は既存定数参照・ハードコードなし）+ プログレスカード。`hasAnySignal` の単一ソース化まで完了（2026-07-09）
> - **15-E-1** 抽出レシピ `brewRecipe: String?`（migration 4.sqm、data-model.md §1.1）/ **15-E-2** JSON エクスポート（`ExportCoffeeRecordsUseCase` + `ShareLink`。フェーズ 6 旧行を統合）/ **15-E-3** 未経験豆の探索提案（`SuggestUnexploredBeansUseCase`、analysis-model.md §3）
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
> 判断は implementation_note 2026-07-07 フェーズ 17 エントリ、教訓（表示⇄解決の集合ズレ / 同系統 2 回失敗で再計画）は lessons 2026-07-08。最終目視は verification-checklist.md「17-D（POI タップ解決）」。

#### フェーズ 19: 都道府県別おすすめカフェのマップ強調表示（2026-07-16 起票）

> 完了（2026-07-16〜07-18、全ステップのユーザー確認済み）: キュレーション済みおすすめカフェを Firestore `curatedCafes/{prefectureCode}`（JIS X 0401、1 県 1 ドキュメント + 埋め込み配列、read-only）で配信し、マップに専用ピンで強調。要件は requirements.md §5-6、モデルは data-model.md §1.10、プランは `.claude/plans/magical-drifting-river.md`。
>
> - **KMP / iOS**: `CuratedCafe` + `CuratedCafeRepository`（BeanProfile パターン、one-shot + メモリキャッシュ、失敗時サイレント）。ピン優先順位: 訪問済み > 保存済み > 検索結果 > curated > Apple 周辺。Mapper は 1 ドキュメント → List で BeanProfile 型と非対称（implementation_note 2026-07-17）
> - **ピン意匠（ユーザーフィードバックで 2 回改訂）**: star 意匠 → 通常カフェピンと同アイコン（`cup.and.saucer.fill`）の 34pt 拡大 + 素の `Color.orange`、Apple 周辺ピンと同じズームゲート（3000m）でズームイン時のみ表示（implementation_note 2026-07-18、色セマンティクスは ui-ux-guidelines 第 5 概念）
> - **データ**: 東京 157 件投入済み（基準上位 100 = 評価 4.4/レビュー 100 件以上 + 人気枠 57 = 3.7/500 以上を枠外全件）。生成 → 人手レビュー → 投入の 2 段構成（`scripts/seed/generate-curated-cafes.mjs` / `seed-curated-cafes.mjs`）。coffee_shop タイプ厳格化でシーシャ・コンセプト店を排除、レビュー除外店は `EXCLUDED_NAME_KEYWORDS` で再混入防止。保存は placeId + 名前 + 座標 + 県コードのみ（Places 規約、詳細はタップ時 getDetails）
> - **他県展開（2026-07-28）**: 9 県へ拡張することをユーザー確定。`subAreas` 定義（スクリプト側）は完了、生成 → レビュー → 投入はカテゴリ 4「リリース前バックログ」で追跡する。アプリコードの変更は不要。47 県フル展開時のメモリ面は UIState 全件保持のまま（描画はズームゲートで解消済み）

#### フェーズ 6 既知バグ: エディタ buildCafe の Edit/Duplicate 分岐（2026-07-08 着手）

> 完了（2026-07-08）: セルフ抽出記録（元 cafe = null）の編集 / 複製で手入力カフェ名が無言で捨てられるバグ（`CoffeeEditorViewModel.buildCafe`）を、cafe 採用の状態ベース 3 段判定への一本化（mode 分岐削除・手入力は新規 UUID 採番）で修正 + 簡素化。回帰テスト 2 件追加、iOS / Android green。判断は implementation_note / lessons 2026-07-08。

#### 産地シノニム正規化 OriginNormalizer（2026-07-08 着手）

> 完了（2026-07-08）: 「Ethiopia」「イルガチェフェ」→「エチオピア」の名寄せを `object OriginNormalizer`（trim → lowercase → シノニム辞書完全一致、辞書外は素通し）で決定論のまま実現し、全 origin 正規化ポイント 5 箇所に適用（ベクトル検索は過剰と判断し見送り）。domain 170 件 green（iOS / Android）+ 統合ビルド成功。仕様反映は analysis-model.md §1 / data-model.md §1.8、経緯は implementation_note 2026-07-08、複合語×辞書のすれ違いは lessons 2026-07-08。

#### テイスティングスライダーの tap-to-seek 化（2026-08-06 起票）

> 完了（2026-08-06）: ユーザー報告「つまみを正確に掴まないと動かせない」への対応。標準 `Slider` を `.allowsHitTesting(false)` で描画専用にし、重ねた透明レイヤーの `DragGesture(minimumDistance: 0)` で駆動する `TappableTastingSlider`（`CoffeeEditorView+Sections.swift`）で tap-to-seek 化。つまみ半径ぶんのインセット補正込み。本体はむしろ `Form` 内でのジェスチャー共存で、親レビューで副作用 2 件（touch down 発火による値の書き換え / `onEnded` 未発火でのラッチ固着）を潰した。ビルドは親がフラグ無しで独立再検証、実操作もユーザー確認済み。経緯は implementation_note 2026-08-06、教訓と sweep は lessons 2026-08-06、規約は `.claude/rules/swift-ios.md` へ昇格。

---

## カテゴリ 2: 設計・アーキテクチャ / コード品質

### 未完・バックログ

#### Swift 5 → Swift 6 移行（2026-08-07 起票 / 2026-08-08 完了）

> **2026-08-08 に SW6-1〜7 すべて完了。** `iosApp` を Swift 6 言語モード + **既定 MainActor 分離**（`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` / `SWIFT_APPROACHABLE_CONCURRENCY = YES`）へ移行し、`OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED` 無しの clean build で **Debug / Release とも警告 0・エラー 0**（残る 1 件は Swift 6 と無関係な `UIWindow()` の iOS 26 deprecation）。設定は `iosApp/Configuration/Base.xcconfig` に一本化した（`project.pbxproj` への `SWIFT_VERSION` 直書きは xcconfig より優先されるため削除）。
>
> **`shared/**` は 1 行も触っていない** — `SharedLogic.swiftmodule` の `.swiftinterface` が `-language-mode 5 -enable-library-evolution` でビルドされており、アプリを Swift 6 にしても SKIE 生成コードは Swift 5 セマンティクスで再構築されることを実読みで確認した。
>
> 変更は 24 ファイル。**ViewModel ブリッジ 8 本 = `isolated deinit`（SE-0371）/ Kotlin interface 実装 8 本 = `nonisolated`（可変キャッシュは `OSAllocatedUnfairLock` + `@unchecked Sendable`）/ `PhotoFileStore.loadThumbnail` = `@concurrent` / デリゲート 2 本 = `MainActor.assumeIsolated`**。`@preconcurrency import SharedLogic` の追加は 3 ファイルに限定（移行前から 4 ファイルに存在）。
>
> **判断の根拠・使い分けの軸・計測方法の落とし穴は [`implementation_note.md`](./implementation_note.md) 2026-08-08 が正本**。規約への昇格先は [`coding-conventions.md`](./coding-conventions.md) §2.5 / [`kmp-bridge.md`](./kmp-bridge.md)「Swift 6 の並行性境界」/ `.claude/rules/swift-ios.md`。
>
> **残務は実機目視のみ**（[`verification-checklist.md`](./tasks/verification-checklist.md) へ移送済み）。特に `CoffeeInsightProviderIosImpl` の `nonisolated` 化で**オンデバイス LLM 推論がメインスレッドから外れた**副次効果の確認が要る。

#### Swift 6 移行で発見した別件（2026-08-08 起票）

> SW6-3 の横断確認中に見つかった、**移行のスコープ外**の既存課題。どちらも移行で悪化したものではない。

| 状態 | タスク | 備考 |
|------|--------|------|
| [x] | SW6-A | ~~**メインスレッドでの同期フルデコード 2 箇所**~~ → **2026-08-08 完了**。着手時の調査で**起票時の想定 2 箇所 → 実際 3 箇所**と判明した（記録写真をフルデコード表示しているのは `PhotoThumbnailCell` 100pt / `PhotoDetailCell` 120pt / `CafePhotoHeader.ownPhotoCell` 224pt の 3 つで、**いずれも `LazyHStack` 横スクロール内**。長辺 2048px = 約 16MB/枚を `body` から同期デコードしており、再描画のたびに走ってキャッシュも効いていなかった）。**2026-08-07 に一覧の `CoffeeRowThumbnail` だけが直され、横展開されていなかった**のが構図。共通 View `Components/RecordPhotoThumbnail.swift` に切り出して 4 箇所を統合（ユーザー選択）。`ImageDownsampler` は `downsampledJPEG` を `@concurrent async` 化 + `downsampledImage`（Data → UIImage、JPEG 再エンコードなし）を新設。**対象外**: `CoffeeShareCardView` は 1080×1350px 出力なのでフルデコードが正しい | iosApp 完結 |
| [x] | SW6-B | ~~**`AppleSignInCoordinator` の `UIWindow()` が iOS 26 で deprecated**~~ → **2026-08-08 完了**。`presentationAnchor(for:)` のフォールバック（scene 探索 → `UIWindow(windowScene:)` → `UIWindow()`）を**丸ごと削除**し、`presentationAnchor` が nil なら `preconditionFailure` に変更（ユーザー選択）。呼び出し経路を追うと全パスが到達不能で、探索ロジックは `AccountView.currentPresentationAnchor()` と二重だった。実行パス 18 行 → 2 行。**これで iosApp のビルド警告が 0 件になった**（Debug / Release 両方） | iosApp 完結 |
| [-] | SW6-C | ~~**CI が `CURRENT_PROJECT_VERSION` を `xcodebuild` の引数で渡している**~~ → **2026-08-08 取り下げ（ユーザー判断）**。`release-testflight.yml` の archive ステップが `CURRENT_PROJECT_VERSION=${{ github.run_number }}` を渡しており、コマンドライン引数のビルド設定は**ターゲットを選ばず SPM 依存パッケージにも適用される**（lessons 2026-08-08 の sweep で検出）。ただし **CI の run_number をビルド番号に採用するのは意図した設計**で、TestFlight ビルドも通っているため対処しない。`SWIFT_VERSION` のような「依存先が対応していないと壊れる」設定とは性質が違う（`CURRENT_PROJECT_VERSION` は数値が渡るだけ） | — |

#### docs 棚卸し 第 2 巡（2026-07-27 / 未実施 doc への Phase 1 適用）

> 2026-07-25 の第 1 巡（data-model / implementation_note / kmp-bridge / architecture）で**触れていない 8 本**にコード突き合わせ（curate-doc Phase 1）を通した。行数閾値の超過は `data-model.md` 708 行のみで、今回の主目的は縮約ではなく**実装との乖離の検出**。検出は陳腐化 10 件 / 欠落 4 件 / コード側 2 件。
> - **coding-conventions** — iosApp ツリーの `App/` `Bridge/` `Extensions/` が 3 つとも実在しない（実態は直下 + `Utilities/` + `PreviewSupport/` + `Ads/`）/ 「Dispatcher は `shared/core` の `platform/` パッケージ」が実在しない（`expect` は `data-local` の 2 件のみ）/ 「`Bridge/` のヘルパを通す」を SKIE の呼び出し方向 + `FlowBridge.swift` に是正 / アンカーリンク 2 箇所を本文名指しへ
> - **ui-ux-guidelines** — 「将来 `sharedUI/` を実装する段階で」（実装済み）/ トースト集約の例に実在しない `locationManager.error`。ピン 6 種の意匠（白フチ・影・サイズ序列）は MP-1〜3 適用後の実装と一致を確認
> - **paid-services** — 広告 2 面の記述が「マップ検索ドロップダウン」のまま（2026-07-22 に下部シートへ移設済み。requirements §11-2 だけ追随していた）。Places の FieldMask / 写真枚数（3→3 ずつ・上限 10 / 400・200・150px）は一致
> - **root README** — `sharedLogic` の現在形 2 箇所 / `core` = 「Result / Logger / Dispatchers」（実体は AppContainer + Repository 合成）/ `sharedUI` モジュールの欠落
> - **app-store-metadata** — 2026-07-14 から残っていた「`PrivacyInfo.xcprivacy` の追随を要確認」を解消（アプリのコードは IDFA を読まないため manifest は据え置きで整合。App Privacy 申告とは別枠組み）/ 変更履歴の日付順の乱れ
> - **verification-checklist** — MP-1〜3（ピン意匠統一）の目視項目が無い → 追加
> - **requirements / analysis-model** — 陳腐化 0 件（機能 ID 2-13・5-5・5-6・11-x、4 タブ、~43 か国、統計定数 5 種、`RECOMMEND_MIN_RATING` まで照合し一致）
> - **data-model** — 708 行の閾値超過は**分割せず前文に例外理由を明記**する方針でユーザー確定（表現軸で切ると 1 エンティティの追随に複数 doc を往復することになる）
>
> 締めの機械検査（2026-07-27）: 節番号の dangling **0 件**（281 ファイルを照合。検出 5 件はいずれも「1 行に他 doc 名と自 doc の節番号が併存」による誤爆と、requirements §3/§4 の意図的欠番）/ code fence の対応 **全 doc 偶数** / doc 内のコード行番号参照は **live pointer 1 件を解消**（`SavedCafeListSheet.swift:78` → MP-4 として起票。残りは「この行番号が壊れた」等の史実記述）/ doc が名指しするファイル 186 種の生存確認（見つからない 19 件はプレースホルダ `N.sqm` / git 管理外 `Secrets.xcconfig`・`google-services.json` / 廃止済みを「旧」と明示した史実記述のみ）。
>
> 経緯は implementation_note 2026-07-27、教訓は lessons 2026-06-16 エントリへ再発実測として追記。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | ios-engineer: `iosApp/iosApp/ContentView.swift` を削除（KMP テンプレートの残骸。参照 0 件） | 2026-07-27 完了。`PBXFileSystemSynchronizedRootGroup` 採用のため pbxproj の編集は不要（削除も `rm` だけで足りることを実証）。implementation-note-archive 2026-07-03 の申し送り③「削除候補・要ユーザー確認」がここで解消 |
| [x] | ios-engineer: `AppleNearbyCafePin` の KDoc 是正（「小径 24pt」→ 実装は 28pt / 白フチ追加後の現状に合わせる） | 2026-07-27 完了。あわせて `SavedCafePin`（「既存 3 種ピン」= 現在 6 種で数え違い）/ `CuratedCafePin`（pt 値・5 色の列挙）も docs 参照へ置換。ピンは 4 → 5 → 6 種と増えるため、数え上げを書いた KDoc は追加のたび全件陳腐化する（`CuratedCafe.kt` 2026-07-25 と同方針）。**親がフラグ無しで `** BUILD SUCCEEDED **` を独立再確認** |

#### docs 棚卸し（2026-07-25 / curate-doc skill 制定と初適用）

> 500 行超で棚卸しするルールを制定（`curate-doc` skill + `check-file-size.sh`）し、3 doc に適用。
> - **data-model.md** 1246 → 708 行（陳腐化 6 件是正 + 欠落 2 件補完 → 縮約 → 分析系 3 節を `analysis-model.md` へ分離）
> - **implementation_note.md** 1273 → 840 行（`- 領域:` 廃止 + 系列統合 → 2026-06 の 36 件を `implementation-note-archive.md` へ凍結）。作業ログは行数閾値と相性が悪いため**フロー型は 1200 行 / 月次アーカイブ**運用に分離
> - **kmp-bridge.md** 573 → 455 行（陳腐化 6 件 → 縮約）。最大の検出は「SKIE を使わない場合」節 47 行が**実在しないコードの説明**だったこと（`FlowWrapper` / `Shared/Bridge` は 0 件）
> - **architecture.md** 589 → 438 行（陳腐化 3 件 + 欠落 2 件 → ビルドスクリプト・実装コードの逐語コピーを要点へ置換）。副産物で root `README.md` の旧ドメイン名 6 箇所を是正 + フック対象に README を追加
>
> 経緯は implementation_note 2026-07-25（3 エントリ）、教訓は lessons 2026-07-25。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `build-logic/.../kmp.feature.gradle.kts` の KDoc 陳腐化（「feature モジュールはまだ存在せず」「`feature/visit-list` を作るときに使う想定」）を是正 | 2026-07-25 完了。モジュール名は列挙せず「`settings.gradle.kts` を真とする」形へ。`kmp.library` は陳腐化なし、`android.library` は「適用する側はない」が今も事実（適用モジュール 0 件を親が grep で裏取り）のため変更不要と判断。親がフラグ無しで `:build-logic:convention:compileKotlin` + feature 2 モジュールの `compileKotlinIosSimulatorArm64` を BUILD SUCCESSFUL 再確認。commit `4cd45e1`（docs コミットに混入。下記 lessons 参照）|

#### data-model.md 棚卸しの是正（2026-07-25 起票 / 完了）

> `docs/data-model.md` をコードと突き合わせた棚卸し。**3 段**で実施し全て完了: ①陳腐化チェック（陳腐化 6 件是正 + 欠落 2 件補完。commit `4ae4885`）②縮約 1246 → 901 行（ソースの逐語コピーと経緯を排除。基準は doc 前文に明文化。commit `bc21dec`）③分析系 3 節を [`analysis-model.md`](./analysis-model.md) へ分離（data-model 901 → 708 行 + 新 doc 231 行。旧番号はリダイレクト表を残し、live pointer のみ張り替え = docs 24 + KDoc 19 箇所）。
> 副産物のバグ（エクスポートが `region` を落とす）は commit `bbf51c6` で修正済み。判断の経緯は implementation_note 2026-07-25、教訓は lessons 2026-07-25。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: エクスポート DTO の `region` 追随漏れ修正（`CoffeeRecordExportDto` + `CoffeeRecordExportMapper` に `region` 追加 + テスト） | 2026-07-25 完了。DTO / Mapper に `region` 追加 + `CoffeeRecordExportMapperTest`（全フィールド突合）新設 + 既存 `ExportCoffeeRecordsUseCaseTest` に region ケース。**親がフラグ無しで再検証**: `iosSimulatorArm64Test` 5 件 pass / `assembleSharedLogicXCFramework` BUILD SUCCESSFUL（public DTO 変更のため SKIE 経由のリンクまで確認）。6 経路の横断点検で **`scripts/seed/seed-coffees.mjs` の `toDocument`（明示 allowlist）も同じく `region` を落としていたため親が修正**（`--dry-run` で実測確認）。他フィールドの漏れは無し → lessons 2026-07-25 に記録し `.claude/rules/kotlin-kmp.md` のチェックリストへ昇格 |
| [x] | kmp-engineer: `CuratedCafe.kt` KDoc のピン記述を実装に合わせる（現 KDoc「amber + star、トグルなし常時表示」→ 実装は system orange + `cup.and.saucer.fill` + ズームゲート非表示あり） | 2026-07-25 完了。見た目の詳細（pt / SF Symbol）は KDoc に書き写さず §1.10 参照に留め、「トグル対象外だがズームゲートで非表示になりうる」という挙動要点だけ残した（domain モデルを iOS の見た目仕様に密結合させない = 再陳腐化の予防） |
| [x] | kmp-engineer: `BeanProfile.kt` KDoc の例示を日本語表記に（現「"Ethiopia"」「"Geisha"」「"Chocolate"」→ 2026-07-08 確定の日本語統一規約と不一致） | 2026-07-25 完了。あわせてクラス KDoc のマッチ方式記述も是正（`origin`（trim/lowercase）→ `OriginNormalizer.normalize` = trim + lowercase + シノニム辞書）。`flavorNotes` の「統一語彙から選ぶ・自由記述禁止」制約も明記（語彙 42 語は複製せず §3.2 参照） |

#### 産地サジェスト撤去の残骸削除（2026-07-31 起票 / 完了）

> エディタの産地サジェスト（2026-07-22 に産地ドロップダウン化で撤去）の名残で、呼び出し元ゼロのまま残っていた 4 シンボルを削除。`BeanProfileMatchUseCase` クラス本体は `SuggestUnexploredBeansUseCase` が内部で合成して使用中のため存続。経緯は implementation_note 2026-07-31。

| 状態 | タスク | 備考 |
|------|------|------|
| [x] | kmp-engineer: `AppContainer.beanProfileMatchUseCase` / `AppContainer.fetchBeanSuggestions` / `BeanProfileRepository.getByOrigin` + Android 実装を削除 | 2026-07-31 完了。59 行削除。`ExportCoffeeRecordsUseCase` KDoc の宙に浮いた `beanProfileMatchUseCase` 参照も `DeleteAccountUseCase` へ差し替え。フラグ無しで `:shared:framework:compileKotlinIosSimulatorArm64` + domain / core / data-firebase のテスト BUILD SUCCESSFUL |
| [x] | ios-engineer: `BeanProfileRepositoryIosImpl.__getByOrigin` とクラス doc の言及を削除 | 2026-07-31 完了。**親がフラグ無しで `xcodebuild ... -scheme iosApp` を `** BUILD SUCCEEDED **` 再検証**（`commonMain` の public API 削除のため = lessons 2026-07-25）。ios-engineer 側で `.swiftinterface` に `getByOrigin` が無いことも裏取り済み |

#### docs / 設計判断バックログ（後回し可）

> 2026-06-16 の docs 全体精査で洗い出した中・低優先の項目。いずれも今すぐ直さないと害が出る種類ではない。必要になったフェーズで着手する（経緯は [`tasks/lessons.md`](./tasks/lessons.md) 2026-06-16 エントリ）。
> 完了済み（2026-07-09 縮約）: B-3（07-01 requirements の API キー記述修正）/ B-5（07-08 CI グリーン確認）/ B-6（07-07 Persona テストの Native `.format` 置換で domain iOS テスト回復）/ B-7（07-09 `AccountViewModelTest` の `vm.clear()` + drain）/ D-2（07-04 architecture 書き込みフロー現行化）/ E-1（07-09 フェーズ 5.2 で成立）。F-1 はカテゴリ 4「リリース前バックログ」へ移管。詳細は git 履歴 / lessons。
> 追記（2026-07-12 実態突き合わせで解消確認）: B-2（「主要 VM が未テスト」が陳腐化 — 8 VM 中 7 つに commonTest あり、規約と実態の乖離は解消。未テストは `CoffeeDetailViewModel` のみ）/ C-1（「core 暫定置き場」運用は消滅 — 全 VM が最初から `shared/feature/*` 配下に配置済み）。

| 状態 | ID | タスク | 着手目安 / 備考 |
|------|----|------|----------------|
| [ ] | B-1 | マルチデバイス書き込みの競合解決方針を明文化（`updatedAt` での last-writer-wins 等）。現状 remote→local は `INSERT OR REPLACE` で世代比較なし | 複数端末同期（要件 7-3、優先度○）を実装・検証する段階。単一端末では実害なし |
| [x] | B-9 | `AppContainer` のクラス KDoc に書かれた Swift init シグネチャ 2 件が古い（`init(sqlDriver:remoteCoffeeDataSource:remoteSavedCafeDataSource:authRepository:placesApiKey:)` 等で `beanProfileRepository:` / `curatedCafeRepository:` が欠落）。**同ファイル内のセカンダリコンストラクタ KDoc とは矛盾している**（そちらは正しい）。実引数は プライマリ 9 / iOS 8 / Android 7 | 2026-08-01 の implementation_note 棚卸しで検出（Phase 1 = コード側の誤り）。**シグネチャを書き写さず「セカンダリコンストラクタの KDoc を参照」に寄せる**のが再発防止（数え上げ・列挙は依存追加で全滅する）。**2026-08-01 完了**。着手時に親が KDoc 側の横断点検を回し、**同型 3 件を検出して同じ dispatch に合流**（`AppContainer:115` の「8 引数」/ `AnalysisViewModel` の同一ファイル内「3 種」vs「4 種」矛盾 / `MapViewModel` の序数「第 4 種ピン」= 現在 6 種 + 廃止済み「検索タブ」）。さらに sweep 残りの `DummyCoffeeData` を「固定データだから変わらない」で除外しかけたが実測したところ**実数不一致 3 箇所**（その他 18→20 / 産地 8→9 種 / 焙煎度 null 3→4 件）。**親が数え直して全件を独立確認 + フラグ無し `BUILD SUCCESSFUL` を再検証**。全件 KDoc / コメントのみで実行コード差分ゼロ。lessons 2026-08-01 に追記 |
| [x] | B-8 | レビュー依頼（9-8）の `.onChange` 経路を `.task(id:)` へ作り替える。現状 `AnalysisView` の `.onChange` は `Task { }` で非構造化タスクを起こすため、1.5 秒の遅延中にタブを離れてもキャンセルされず**他タブの上にダイアログが出うる**（`.task` 経路は `Task.isCancelled` で抑止済み） | 2026-08-01 起票・**同日完了**。`.task` + `.onChange` の 2 経路を `.task(id: readiness?.hasAnySignal)` 1 本に統合（`.task(id:)` は 表示時 / id 変化時 / ビュー消滅時のキャンセル をまとめて satisfy するため 2 経路のカバレッジを包含）。**横断点検で `CoffeeEditorView` の写真取り込みにも同型 1 件**を検出し同時に是正（実害は「閉じたエディタのために最大 10 枚のデコードを続ける」資源の無駄で、ファイルは漏れない）。`grep -rn -A3 "\.onChange(of:" iosApp \| grep "Task {"` が **0 件**に。**親がフラグ無しで `** BUILD SUCCEEDED **` + Gradle タスク実行 + error 0 件を再検証**。一般則を `.claude/rules/swift-ios.md` へ昇格、lessons 2026-08-01 記録 |
| [x] | B-4 | `rating=0.0`=「未評価」の暗黙 sentinel を解消し、`CoffeeRecord.rating` を **nullable 化する**（2026-07-12 ユーザー決定） | 2026-07-13 完了。あわせて未評価のまま保存可に変更（従来はエディタで評価必須 = requirements と矛盾していた）。migration 5（0.0→NULL、JVM / NativeSqliteDriver 両方でテスト実証）+ Firestore は読み側で legacy 0.0 正規化。requirements §未決事項も消し込み済み。判断は implementation_note 2026-07-12、SQLDelight migrate の off-by-one は lessons 2026-07-13。**シミュレータ目視（未評価保存 → 表示 → 分析除外 → 既存 DB の migration）はユーザー作業** |
| [x] | D-1 | `ui-ux-guidelines.md` の写真サムネ記述に「Places 写真は永続キャッシュ禁止（規約）、ローカル写真とは読み込み方針が違う」旨を補足 | 2026-07-26 完了。「写真表示」節に記録写真 / Places 写真の対比表（取得元・キャッシュ・表示枚数・失敗時・アクセシビリティ）を追加し、実装（`PhotoFileStore` / `PlacePhotoLoader` / `PlacePhotoThumbnail`）と突き合わせて記載。**旧記述「一覧では `AsyncImage` または独自のキャッシュ画像 View でサムネイル表示」が Places 写真に適用すると規約違反を誘発する**ため削除。枚数上限は複製せず `paid-services.md` 参照 |

#### MapTabView の分割リファクタ（God View 解体 / 2026-07-24 起票）

> `iosApp/iosApp/Features/Map/MapTabView.swift` が 2008 行、うち `MapTabView` 1 struct が約 1770 行（`@State` 30 個 + メソッド約 50 個）に肥大化。複数の独立責務（検索 / Apple 周辺カフェ / ピン描画 / 位置・カメラ / 選択カード / フィルタ）が単一 View に同居し変更影響が読めない。**方式=独立 View 構造体（+ 一部 `@Observable` サービス / extension）、スコープ=Phase 0–4 全部**（2026-07-24 ユーザー決定）。各フェーズ独立でビルド＆シミュレータ確認＆コミット、実装は `ios-engineer` に 1 フェーズ = 1 dispatch。目標: `MapTabView.swift` ルートを ~500 行（State + body + mapContent の組み立てのみ）へ。挙動リグレッション（カメラ・検索シート detent・エリア検索ボタン出現条件）を招きやすいので `verify-kmp-ios` 必須。

| 状態 | ID | フェーズ | 内容 | リスク |
|------|----|--------|------|--------|
| [x] | M-0 | Phase 0 | 既に独立している `RecommendationMatchSheet` + `preferenceMatchAxisLabel` + `CafeDetailRoute` を別ファイルへ純粋移動（本体無変更）。2026-07-24 完了: `RecommendationMatchSheet.swift` / `MapNavigation.swift` 新設、192 行移動で 2008→1816 行。ビルド成功（フラグ無し） | 極小 |
| [x] | M-1 | Phase 1 | リーフ View 抽出。2026-07-24 完了: `MapPins.swift`（ピン6種 + `ApplePoiCafe`）/ `CafeSelectionCard.swift` / `MapFilterChipRow.swift` / `MapSearchResultsSheet.swift` / `MapTabView+PinResolution.swift` の 5 ファイルへ抽出。状態は init 引数/Binding で受け渡し。MapTabView.swift 1816→1223 行。親のフラグ無しクリーンビルドで `BUILD SUCCEEDED` 再検証済み。シート detent 状態は親残置（→ implementation_note 2026-07-24、Phase 3 で再検討） | 低 |
| [x] | M-2 | Phase 2 | Apple POI fetch を `@MainActor @Observable final class AppleNearbyCafeLoader` へ隔離。2026-07-24 完了: デバウンス300ms/キャンセル/ズームゲート/スロットリング耐性/ネガキャッシュ/名前フィルタを1対1移設。zoomGate しきい値は `AppleNearbyCafeLoader.zoomGateRadiusMeters` に定義集約し `displayedCuratedCafes` から参照。dedup は `Loader.displayed(excluding:)` に既存座標を引数渡し（bridge 非依存）。MapTabView.swift 1223→1132 行。親のフラグ無し再検証で `BUILD SUCCEEDED` | 中 |
| [x] | M-3 | Phase 3 | 検索 + エリア検索を `@MainActor @Observable final class MapSearchController` へ。2026-07-24 完了: `MapSearchController.swift` 新設。camera 移動は `onRequestCamera`、キーボード解除は `onDismissKeyboard` のコールバック注入で SwiftUI 固有要素から分離。`@State` 初期値式から `self` 参照不可のため、コールバックは `.task`（searchBridge 生成と同じ初回ガード）内で `configureCallbacks` 事後配線（→ implementation_note 2026-07-24）。detent は M-1 と同じ FAB 二重消費理由で View 残置。MapTabView.swift 1132→968 行。親のフラグ無し再検証で `BUILD SUCCEEDED` | 高 |
| [x] | M-4 | Phase 4 | 位置・カメラ（`currentLocationFAB` / `recenterToCurrentLocation` / `setupLocation` / `locationStream` / `setInitialCameraFromVisitedCafes`）を `MapTabView+Location.swift`（`extension MapTabView`）へ機械移動。2026-07-24 完了: 170 行移動で 968→798 行。extension 参照のため `cameraPosition`/`locationManager`/`didSetInitialCamera`/`pendingRecenter` を internal 化。親のフラグ無し再検証で `BUILD SUCCEEDED`。**分割完了: MapTabView.swift 2008→798 行（60%減）** | 低 |

#### マップピンの主従関係の是正（2026-07-27 起票）

> ユーザー指摘: おすすめ（curated）ピンが訪問済みピンより目立つ。原因は色ではなく**白フチの非対称** — `CuratedCafePin` / `AppleNearbyCafePin` には `Circle().stroke(Color(.systemBackground), lineWidth: 1.5)` があるが `VisitedCafePin` には無く、36pt vs 34pt のサイズ差が打ち消されている。訪問済みに白フチを足して主従を戻す。**色は変更しない**（curated = `Color.orange` の色セマンティクスは維持）。
>
> 検討して見送った案（2026-07-27）: ① ロースト ランプ流用（訪問済み = イタリアン / おすすめ = ハイ）→ イタリアン #3A230D はダーク地図で 1.06:1 と同化、ハイ #8A715C は accent #8B5A2B と輝度 1.28:1 でほぼ同色。2026-07-18 に burnt orange が「訪問済みの茶と誤認」で orange へ戻した経緯の再演になるため不採用。② curated を mint 等の寒色へ変更 → まず①のフチ調整だけで足りるか見る（ユーザー判断）。
>
> MP-1 の目視確認後、**6 ピン全体でフチが不揃い**（当時 3/6 のみ）と判明したため MP-2 で統一（2026-07-27 ユーザー決定）。規則は ui-ux-guidelines「ピンの意匠ルール」に昇格、教訓と sweep 結果は [`tasks/lessons.md`](./tasks/lessons.md) 2026-07-27。

| 状態 | ID | タスク | リスク |
|------|----|------|--------|
| [x] | MP-1 | ios-engineer: `VisitedCafePin` に白フチ（`Circle().stroke(Color(.systemBackground), lineWidth: 1.5)`）を追加。他ピン・色は無変更 | 2026-07-27 完了。1 行追加のみ（`.frame` 直後・`.shadow` 直前 = 既存 2 ピンと同じ挿入順）。フラグ無しで `BUILD SUCCEEDED`。訪問回数バッジは `ZStack` 全体への `.overlay(alignment: .topTrailing)` なので常にフチの上に描画され、欠け・被りは構造上起きない。**2026-07-27 ユーザー目視確認済み**（主従が戻り、バッジ近傍の見え方も問題なし）。commit `b685c56` |
| [x] | MP-2 | ios-engineer: 残り 3 ピン（`RecommendedCafePin` / `SavedCafePin` / `SearchResultPin`）にも白フチを追加し、全 6 ピンで統一。色・サイズ・影は無変更 | 2026-07-27 完了。3 行追加のみ、挿入位置は既存 3 ピンと同順。フラグ無しで `BUILD SUCCEEDED`。`SearchResultPin` の選択時 `scaleEffect(1.3)` はフチ線幅も 1.95pt 相当に拡大するが、直径も 41.6pt に拡大するためフチ比率は約 4.7% で一定（周辺ピンの 5.4% より細い）→ 相似拡大であり修正不要と判断。**2026-07-27 ユーザー目視確認済み** |
| [x] | MP-3 | ios-engineer: `CuratedCafePin` の影を `opacity(0.5)` → `0.4` に揃える（他の意味ピンと同値。影は仕様外の暗黙強調だった） | 2026-07-27 完了（MP-2 の目視後にユーザー判断で着手）。数値 1 点のみ変更、`radius: 4 / y: 2` は不変。フラグ無しで `BUILD SUCCEEDED`。これで意味ピン 5 種が白フチ・影ともに完全に揃い、強弱はサイズと色だけが担う状態になった（`SearchResultPin` の選択時 0.6 / `AppleNearbyCafePin` の 0.25 は規則上の意図的な例外）。**2026-07-27 ユーザー目視確認済み** |
| [x] | MP-4 | ios-engineer: `SavedCafeListSheet` の「記録あり」バッジが `.brown` 直書きで孤立している（`visitedCafePin` の brown → accentColor 化に未追随）。**訪問済みの意味なので `Color.accentColor` へ揃える**（ui-ux-guidelines「マップ概念の色セマンティクス」の「ブランド / 訪問済み」行）。色 1 点のみ、他は無変更 | 2026-07-27 完了。1 行のみ（`.foregroundStyle(.brown)` → `Color.accentColor`）。**親がフラグ無しで `** BUILD SUCCEEDED **` を独立再確認**。起源は implementation_note 2026-07-06 の「後続候補」で、棚卸しの行番号検査（live pointer の掃除）で拾い上げた。**横断点検で同型 5 箇所を検出**（下記 MP-5 として分離）。ライト / ダーク両方の目視はユーザー作業 |
| [x] | MP-5 | オンボーディング系 2 画面の `.brown` 直書き 5 箇所を `Color.accentColor` へ揃えるか判断する（`DataConsentOnboardingView` = 見出しアイコン / 目的リスト 3 アイコン / CTA の `tint`、`AdPrePromptView` = 見出しアイコン / CTA の `tint`）。ui-ux-guidelines「カラーの役割定義」は**アプリ全体**で「アクセント = `.accentColor`」と定めており、`.brown`（固定色）は AccentColor（light #8B5A2B / dark #C08552）と一致しないためダークで色がずれる | 2026-07-27 完了（**5 箇所すべて揃えるでユーザー確定**）。`purposeRow` は 3 アイコン共通のヘルパなので実変更は 2 ファイル 5 差分。色のみで文言・レイアウト・アクセシビリティは無変更。`AdPrePromptView` だけ brown 維持の案も出したが、直前の同意オンボーディングと地続きの導入フローなので統一を採った。**`.brown` 直書きは `iosApp/**` から 0 件**（親が grep で独立確認）、**親がフラグ無しで `** BUILD SUCCEEDED **` を独立再確認**。両 View の `#Preview` を Light / Dark 2 本立てにして目視しやすくした。**目視はユーザー作業**（初回起動フローのため、アプリ削除 → 再インストールが要る）|

### 完了

#### CoffeeEditorView 分割（2026-07-24 完了）

> `CoffeeEditorView.swift` 859 行を 4 ファイルへ分割。フォーム系 View のため `extension CoffeeEditorView` を UI セクション用（`+Sections`）と写真非同期処理用（`+Photos`）に分け、`PhotoThumbnailCell` は独立ファイルへ純粋移動。別ファイル extension から参照する `@State` / メンバは internal 化。`CoffeeEditorView.swift` 859→277 行、全ファイル 800 以下。coding-conventions §3.4 の適用例（3 例目）。親のフラグ無し再検証で `BUILD SUCCEEDED`。

#### AnalysisView 分割（2026-07-24 完了）

> `AnalysisView.swift` 1929 行を責務別 7 ファイルへ分割。既に 18 サブビューへ分解済みだったため純粋移動 + `extension AnalysisView`（統計チャート系）抽出のみ（低リスク）。`AnalysisQaViews` / `AnalysisInsightViews` / `AnalysisSignalViews` / `AnalysisBeanViews` / `AnalysisView+Statistics` / `AnalysisView+Preview` に切り出し。別ファイル extension から参照する `private` メンバは internal 化。`AnalysisView.swift` 1929→266 行、全ファイル 800 以下。coding-conventions §3.4 分割規約の適用例（MapTabView 分割 M-0〜M-4 の続き）。親のフラグ無し再検証で `BUILD SUCCEEDED`。

#### CoffeeEditorViewModel 分割（2026-07-25 起票）

> `CoffeeEditorViewModel.kt` 896 行を 3 ファイルへ分割。KMP 側で初めて 800 行超が出たケース（Swift の View 分割 3 件に続く）。**Kotlin のクラス本体は分割不可**（`extension` で複数ファイルに割れる Swift と異なる）ため、クラスに閉じる必要のない純粋ロジックを top-level 関数として同一パッケージの兄弟ファイルへ抽出する方式。Swift Bridge / 公開 API 無変更・振る舞い不変。① `CoffeeEditorViewModel.kt`（クラス本体、~665 行）② `CoffeeRecordBuilder.kt`（`validate` / `buildRecord` / `buildCafe` / `CafeSnapshot` を純粋関数化、暗黙参照していた mode / initialRecord / selectedCafe を引数注入、~130 行）③ `CoffeeEditorMapping.kt`（`toDraft` / `toDuplicateDraft` / `clamped` / `clampTasting` + companion の `defaultDraft` を移動、~110 行）。nested 型（`Mode`/`UIState`）の top-level 化は Swift 公開名が変わるため不採用。domain UseCase 昇格は `CoffeeDraft`（feature 層 draft）依存のため見送り。coding-conventions §3.4 の KMP 版適用例。

| 状態 | ID | 内容 | リスク |
|------|----|------|--------|
| [x] | CE-1 | kmp-engineer: `CoffeeEditorViewModel.kt` を 3 ファイルへ分割（純粋関数の top-level 抽出 + 引数注入）。2026-07-25 完了: `CoffeeEditorViewModel.kt` 896→695 行 / `CoffeeRecordBuilder.kt` 141 行（`validate`/`buildRecord`/`buildCafe`/`CafeSnapshot`、mode/initialRecord/selectedCafe を引数注入）/ `CoffeeEditorMapping.kt` 88 行（`toDraft`/`toDuplicateDraft`/`clamped`/`clampTasting`）。`DEFAULT_COFFEE_NAME` と `defaultDraft()`（Swift Bridge が `companion.defaultDraft()` で参照する public メンバ）は companion 残置。**初回に `defaultDraft` を top-level internal 化して Swift ビルドを壊し companion へ戻した**（→ lessons / implementation_note 2026-07-25）。`CoffeeEditorViewModelTest` 20/20 無改変 green + 親のフラグ無し XCFramework link + iosApp 実 Swift ビルド `BUILD SUCCEEDED`。全ファイル 800 以下 | 低 |

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

#### docs 敵対的レビューの指摘対応（2026-07-25）

> `docs/**` 全体をコード・CI・git 状態と突き合わせた敵対的レビューで検出した高重要度 7 件を是正。**CI の穴（#3）が実害あり**: Android ジョブが `:shared:data-local:testAndroidHostTest` 1 モジュールしか指定しておらず、domain / core / feature/* の commonTest 300 件超が PR チェックで未実行だった。判断は implementation_note 2026-07-25 CI エントリ。

| 状態 | ID | 内容 | 備考 |
|------|----|------|------|
| [x] | #1 | `tasks.md`「広告導入」/「CI リリースへの本番 AdMob ID 注入」の本番 AdMob ID 状態を実態へ是正 | 「未発行」→ **発行済み**（値は git 非追跡の `docs/admob-setup-todo.md`）。`Secrets.xcconfig` ではコメントアウトしてデモ ID 運用中。ユーザー作業 2 行を `[x]` へ |
| [x] | #2 | `app-store-metadata.md` §6.3 の AdMob 行から撤去済み 2 面（記録 / 分析タブ）を削除 | 審査申告に転記する原稿。実装していない面の申告を防ぐ |
| [x] | #3 | `ci.yml` のテスト対象を `testAndroidHostTest` 一括指定へ + architecture / implementation_note の CI 記述を実態化 | ローカル検証: **360 件・37 クラス全 green**（`errors=0 / failures=0`）。iOS 側 `xcodebuild` が CI 非対象である点も architecture に明文化 |
| [x] | #4 | `coding-conventions.md` §1.3 のドメインモデル例を `rating: Double?` へ（B-4 追随） | 「0.0 = 未評価 sentinel」の旧例をコピーされると sentinel が復活するため |
| [x] | #5 | `kmp-bridge.md` の `PreferenceMatchAxis` を 4 値へ（`Processing` 追加、2026-07-20 追随） | 「`default` なし全網羅」と書いた箇所で case 欠落＝記述どおり書くとコンパイルエラーだった |
| [x] | #6 | `data-model.md` §4.2 の `runRemote` サンプルを `runCatching` → `try/catch` + `CancellationException` 再スローへ | 実コードは元から正しい。docs だけが自プロジェクトの禁止パターン（coding-conventions §1.7）を例示していた |
| [x] | #7 | `data-model.md` §2.1 の `upsert` に `brew_recipe` 列を追加（実体 `CoffeeRecord.sq` と一致） | 列 30・プレースホルダ 30 に是正。lessons 07-07「列追加は Mapper と upsert 両方」の再発防止 |

> 未対応で残した指摘（重要度中）: 2026-07-24 の機能変更 3 件が tasks.md 未起票 / `admob-setup-todo.md` の除外が `.git/info/exclude`（ローカル限定）/ coding-conventions §1.4 とデフォルト引数の SKIE 制約の衝突 / app-store-metadata §7「共有機能なし」と 2-12 共有カードの不整合。着手時は本セクションを起点にする。
> **解消（2026-07-25）**: 「`verification-checklist.md` が 2026-07-08 以降未更新」→ 目視 QA を checklist に完全集約し（tasks.md の目視行 19 本を移送・削除）、陳腐化 2 件（行番号参照 / マップ検索の旧 UI 記述）も是正した。

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
| [x] | **ガイドライン 5.1.1(i): プライバシーポリシーにアプリ内から到達できない**（2026-08-07 起票・実装完了）。設定画面に**プライバシーポリシー / サポート**の 2 リンクを追加する | **リジェクト実績のある条項**。「App Store Connect のメタデータ**と**アプリ内のアクセスできる場所」の両方が要求される。現在のアプリ内リンクは `DataConsentOnboardingView.swift:86` の 1 箇所のみで、この画面は Firestore `users/{uid}` が未作成のときしか出ない（`AppState.checkConsentOnboarding`）。同意・拒否のどちらでも doc が作られるため **2 回目以降の起動では到達不能**。`SettingsView` の「データとプライバシー」セクション（同意トグルの隣）に置く。サポート URL も同時に入れて 1.5（デベロッパ連絡先）を厚くする。URL は app-store-metadata §6.4 が正。iosApp 完結。**2026-08-07 完了**: `SettingsView` の「データとプライバシー」に 2 リンク追加、URL は新設 `Utilities/LegalLinks.swift` に集約して `DataConsentOnboardingView` 側のリテラルも差し替え（重複解消）。**2026-08-07 にユーザーが目視確認済み**（設定 → 2 リンクが Safari で開くこと）|
| [x] | **ガイドライン 5.2.2 / Google Maps Platform ポリシー: 帰属表示が皆無**（2026-08-07 起票・実装完了）。①Places データ表示画面に **Google Maps 帰属**、②写真に**作者帰属（`authorAttributions`）** | Places のコンテンツを **Google マップ以外（本アプリは Apple MapKit + 自前 UI）に表示する場合、Google Maps ロゴ（狭ければ「Google Maps」テキスト）が必須**。写真は「表示する際は常に作者をクレジットする」と明記（[Places ポリシー](https://developers.google.com/maps/documentation/places/web-service/policies) を 2026-08-07 に一次確認）。`grep` 実測で該当表示 **0 件**。②は `Cafe` が `photoReferences: List<String>` しか持たず帰属をモデルに載せていないのが原因で、FieldMask は `places.photos` を丸ごと要求済み（`PlacesClientImpl.kt:245`）なのでレスポンスには含まれている。**写真参照を永続化している以上、帰属も永続化しないと DB スナップショット由来の表示が無帰属になる** → `photoReferences` と同型で `Cafe` に列追加（`CoffeeRecord.sq` / `SavedCafe.sq` の 2 テーブル + migration 7 + Firestore キー、migration 6 の `region` 追加と同型）。**未リリースでスキーマ変更が最も安いタイミングのため一括対応をユーザー確定**（2026-08-07）。審査より **Google 側の是正要求 → API キー停止**のほうがリスクが大きい。関連: `CoffeeRecord` への `Cafe` スナップショット永続保存自体もポリシー上グレー（無期限保存が明示的に許されるのは place ID のみ）だが、記録アプリの成立要件のため今回は対象外。**2026-08-07 完了**: KMP = `Cafe.photoAttributions`（`photoReferences` と同じ順序・長さ / 作者不明は空文字）+ Places パース 3 経路 + SQLDelight 2 テーブル + `migrations/7.sqm` + Android Firestore mapper。iOS = 新設 `GoogleMapsAttributionText` を **4 面**（カフェ詳細 / マップ検索結果シート / ピン選択カード / エディタのカフェ検索シート）+ `CafePhotoHeader` に作者バッジ + Swift Firestore mapper 追随。`scripts/seed/seed-coffees.mjs` の allowlist も追随（**空配列は `dropNullKeys` をすり抜けるので `undefined` に潰す**）。**出さない面の線引き**（記録一覧 / 記録詳細 / 共有カード / 保存済みリスト = 保存済みスナップショットの表示なので対象外）と、**小サムネイルの作者帰属を省略した根拠**（ポリシーの「スペースが限られる場合、より大きな版で完全な帰属にアクセスできれば省略可」/ タップ → カフェ詳細で到達可能）は implementation_note 2026-08-07。**親が独立再検証済み**（フラグ無し `xcodebuild` で `** BUILD SUCCEEDED **` / `iosSimulatorArm64Test` 3 モジュール green / `verifyCommonMainAppDatabaseMigration` を `--rerun` で強制実行し成功）。教訓 2 件を lessons 2026-08-07 に記録し横断点検も実施。**2026-08-07 にユーザーが目視確認済み**（4 面の帰属表示 + 写真の作者バッジ）|
| [x] | **ガイドライン 5.2.1: ライセンス表示の欠落**（2026-08-07 起票・実装完了）。`LicensesView` に **Google Mobile Ads SDK / UMP SDK / Google Places** を追加 | 現在の 7 件（`LicensesView.swift:16-24`）は Firebase / SQLDelight / Ktor / kotlinx 3 種 / SKIE のみ。GoogleMobileAds は Apache 2.0 ではなく Google 独自条項で帰属表示義務がある。上記の Google Maps 帰属と同じ dispatch で処理した。**2026-08-07 完了**: 3 件追加。**`Apache 2.0` と書かないこと** — SPM パッケージの `Package.swift` は Apache 2.0 だが、それはバイナリを取得するだけのラッパー層で、実体の `GoogleMobileAds.xcframework` は AdMob 利用規約（独自条項）。Places は SDK 同梱ではなく REST 利用なので Google Maps Platform 利用規約。**2026-08-07 にユーザーが目視確認済み**（設定 → 2 リンクが Safari で開くこと）|
| [x] | **アカウント削除の消し残しを是正**（2026-08-06 起票・実装完了）。削除後の Firestore に **`users/{uid}` ルート doc と `savedCafes` が残る**（`coffees` のみ消えていた） | **リリースブロッカー**。verification-checklist パス 6 の実機検証中にユーザーが発見。公開済みプライバシーポリシー（「アカウント削除により削除されます」）/ 要件 1-4 / ガイドライン 5.1.1(v) に違反し、Rules（`request.auth.uid == uid`）の構造上**本人が二度と消せない永久孤児**になる。修正は `DeleteAccountUseCase` を 4 段（savedCafes → coffees → ルート doc → `deleteAuthUser`）にし、`AuthRepository.deleteUserProfile()` を 1 本追加。**順序が仕様**（Firestore はサブコレクションをカスケードしない / Auth 削除後は配下へ到達不能）。savedCafes 側は既存 API の再利用で足り、SQLDelight もプラットフォーム実装も無変更。**「coffees は好み分析用に残す」案は不採用**（ポリシー矛盾 + 個人紐付きデータの保持。将来は 12-D の枠組みで同意 + 非個人化 + ポリシー改訂をセットで）。経緯は implementation_note 2026-08-06、削除範囲の正本は data-model §3.1。**親が独立再検証済み**（`testAndroidHostTest` + `iosSimulatorArm64Test` 両ターゲット green / フラグ無し `xcodebuild` で `> Task :shared:framework:...` を伴う `** BUILD SUCCEEDED **`）。テストは各ステージの早期中断を 3 系統でカバー（特に `deleteUserProfile` 失敗時に `deleteAuthUser` を呼ばないこと）。**残る実機検証は verification-checklist パス 6**（合否条件を具体化済み）。**既存の孤児データは 2026-08-06 にユーザーが Firebase Console から手動削除済み**（Rules 上クライアントからは到達できないため手動が唯一の手段。未リリースのため実ユーザー分は存在しない） |
| [x] | **アプリが「英語バンドル」として振る舞う不具合の是正 + 暦法依存バグ 2 件**（2026-08-06 起票・完了）。エディタの `DatePicker` が日本語端末でも `Aug 6, 2026` と英語表記になる | **App Store スクリーンショット撮影中に発見**（実装と無関係な作業でなければ提出まで気づかなかった）。原因は有効ローカライゼーションが `en` のみで iOS が `Locale.current` を英語にフォールバックすること。`developmentRegion` = `ja` / `knownRegions` に `ja` / `CFBundleLocalizations = [ja]` の 3 点で是正（`.lproj` は新設せず、文言は不変）。**親がフラグ無しで `** BUILD SUCCEEDED **` + 成果物 `Info.plist` の実読み（`CFBundleDevelopmentRegion = ja` / `CFBundleLocalizations = [ja]`）を独立再確認**、ユーザーが実画面で日本語表記を確認。**横展開点検が 2 件の暦法依存バグを掘り当てた**: ①`SettingsView` の `DateFormatter` に `locale` 未設定（和暦端末でエクスポート名の年がずれる。**この `ja` 化で顕在化しうる状態になっていた**）②**`CoffeeEditorView` の `LocalDate ↔ Date` 変換が `Calendar.current`** — 親の PoC 実測で表示 `2026-08-06` → **`4044-08-06`**、Firestore 保存値 **`0008-08-06`** と**永続データが壊れる**性質と判明（プロジェクト初期から存在。未リリースのため被害なし）。`Calendar(identifier: .gregorian)` 固定で是正。教訓 3 件を lessons 2026-08-06 に記録、`.claude/rules/swift-ios.md` へ 2 件昇格 |
| [x] | **App Store スクリーンショットの撮影（6.9" のみ / 6 枚）** | 2026-08-06 完了。**6.5" は不要**と Apple 公式で確認し §5 を是正（6.9" を出せば ASC が自動縮小。撮影枚数が半分になった）。iPhone 17 Pro Max / iOS 26.5 で撮影し `screenshots/6.9/` に配置、全枚 1320×2868 を `sips` 実測。**7 枚計画 → 6 枚構成へ変更**（記録詳細と「行きたい」リストを落とし分析を 2 枚に。ユーザー確定）。撮影中に**リリースブロッカーを 3 件検出**（上行のロケール / 暦法バグ）。`06-cafe-detail.png` は初回に **AdMob のテスト広告が写り込み**差し替え、`05-record-editor.png` はロケール修正後に撮り直して日付が `2026/08/06` になったことをスクショ自体で実証。提出用のアルファ除去は `screenshots/flatten-alpha.swift`（出力 `screenshots/submit/` は git 非追跡） |
| [x] | **おすすめカフェ（`curatedCafes`）を 9 県へ拡張**（2026-07-28 起票 / ユーザー確定）。東京 + 大阪 / 京都 / 神奈川 / 愛知 / 福岡 / 北海道 / 千葉 / 埼玉 | **47 県フルはやらない**（地方は評価 4.4・レビュー 100 件の基準を満たす店が 30 件に満たず人気枠のチェーンで埋まる + 30 日ごとのリフレッシュコストが県数に線形）。2026-07-28 に生成 → レビュー → 投入までユーザー実行済み（**453 件**）。その後の点検で**大手チェーン 33 件の混入**を検出 → `EXCLUDED_NAME_KEYWORDS` を 10 語拡充して 32 件除去（`STARBUCKS RESERVE ROASTERY TOKYO` のみユーザー判断で残置）→ **421 件**。2026-08-01 に除去後 JSON で再投入までユーザー実行済み（**Firestore = 421 件**）。目視確認は verification-checklist へ |
| [x] | **`beanProfiles` の本番 Firestore 投入状況を確認**（未投入なら投入） | **2026-07-30 にユーザー投入済み（38 件）**。本行は下記「BeanProfile 初期データ整備」と二重管理になっており、投入完了が反映されないまま残っていた（2026-08-01 是正）。備考にあった「エディタの産地サジェスト」は 2026-07-22 の産地ドロップダウン化で**撤去済みの機能**。残る目視は verification-checklist 15-E-3 で、seed は `CoffeeOriginCatalog` 43 か国のうち 21 産地しかカバーしないため `bestOrigin` が未カバー国に落ちると投入済みでも空になる点に注意 |
| [x] | プライバシーポリシー / サポートページの公開（記録データをサービス改善に使用する旨の明記） | 本文は 2026-07-21 起草、**2026-08-06 に GitHub Pages で公開**（`.github/workflows/pages.yml` / `docs/legal/` のみを配信し設計 doc は Web 公開しない）。名義 = `noricoffee`、2 ページを相対パスで相互リンク、`index.html` 新設でルート 404 回避。アプリ内の `https://example.com/privacy`（404）も実 URL へ差し替え（`DataConsentOnboardingView`、親がフラグ無し `** BUILD SUCCEEDED **` 再確認）。副産物: **起草者向けの指示文が本文に残っていた**（§5 の `.note` div「※ App Store の年齢レーティング設定と整合させてください」）ため削除 — 公開すればユーザーに見える状態だった。サポート用メールアドレス（`noricoffee593@gmail.com`）も同日に発行・反映し**プレースホルダは全て解消**。9-6 協調フィルタ（未実装）は実装着手時に追記。URL は app-store-metadata §6.4 |
| [x] | **F-1**: `PrivacyInfo.xcprivacy` のアプリ全体 Required Reason API 網羅監査（File Timestamp / System Boot Time / Disk Space 等）。フェーズ 18 では UserDefaults（`CA92.1`）+ テレメトリ集計データ種別のみ宣言済み | 2026-07-12 完了。Swift 側 = UserDefaults のみ（宣言済み）。**`SharedLogic`（K/N ランタイム）が stat 系 6 シンボルをリンク**（`nm -u` 実測）→ FileTimestamp **C617.1** を追加宣言。Boot Time / Disk Space / Keyboard 該当なし、Firebase は SDK 同梱マニフェストで自己申告済み。`plutil -lint` OK。判断は implementation_note 2026-07-12 |
| [x] | 逆変換 PoC 導線（分析タブ最下部の `TastePreferenceConversionView` への NavLink）を本番に含めるか判断する（含める / 設定の開発者向けへ移動 / 削除） | 2026-07-12 ユーザー決定: **本番に含める**。FM 非対応端末では `makeIfAvailable()` ガードで導線非表示をコード確認済み（`AnalysisView.swift`）→ 追加実装なし。判断は implementation_note 2026-07-12 |
| [x] | **アプリアイコン / LaunchLogo の刷新**（2026-08-06 起票・完了）。「コーヒーだけで Vision 感がない」というユーザー指摘が発端だが、着手時に**より重い問題**が判明 — 旧実装は SF Symbol `cup.and.saucer.fill` を PNG に焼き込んでおり、**SF Symbols のライセンスがアプリアイコン / ロゴでの使用を禁じている**。新意匠「アイライン（アーモンド型輪郭）の中にカップ」を全て `NSBezierPath` で自前描画 | 意匠は候補 11 案をレンダリングして比較のうえユーザー確定。親が参照 PNG を先に作り、`ios-engineer` の生成物と**バイト一致**で検証（3 枚とも一致）。`grep -rn "systemSymbolName" iosApp/` = **0 件**。親がフラグ無しで `** BUILD SUCCEEDED **` を独立再確認。light の背景下端色が `#5A3A22` → `#4E3020` に変更。**ホーム画面での小サイズ判別性 / 起動画面ロゴの中央配置 / light・dark・tinted の 3 バリアントは 2026-08-06 にユーザー目視確認済み**（verification-checklist からは規約どおり削除）。経緯と計測手法は implementation_note 2026-08-06、規約への反映は ui-ux-guidelines「アイコン」/ `.claude/rules/swift-ios.md` |

### 未完あり

#### ASO / グロース（2026-07-27 起票 / 残り ※保留）

> **2026-08-01 現在: 残る ASO-4 / ASO-5 / ASO-7 は保留**（ユーザー判断）。実装系は ASO-1（レビュー依頼）と ASO-6（★1 リスクの期待値管理）が完了、ASO-2 は原稿確定済み（残るは ASC 転記）、ASO-3 は取り下げ。**保留 3 件はここまでとは性格が違い**、ASO-4 は動画・スクショの素材制作、ASO-5 は Widget / App Intents という新機能追加、ASO-7 は In-App Events 等のストア運用で、いずれも「既存コードの手直し」では済まない。優先度が上がった時点で再検討する。
>
> 「App Store で上位を狙うのに何が足りないか」の棚卸しから起票。**狙う土俵はカテゴリ総合ではなく検索キーワードでの上位**（フード/ドリンク総合は大手チェーン・デリバリーの枠）。機能面は作り込まれている一方、「見つけられる / 選ばれる / 続けてもらう / 評価される」の 4 系統が手つかずだった。原稿・申告の正は [`app-store-metadata.md`](./app-store-metadata.md)。
>
> **実測した欠落**（2026-07-27 に grep で確認）: `requestReview` / `SKStoreReview` = **0 件** / `UserNotifications` `FirebaseMessaging` = 0 件 / `WidgetKit` `AppIntent` `CoreSpotlight` = 0 件 / `.xcstrings` `.lproj` = 0 件（`String(localized:)` のキーが日本語のまま = 英語化にはカタログ整備が必要）。

| 状態 | ID | タスク | 備考 |
|------|----|------|------|
| [x] | ASO-2 | 親: アプリ名のキーワード化 + サブタイトル改訂 + キーワード再構成 + 英語(U.S.) キーワード枠の新設（app-store-metadata §1 / §4 / §10 / 変更履歴） | 2026-07-27 完了。コード変更ゼロ。アプリ名 `CoffeeVision`（12 字）→ `CoffeeVision コーヒーマップ＆好み分析`（25 字、ユーザー確定）。**残るのは ASC 上の転記作業**（§10「App Store Connect 設定」の英語ロケール追加行）|
| [x] | ASO-1 | **レビュー依頼導線**（`AppStore.requestReview(in:)`）。**2026-08-01 完了**: 発火は**分析タブで傾向信号が初めて出た瞬間の 1 箇所のみ**（要件 9-8 に仕様化）。記録件数は「価値を感じた証拠」にならず、共有完了は `ShareLink` が完了コールバックを持たない（`UIActivityViewController` への置き換えが必要）ため不採用。ゲート = Remote Config キルスイッチ（未設定時 true）/ `UserDefaults` で端末あたり 1 回きり / 前回起動でクラッシュしていない / 1.5 秒遅延。`ReviewPrompt.swift` + `RemoteConfigBootstrap.swift` 新設 | **ON で出荷 + キルスイッチ**（ユーザー確定）。会話中に**私の助言を撤回**した項目 — 当初は「★1 の原因が未対処なので OFF 出荷」を推したが、ASO-6 ①②の完了で前提が解消した。`FIRRemoteConfigValue.boolValue` は**未設定キーで `false` を返す**ため素直に読むと意図と逆に一切発火しない罠があり、`source != .static` で判別（implementation_note 2026-08-01）。**親がフラグ無しで `** BUILD SUCCEEDED **` を独立再確認**。レビューで `try? await Task.sleep` のキャンセル飲み込みも検出・是正 |
| [-] | ASO-3 | ~~**オンボーディングの再設計**~~ → **2026-08-01 ユーザー判断で現状維持（取り下げ）**。初回起動の「データ利用同意 → 広告プレプロンプト → ATT」の 3 連はそのまま残す。空状態（`CoffeeListView.emptyView`）の CTA 追加も今回は着手しない | **起票文にあった「価値訴求を先に出し、許諾は最初の記録を保存した後へ回す」は親が書いた提案であって確定仕様ではない**（再検討時にこれを前提として引き継がないこと）。grilling の Q1（初回起動に何を見せるか）の時点で見送り。**調査で判明した非自明な事実**（ATT 未実施でも広告は自動的に NPA になるため、ATT を後ろへ回してもポリシー違反の窓は開かない）は implementation_note 2026-08-01 に保存済み。要件 §11-4 / 画面一覧は**改訂せず現行のまま**|
| [ ] | ASO-4 | **ストアページの CVR 投資**: ① App Preview 動画（マップ → 記録 → 分析の 15 秒）② スクショにキャプションを焼き込んだデザイン版（§5 のキャプション案を流用）③ Product Page Optimization（A/B テスト）と Custom Product Pages の活用 | §5 の現計画は生キャプチャ + キャプション案まで。②③ はどちらも ASC の無料機能 |
| [ ] | ASO-5 | **リテンションのフック**: App Intents（「コーヒーを記録」の Siri / Shortcuts / Spotlight 露出）+ ホーム画面 Widget（今月の杯数 → タップで記録）。既存方針「記録の摩擦を削る」（要件 2-8 / 2-9 / 2-10）の延長で、機能追加ではなく入口の追加 | 旧「フェーズ 6」の Widget 行を実質引き継ぐ。CoreSpotlight への記録インデックス / 週次ふりかえり通知は後続候補（通知は 4 つ目の許諾になる点に注意）|
| [x] | ASO-6 | **★1 リスクの潰し込み**（①②③すべて決着）。~~① 写真が機種変更で消える~~ → **2026-08-01 完了**: 設定に「データの保存先」セクション新設（記録=クラウド / 写真=この端末のみ）+ エクスポート footer に「写真は端末のバックアップで残してください」。~~② 匿名アカウントは端末間で参照不可~~ → **2026-08-01 完了**: アカウント管理（匿名時）の説明を是正。**着手前の現状把握で、新規コピーより既存コピーの方が問題だと判明** — 「現在の訪問記録はそのまま引き継がれます」が写真まで引き継がれると読め、★1 に最も直結していた。~~③ iPad の方針決め~~ → **2026-07-28 決着（iPad 対象外）**。`TARGETED_DEVICE_FAMILY` を `"1,2"` → `1` に変更し、死んだ `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` も除去。ビルド後の `Info.plist` が `UIDeviceFamily = [1]` になることを実測確認 | **前提を 1 つ訂正**: 「写真が機種変更で消える」は無条件には成立しない。`Documents/photos/` 保存で `isExcludedFromBackup` は 0 件 = **端末バックアップには含まれる**。失われるのは「新端末に入れ直してサインインしただけ」のケースで、コピーもその整理に合わせた（implementation_note 2026-08-01）。文言はユーザーが 3 点選択（設定=簡潔版 / 匿名時=穏当版 / エクスポート=行動を促す版）。**親がフラグ無しで `** BUILD SUCCEEDED **` + 成果物 `.app/Info.plist` の実読みまで再確認**。副産物: 旧用語「訪問記録」5 箇所を是正（Swift 4 + **Info.plist 1** — 許可ダイアログに約 1 年半出続けていた。lessons 2026-08-01）|
| [ ] | ASO-7 | 低コストで拾えるもの: ① In-App Events（「今月のコーヒーふりかえり」で検索結果・カテゴリにイベントカードを露出）② 共有カード footer の App Store 導線（現状 `CoffeeShareCardView.swift` の footer は `Text("CoffeeVision")` のみで URL / QR なし。2-12 の「カードの簡潔性」と衝突するので footer 1 行に収める範囲で）③ 小刻みなアップデート | ② は仕様（要件 2-12）の改訂が前提 |

#### BeanProfile 初期データ整備（2026-07-08）

> 完了分（2026-07-08）: seed データ `scripts/seed/bean-profiles.json`（主要産地 38 件・日本語表記統一・flavorNotes 統一語彙 42 語 = data-model.md §3.2）+ 冪等 upsert スクリプト `seed-bean-profiles.mjs` + README。`--dry-run` バリデーション全通過。確定仕様（grilling で親確定）と経緯は implementation_note 2026-07-08 エントリ。
> **本番 Firestore への投入は 2026-07-30 にユーザー実行済み（38 件）**。残る目視は [`tasks/verification-checklist.md`](./tasks/verification-checklist.md) 15-E-3。seed がカバーするのは `CoffeeOriginCatalog` 43 か国のうち **21 産地**で、ベトナム / メキシコ 等 22 か国は未カバー（`bestOrigin` がそこに落ちると投入済みでも両セクションが空になる = 確認時の誤判定要因）。

#### フェーズ 18: Firebase テレメトリ導入（Crashlytics / Analytics / Performance、2026-07-08 起票）

> 実装完了（2026-07-08）: iOS のみ。**Crashlytics + Performance = 常時収集（同意不要）、Analytics = `analyticsConsent` 同意時のみ**（`Info.plist` で起動時 OFF → `AppState.applyTelemetryConsent` で有効化。IDFA 非依存で ATT 不要を維持）。SPM 3 プロダクト追加 + dSYM アップロード build phase + `.trackScreen` modifier（4 タブ + 主要画面）+ `PrivacyInfo.xcprivacy` 宣言まで実装済み、override 無しビルド成功。全体の Required Reason API 監査は「リリース前バックログ」の F-1。経緯は implementation_note 2026-07-08、プライバシー申告は app-store-metadata.md 6.1/6.3。
> 目視: Analytics の consent gating と `screen_view` 発火は 2026-07-21 確認済み。**残る Crashlytics / Performance のコンソール観察は [`tasks/verification-checklist.md`](./tasks/verification-checklist.md)「フェーズ18 の残務」**。

### 完了

#### フェーズ 0: プロジェクト準備

> 完了（2026-06-02〜2026-07-09）: KMP スケルトン初期化 / docs 一式整備 / libs.versions.toml / SKIE 0.10.12 採用 / Firebase 設定ファイル非コミット方針 / CI 整備（PR ごと iOS + Android 必須チェック、2026-07-08 ユーザーがグリーン確認）/ API キー管理（xcconfig + CI の Secrets 復元）/ TestFlight ワークフロー `release-testflight.yml`（workflow_dispatch / ASC API キー + cloud signing、implementation_note 2026-07-07）。**Secrets 5 件（`ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_PRIVATE_KEY`＝App Manager 以上 / `GOOGLE_SERVICE_INFO_PLIST_BASE64` / `PLACES_API_KEY`）の登録 + 初回実行で TestFlight 反映を 2026-07-09 ユーザー確認済み**。

#### フェーズ 5.2: アカウント削除時の Apple トークン失効（E-1）

> 完了（実装 2026-06-24 / 設定 2026-07-09）: App Store ガイドライン 5.1.1(v) 対応。削除時に Apple 再サインイン →（authorization code 取得）→ reauthenticate → `revokeToken` → KMP 削除を iOS がオーケストレーション（キャンセル = 無音中断 / revoke 失敗 = 削除中断。詳細は implementation_note 2026-06-17 アカウント機能エントリ）。前提のユーザー作業（Apple Developer で Sign in with Apple Key（.p8）+ Services ID 作成 → Firebase Apple プロバイダに Services ID / Team ID / Key ID / 秘密鍵の 4 項目登録）も 2026-07-09 完了。実機での削除完走 + revoke 確認は verification-checklist.md（**シミュレータ不可・実機必須**）。
