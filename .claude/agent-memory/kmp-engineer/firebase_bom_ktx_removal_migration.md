---
name: firebase-bom-ktx-removal-migration
description: Firebase Android BoM を 34.x 以降へ上げて -ktx artifact を主モジュールへ統合するときの確認手順
metadata:
  type: project
---

Firebase BoM 34.0.0（2025-07）で `-ktx` artifact のリリースが停止し、BoM から `firebase-*-ktx` が削除された。35.0.0（2026-10）では minSdk 要件が API 24 に上がった程度で、Firestore / Auth / Storage の破壊的 API 変更はない（CoffeeVision が使う `Task` / `SetOptions` / `PersistentCacheSettings` / `addSnapshotListener` / `firestoreSettings {}` DSL はいずれも非 ktx パッケージパスのまま変化なし）。

## 確認したこと（33.7.0 → 35.1.0 移行時）
- コード側で `com.google.firebase.*.ktx` パッケージを import している箇所はゼロ（`grep -rn "import com.google.firebase" shared/data-firebase androidApp` で確認）。`firestoreSettings { ... }` のような DSL ビルダーは数年前から非 ktx パッケージ（`com.google.firebase.firestore.firestoreSettings`）に統合済みなので、依存を `-ktx` → 無印に変えるだけで import 修正は不要だった
- `gradle/libs.versions.toml` の `libs.firebase.firestore` 等のエイリアス名は変えず、`module = "...-ktx"` → `module = "..."`（無印）だけ書き換える。呼び出し側（`shared/data-firebase/build.gradle.kts` / `androidApp/build.gradle.kts`）は無変更で済む
- `firebase-storage`（catalog には定義されているが `grep -rln "FirebaseStorage"` でコード使用箇所ゼロ）のような未使用依存も、タスク指示にあるなら素直に rename する（削除するかは親の判断。自分で削らない）
- BoM の最新安定版確認は `https://dl.google.com/android/maven2/com/google/firebase/firebase-bom/maven-metadata.xml`（AndroidX と同じ dl.google.com 配下）

## 検証コマンド
`./gradlew :shared:data-firebase:testAndroidHostTest :androidApp:assembleDebug --console=plain`（フラグなしで通った。BUILD SUCCESSFUL、data-firebase のテスト結果 XML 3 本すべて failures=0）

## sandbox の注意
macOS の Bash ツールには GNU `timeout` コマンドが無い（`command not found`、exit 127）。長時間コマンドは Bash ツール自体の `timeout` パラメータ（ミリ秒）を使うこと。シェルの `timeout 590 ...` は使えない。
