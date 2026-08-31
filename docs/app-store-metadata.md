# App Store Connect 提出用メタデータ

CoffeeVision の App Store Connect 申請に使う原稿・設定値・チェックリストをまとめたドキュメント。
リリース直前に App Store Connect の各フィールドへ転記する。事実が変わったら本ドキュメントを真として更新する。

> 数値・ID 系は実体（`iosApp/Configuration/Config.xcconfig` / `iosApp/iosApp/Info.plist`）を真とする。
> プライバシー宣言は [`requirements.md` §非機能要件](./requirements.md) / [写真ストレージ方針](./implementation_note.md) の実装事実と齟齬が出ないよう保つ。

---

## 1. アプリ基本情報

| 項目 | 値 | 出典 / 備考 |
|------|----|-----------|
| アプリ名（App Name） | CoffeeVision コーヒーマップ＆好み分析 | 30 字以内（**25 字**）。ASO のため名前フィールドにキーワードを載せる。**`CFBundleDisplayName` とは別フィールドで、一致させる必要はない** — ホーム画面のアイコン下は `CoffeeVision` のまま短く保つ（長いと省略される） |
| サブタイトル（Subtitle） | カフェ巡り記録・テイスティング・行きたい店 | 30 字以内（**21 字**）。**アプリ名と 1 語も重複させない**方針 — `コーヒー` / `分析` はアプリ名側が拾うため、サブタイトルは `カフェ` / `巡り` / `記録` / `テイスティング` / `行きたい` / `店` に充てる |
| Bundle ID | `com.noricoffee.coffeevision` | `Config.xcconfig`（`$(TEAM_ID)` を除いた本体） |
| SKU | `com.noricoffee.coffeevision` | Bundle ID と同値。外部には出ない社内識別子だが**登録後は変更できない** |
| Apple ID（App ID） | `6788339362` | ASC が採番。ストア URL は `https://apps.apple.com/app/id6788339362` |
| ストア URL | `https://apps.apple.com/app/id6788339362` | **アプリ内に埋めるのはこの短縮形**。ASC がコピーさせる長い URL（`/app/coffeevision-コーヒーマップ-好み分析/id...`）の**スラグ部分はアプリ名から生成される装飾**で、リダイレクトにしか使われない。ASO で名前を変えるたびに変わる文字列をバイナリへ焼かない（アプリ名は ASO-2 で一度変更済み） |
| バージョン | 1.0.1 | `MARKETING_VERSION` |
| ビルド番号 | CI が採番 | `CURRENT_PROJECT_VERSION`。`release-testflight.yml` が `github.run_number` を `xcodebuild archive` に渡すため、`Config.xcconfig` の `1` は Release では使われない。**手入力・手動更新は不要**（詳細は §10） |
| 最小 OS | iOS 26.0 | `IPHONEOS_DEPLOYMENT_TARGET` |
| デバイス | iPhone | `TARGETED_DEVICE_FAMILY = 1`。iPad は対象外（`"1,2"` のままだと iPad にインストール可能になり、ASC が iPad スクショを必須要求する）|
| プライマリカテゴリ | フード/ドリンク（Food & Drink） | |
| セカンダリカテゴリ | ライフスタイル（Lifestyle） | （任意） |
| 価格 | 無料 | アプリ内課金なし |
| 年齢制限（Age Rating） | 4+ | 不適切コンテンツなし。下記 §7 で再確認 |
| 対応言語 | 日本語（プライマリ）+ **英語(U.S.)（キーワード枠としてのみ追加）** | アプリ本体の UI は日本語のみ（`.xcstrings` / `.lproj` は未整備）。**バンドルの実効言語は `ja`**（`developmentRegion = ja` / `CFBundleLocalizations = [ja]`）— これは `.lproj` の追加や多言語文言の追加を意味せず、`DatePicker` 等 **OS が描画する部分の書式が英語にフォールバックする不具合**を塞ぐための設定（lessons 2026-08-06）。英語(U.S.) ロケールは §4 の英語キーワード 100 字を得る目的だけで追加し、名前 / サブタイトル / 説明文 / スクショは日本語をそのまま転記する（理由は §4 の注記） |

> **アプリ名 = ストア表示名 / `CFBundleDisplayName` = ホーム画面のアイコン下**で、両者は独立したフィールド。同一視しないこと。

---

## 2. プロモーションテキスト（Promotional Text）

> 170 字以内。審査なしで後から差し替え可能なので、キャンペーン文言に使える枠。
>
> ⚠️ **この枠は検索インデックスの対象外**（Apple がインデックスするのはアプリ名 / サブタイトル / キーワードフィールド + デベロッパ名というのが ASO の定説。§4 の「トークナイズ挙動は Apple 非公開」と同じ確度）。**キーワードを詰め込んでも検索ヒットは増えない**ので、ここは CVR のための文面として書く。検索で拾う語を増やしたいときは §4 の 3 フィールドを見る。

```
甘味・ボディ・酸味・風味・後味。5 軸で味を残していくと、グラフがあなたの好みの輪郭を描き出し、次に試したい一杯を提案します。Apple Intelligence 対応端末なら、好みの豆の特徴を言葉にすることも。行きたい店はマップに保存、訪れた店はピンになって地図が自分のコーヒー地図に育ちます。
```

（**148 字**（`len` 実測）。**説明文の書き出しと内容を重複させないこと** — 製品ページではプロモ文と説明文が連続表示されるため、同じ話を 2 回読ませることになる。折りたたまれる前に見えるのは先頭 2〜3 行なので、差別化点である 5 軸テイスティングと分析を冒頭に置いている。

