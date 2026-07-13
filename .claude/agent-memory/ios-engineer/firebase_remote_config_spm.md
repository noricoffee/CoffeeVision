---
name: firebase-remote-config-spm
description: FirebaseRemoteConfig を SPM 追加するときの pbxproj 手編集手順と FIRRemoteConfigValue.stringValue の non-optional 挙動
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
