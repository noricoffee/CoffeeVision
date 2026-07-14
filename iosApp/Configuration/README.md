# Configuration ディレクトリ

このディレクトリには Xcode Build Configuration ファイルを置きます。

## ファイル構成

| ファイル | コミット | 説明 |
|---------|---------|------|
| `Config.xcconfig` | する | TEAM_ID / バンドル ID / その他ビルド設定 |
| `Base.xcconfig` | する | API キー変数宣言 + Secrets.xcconfig の optional include |
| `Secrets.xcconfig` | しない | ローカル開発用 API キー（.gitignore 済） |
| `ExportOptions.plist` | する | App Store Connect 提出用エクスポート設定（`release-testflight.yml` から使用） |

## Places API キーの設定手順

1. Google Cloud Console（https://console.cloud.google.com/）で Places API (New) を有効化する
2. API キーを作成し、iOS アプリのバンドル ID `com.noricoffee.coffeevision` で制限をかける
3. `iosApp/Configuration/Secrets.xcconfig` を作成（なければ新規、あれば編集）して以下を記述:
   ```
   PLACES_API_KEY = AIza...
   ```
4. Xcode でビルドすると `Info.plist` の `PLACES_API_KEY` エントリに値が反映され、
   アプリが `Bundle.main.object(forInfoDictionaryKey: "PLACES_API_KEY")` で取得できるようになる

## AdMob App ID / ネイティブ広告ユニット ID の設定手順（本番切り替え）

ネイティブ広告 4 面（requirements.md §11）は `Base.xcconfig` に Google 公式のテスト用 ID が
フォールバックとして設定済みのため、`Secrets.xcconfig` が無くてもテスト広告で動作する。
本番 ID へ切り替えるときだけ以下を行う。

1. AdMob（https://admob.google.com/）でアプリを登録し、App ID を発行する
2. ネイティブ広告ユニットを 4 つ発行する（カフェ詳細 / マップ検索ドロップダウン / コーヒー記録タブ下部固定 / 分析タブ下部固定）
3. `iosApp/Configuration/Secrets.xcconfig` に以下を追記（キーは `Base.xcconfig` のフォールバックと同名）:
   ```
   ADMOB_APP_ID = ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy
   ADMOB_NATIVE_AD_UNIT_ID_CAFE_DETAIL = ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy
   ADMOB_NATIVE_AD_UNIT_ID_MAP_SEARCH = ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy
   ADMOB_NATIVE_AD_UNIT_ID_COFFEE_LIST = ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy
   ADMOB_NATIVE_AD_UNIT_ID_ANALYSIS = ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy
   ```
4. Xcode でビルドすると `Info.plist` の `GADApplicationIdentifier` / 各 `ADMOB_NATIVE_AD_UNIT_ID_*`
   エントリに本番値が反映される
5. AdMob アプリと Firebase プロジェクトのコンソールリンクを行う（任意だが Google 公式推奨。
   Analytics に広告収益イベントが流れるようになる）

## 注意事項

- `Secrets.xcconfig` は `.gitignore` に登録済みのためコミットされない
- 検証用 CI（`ci.yml`）では `Secrets.xcconfig` が存在しないため `PLACES_API_KEY` が空文字になる
  アプリはビルドできるが、Places API 呼び出しは 401 エラーになる
- `ADMOB_APP_ID` / `ADMOB_NATIVE_AD_UNIT_ID_*` は `Secrets.xcconfig` が無くても Google 公式のテスト用 ID
  にフォールバックするため、CI・ローカル開発ともにテスト広告として動作する（401 等のエラーにはならない）
- リリースワークフロー（`release-testflight.yml`）は GitHub Secrets の `PLACES_API_KEY` から
  `Secrets.xcconfig` を、`GOOGLE_SERVICE_INFO_PLIST_BASE64` から `GoogleService-Info.plist` を復元してビルドする
  （本番 AdMob ID を使う場合は同様に GitHub Secrets → `Secrets.xcconfig` への復元手順を追加する必要がある。
  未追加の間はテスト広告のままビルドされる）
- API キーの管理・ローテーション・利用制限については Google Cloud Console / AdMob のドキュメントを参照