**「好みの豆の特徴を言葉にする」に端末条件を明記しているのは仕様上の制約**: `CoffeeInsightProviderIosImpl.makeIfAvailable()` が `SystemLanguageModel.default.availability == .available` のときだけインスタンスを返し、非対応端末・Apple Intelligence 無効・モデル未準備ではセクション自体が出ない。§3 の説明文も同じ条件を明記している。一方**「好みの傾向」と「未体験豆の提案」は統計とマッチングによる算出で端末を選ばない**ため、条件を付けずに書いてよい）

---

## 3. 説明文（Description）

> 最大 4000 字。改行・箇条書き可（Markdown 記法は不可、プレーンテキスト）。

```
CoffeeVision は、飲んだ一杯の記録から、好みの分析、次に行きたいお店の保存まで——コーヒー体験を過去から未来までひとつにつなぐアプリです。
カフェの 1 杯も自宅の 1 杯も「1 杯 = 1 件」で記録。記録が増えるほど好みが見え、次の一杯に出会いやすくなります。

【主な機能】

■ 1 杯ずつ、細かく残す
・コーヒー名と抽出方法（エスプレッソ／ハンドドリップ／フレンチプレスなど）
・産地・品種・精製方法・焙煎度・カップ
・0.5 刻みの星評価（ハーフスター対応）と自由メモ
・甘味・ボディ・酸味・風味・後味の 5 要素テイスティング
・「ラテアート」「浅煎り」など自由なタグ
・豆量・湯温・抽出時間などの抽出レシピメモ（自宅ドリップ派に）
・過去の記録を複製して、いつもの一杯をすぐ記録
・写真を添付して見た目も記録

■ カフェと一緒に記録する
・店名やキーワードでカフェを検索（Google Places）
・マップの「このエリアを検索」で表示範囲のカフェを一括表示
・現在地周辺のカフェをワンタップでセット（位置情報許可時）
・カフェに紐付けない自宅・セルフ抽出の記録もOK

■ 行きたいお店を保存する
・気になるカフェを「行きたい」として保存、マップに専用ピンで表示
・保存リストから次のカフェ巡りを計画

■ マップで振り返る
・記録のあるカフェをマップ上のピンで一覧
・同じカフェで飲んだ過去の記録をまとめて確認
・周辺のまだ行っていないカフェも控えめなピンで表示
・タグや好みでピンを絞り込み

■ 好みを分析する
・杯数・産地・焙煎度・抽出方法・評価の統計をグラフで表示
・好みに合いそうな「まだ試していない豆」の提案
・記録一覧はキーワード検索と月別表示で振り返りやすく
・Apple Intelligence 対応端末では、記録からあなたの傾向を要約したり、「好きな産地は？」といった質問に答えたりできます（処理はすべて端末内で完結します）

■ 安心して使える
・ライト／ダーク／システムのテーマ切り替え
・オフラインでも記録の閲覧・追加が可能
・記録はクラウドに自動でバックアップ（写真は端末内に保存）
・記録データは JSON 形式でいつでもエクスポート可能

昨日の一杯を残すことが、明日の一杯に出会う近道になる。あなたのコーヒー体験のすべてを、CoffeeVision に。
```

> 写真の扱い（端末ローカル保存 / クラウド非同期）は §6 プライバシーと整合させること。「クラウドに自動でバックアップ」は記録テキスト（Firestore）を指し、写真は含まない旨を誤解させない表現にしている。

---

## 4. キーワード（Keywords）

> カンマ区切りで合計 100 字以内。スペースは入れない（カンマ直後も詰める）。**アプリ名・サブタイトル・カテゴリ名に含まれる語はキーワードに入れない**（インデックス上は同一枠のため二重に書くと枠の無駄になる）。

### 4.1 語の割り当て（名前 / サブタイトル / キーワードを 1 つの予算として配分）

| フィールド | 文字数 | 拾う語 |
|-----------|-------|-------|
| アプリ名 | 25 / 30 | `コーヒー` `マップ` `好み` `分析` |
| サブタイトル | 21 / 30 | `カフェ` `巡り` `記録` `テイスティング` `行きたい` `店` |
| キーワード（日本語） | 89 / 100 | 下記 19 語 |
| キーワード（英語 U.S.） | 98 / 100 | 下記 15 語 |

### 4.2 日本語ロケール

```
珈琲,喫茶店,焙煎,自家焙煎,ハンドドリップ,スペシャルティ,コーヒー豆,抽出,ラテ,エスプレッソ,カプチーノ,浅煎り,深煎り,シングルオリジン,バリスタ,手帳,風味,味覚,日記
```

（**19 語・89 字**。`len` 実測。アプリ名 / サブタイトルが拾う語は入れない = §4.1 の配分表）

### 4.3 英語(U.S.) ロケール

```
coffee,cafe,journal,diary,log,tracker,tasting,brew,espresso,pourover,beans,roast,barista,latte,map
```

（**15 語・98 字**。`len` 実測）

> **英語ロケールを「キーワード枠としてのみ」使う理由**: 日本の App Store では日本語ロケールに加えて英語(U.S.) のメタデータもインデックスされるのが ASO の定説で、ロケールを 1 つ足すとキーワード枠が実質倍になる。一方でアプリ本体の UI は日本語のみなので、名前 / サブタイトル / 説明文まで英語にすると「英語アプリだと思って DL したら日本語だった」という★1 レビューを招く。したがって **keywords フィールドだけ英語を入れ、他のフィールドは日本語をそのまま転記する**。将来アプリを英語化して配信国を広げる場合は、EU 向けに UMP の GDPR フォーム実装が先（requirements.md §11 / §10 チェックリスト）。

