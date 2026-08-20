---
name: firebase-remote-config-spm
description: FirebaseRemoteConfig を SPM 追加するときの pbxproj 手編集手順、FIRRemoteConfigValue.stringValue の non-optional 挙動、Bool キーの「未設定→true」実装パターン
metadata:
  type: project
---

## 新規 Firebase SPM プロダクトの pbxproj 追加手順（2026-07-13、`FirebaseRemoteConfig` 追加で確認）

- `iosApp.xcodeproj/project.pbxproj` は手書き ID 命名規則（`FB000001.../FB000002...`）に**プロダクトごとの連番**が振られている（Crashlytics=4, Analytics=5, Performance=6 など）。新規プロダクトは次の連番（例: RemoteConfig=7）を使い、以下 4 箇所に同時追記すれば Xcode UI 不要で通る:
  1. `PBXBuildFile` セクション（`FB0000010000000000000007 /* X in Frameworks */`）
  2. `PBXFrameworksBuildPhase.files` 配列
  3. `PBXNativeTarget.packageProductDependencies` 配列
  4. `XCSwiftPackageProductDependency` セクション（`FB0000020000000000000007 /* X */`、`productName = X;`）
- `package =` は既存の `XCRemoteSwiftPackageReference "firebase-ios-sdk"`（`FB0000030000000000000001`）をそのまま再利用する（バージョン指定は 1 箇所のみ、プロダクト追加時に変更不要）。
- SPM プロダクト名の正確な綴りは、DerivedData 配下の checkout（`~/Library/Developer/Xcode/DerivedData/iosApp-*/SourcePackages/checkouts/firebase-ios-sdk/Package.swift`）を `grep` して確認するのが確実（Firebase 公式ドキュメントの記載と実際の Package.swift の product 名が一致するとは限らないため）。
- 新規プロダクトのプライバシーマニフェスト（`PrivacyInfo.xcprivacy`）は checkout 内の `<Product>/Swift/Resources/PrivacyInfo.xcprivacy` 等で自己申告済みか確認する（アプリ側 `PrivacyInfo.xcprivacy` の追記が不要かどうかの裏取り、F-1 監査と同じ確認方法）。`FirebaseRemoteConfig` は `NSPrivacyAccessedAPICategoryUserDefaults`（`1C8F.1`）のみ宣言、tracking なし → アプリ側追記不要。

## `FIRRemoteConfigValue.stringValue` は `NSString * _Nonnull`（Swift では `String`、non-optional）

- ObjC ヘッダ（`FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h`）で `@property(nonatomic, readonly, nonnull) NSString *stringValue;` と宣言されている。**`guard let` で unwrap しようとするとコンパイルエラー**（非 Optional に `let` パターンは使えない）。未取得のキーに対しては空文字 `""` が返る仕様なので、フォールバック判定は `!rawValue.isEmpty` で行う（`RemoteConfigValue.stringValue` を使う新しいキー追加時も同様の非 Optional 前提で書く）。
- `try await RemoteConfig.remoteConfig().fetchAndActivate()` は公式 async/await API（テストコード `FirebaseRemoteConfig/Tests/Swift/SwiftAPI/AsyncAwaitTests.swift` で確認済み）。completion handler 版へのフォールバック実装は不要。

## Bool キーで「未設定のときは true（既定 ON）」を実装するときは `.boolValue` 単体では判定できない。`FIRRemoteConfigValue.source == .static` を使う（2026-08-01、ASO-1 レビュー依頼キルスイッチで確認）

- `stringValue` と同様、`boolValue` も non-optional で、未取得キーには型の静的既定値（`false`）が返る。**`boolValue` だけを見ると「未設定」と「明示的に false」を区別できない**（`false` を「未設定→true にフォールバック」の判定に使えない）。
- 区別には `FIRRemoteConfigValue.source: FIRRemoteConfigSource` を使う。`FIRRemoteConfig.h` のコメント上、3 値の意味は `.remote`（fetch 済みの値）/ `.default`（in-app defaults に設定した値）/ `.static`（"The data doesn't exist, return a static initialized value." = remote にも in-app defaults にも存在しない）。**`.static` のときだけ**「未設定」と確定できる。
- 実装ソースでの裏取り: `FIRConfigValue.m` の `init`（引数なし）が `initWithData:nil source:FIRRemoteConfigSourceStatic` を呼んでおり、`boolValue` は `stringValue.boolValue` 経由（`stringValue` は `data` が nil のとき `""` を返す）。キーが存在しないときに `configValueForKey:` がこのデフォルト初期化済みインスタンスを返すことは `FIRRemoteConfig.m` の `configValueForKey:` 実装で確認できる。
- 実装パターン:
  ```swift
  let value = RemoteConfig.remoteConfig().configValue(forKey: key)
  guard value.source != .static else { return true } // 未設定 → 既定 ON
  return value.boolValue
  ```
- ソース裏取りが必要なとき、`FirebaseRemoteConfig` の `.swiftinterface` / Obj-C ヘッダには `source` プロパティの型しか載らずセマンティクスは載らない。**DerivedData 配下の SPM checkout 実装（`.m` ファイル）まで読むと確実**（`~/Library/Developer/Xcode/DerivedData/iosApp-*/SourcePackages/checkouts/firebase-ios-sdk/FirebaseRemoteConfig/Sources/FIRConfigValue.m` / `FIRRemoteConfig.m`）。ヘッダのコメントだけで判断せず、実装まで見れば「未取得キー→ `.static` + 型既定値」という組み合わせが動作として確定する。
