---
name: location-mapkit
description: LocationManager の無音取得パターン、MKLocalPointsOfInterestRequest / MKLocalSearch による常時カフェピン実装
metadata:
  type: project
---

## 位置情報を「許可済みのときだけ無音取得」する実装パターン（2026-07-06、CoffeeEditor 現在地サジェストで確認）

- 既存 `iosApp/iosApp/Utilities/LocationManager.swift` の `requestLocation()` は `.notDetermined` のとき自動で許可ダイアログを出す仕様（`MapTabView` の「タップして現在地」導線向け）。**「未許可なら無音でスキップ」が要件の画面（例: エディタ起動時の自動サジェスト）では `requestLocation()` を直接呼ばず、呼ぶ側で `authorizationStatus` を switch して `.authorizedWhenInUse` / `.authorizedAlways` のときだけ呼ぶ**。`LocationManager` 自体は変更不要（既存の他画面の挙動を壊さないため）。
- 取得結果の反映は `.onChange(of: locationManager.lastLocation?.latitude)` で拾うのが確立パターン（`CLLocationCoordinate2D` が `Equatable` 非準拠なため `latitude` を見る。`MapTabView` と同型）。

## `MKLocalPointsOfInterestRequest` + `MKLocalSearch` で「常時見えるカフェピン」を実装するパターン（フェーズ 17、周辺カフェ自前ピン化で確認）

- `MKLocalPointsOfInterestRequest(center:radius:)` の Swift シグネチャは ObjC ヘッダの `initWithCenterCoordinate:radius:` から素直に導出できる（`.swiftinterface` 確認不要、Apple 公式 SDK ヘッダ `MapKit.framework/Headers/MKLocalPointsOfInterestRequest.h` を直接読めばよい。KMP ブリッジと違い純正 Apple API なので裏取り先が異なる）。
- `MKLocalSearch(request:)` → `try await .start()` は completion handler ベースの ObjC API に対する Apple 公式 Swift async overlay（ヘッダには載らない）。広く使われる確立パターンなので信頼してよい。
- `MKPointOfInterestFilter(including:)` は SwiftUI `MapStyle` の `PointOfInterestFilter.including(_:)`（`.mapStyle(.standard(pointsOfInterest:))` に渡す方）とは**別の型**（`MKPointOfInterestFilter`、MapKit の ObjC 型）。名前が同じ `including` で紛らわしいので取り違えに注意。
- デバウンス+キャンセルは `Task` を `@State` に保持し、新規スケジュール時に前回を `cancel()` → `Task.sleep` → `Task.isCancelled` チェック、が定番。ズームゲート（半径がしきい値超なら fetch せずクリア）は入口でガードするだけで十分。
- 座標近接による重複排除は `CLLocation.distance(from:)`（メートル単位）で十分。既存ピンの座標一覧はトグル（`bridge.showVisited` 等）の状態に関わらず**全件**から作る（表示トグルは見た目の間引き、dedup はトグル非依存という既存パターンを踏襲）。

## `MKMapItem.location`（ios 26.0+）を使う。`.placemark` は deprecated（2026-07-07、フェーズ 17 確認）

`iosApp` の `IPHONEOS_DEPLOYMENT_TARGET` は 26.0 のため、`API_AVAILABLE(ios(26.0))` の新 API を無条件で使ってよい（可用性チェック不要）。`MKMapItem.placemark` は ios 26.0 で deprecated（`API_DEPRECATED(..., ios(6.0, 26.0))`）になっており、代わりの `MKMapItem.location`（`CLLocation`, `API_AVAILABLE(ios(26.0))`）を使う。`.placemark.coordinate` ではなく `.location.coordinate` でビルド警告 (`DeprecatedDeclaration`) を避けられる。同様のパターン（旧 API が ios 26.0 で deprecated、新 API が ios 26.0 available）は他の SDK API でも今後遭遇し得るので、warning が出たら新 API への置換をまず検討する。