> **日本語のトークナイズ挙動は Apple 非公開**。「サブタイトルに `カフェ` があれば `カフェ巡り` でも当たる」というクロスマッチ前提は定説ではあるが確証がないため、`喫茶店` `自家焙煎` `コーヒー豆` のような複合語も残して保険をかけている。リリース後に App Store Connect の検索順位・インプレッションを見て調整する。
>
> **サブタイトルを旧文言「コーヒー記録・分析・行きたい店」に戻す場合**は、キーワードから `日記` を外し `カフェ` `カフェ巡り` `テイスティング` を戻す（83 字 / 17 語）。名前が `カフェ` を含まないため、この 3 語をどこかで拾う必要がある。

---

## 5. スクリーンショット計画

> **6.9 インチの 1 サイズだけでよい**（最大 10 枚 / 最低 1 枚）。6.5 インチは「6.9 インチを提供しない場合のみ必須」で、6.9 インチを出せば ASC が小さい表示サイズ向けに自動で縮小する。出典: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)。
>
> **撮影は iPhone 17 Pro Max（6.9 インチ）シミュレータのネイティブ解像度 1320×2868 ポートレート**。ASC が受理しない場合のみ `sips` で 1260×2736 へ縮小する（アスペクト比 0.4602 → 0.4605 でほぼ無損失）。アルファチャンネル入りの PNG は弾かれる。

**6 枚構成**。原本は `screenshots/6.9/`、**提出物はキャッチコピーを焼き込んだ `screenshots/submit/`**。ASC アップロード順 = ファイル名の番号順 = ストアでの表示順。

| # | ファイル | 画面 | 訴求ポイント | **焼き込みコピー**（確定） |
|---|---------|------|------------|--------------|
| 1 | `01-analyze-summary.png` | 分析画面（サマリ） | 総杯数・平均評価 + 評価分布 + テイスティングレーダー | 味覚の輪郭が、／見えてくる |
| 2 | `02-analyze-suggest.png` | 分析画面（傾向と提案） | 4 軸の好み傾向 + 好みの豆の言語化 + 未体験豆の提案 | 好みから、／次の一杯が見えてくる |
| 3 | `03-map.png` | マップ画面 | 訪問済み / 好み一致 / 保存済みのピン + 埋め込み検索バー | お気に入りの一杯を／発見しよう |
| 4 | `04-record-list.png` | コーヒー記録一覧画面 | 月別セクションの振り返り + 検索 + ナビバー右上の追加ボタン | 一杯ずつ、／積み上がっていく |
| 5 | `05-record-editor.png` | コーヒー記録 作成 / 編集画面 | テイスティング 5 軸のスライダー + 星評価 | 味の記憶を、／5 つの軸で |
| 6 | `06-cafe-detail.png` | カフェ詳細画面 | 店舗写真・評価・営業状況 + 同じ店の記録の集約 | もちろん／カフェの情報もチェック |

> **表示順は「分析サマリ → 分析サジェスト → マップ」で始める**。検索結果のサムネイル実寸（幅 300px 相当）で並べた実測では、マップは訪問済みピンが地図の陰影に沈み、ピンの意匠 3 種の描き分けもフィルタチップも判読できず「地図のスクショ」以上の情報が残らなかった一方、分析サマリは 3 つの数値・評価分布のバー・レーダーの五角形が形として生き残った。限られた上位枠は差別化点（= 分析）に寄せる。**検索結果ではポートレート 3 枚が見える**のでマップが 3 番でも preview には入る。
>
> **上部の写り込みに注意**: 初回撮影時、分析サマリだけ**ダイナミックアイランドが黒いピルとして写り込んでいた**（原本の座標 (660, 80) が `rgb(0,0,0)`。他 5 枚は同座標が背景色）。ストアでは 6 枚が横並びで見えるため 1 枚だけ上部に黒い切り欠きが出る。**撮影後は 6 枚の同座標を並べて比べる**のが検出手段（1 枚だけ見ても「そういうものか」と流れる）。

> **コピーの設計方針**: ①**句点を付けない**（焼き込みでは間延びするため）②**12〜15 字に揃える**（1 枚だけ長いとフォントサイズを全体で落とすことになる）③**読点で 2 行に割る**（`／` が改行位置。文字を大きく見せられ、ストア一覧のサムネイルでも読める）④**アプリ名・サブタイトルと語を重複させない** — ストアではスクショの上に `CoffeeVision コーヒーマップ＆好み分析` と `カフェ巡り記録・テイスティング・行きたい店` が並ぶため、「記録」「分析」「マップ」を重ねると限られた面積で同じことを繰り返すことになる。

> **6 枚構成の根拠**: 分析画面を 2 枚（サマリ / 傾向・提案）に割いているのは、分析がこのアプリの差別化点で 1 枚では統計グラフと好みの言語化の両方を見せられないため。**枚数を増やすなら最初の候補は「写真添付が写る枚」と「『行きたい』保存の訴求」**（現状 前者はどの枚にも写っておらず、後者は `03-map.png` の保存済みピンだけが担う）。

### 撮影の再現手順

```
xcrun simctl status_bar <udid> override --time "9:41" --batteryState charged \
  --batteryLevel 100 --cellularBars 4 --dataNetwork wifi --wifiBars 3
SIMCTL_CHILD_SEED_DUMMY_DATA=1 xcrun simctl launch <udid> com.noricoffee.coffeevision
xcrun simctl io <udid> screenshot screenshots/6.9/NN-name.png
```

