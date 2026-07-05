---
name: verify-kmp-ios
description: CoffeeVision の KMP / iOS 変更後の検証手順。shared や iosApp を変更したとき、サブエージェントのビルド成功報告を受けたとき、「ビルドは通るのに動かない」系の切り分けが必要なときに使う。
---

# KMP / iOS 変更の検証手順

「コンパイルが通る ＝ 正しい」ではない、が本プロジェクトの検証の大前提。
lessons.md に蓄積された検証の定石を手順化したもの（各項目の詳細・発生源は `docs/tasks/lessons.md` の該当日付エントリを参照）。

## 変更内容 → 必須検証のマトリクス

| 変更した場所 | 必須の検証 |
|---|---|
| `shared/**`（commonMain 含む） | ① ユニットテスト（下記 2 ターゲット） ② `assembleSharedLogicXCFramework` |
| `shared` の公開 API（Swift から見える型・シグネチャ） | 上記 ＋ ③ `xcodebuild`（override フラグ無し）で iosApp フルビルド |
| `iosApp/**` のみ | ③ `xcodebuild`（override フラグ無し） |
| UI 挙動バグの修正 | 上記 ＋ ④ ユーザーにシミュレータ / 実機確認を依頼（ビルド成功 ≠ 修正完了） |
| 選定・集計ロジック（max / comparator / 統計） | 境界ケースのユニットテスト必須（`maxWith`+`compareByDescending` 逆転、mapNotNull 全 null の前例あり） |

## ① ユニットテスト — 必ず 2 ターゲットで回す

```bash
./gradlew testAndroidHostTest
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./gradlew iosSimulatorArm64Test
```

- `androidHostTest` はソースセット名。実行タスクは `testAndroidHostTest`（コンパイル単体は `compileAndroidHostTest`）
- **commonTest を JVM だけで回さない**。接続設定（PRAGMA 等）の乖離で「JVM だけ green」になった前例あり（2026-07-03 FK 無効）
- iOS テストの実行は**親セッションの仕事**。サブエージェント sandbox は `MissingXcodeException` で失敗する（代替としてサブエージェントには `compileTestKotlinIosSimulatorArm64` まで指示する）

## ② iOS ターゲットの実コンパイル

```bash
./gradlew assembleSharedLogicXCFramework
```

- `compileKotlinMetadata`（commonMain）成功だけでは不十分。クロスモジュールの nullable smart cast エラー等は iOS ターゲットの実コンパイルでしか出ない（2026-06-19）

## ③ iosApp フルビルド — override フラグ厳禁

```bash
xcodebuild -project iosApp/iosApp.xcodeproj -scheme iosApp -sdk iphonesimulator -configuration Debug build
```

- `OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED=YES` 付きの BUILD SUCCEEDED は**偽の成功**（Gradle がスキップされ、古い framework に対して Swift がコンパイルされる）。サブエージェントがこのフラグ付きで成功報告してきたら、親がフラグ無しで再検証してから完了扱いにする
- ログに `> Task :shared:framework:...` と Gradle 側の `BUILD SUCCESSFUL` が出ていることを確認する

## 切り分け集（「通るはずなのに」「直したはずなのに」）

- **SourceKit の `No such module 'SharedLogic'`**: `xcodebuild` が成功していれば偽陽性として無視可。気になる場合は DerivedData（`~/Library/Developer/Xcode/DerivedData/iosApp-*`）削除 + Clean Build Folder
- **`.allCases` has no member 等、SDK 更新後の不可解なエラー**: DerivedData の broken symlink を疑う。`xcodebuild -showBuildSettings` で検索パスを確認 → DerivedData 削除
- **ソース修正したのに挙動が変わらない**: バイナリ実読みで切り分ける。`xcrun simctl get_app_container <udid> <bundleId>` で .app パス取得 → `LC_ALL=C grep -a -c "<修正で入る文字列>" <app>/coffeevision.debug.dylib`（Debug は dylib 側に実体が入る）
- **xcconfig の変数が効いているか**: ソースを見ても分からない。ビルド成果物の `.app/Info.plist` を PlistBuddy で実読みする。フォールバック宣言（`KEY =`）は `#include?` の**前**に置く（後ろだと実値を空で上書き）
- **「重い」報告**: 最初に (a) Release/Profile で再現するか (b) デバッガをデタッチして再現するか を切り分ける。debug 限定なら実在しない問題（K/N 非最適化 + os_log 転送のアーティファクト）なので追わない
- **外部 API が「0 件」を返す**: 「本当に空 200 か / 握り潰した非 2xx か」を疑う。Ktor `expectSuccess` と DTO のデフォルト値がエラーを正常デコードに化けさせる経路（2026-06-23）。curl で実送信ボディを突き合わせる
- **Kotlin scope のリーク検証**: Instruments で Swift Bridge を見ても検出できない。collector に `.onCompletion { println }` を一時的に仕込み、push→pop で完了ログが出るか（コルーチンの寿命）で見る（2026-06-24）

## 完了条件チェックリスト

- [ ] 変更範囲に対応するマトリクスの検証をすべて実行した（ログ確認込み）
- [ ] サブエージェントの成功報告を鵜呑みにしていない（override フラグ / 実行できないタスクの「成功」）
- [ ] UI 挙動の修正なら、ユーザーの実機 / シミュレータ確認を明示的に依頼した
- [ ] 「テストの人工物で実データなら問題ない」系の説明は、実測で裏を取るまで留保した
