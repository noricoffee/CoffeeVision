# 有料・課金対象サービス棚卸し

CoffeeVision が利用する外部サービスのうち、課金が発生する（または将来発生しうる）ものの一覧。
コスト影響のある変更（API 呼び出しの追加・FieldMask の拡張・同期対象の追加）をするときはこのドキュメントを更新する。

最終棚卸し: 2026-07-13（コード突き合わせ済み）

---

## 1. Google Places API (New) v1 — **主要コスト源**

- 実装: `shared/data-places`（Ktor で REST 直叩き、SDK 不使用）。API キーは `iosApp/Configuration/Secrets.xcconfig`（git 管理外）→ `Info.plist` 経由で注入。
- 課金単位: **リクエスト毎**（結果件数ではない）。エンドポイント × FieldMask の組み合わせで SKU が決まる。

### 使用エンドポイントと呼び出し元

| エンドポイント | 呼び出し元機能 | 呼び出し頻度の性質 |
|---------------|--------------|------------------|
| `places:searchText` | カフェ検索画面のキーワード検索（`CafeSearchViewModel`）/ マップ POI タップ解決（`MapViewModel.searchByNameNear`、型フィルタなし版） | ユーザー操作起点。検索実行・POI タップ毎に 1 リクエスト |
| `places:searchNearby` | カフェ検索画面の周辺検索（`CafeSearchViewModel`）/ コーヒー記録エディタの周辺カフェ候補（`CoffeeEditorViewModel`、上位 3 件サジェスト） | ユーザー操作起点。エディタ側は位置取得毎に 1 リクエスト（`take(3)` は表示の絞り込みで課金は 1 リクエスト分） |
| `places/{placeId}`（Place Details） | カフェ詳細のリフレッシュ（`CafeDetailViewModel`） | **抑制済み**: DB スナップショット由来で `googleRating == null` のときだけ 1 回取得（フェーズ 16）。検索 / POI 由来の新鮮な Cafe では叩かない |
| `{photoName}/media`（Photo Media） | カフェ写真表示（`PlacePhotoLoader` → `PlacePhotoThumbnail`）。表示画面: マップ・カフェ検索結果・カフェ詳細ヘッダー | サムネイル 1 枚毎に 1 リクエスト。表示枚数は View 側で制限: カフェ詳細ヘッダーは段階読み込み（初期 3 枚 →「さらに表示」で 3 枚ずつ、上限 10 枚。maxWidthPx 400、LazyHStack で表示分のみ順次取得。2026-07-13）/ 検索結果行 1 枚（maxWidthPx 200）/ マップ選択カード 1 枚（maxWidthPx 150）。データ層は無制限で `photoReferences` に全件保持。返る URL は時限署名付きで**利用規約により永続キャッシュ禁止**（URLSession 標準キャッシュのみ。画面再表示のたびに再リクエスト） |

### SKU に影響する FieldMask（`PlacesClientImpl`）

検索 / Details とも `rating` / `userRatingCount` / `priceLevel` / `currentOpeningHours` / `websiteUri` / `nationalPhoneNumber` を要求しており、**基本 SKU より上位の課金ティアに該当する**。FieldMask にフィールドを足すときは [Places API 課金表](https://developers.google.com/maps/billing-and-pricing/pricing) で SKU が上がらないか確認すること。

### コスト抑制の現状

- Place Details は鮮度条件付きで最大 1 回（上表）
- Photo Media はメモリキャッシュでセッション内の再取得を回避
- API キーは iOS アプリ（Bundle ID）制限付き（`403 API_KEY_IOS_APP_BLOCKED` 診断が `PlacesClientImpl` に記載あり）

---

## 2. Firebase（Blaze 従量課金の対象）

導入 SDK（iOS SPM / Android Gradle）: Auth / Firestore / Storage / Crashlytics / Analytics / Performance / Remote Config（iOS のみ）。

| プロダクト | 課金 | 利用状況 |
|-----------|------|---------|
| **Cloud Firestore** | **従量課金**（read / write / delete / ストレージ / 帯域） | 同期の本体。`users/{uid}`（analyticsConsent）+ `users/{uid}/coffees`（コーヒー記録）+ `users/{uid}` 配下の savedCafes 等のサブコレクション、`beanProfiles`（豆ナレッジベース、クライアント read-only・write は Admin SDK のみ）。オフライン永続化に同期を委ねる設計で独自同期キューなし。SQLDelight ローカル DB が検索・参照を担うため読み取りは同期時中心 |
| Firebase Auth | 実質無料（電話認証なし） | 匿名認証 + Sign in with Apple のリンク。SMS を使わないため課金なし |
| Cloud Storage for Firebase | **現状課金なし** | **採用見送り済み**。SDK リンクと `storage.rules` は残っているが、写真は端末ローカル（Documents/photos/）保存のみで `Photo.remoteUrl` は常に null。将来復活用にフィールド・rules を残置（data-model.md §1.4） |
| Crashlytics / Analytics / Performance | 無料 | クラッシュレポート・利用分析・パフォーマンス計測 |
| Remote Config | 無料 | マップ POI 除外キーワードの配信（`map_poi_excluded_name_keywords`、`ApplePoiFilterConfig`）。起動時 fetch 1 回・最小フェッチ間隔は SDK 既定 12h（2026-07-13） |

---

## 2b. Google AdMob — **収益側**（課金なし・導入決定済み / 実装前）

- 2026-07-14 に導入決定（仕様は [requirements.md §11](./requirements.md)）。Places 従量コストの回収手段。SDK 利用自体は無料（収益から Google が手数料控除）。
- アダプティブバナー広告 4 面: カフェ詳細 / マップ検索ドロップダウン（インライン）+ コーヒー記録タブ・分析タブの下部固定（アンカー）。iosApp View 層完結・iOS のみ。当初ネイティブ広告だったが MediaView 必須制約で同日バナーに再編（requirements §11）。
- **規約上の注意**: Places 由来のデータ（店名等）を広告リクエストのターゲティングシグナルに渡さないこと（Google Maps Platform Service Specific Terms）。実装・レビュー時に確認する。
- App ID / 広告ユニット ID（4 ユニット）は `Secrets.xcconfig` → `Info.plist` 注入（Places キーと同経路）。

---

## 3. 無料のもの（誤解しやすいので明記）

- **Apple MapKit / Apple Maps POI**: ネイティブアプリでの MapKit 利用は無料。マップ表示・POI タップ自体には課金なし（POI 解決で Places `searchText` を叩いた時点で課金）
- **Sign in with Apple**: Apple Developer Program 年会費以外の従量課金なし
- **Foundation Models（分析タブ 階層 3）**: Apple のオンデバイス LLM。API 課金なし

---

## 更新ルール

- Places のエンドポイント追加 / FieldMask 変更、Firestore の同期対象コレクション追加、Storage 復活などコスト構造が変わる変更では、同じ変更内でこのドキュメントを更新する（親の責務）
