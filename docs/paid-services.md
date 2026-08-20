# 有料・課金対象サービス棚卸し

CoffeeVision が利用する外部サービスのうち、課金が発生する（または将来発生しうる）ものの一覧。
コスト影響のある変更（API 呼び出しの追加・FieldMask の拡張・同期対象の追加）をするときはこのドキュメントを更新する。

最終棚卸し: 2026-07-27（コード突き合わせ済み。Places のエンドポイント / FieldMask / 写真の段階読み込み枚数は実装と一致を確認）

---

## 1. Google Places API (New) v1 — **主要コスト源**

- 実装: `shared/data-places`（Ktor で REST 直叩き、SDK 不使用）。API キーは `iosApp/Configuration/Secrets.xcconfig`（git 管理外）→ `Info.plist` 経由で注入。
- 課金単位: **リクエスト毎**（結果件数ではない）。エンドポイント × FieldMask の組み合わせで SKU が決まる。

### 使用エンドポイントと呼び出し元

| エンドポイント | 呼び出し元機能 | 呼び出し頻度の性質 |
|---------------|--------------|------------------|
| `places:searchText` | カフェ検索画面のキーワード検索（`CafeSearchViewModel`）/ マップ POI タップ解決（`MapViewModel.searchByNameNear`、型フィルタなし版） | ユーザー操作起点。検索実行・POI タップ毎に 1 リクエスト |
| `places:searchNearby` | カフェ検索画面の周辺検索（`CafeSearchViewModel`）/ コーヒー記録エディタの周辺カフェ候補（`CoffeeEditorViewModel`、上位 3 件サジェスト） | ユーザー操作起点。エディタ側は位置取得毎に 1 リクエスト（`take(3)` は表示の絞り込みで課金は 1 リクエスト分） |
| `places/{placeId}`（Place Details） | カフェ詳細のリフレッシュ（`CafeDetailViewModel`）。おすすめカフェピン（curated、フェーズ 19）のタップも placeId 直渡しの詳細 push なのでこの経路（検索を経由せず Details 1 回のみ） | **抑制済み**: DB スナップショット由来で `googleRating == null` のときだけ 1 回取得（フェーズ 16）。検索 / POI 由来の新鮮な Cafe では叩かない |
| `{photoName}/media`（Photo Media） | カフェ写真表示（`PlacePhotoLoader` → `PlacePhotoThumbnail`）。表示画面: マップ・カフェ検索結果・カフェ詳細ヘッダー | サムネイル 1 枚毎に 1 リクエスト。表示枚数は View 側で制限: カフェ詳細ヘッダーは段階読み込み（初期 3 枚 →「さらに表示」で 3 枚ずつ、上限 10 枚。maxWidthPx 400、LazyHStack で表示分のみ順次取得。2026-07-13）/ 検索結果行 1 枚（maxWidthPx 200）/ マップ選択カード 1 枚（maxWidthPx 150）。データ層は無制限で `photoReferences` に全件保持。返る URL は時限署名付きで**利用規約により永続キャッシュ禁止**（URLSession 標準キャッシュのみ。画面再表示のたびに再リクエスト） |

### SKU に影響する FieldMask（`PlacesClientImpl`）

