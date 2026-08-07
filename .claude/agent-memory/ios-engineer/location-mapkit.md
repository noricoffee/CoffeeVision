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

## 既存ズームゲートを別ピン種にも「再利用」する実装パターン（フェーズ 19、curated ピンのズームゲート追加で確認）

`MapTabView` の Apple 周辺ピン用ズームゲート（`applePoiZoomGateRadiusMeters` = 3000m、`scheduleAppleNearbyFetch` 内で `center.radiusMeters` と比較）は fetch 実行可否のガードだが、別ピン種（curated、fetch 不要でメモリ上の一覧をそのまま出す）の表示可否にも**同じ static let しきい値**を流用できる。fetch を伴わないピン種は `.onMapCameraChange` の副作用ではなく、表示用の filter 関数（`displayedXxx(bridge)`）内で `appState.mapSearchCenter?.radiusMeters` を直接参照してガードすればよい（新規 `@State` 追加不要）。`appState.mapSearchCenter` は `.onMapCameraChange(frequency: .onEnd)` でのみ更新されるため、初回カメラ確定前は `nil` — この間は該当ピンを非表示にする（Apple 周辺ピンの初期挙動と揃う）。

## `UserAnnotation()` で標準ブルードットを出すときは `LocationManager.authorizationStatus` でゲートする（2026-07-21、マップ現在地表示追加で確認）

`Map(position:) { ... }` コンテンツ内に `UserAnnotation()`（iOS 17+、`import MapKit` のみで使え `CoreLocation` 直参照不要）を `if locationManager.authorizationStatus == .authorizedWhenInUse || ... == .authorizedAlways` で囲むだけで動く。既存の現在地 FAB（recenter 用）とは完全に独立で、`LocationManager`（ワンショット取得）側の変更は不要 — `UserAnnotation()` は MapKit が内部で位置更新を自前管理する。ズームゲート等の既存ロジックとも無関係なので、`Map` コンテンツの一番手前（既存ピンの前）に足すだけで副作用が出ない。

## Places `locationBias` は範囲制限ではない → クライアント側で `MKCoordinateRegion` 矩形フィルタが要る（2026-07-24、「このエリアを検索」範囲外混入修正で確認）

Places API の Text Search に `LocationBias` を渡しても「近くを優先するヒント」でしかなく、範囲外の同名店（遠方の同一チェーン店等）が結果に混ざりうる。サーバー側の厳密な範囲制限（`locationRestriction`）は shared 側の大改修になるため、**iOS 側で表示用に矩形フィルタする**のが軽量な対処。パターン: 検索実行ボタン押下時点の `MKCoordinateRegion`（`.onMapCameraChange` で得た最新値を `@State` に保持しておき、ボタンコールバックに渡す）を「検索実行時にスナップ」して保持し、完了時に `region.center ± region.span/2` の緯度経度レンジで `results.filter` する。検索完了時の最新 region ではなく実行時にスナップするのは、検索中にユーザーが地図を動かしても「押した瞬間の範囲」で絞るのがユーザー期待に合うため。座標欠損の結果は範囲外扱いで除外。副作用として Places 1 回 20 件上限のうち範囲外分をクライアントで捨てるため表示件数が減りうる（locationBias で近傍が上位に来るため実用上は小さい）。

## マップピンの実データ目視確認は「iosApp (Dummy Data)」scheme + `simctl install/launch` + Python(Pillow) crop で完結する（2026-08-07、概念ピン意匠統一 UX-9 で確認）

`docs/ui-ux-guidelines.md` のピン意匠変更（バッジのクリップ有無等）は自分でログインして記録を作らなくても検証できる。手順: ①対象 scheme を `-scheme "iosApp (Dummy Data)"` でビルド（`AppState.swift` が起動時に固定 ID `dummy-0001`〜`dummy-0030` を自動 seed/clear する。専用 scheme のときだけ発火）②`xcrun simctl install <UDID> <built .app>` → `xcrun simctl launch <UDID> com.noricoffee.coffeevision` ③`xcrun simctl io <UDID> screenshot out.png` で撮影 ④密集ピンの拡大確認は `sips` に矩形オフセット crop が無い（`-c` は中心クロップのみ）ため `pip3 install --user Pillow` して `Image.crop((x0,y0,x1,y1))` で切り出す。**シミュレータへのタップ送信（osascript 経由の System Events クリック）はアクセシビリティ権限プロンプトでブロックされ実質使えない**（120s タイムアウトで背後に回り失敗した）。表示直後の初期カメラ位置だけで確認が足りない場合、UI 操作が要る検証（フィルタチップ切替等）は素直に「未検証、ユーザー確認依頼」に倒す。

## `MKError` の Swift ブリッジは struct（NSError bridge）で、静的メンバは `MKError.Code` を返す（2026-07-18、スロットリング耐性対応で確認）

`MKTypes.h` の `MKErrorCode`（`NS_ENUM` + apinotes の `NSErrorDomain: MKErrorDomain` 注釈）は Swift 側で `MKError`（struct, `Error` 準拠, NSError ブリッジ）としてインポートされる。**`MKError.loadingThrottled` は `MKError` ではなく `MKError.Code` を返す**ため、`catch` 節で特定エラーを判別するときは `if let mkError = error as? MKError, mkError == .loadingThrottled` ではコンパイルエラーになる（"produces result of type 'MKError.Code', but context expects 'MKError'"）。正しくは `mkError.code == .loadingThrottled`（`.code` プロパティ経由で `Code` 同士を比較）。この `.h` ヘッダに `MKError` という型は存在せず（`MKErrorCode`/`MKErrorDomain` のみ）、Swift 側の型形状は apinotes のブリッジ規則からの類推が必要 — 実際にコンパイルしてエラーメッセージで裏取りするのが確実（`.swiftinterface` にも `MKError` の記載はない。Swift の自動 NSError ブリッジ規則で生成される暗黙の型のため）。