- 機種は **iPhone 17 Pro Max（6.9 インチ / iOS 26.5）**。ネイティブ解像度がそのまま 1320×2868 になる
- **`SEED_DUMMY_DATA=1` を必ず付ける**。付けずに起動すると `AppState.seedOrClearDummyData` が `clearDummyData` を呼び、ダミー 30 件が消える
- ダミーデータは**写真と `SavedCafe` を持たない**（`DummyCoffeeData.kt` は `photos = emptyList()`）。カフェも `dummy-place-001` 等の架空 ID で Places に存在しないため、営業時間・店舗写真が要る画面（#6）は**実在の店を検索して記録を作る**必要がある。写真は `xcrun simctl addmedia` でフォトライブラリに投入する
- **カフェ詳細（#6）には広告が入る**（情報系の後・記録の前）。Debug ビルドは AdMob デモ ID なので、スクロール位置を上げて **"Test Ad" を画面外に出す**こと（1.0 の撮影時に 1 度写り込んで撮り直した）
- 分析画面（#5 相当）の Foundation Models 要約は Apple Intelligence 有効な実機でのみ表示される（シミュレータ撮影なら統計グラフのみ）

### 提出物の生成（キャッチコピーの焼き込み）

```
xcrun swift screenshots/compose-captions.swift screenshots/6.9 screenshots/submit
```

**コピーの文言は `compose-captions.swift` 冒頭の `captions` 辞書が実体**（上の表と一致させること）。デザインはクリーム背景 `#F6EFE5` + 濃茶文字 `#8B5A2B`（AccentColor の light 値）で、スクリーンショットを幅 84% の角丸カード（+ 影）として配置し下端を画面外へ逃がす。フォントは `HiraginoSans-W6` / 82pt、カード幅に収まらない行は自動で縮む。

出力先 `screenshots/submit/` は **git 非追跡**（原本 + スクリプトからいつでも再生成できるため）。**ASC にはこちらをアップロードする**。

> **アルファチャンネルに注意**: `simctl` のスクリーンショットは全ピクセル不透明でも**アルファチャンネルを持ち**、ASC の「alpha channels or transparencies を含む画像は不可」に抵触しうる。`compose-captions.swift` は `CGImageAlphaInfo.noneSkipLast` で描画するため出力は**アルファ無し**（`sips -g hasAlpha` で `no` を確認済み）。**焼き込みをやめて生キャプチャを提出する方針に戻す場合は、アルファ除去を別途行う必要がある**（かつての `flatten-alpha.swift` が commit `59f72c6` にある）。

---

## 6. プライバシー（App Privacy / 栄養表示ラベル）

App Store Connect の「App のプライバシー」セクションで申告する内容。実装事実に基づく。

### 6.1 収集するデータ

| データ種別 | 収集 | 用途 | ユーザーに紐付け | トラッキング | 備考 |
|-----------|------|------|----------------|------------|------|
| 位置情報（おおよそ / 正確） | する | アプリ機能（周辺カフェ検索・地図上の現在地表示） | 紐付けない | しない | `NSLocationWhenInUseUsageDescription`。カフェ検索と地図表示中の現在地表示（when-in-use）に使用、バックグラウンド常時取得はしない。保存・送信は座標を Google Places に渡すのみ |
| 写真 | する（端末内） | アプリ機能（コーヒー記録への添付） | — | しない | 端末ローカル（Documents 配下）保存のみ。**サーバ送信なし**。App Privacy 上は「デバイスから持ち出さないデータ」に該当 → 申告不要の可能性が高いが、保守的に記載 |
| ユーザーコンテンツ（コーヒー記録: 評価 / テイスティング / メモ / タグ / カフェ情報） | する | アプリ機能（クラウド同期 / バックアップ）+ **同意時のみ** サービス改善のための分析 | 紐付ける | しない | Firestore に保存。匿名 uid に紐付く。サービス改善利用は初回オンボーディング / 設定の同意トグル（`analyticsConsent`、既定 false）にオプトインした場合のみ |
| 識別子（匿名ユーザー ID） | する | アプリ機能（同期のためのアカウント識別） | 紐付ける | しない | Firebase 匿名認証の uid |
| メールアドレス | する（任意。Apple でサインイン時のみ） | アプリ機能（アカウントのアップグレード / 引き継ぎ） | 紐付ける | しない | Sign in with Apple での匿名アカウントアップグレード時に Firebase Auth が保持。ユーザーは Apple の「メールを非公開」を選択可。申告する（ASC の分類は「連絡先情報 > メールアドレス」/ 用途 = App の機能 / 紐付ける / トラッキングしない）。「メールを非公開」選択時もリレーアドレスを保持するため、収集している事実は変わらない |
| 診断情報（クラッシュ / パフォーマンス） | する（**常時**） | アプリ機能（安定性・技術品質の改善） | 紐付ける（匿名 uid / Firebase Installation ID） | しない | Firebase Crashlytics + Performance。同意不要（安定性・技術品質の正当利益）。クラッシュスタック・非致命的エラー・起動/描画/ネットワークの遅延など。広告なし・IDFA なし |
| 使用状況データ（製品インタラクション: `screen_view` / 自動収集イベント） | する（**同意時のみ**） | サービス改善のための分析 | 紐付ける（匿名 uid） | しない | Firebase Analytics（素の `FirebaseAnalytics` プロダクト。現行 SDK は既定で IDFA 非依存）。`analyticsConsent = true` の場合のみ収集を有効化。既定（未同意）は収集停止。カスタムイベントは未導入（自動収集 + `screen_view` のみ） |
| ユーザーコンテンツ（味覚プロファイル: テイスティング平均 5 軸 / カテゴリ好み / 高評価カフェの placeId・座標） | する（**同意時のみ**・9-6 設計確定/未実装） | アプリ機能（好みが近いユーザー間のカフェ推薦） | 紐付ける（匿名 uid） | しない | `recommendationConsent = true` のときだけ `sharedTasteProfiles` に匿名 uid 紐付けで保存。生メモ・タグ・カフェ名は含めない。`analyticsConsent` とは別の独立同意（既定 false）。横断参照は Cloud Function 特権に閉じ、他ユーザーへ生データを開示しない。**⚠ 9-6 が未実装のリリースでは本行を App Privacy 申告に含めないこと**（App Privacy は実際に収集しているデータのみを申告する。申告と実態の乖離は審査指摘の対象。9-6 実装後に本行を有効化して申告を最終化する） |
| 識別子（広告 ID / IDFA）・広告データ | する（**ATT 許諾時のみ**） | 第三者広告（デベロッパーの広告 / マーケティング） | 紐付ける | **する**（許諾時のみ） | Google Mobile Ads SDK（AdMob）。ATT 許諾時はパーソナライズ広告に IDFA を利用、拒否時は非パーソナライズ（NPA）配信で IDFA 不使用。広告インタラクションデータは AdMob が収集（requirements.md §11） |

