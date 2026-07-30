## commonMain の公開 API メソッドをまるごと削除するときのチェックリスト

`interface` から `suspend fun` を 1 つ削除する（例: `BeanProfileRepository.getByOrigin`）ような小さい削除でも、
実際に触る箇所は思ったより多い。

1. interface 宣言 + KDoc（`shared/domain/.../repository/*.kt`）
2. 各プラットフォーム実装（Android: `shared/data-firebase/androidMain/...`）
3. 呼び出し元の grep（`grep -rn "<メソッド名>" --include="*.kt" shared androidApp | grep -v /build/`）
4. **呼び出し元がゼロでも、他ファイルの KDoc 内に「例として」参照されていることがある**
   （例: `ExportCoffeeRecordsUseCase.kt` の KDoc が `AppContainer.beanProfileMatchUseCase` を
   「他の UseCase の呼び出し例」として名指ししていた。削除後は宙に浮いた参照になるので
   `grep -rn "<削除したシンボル名>"` を **KDoc コメント込みで** 全文検索すること）
5. **Swift 側の interface 実装（`iosApp/iosApp/FirebaseRepositories/*.swift`）は自分のスコープ外だが、
   削除した interface メソッドに対応する `override func __xxx` がまだ残っている**（Kotlin 側は
   コンパイルエラーにならない — Swift の protocol 適合は「余分なメソッドがあってもエラーにならない」
   ため、これはコンパイラでは検出できない）。iOS 側の追随削除を親への依頼として必ず明記する。

Kotlin コンパイラ（`compileKotlinIosSimulatorArm64` 等）が green でも、上記 4 と 5 は
grep や docs 突き合わせでしか見つからない。
