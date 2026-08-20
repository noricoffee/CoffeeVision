---
name: firebase-spm-pbxproj
description: iosApp.xcodeproj への Firebase SPM プロダクト手動追加の一般手順と FirebaseAnalyticsWithoutAdIdSupport 廃止の注意（個別ケースは [[firebase-remote-config-spm]] 参照）
metadata:
  type: project
---

## Firebase SPM の SPM プロダクト名は pbxproj 手編集で追加できる。ただし `FirebaseAnalyticsWithoutAdIdSupport` は現行 SDK（12.14.0 時点）で廃止済み（2026-07-08、テレメトリ導入で確認）

- `iosApp.xcodeproj/project.pbxproj` は手書き/短縮 ID（`FB0000...`）で管理されており xcodegen 等の生成ツールは使っていない。新規 SPM プロダクト追加は `PBXBuildFile` + `PBXFrameworksBuildPhase.files` + `PBXNativeTarget.packageProductDependencies` + `XCSwiftPackageProductDependency` の 4 箇所に同じ ID 命名規則（`FB000001.../FB000002...`）で追記すれば通る（Xcode UI 不要。連番の割り当てルールは [[firebase-remote-config-spm]] 参照）。新規 Run Script Build Phase も同様に手書き追加可能（`PBXShellScriptBuildPhase` セクション + native target `buildPhases` 配列への ID 追記）。
- **重要な仕様変更**: 旧来 IDFA 回避目的で使われていた SPM プロダクト `FirebaseAnalyticsWithoutAdIdSupport` は、firebase-ios-sdk 12.14.0 時点の `Package.swift` に存在しない（`grep AdIdSupport Package.swift` が 0 件）。**現行 SDK ではデフォルトの `FirebaseAnalytics` プロダクト自体が IDFA 非対応（旧 WithoutAdIdSupport 相当）**になっており、IDFA/AdId を使いたい場合だけ追加で `FirebaseAnalyticsIdentitySupport`（旧命名の逆転）を足す方式に変わった。`Carthage.md` に「AdId support を無効化するには `GoogleAppMeasurementIdentitySupport.xcframework` を含めない」という記述があり裏取りできる。**docs や実装ノートに `FirebaseAnalyticsWithoutAdIdSupport` という名前が残っていたら、`FirebaseAnalytics`（プレーン）に読み替える**。IDFA 非依存という要件自体は `FirebaseAnalyticsIdentitySupport` を追加しなければ変わらず満たされる。
- Crashlytics dSYM アップロード run-script 追加後、Debug 構成ビルドで `DEBUG_INFORMATION_FORMAT should be set to dwarf-with-dsym` warning が出るのは想定内（Debug は `dwarf`、Release のみ `dwarf-with-dsym` のプロジェクト設定のため。Release/TestFlight ビルドでのみ実際に dSYM がアップロードされれば良く、Debug 警告は無害）。
- 新しい `FirebaseAnalytics` SDK（12.x）は `.analyticsScreen(name:class:extraParameters:)` という公式 SwiftUI screen-tracking modifier を同梱している（`FirebaseAnalytics/README.md` に記載）。自前の `.trackScreen(_:)` extension を書く代わりに使える将来の選択肢として認識しておく（今回は独自命名の `.trackScreen` を採用。理由は screen 名を `AnalyticsParameterScreenName`/`ScreenClass` に同一値で渡す既存方針に寄せたかったため）。