> 分析タブの AI 機能（傾向要約・Q&A・好み検索）は Apple の Foundation Models による**オンデバイス処理**で、記録データを外部サーバに送信しない（App Privacy の申告対象にならない）。

### 6.2 トラッキング

- **App Tracking Transparency（ATT）**: **必要**。AdMob のパーソナライズ広告に IDFA を利用するため、既存のデータ利用同意オンボーディング直後にプレプロンプト → ATT ダイアログを表示（requirements.md §11-4）。拒否時は非パーソナライズ広告（NPA）にフォールバックし IDFA 不使用。`NSUserTrackingUsageDescription` の記載が必要。Firebase Analytics は引き続き IDFA 非依存（素の `FirebaseAnalytics` プロダクト、`FirebaseAnalyticsIdentitySupport` 未追加）。
- サードパーティとのデータ共有: Google Places API へ検索クエリ / 座標を送信（カフェ検索機能の実現に必要な範囲のみ）。Firebase（Google）にユーザーコンテンツを保存。

### 6.3 第三者 SDK

| SDK | 提供元 | 用途 | 送信データ |
|-----|--------|------|-----------|
| Firebase Auth | Google | 匿名認証 + Sign in with Apple 連携 | 匿名 uid（Apple サインイン時は Apple ID 連携情報・メールアドレス） |
| Firebase Firestore | Google | 記録の同期 / バックアップ | コーヒー記録（評価 / テイスティング / メモ / タグ / カフェ情報スナップショット / 写真メタデータ）+ データ利用同意フラグ（+ 同意時の味覚プロファイル共有 = 9-6 設計確定/未実装） |
| Google Places API | Google | カフェ検索・エリア検索・詳細・写真取得 | 検索クエリ / 現在地・マップ中心座標 |
| Firebase Crashlytics | Google | クラッシュ / 非致命的エラー診断（**常時**） | クラッシュスタック・デバイス/OS・Firebase Installation ID・（同意時のみ）Analytics breadcrumb |
| Firebase Performance | Google | 起動 / 描画 / ネットワーク性能診断（**常時**） | トレース時間・ネットワークリクエストの URL/遅延/ステータス・デバイス/OS |
| Firebase Analytics | Google | 製品利用分析（**同意時のみ**） | `screen_view`・自動収集イベント（起動/セッション等）。IDFA なし・クロスアプリ追跡なし |
| Firebase Remote Config | Google | マップ POI 除外キーワードの設定値配信（**常時**、同意不要） | 設定値取得のためのリクエスト（Firebase Installation ID・アプリバージョン/デバイス構成）。ユーザーデータの送信なし（SDK 同梱マニフェストは Other Diagnostic Data / 非トラッキングを自己申告） |
| Google Mobile Ads SDK（AdMob） | Google | アダプティブバナー広告の配信（**カフェ詳細 / マップ検索結果シートの 2 面のみ** = requirements.md §11。記録タブ・分析タブには置かない） | ATT 許諾時: IDFA・広告インタラクション。拒否時: NPA 配信（IDFA なし）。`maxAdContentRating = G`。Places 由来データはターゲティングシグナルに渡さない |
| UMP SDK（User Messaging Platform） | Google | （コードから未使用） | Google Mobile Ads SDK の内部依存としてリンクされるのみで、API は一切呼ばない（同意 UI は自前プレプロンプト + ATT で完結。requirements.md §11）。EU 配信を始める場合に GDPR フォームとして再導入 |

> Firebase Crashlytics / Performance は**常時**収集（同意不要 = 安定性・技術品質の正当利益）、Firebase Analytics は `analyticsConsent = true` の**同意時のみ**有効化（既定は収集停止）。Analytics は素の `FirebaseAnalytics` プロダクト（現行 firebase-ios-sdk 12.14.0 で既定 IDFA 非依存。旧 `WithoutAdIdSupport` は廃止、IDFA 利用時のみ `FirebaseAnalyticsIdentitySupport` 追加の反転構成）でクロスアプリ追跡を行わない。`PrivacyInfo.xcprivacy` に集計データ種別（Crash Data / Performance Data / Product Interaction）を宣言済み。

> **`PrivacyInfo.xcprivacy`（アプリ側 manifest）と App Privacy 申告（§6.1）は別物**。privacy manifest は**そのバイナリ自身のコードが**収集・アクセスするものを宣言する枠組みで、SDK 側の収集は SDK 同梱の manifest が宣言する。`iosApp` のコードは `AdConsentCoordinator` で `ATTrackingManager` の状態確認 / 許可要求を行うだけで、`AdSupport` を import せず IDFA を直接読まない（広告 ID を扱うのは Google Mobile Ads SDK）。したがってアプリ側 manifest は現状の `NSPrivacyTracking = false` / トラッキングドメイン空 / 収集データ 3 種（Crash / Performance / ProductInteraction）**のままで整合**し、追加宣言は不要。一方 **App Store Connect の App Privacy 申告では §6.1 の IDFA 行を「トラッキングする」で申告する**（アプリが埋め込む SDK の挙動も申告対象のため）。

### 6.4 必要 URL