検索 / Details とも `rating` / `userRatingCount` / `priceLevel` / `currentOpeningHours` / `websiteUri` / `nationalPhoneNumber` を要求しており、**基本 SKU より上位の課金ティアに該当する**。FieldMask にフィールドを足すときは [Places API 課金表](https://developers.google.com/maps/billing-and-pricing/pricing) で SKU が上がらないか確認すること。

### コスト抑制の現状

- Place Details は鮮度条件付きで最大 1 回（上表）
- Photo Media はメモリキャッシュでセッション内の再取得を回避
- API キーは iOS アプリ（Bundle ID）制限付き（`403 API_KEY_IOS_APP_BLOCKED` 診断が `PlacesClientImpl` に記載あり）
- **予算アラート（Cloud Billing）設定済み**（2026-08-11 / App Store 提出後）。通知するだけで請求は止まらないため、下のクォータ上限とセットで初めて天井になる
- **クォータ上限（Places API (New) の分あたりリクエスト数）設定済み**（2026-08-11）。**実値は Cloud Console が正本**なのでここに書かない（変えるたびに嘘になる）。`per user` 側は無制限のまま — 2 つのクォータは AND で評価されるので、プロジェクト × API 単位の分あたり上限だけで請求の天井は成立する。`per user` が買うのは天井ではなく**発信元の隔離**（単一発信元が全体枠を食い尽くして正規ユーザーが 429 になるのを防ぐ）だが、本アプリは API キーのみで OAuth ユーザー identity を持たず Google 側の「user」識別が確実でないため、依存しない判断（2026-08-11）
  - **クォータはキー単位ではなく「プロジェクト × API」単位**。不正利用時は請求を守る代わりに正規ユーザーも一緒に絞られる。これは避けられない割り切りで、本命の解はバックエンドプロキシ + App Attest（規模拡大時。実装ノートの Places キー行）
- **API キーの「API の制限」を Places に限定済み**（2026-08-11）。ここが「制限なし」だと、抜かれたキーで Geocoding / Directions 等の他 Maps API を叩かれ、**Places に付けたクォータ上限を迂回される**。上のクォータ上限は「API 制限とセットで初めて天井になる」点に注意（Cloud Console →「APIとサービス」→「認証情報」→ 該当キー →「API の制限」）。**新しい Google API を使い始めるときはここの許可リストへの追加が必要**になる（追加を忘れると `403` で機能が動かない）
- **アプリ外の一時コスト**: おすすめカフェのシード生成 `scripts/seed/generate-curated-cafes.mjs`（フェーズ 19）が Text Search を叩く（2 クエリ × subAreas 数）。**2026-07-28 に対象を東京 1 県 → 9 県へ拡張**（東京 / 大阪 / 京都 / 神奈川 / 愛知 / 福岡 / 北海道 / 千葉 / 埼玉）したため、フル実行 1 回あたり **32 回 → 124 回**。実行は初回シードと定期リフレッシュ（Places 規約のキャッシュ規定 30 日）時のみで、**県を増やすとリフレッシュのたびのコストが線形に増える**

---

## 2. Firebase（Blaze 従量課金の対象）

導入 SDK（iOS SPM / Android Gradle）: Auth / Firestore / Storage / Crashlytics / Analytics / Performance / Remote Config（iOS のみ）。

| プロダクト | 課金 | 利用状況 |
|-----------|------|---------|
| **Cloud Firestore** | **従量課金**（read / write / delete / ストレージ / 帯域） | 同期の本体。`users/{uid}`（analyticsConsent）+ `users/{uid}/coffees`（コーヒー記録）+ `users/{uid}` 配下の savedCafes 等のサブコレクション、`beanProfiles`（豆ナレッジベース、クライアント read-only・write は Admin SDK のみ）、`curatedCafes`（都道府県別おすすめカフェ、同型 read-only。フェーズ 19。マップ起動時に one-shot 全件 get = **最大 47 reads / 起動**、メモリキャッシュで再読なし。2026-07-28 時点の投入対象は 9 県 = 9 reads / 起動）。オフライン永続化に同期を委ねる設計で独自同期キューなし。SQLDelight ローカル DB が検索・参照を担うため読み取りは同期時中心 |
| Firebase Auth | 実質無料（電話認証なし） | 匿名認証 + Sign in with Apple のリンク。SMS を使わないため課金なし |
| Cloud Storage for Firebase | **現状課金なし** | **採用見送り済み**。SDK リンクと `storage.rules` は残っているが、写真は端末ローカル（Documents/photos/）保存のみで `Photo.remoteUrl` は常に null。将来復活用にフィールド・rules を残置（data-model.md §1.4）。**復活時のコストは「写真 1 枚のサイズ × 枚数」でほぼ決まる**（保存料・転送料とも）ため、下の「写真 1 枚のサイズ」を参照。**復活着手時にコスト再見積もり** |
| Crashlytics / Analytics / Performance | 無料 | クラッシュレポート・利用分析・パフォーマンス計測 |
| Remote Config | 無料 | マップ POI 除外キーワードの配信（`map_poi_excluded_name_keywords`、`ApplePoiFilterConfig`）。起動時 fetch 1 回・最小フェッチ間隔は SDK 既定 12h（2026-07-13） |
| Cloud Functions（**9-6 協調フィルタ / 設計確定・未実装**） | **従量課金**（呼び出し回数 / 実行時間 / アウトバウンド）— 未発生 | 味覚プロファイル横断の近傍計算 callable。Admin 特権で全 `sharedTasteProfiles` を read（**ユーザー数に線形**）→ 近傍 cosine → 推薦カフェを返す。マップの推薦要求時に呼ぶ（起動毎ではない）。将来は地理事前フィルタ / Firestore ネイティブ KNN で read を削減。**実装着手時にコスト再見積もり**（設計は requirements 9-6 / analysis-model §2） |

### 写真 1 枚のサイズ（Storage 復活時のコスト変数）

写真は現在ローカル完結で**課金は発生していない**が、1 枚のサイズは Storage を復活させた場合の保存料・転送料をそのまま決めるため、ここに記録する。

**2026-08-01 に保存時リサイズを導入**（長辺 2048px 上限 / JPEG q0.8 / 1 記録あたり 10 枚上限。`ImageDownsampler`）。それ以前はリサイズが無く、PhotosPicker のフル解像度をそのまま JPEG 再エンコードしていた。

以下は**実測値**（2026-08-01。iOS シミュレータランタイム同梱のサンプル写真に、旧挙動 = フル解像度 q0.85 と新挙動 = 長辺 2048px q0.8 の両方を適用して計測）。

| 元画像 | 元ファイル | 旧挙動（フル解像度 q0.85） | 新挙動（2048px / q0.8） |
|---|---|---|---|
| 4032×3024 **HEIC** | 2.68MB | **4.39MB（×1.64 に膨張）** | 1.31MB |
| 4288×2848 JPEG | 1.81MB | 2.05MB | 0.41MB |
| 1668×2500 JPEG | 1.21MB | 1.15MB | 0.70MB |
| 800×600 JPEG | 0.11MB | — | 0.10MB（**拡大せず原寸**） |

**要点は HEIC の行**。HEIC は同画質で JPEG の約半分なので、フル解像度のまま JPEG へ再エンコードすると **元より大きくなる**（×1.64）。現行 iPhone の既定フォーマットは HEIC なので、これが実際に最も多いケースだった。JPEG 由来の写真は旧挙動でもほぼ等倍（×0.93〜1.13）で、膨張は HEIC 固有。

削減率は元画像の解像度と被写体のディテール量に依存し、**約 1.6〜5 倍**（12MP HEIC の代表ケースで 4.39MB → 1.31MB ＝ 約 3.4 倍）。長辺が 2048px に近い元画像ほど削減は小さい。年間の目安は 1 日 1 杯・平均 1.5 枚で**約 1.6GB → 約 0.4GB**。

上限を 2048px に置いた根拠は、写真を最大解像度で使うのが共有カードの 1080×1350px（requirements 2-12）だから。**この値を上げると Storage 復活時のコストが比例して増える。**

課金以外に 2 つの含意がある。①写真のバックアップは iCloud Backup に委ねる方針（requirements 7-2）だが **iCloud 無料枠は 5GB** なので、リサイズ前のペースはバックアップ失敗を招き、ASO-6 ①「機種変更で写真が消える」の実発生確率を押し上げていた ②クラウド保持を選ぶ場合、**Firebase Storage の対抗案として CloudKit がある**（§3 参照）。

---

## 2b. Google AdMob — **収益側**（課金なし・実装済み / 本番ユニット未発行）

- 2026-07-14 に導入決定（仕様は [requirements.md §11](./requirements.md)）。Places 従量コストの回収手段。SDK 利用自体は無料（収益から Google が手数料控除）。
- アダプティブバナー広告 **2 面**: カフェ詳細 / マップ検索結果シート（いずれもインライン。後者は 2026-07-22 に上部ドロップダウンから下部ドラッグシート `MapSearchResultsSheet` へ移設、結果 3 件目の後という配置ルールは不変）。iosApp View 層完結・iOS のみ。当初ネイティブ広告 4 面だったが MediaView 必須制約で同日バナーに再編 → **2026-07-16 にコーヒー記録タブ・分析タブの 2 面を撤去**（定着優先。requirements §11 11-3）。
- **規約上の注意**: Places 由来のデータ（店名等）を広告リクエストのターゲティングシグナルに渡さないこと（Google Maps Platform Service Specific Terms）。実装・レビュー時に確認する。
- App ID / 広告ユニット ID（2 ユニット）は `Secrets.xcconfig` → `Info.plist` 注入（Places キーと同経路）。

---

## 3. 無料のもの（誤解しやすいので明記）

- **Apple MapKit / Apple Maps POI**: ネイティブアプリでの MapKit 利用は無料。マップ表示・POI タップ自体には課金なし（POI 解決で Places `searchText` を叩いた時点で課金）
- **Sign in with Apple**: Apple Developer Program 年会費以外の従量課金なし
- **StoreKit のレビュー依頼（`AppStore.requestReview(in:)`、要件 9-9）**: OS 提供の機能で課金なし。キルスイッチ用に Remote Config のキー（`review_prompt_enabled`）が 1 つ増えるが、**Remote Config は上表のとおり無料**でパラメータ数による課金もないため、コスト構造は不変（2026-08-01）
- **Foundation Models（分析タブ 階層 3）**: Apple のオンデバイス LLM。API 課金なし
- **CloudKit（未採用 / 写真クラウド保持の対抗案）**: private database はデータが**ユーザー自身の iCloud 容量**を消費するため、**開発者側の従量課金はゼロ**。iOS 単独リリース（Android はリリース対象外）なので選択肢になる。identity が iCloud アカウントになる副次効果があり、Firebase 匿名アカウントのままでも機種変更で写真が引き継がれる（要件 7-3 の制約を部分的に回避）。ただし KMP 共通層からは使えず iosApp 側 Swift 完結になる。**写真をクラウドに置くかを判断する段階で Firebase Storage と比較すること**（どちらを選んでも上記のリサイズが前提）

---

## 更新ルール

- Places のエンドポイント追加 / FieldMask 変更、Firestore の同期対象コレクション追加、Storage 復活などコスト構造が変わる変更では、同じ変更内でこのドキュメントを更新する（親の責務）
- **「今は無料だから対象外」で判断しない**。このドキュメントの対象は冒頭のとおり「課金が発生する**または将来発生しうる**もの」で、`Cloud Storage` / `Cloud Functions` のように**未採用でも行がある**。将来の課金額を決める変数（写真の解像度・枚数上限など）を変えるときは、課金が現時点でゼロでも更新対象（2026-08-01 に写真リサイズで一度見落として指摘を受けた）
