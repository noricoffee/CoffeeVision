# Firestore seed スクリプト

Firestore へのデータ投入スクリプト置き場。いずれも Admin SDK 使用（サービスアカウント鍵が必要、鍵は非コミット）、ドキュメント ID 固定の `set()` による冪等 upsert（再実行 = 上書き更新）、`--dry-run` はバリデーションのみで firebase-admin 不要。

## 共通: サービスアカウント鍵の取得（ユーザー作業）

1. [Firebase Console](https://console.firebase.google.com/project/coffeevision-a54aa/settings/serviceaccounts/adminsdk) → プロジェクトの設定 → サービスアカウント → 「新しい秘密鍵の生成」で JSON 鍵を取得（**リポジトリにコミットしない**。`*service-account*.json` は .gitignore 済み）
2. `cd scripts/seed && npm install`

---

## beanProfiles seed（豆ナレッジ初期データ）

`beanProfiles` コレクション（サービス管理 / クライアント read-only）への初期データ投入。データ本体は `bean-profiles.json`（主要産地網羅 38 件）。表記規約・flavorNotes 統一語彙の正本は [`docs/data-model.md`](../../docs/data-model.md) §3.2。

```sh
# 検証（鍵不要）: 必須フィールド / processings の enum 名 / flavorNotes の統一語彙 / beanId の重複・書式
node seed-bean-profiles.mjs --dry-run

# 本番投入
GOOGLE_APPLICATION_CREDENTIALS=/path/to/coffeevision-service-account.json node seed-bean-profiles.mjs
```

- ドキュメント ID = `beanId`。JSON から項目を消した場合は Firebase Console で手動削除する
- 投入後の確認: 実機の分析タブ「好みの豆の傾向」/「未経験の豆への探索提案」、エディタの産地サジェスト（`docs/tasks/verification-checklist.md` の 15-E-3 項目）。アプリはメモリキャッシュ（one-shot get）のため、投入後はアプリを再起動する

---

## curatedCafes seed（都道府県別おすすめカフェ）

`curatedCafes/{prefectureCode}` コレクション（サービス管理 / クライアント read-only、JIS X 0401 コードで 1 県 1 ドキュメント）への投入。**生成 → 人手レビュー → 投入の 2 段構成**。モデル定義の正本は [`docs/data-model.md`](../../docs/data-model.md)。

> ⚠️ **`generate-curated-cafes.mjs` は `curated-cafes.json` を「`--prefectures` に渡した県だけ」で丸ごと上書きする**。単県で実行すると他県のレビュー済みデータが JSON から消える（Firestore 側のドキュメントは `set()` されないので残るが、リポジトリ内の正本が失われ、次の定期リフレッシュで復元できない）。**投入対象の県は毎回すべて列挙して実行する**こと。

```sh
# 1. 候補生成（Places API Text Search を叩く。9 県フルで 124 回 = 一回きりのコスト）
#    投入対象 9 県を毎回まとめて指定する（東京の再生成は 30 日リフレッシュを兼ねる）
PLACES_API_KEY=... node generate-curated-cafes.mjs --prefectures 13,27,26,14,23,40,01,12,11

# 2. curated-cafes.json を目視レビュー（不適切な候補・閉店済みを削除。件数調整）

# 3. 検証（鍵不要）: コード形式 / 座標の日本域内 / 件数 1〜200 / placeId 重複 / 未知フィールド
node seed-curated-cafes.mjs --dry-run

# 4. 本番投入
GOOGLE_APPLICATION_CREDENTIALS=/path/to/coffeevision-service-account.json node seed-curated-cafes.mjs
```

- 保存するのは **placeId + 名前 + 座標 + 県コードの最小限のみ**。評価・レビュー数は生成時の選別にだけ使い JSON に残さない（Places 規約対応）。アプリはピンタップ時に getDetails で揮発データを解決する
- **定期リフレッシュ**: Places 規約のキャッシュ規定（placeId 以外は 30 日）対応として、generate → seed を定期的に再実行してデータを更新する運用（`updatedAt` で最終シード日時を確認できる）
- 選定は 2 段構成: **基準上位**（評価 4.4 / レビュー 100 件以上、上限 = 東京 100 / 他県 30）+ **人気枠**（評価 3.7 / レビュー 500 件以上、上限の枠外で全件追加）。上限・エリアは `generate-curated-cafes.mjs` の `PREFECTURES` 定数
- **`subAreas` を定義した県だけが実質的な対象**（省略時は県名 1 エリア = 2 クエリのみでカバレッジが極端に薄くなる）。2026-07-28 時点の定義済みは 9 県 — 東京 16 エリア / 大阪・京都・神奈川・愛知・福岡・北海道 各 6 / 千葉・埼玉 各 5。さらに県を増やすときは `PREFECTURES` に `subAreas` を足し、上の `--prefectures` 列にもコードを追加する
- **Places API キーの制限に注意**: アプリ用の本番キーは iOS Bundle ID 制限付きのため、このスクリプトから叩くと `403 API_KEY_IOS_APP_BLOCKED` になる。サーバー実行用の別キー（制限なし / IP 制限）を `PLACES_API_KEY` に渡すこと
- レビューで除外確定した店・ブランド（コンセプト系 / 大手チェーン等）は同スクリプトの `EXCLUDED_NAME_KEYWORDS` に追記する（再生成・定期リフレッシュでの再混入防止）
- 投入後の確認: マップを投入済みの県（東京 / 大阪 等）に移動しておすすめピン（burnt orange の大きめカフェピン）が出ること。**ズームゲート 3000m のため広域表示では出ない**。アプリはメモリキャッシュ（one-shot get）のため、投入後はアプリを再起動する

---

## coffees seed（エクスポート JSON の開発用投入）

アプリのエクスポート JSON（設定 → データのエクスポート。`{ exportedAt, version: 1, records: [] }`）を `users/{uid}/coffees` へ投入する開発用スクリプト。エクスポートしたデータの再投入・別アカウントへの付け替え投入・手書きダミーデータの投入に使う。

```sh
# 検証（鍵不要）: envelope v1 / 必須フィールド / enum 名 / 日付形式 / id 重複 + 変換サンプル表示
node seed-coffees.mjs --dry-run export.json

# 本番投入
GOOGLE_APPLICATION_CREDENTIALS=/path/to/coffeevision-service-account.json \
  node seed-coffees.mjs --uid <firebase-auth-uid> export.json
```

- `--uid` は投入先の Firebase Auth uid（Firebase Console → Authentication で確認）。**全レコードの `userId` をこの値で上書き**するので、別アカウントのエクスポートもそのまま投入できる
- ドキュメント ID = `record.id`。Firestore 直列化規則（[`docs/data-model.md`](../../docs/data-model.md) §`users/{uid}/coffees`）へは投入時に変換する: null フィールドはキーごと省略 / `createdAt`・`updatedAt` は Timestamp 化 / **photos は常に空配列**（画像ファイルは端末ローカルのみのため、メタデータだけ投入しても解決できない）
- 投入後は実機のサインイン中リスナーが自動反映する（アプリ起動中なら即時、未起動なら次回起動時。再インストール不要）
- 投入したレコードは通常のレコードとして全端末に同期される。消したくなったら Firebase Console かアプリから削除する