| 項目 | URL | 状態 |
|------|-----|------|
| プライバシーポリシー URL | `https://noricoffee.github.io/CoffeeVision/privacy-policy.html` | 公開中。位置情報 / Firebase / Places / 広告 IDFA / 同意 / 権利を実装事実ベースで記載 |
| サポート URL | `https://noricoffee.github.io/CoffeeVision/support.html` | 公開中。FAQ + 問い合わせ先 |
| マーケティング URL | （任意） | 未定 |

> **公開方式**: GitHub Pages（`.github/workflows/pages.yml`）。**`docs/legal/` のみ**を Pages アーティファクトにしており、`docs/` 配下の設計 doc は Web 公開されない。ソースは `docs/legal/*.html` 単一で、`develop` への push で自動デプロイされる。名義は `noricoffee`、2 ページは相対パスで相互リンク。
>
> 本文を改訂したら**アプリ内の表示も自動的に追随する**（`DataConsentOnboardingView` は URL を開くだけ）。ただし収集項目や第三者 SDK を変える変更では、§6.1 / §6.3 と `PrivacyInfo.xcprivacy` の 3 点セットで整合を取ること。

---

## 7. 年齢制限（Age Rating）アンケート想定回答

| 質問カテゴリ | 回答 |
|------------|------|
| 暴力 / ホラー / 性的表現 / 不適切な言葉 | なし |
| ギャンブル / コンテスト | なし |
| ユーザー生成コンテンツ / SNS 機能 | なし（記録は本人のみ閲覧。**共有カード（2-12）は端末の share sheet に画像を渡すだけ**で、アプリ内に他ユーザーへ公開する経路はない = ガイドライン 1.2 の通報 / ブロック要件は非該当） |
| 無制限の Web アクセス | なし |
| 位置情報の共有 | なし（他ユーザーとの共有はしない） |
| **アプリ内広告** | **あり**（AdMob アダプティブバナー 2 面 = §6.3 / requirements §11。`maxAdContentRating = G`）。ASC 上で申告済み |

→ 想定レーティング: **4+**（広告ありでも 4+ は維持できる）

> **この表は ASC のアンケート項目に 1:1 で対応させて維持すること**。1.0 前のガイドラインレビューで、**ASC が問う「アプリ内広告の有無」の行が抜けていた**ことが判明した（広告導入時に §6.1 / §6.2 / §6.3 は更新されたが §7 だけ追随していなかった）。申告と実態の乖離はガイドライン 2.3 の指摘対象になる。**収集データ（§6）を変える変更では §7 も開いて突き合わせる**。

---

## 8. App Review に関する情報（Review Notes）

審査担当者向けの補足。匿名認証のため通常のログインデモは不要だが、挙動を明記しておく。

```
・本アプリは起動時に Firebase の匿名認証で自動的にアカウントを作成します。ログイン不要でそのまま利用できます。
・設定タブから「Apple でサインイン」で匿名アカウントをアップグレードできます（任意）。アカウント削除も設定タブから可能で、Apple 連携アカウントの削除時には Apple トークンの失効（revoke）を行います（ガイドライン 5.1.1(v) 対応）。
・初回起動時に、記録データをサービス改善に利用することへの同意を確認するオンボーディングを表示します（任意。設定からいつでも変更可能）。
・カフェ検索・エリア検索には Google Places API を使用します。検索結果の表示には通信が必要です。位置情報はカフェ検索と地図上の現在地表示に使用し、バックグラウンドでの常時取得はしません。
・分析タブの AI 機能（傾向要約・Q&A）は Apple Intelligence 有効端末でのみ表示されます。非対応環境では統計グラフのみ表示されます（AI 処理はすべて端末内で完結し、外部送信はありません）。
・写真は端末内にのみ保存され、サーバーには送信されません。
・デモ用アカウント: 不要（匿名認証のため）
```

| 項目 | 値 |
|------|----|
| 姓名 | noricoffee |
| メールアドレス | `noricoffee593@gmail.com` |
| 電話番号 | **ASC 上で手入力**（必須項目。本 doc には残さない） |
| デモアカウント | 不要（匿名認証） |
| 添付（任意） | 主要画面のメモ等あれば |

---

## 9. What's New（バージョン 1.0 リリースノート）

```
CoffeeVision を初めてリリースしました。
カフェでも自宅でも、飲んだ 1 杯のコーヒーを記録して、マップや分析で自分の好みを振り返れます。
ぜひあなたのコーヒー巡りの記録にお使いください。
```

---

## 10. 提出前チェックリスト

新しいバージョンを提出するたびに上から確認する。**1.0（2026-08-11 提出 / 審査通過）では全項目を消し込み済み**なので、以下は「毎回見る項目」と「一度きりだが変更時に効いてくる知識」に分けてある。

### 毎回確認する

- [ ] **原稿の文字数**（§1〜§4）を `len` で実測して上限内か。アプリ名 30 / サブタイトル 30 / プロモ 170 / 説明文 4000 / キーワード 100 字（ロケールごと）
- [ ] **スクリーンショットが現物の UI と一致するか**（§5）。UI を変えた画面が写っている場合は撮り直す。**6 枚の同座標を並べて比べる**（ダイナミックアイランドの写り込み検出）
- [ ] **App Privacy 申告（§6.1 / §6.3）が実装事実と一致するか**。⚠️ **9-6 味覚プロファイル共有の行は未実装のため申告に含めていない** — 実装したら申告とプライバシーポリシー本文の両方を更新する
- [ ] **年齢制限アンケート（§7）** — 収集データや広告構成を変えたら開いて突き合わせる（1.0 前に「アプリ内広告の有無」の行が抜けていた前例あり）
- [ ] **`MARKETING_VERSION`** を上げる（`iosApp/Configuration/Config.xcconfig`。CI でも上書きしない）
- [ ] **Firestore Security Rules が本番にデプロイ済みか**（`firestore.rules` の編集と `firebase deploy` は別作業。現在の公開内容は Console のルールタブが正本）
- [ ] **Archive → App Store Connect へアップロード**（`release-testflight.yml`）

