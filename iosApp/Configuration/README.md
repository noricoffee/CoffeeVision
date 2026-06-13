# Configuration ディレクトリ

このディレクトリには Xcode Build Configuration ファイルを置きます。

## ファイル構成

| ファイル | コミット | 説明 |
|---------|---------|------|
| `Config.xcconfig` | する | TEAM_ID / バンドル ID / その他ビルド設定 |
| `Base.xcconfig` | する | API キー変数宣言 + Secrets.xcconfig の optional include |
| `Secrets.xcconfig` | しない | ローカル開発用 API キー（.gitignore 済） |

## Places API キーの設定手順

1. Google Cloud Console（https://console.cloud.google.com/）で Places API (New) を有効化する
2. API キーを作成し、iOS アプリのバンドル ID `com.noricoffee.coffeevision` で制限をかける
3. `iosApp/Configuration/Secrets.xcconfig` を作成（なければ新規、あれば編集）して以下を記述:
   ```
   PLACES_API_KEY = AIza...
   ```
4. Xcode でビルドすると `Info.plist` の `PLACES_API_KEY` エントリに値が反映され、
   アプリが `Bundle.main.object(forInfoDictionaryKey: "PLACES_API_KEY")` で取得できるようになる

## 注意事項

- `Secrets.xcconfig` は `.gitignore` に登録済みのためコミットされない
- CI 環境（GitHub Actions 等）では `Secrets.xcconfig` が存在しないため `PLACES_API_KEY` が空文字になる
  アプリはビルドできるが、Places API 呼び出しは 401 エラーになる
- API キーの管理・ローテーション・利用制限については Google Cloud Console のドキュメントを参照