> **`CURRENT_PROJECT_VERSION` は手で上げない。** CI の Archive ステップが `github.run_number` を `xcodebuild archive` に渡し、xcconfig の値を上書きする（現在値は `gh run list --workflow=release-testflight.yml` で確認）。⚠️ `github.run_number` は**ワークフローの同一性に紐づく連番**で、`release-testflight.yml` をリネーム / 削除して作り直すとカウンタが 1 に戻り、ASC が「ビルド番号が既存以下」で受け付けなくなる。**このファイル名は変えない**。

### 本番環境の設定（**アプリが動くかでは検出できない**もの）

> ここは「無くてもアプリは正常に動くが、無いと無防備になる / 事故ったときに手が無い」設定を追跡する。Firestore Rules や Sign in with Apple の Firebase 登録は**無いとアプリが動かない**ので TestFlight で自然に検出されるが、この節の項目は**動いたまま抜ける**。実際 1.0 の提出後レビューで 3 件が未実施のまま見つかった（方針は 1 か月前から implementation_note に書いてあった）。**本番環境への設定を伴う方針を決めたら、その場でここに行を立てる**。

- [x] **Places API キーの悪用対策 3 点**（1.0 / Google Cloud Console）。**3 つで 1 つの防御**として扱う — どれが欠けても天井が成立しない
  - **予算アラート**（Cloud Billing / 気づくための層。通知するだけで請求は止まらない）
  - **クォータ上限**（Places API (New) の分あたりリクエスト数 / Places の量に天井。`per user` は無制限のまま = 判断根拠は `paid-services.md` §1）
  - **API の制限を Places に限定**（認証情報 → 該当キー / 他 Maps API への迂回路を塞ぐ。**新しい Google API を使い始めるときは許可リストへの追加が必要**）
  - **実値は Cloud Console が正本**（doc に書かない）。背景はキーがクライアント埋め込みで抽出不可避なこと
- [x] **Remote Config `review_prompt_enabled`**（1.0 / Boolean・既定値 `true`・条件なし）。要件 9-9 のレビュー依頼キルスイッチ。実装は**キー未設定なら発火する**側に倒してあるため、キーが無い状態は「止める手段が無い」と同義。⚠️ **即時停止はできない**（`minimumFetchInterval` 12h + fetch は起動時 1 回 → 反映まで最大 12h + 次回起動）

### 一度きりの設定（1.0 で完了済み / 変えるときに効いてくる知識）

- **App Store Connect**: 英語(U.S.) ロケールを追加し keywords だけ英語（§4.3）、他フィールドは日本語を転記 / 価格・配信地域（無料・**日本のみ**。EU へ拡大するなら UMP の GDPR フォーム実装が先） / SKU は登録後変更不可
- **アプリ名 / サブタイトル / キーワードは、新しいバイナリを出さずに編集できる**（2026-08-31 に ASC 実画面で確認）。Apple 公式リファレンスの表は Name を「編集不可」側に置き、実務の定説も「キーワードは version-level なので新バージョンの提出が要る」としており**どちらとも食い違う**ため、ASO の反映計画を立てるときは**推測せず ASC を開いて確かめる**。⚠ ただし**変更の公開に審査が挟まるかは未確認** — 反映のリードタイムを見込む場合はここを先に確かめること
- **輸出コンプライアンス**: 暗号利用は標準 HTTPS と Sign in with Apple の nonce ハッシュ（CryptoKit SHA256 = Apple 標準・ハッシュは暗号化に非該当）のみで免除対象。`ITSAppUsesNonExemptEncryption = NO` を `Info.plist` に設定済みのため、提出のたびの暗号化アンケートは**自動スキップされる**
- **App Icon がアルファチャンネルを持たないこと**（違反すると `ITMS-90717`）。**検証は Release / Archive で行う。Debug では判定できない** — 派生 PNG は **Debug では常に `hasAlpha: yes`**（actool が RGBA コンテナで書き出すため。ソースのアルファ有無と**無関係**）、**Release では常に `no`**。ローカルの `builtin-validationUtility -validate-for-store` は**アルファをチェックしない**ので、通っても ASC 通過の証明にはならない
- **App Icon / LaunchLogo に SF Symbols を使わない**（ライセンス条項がアプリアイコン / ロゴでの使用を禁じている）。現在は `iosApp/scripts/generate_app_icon.swift` の自前パス描画で、`grep -rn "systemSymbolName" iosApp/` が 0 件であることが検証手段
- **App Icon は light / dark / tinted の 3 バリアント**が要る。**TestFlight 成功では証明できない** — dark / tinted は任意で、欠けていてもビルド・アップロードとも通るため、資産カタログを直接見る必要がある
- **配信前は Apple 側の各所にアプリアイコンが出ないのが正常**（ASC の「App 情報」ページ / iOS 設定 App の「Apple でサインイン」一覧など）。これらは App Store の配信済みアートワークを引いており、バンドル内の `AppIcon` とは無関係。**未配信を理由とする空欄を不具合と誤認しないこと**
- **Sign in with Apple の revoke 用 OAuth コードフロー設定**（Services ID / Team ID / Key ID / 秘密鍵）が Firebase Console に登録済みであること。**未設定だとアカウント削除がエラーになる**
- **Crashlytics の疎通と dSYM アップロードは 2026-08-21 に TestFlight 実機で実証済み**（スタックが `SettingsView.swift` の行番号まで解決されることを確認）。⚠️ **ビルド成功でも設定の存在でも証明できない** — dSYM アップロードのビルドフェーズ（`project.pbxproj` の `Upload dSYM to Crashlytics`）が壊れても Archive もアップロードも普通に通り、**クラッシュが起きるまで誰も気づかない**。Firebase SDK のメジャー更新や当該フェーズのスクリプトパス（`.../SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run`）に触れたら再検証する。手順は implementation_note 2026-08-21（Release ビルドに意図的クラッシュの導線を載せた検証専用ブランチが要る）

---

## 11. Featuring Nomination（App Store 掲載推薦の申請）

> ASC の **Featuring → Nominations**。Apple のエディトリアル面（Today / カテゴリ / コレクション）への推薦を自己申請する枠で、**無料・原稿だけ**で出せる。返信は刺さった場合のみ来るので、**無応答を失敗と読まない**（tasks ASO-10）。

### 11.1 制度の要点

| 項目 | 内容 |
|------|------|
| 種別 | `App Launch`（新規リリース / 予約注文）/ `App Enhancements`（新機能・大きな UX 改善を伴うアップデート）/ `New Content`（新規のアプリ内コンテンツ・季節キャンペーン・イベント・特典） |
| **提出後に変更できない** | Nomination ID / **Related Apps** / **Nomination Type** |
| 必須 | Related Apps（自アプリの Apple ID + 関連 9 本まで）/ Nomination Type / **Nomination Name（60 字）** |
| 任意（書く） | Nomination Description（1,000 字）/ **Helpful Details（500 字 = 独自性を書く枠）** / Publish Date（YYYY-MM-DD）/ Relevant Countries（ISO 3 文字）/ Platforms / Localization / Related In-App Events（25 件まで）/ Supplemental Materials（URL 5 本まで） |
| リードタイム | **最低 2 週間、Apple 推奨は 3 週間以上前** |
| 権限 | Account Holder / Admin / App Manager / Marketing |

出典: [Nominations template](https://developer.apple.com/help/app-store-connect/reference/nominations-template/) / [Nominate your app for featuring](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/)

### 11.2 種別の選び方（未確定 / 提出前に決める）

**種別は提出後に変更できない**ため、次バージョンの中身が固まってから提出する。現時点の候補は 2 つで、性格が違う。

- **`App Launch`** — 初回配信が 2026-08-17 で、リリース直後の窓がまだ残っている。ただしリードタイム（推奨 3 週間前）の考え方からすると本来は**配信前に出す**枠
- **`App Enhancements`** — 次バージョンに合わせる。**中身のあるアップデートが要る**ので、機能追加を伴わないメタデータ改訂だけの版に付けると訴求が弱い

> **原稿（11.3）は種別によらず共通**。訴求の芯（5 軸テイスティング / オンデバイス Foundation Models / 1 杯 = 1 件の設計）は版に依存しないため、種別だけ差し替えれば出せる。

### 11.3 原稿（`len` 実測済み）

**Nomination Name**（**57 字** / 60）

```
CoffeeVision: on-device taste analysis for coffee logging
```

**Nomination Description**（**995 字** / 1,000）

```
CoffeeVision is a coffee journal built for Japan's specialty coffee scene. Each cup — whether pulled at a cafe or brewed at home — is one record, capturing origin, variety, process, roast level, brew method, a half-star rating, and a five-axis tasting profile: sweetness, body, acidity, flavor, aftertaste.

Those five axes are what the app is built around. As records accumulate, the analysis tab draws the shape of the user's palate as a radar chart, surfaces which origins and roast levels they gravitate toward, and suggests beans they have not tried yet that fit the pattern.

On devices with Apple Intelligence, the Foundation Models framework puts that palate into words and answers questions like "which origins do I like?" — entirely on device. Records never leave the phone to be summarized or queried.

Cafes are searched through Google Places. Visited shops become pins on a map, shops the user wants to try are saved with their own pin, and the map grows into a personal coffee map.
```

**Helpful Details**（**499 字** / 500）

```
Three things set CoffeeVision apart. First, the five-axis tasting profile is the primary record rather than an afterthought — the entire analysis layer is built on it. Second, the Apple Intelligence features run through the on-device Foundation Models framework, so coffee records never leave the phone to be summarized or queried. Third, a cafe cup and a home brew are the same unit, so the map and the palate analysis draw on one continuous history. Solo-developed in Japan; free, no subscription.
```

**その他のフィールド**

| フィールド | 値 |
|-----------|----|
| Related Apps | `6788339362`（自アプリのみ。**提出後変更不可**） |
| Relevant Countries | `JPN` |
| Platforms | `iOS (iPhone)` |
| Localization | `ja` |
| Publish Date (Start) | 次バージョンの配信予定日（**提出はその 3 週間以上前**） |

> **英語で書く理由**: 申請の読み手は Apple のエディトリアルチームで、日本語ロケール限定の配信でも申請自体は英語で通す方が読まれる。ストア掲載原稿（§1〜§4）が日本語であることとは独立している。
>
> **オンデバイス処理を前面に出しているのは意図的**。Apple が推している Foundation Models framework を個人開発アプリが実装済み、という点が最も差別化される訴求で、`CoffeeInsightProviderIosImpl` の実装事実に基づく（§2 と同じ条件付きの機能）。

### 11.4 提出履歴

| 提出日 | 種別 | 対象バージョン | 結果 |
|--------|------|--------------|------|
| （未提出） | — | — | — |

---

## 変更履歴

1.0 リリース時点の内容。それ以前の原稿・申告の変遷は git log と [`tasks-archive.md`](./archive/1.0/tasks-archive.md)（ASO-1 / ASO-2 / ASO-6 の各行）を参照。

**2026-08-31**: §11 Featuring Nomination を新設（ASO-10）。§4 のキーワード再配分（ASO-8）は実測待ちのため未反映。
