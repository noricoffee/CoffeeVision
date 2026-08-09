package com.noricoffee.repository

import com.noricoffee.domain.CoffeeRecord
import kotlinx.coroutines.flow.Flow

/**
 * Firestore（または同等のリモート KVS）への薄いアダプタインターフェース。
 *
 * - `commonMain` には interface のみを置き、実装は各プラットフォームの公式 SDK で行う
 *   （iOS は `iosApp/FirebaseRepositories/`、Android は `shared/data-firebase/androidMain`）
 * - 本データソースは UI から **直接参照されない**。[CoffeeRepositoryImpl] が
 *   [LocalCoffeeRepository] と本データソースを合成して、UI には [CoffeeRepository] 1 本だけを見せる
 *
 * ## 設計方針
 *
 * - [observeChanges] は Firestore リスナを `Flow` として公開する。[CoffeeRepositoryImpl] が
 *   それを購読し、ローカル DB に upsert することでローカル DB を Single Source of Truth として保つ
 * - [upload] / [remove] は **書き込み順序を「ローカル → リモート」に保つために**
 *   [CoffeeRepositoryImpl] から **ローカル書き込み成功後に** 呼ばれる契約とする
 * - リモートのリトライ・オフラインキューイングは各プラットフォームの Firestore SDK の
 *   オフライン永続化に委ね、本層では独自キューを持たない
 *
 * Firestore の新コレクション構造: `users/{uid}/coffees/{coffeeId}`
 * photos は埋め込み配列として保持するため、observe は 1 本のリスナで完結する。
 */
interface RemoteCoffeeDataSource {

    /**
     * リモート側の変更を観測する。
     *
     * - 各要素は **指定 userId の全 CoffeeRecord のスナップショット**（差分ではなく全体）を返す
     * - [CoffeeRepositoryImpl] はこの Flow を購読してローカル DB を更新する
     * - サインアウト等で購読が無効になったら、購読側スコープのキャンセルに任せる
     *
     * ## エラー契約（実装が守ること）
     *
     * 上流が**回復不能な失敗**（Firestore の `permission-denied` 等）を返したら、
     * **Flow をその例外で終了させる**こと。握り潰して黙って emit を止めてはいけない
     * （購読側から「まだ来ていないだけ」と区別がつかず、Flow が永久に宙吊りになる）。
     *
     * - Android: `callbackFlow` の `close(error)`
     * - iOS: Swift 側ブリッジ `CallbackFlow` の `fail(_:)`（= `collect` の completionHandler に
     *   `NSError` を渡す）
     *
     * 一時的なネットワーク断は Firestore SDK のオフライン永続化が内部で吸収するため、
     * ここに現れるのは「リトライしても直らない」失敗だけになる。購読側
     * （[CoffeeRepositoryImpl.startSync]）はこの終了を**同期の停止**として扱い、再購読しない。
     */
    fun observeChanges(userId: String): Flow<List<CoffeeRecord>>

    /**
     * CoffeeRecord をリモートに書き込む（作成・更新の両方）。
     *
     * 呼び出し前提: [CoffeeRepositoryImpl] が既にローカル DB への upsert を成功させていること。
     */
    @Throws(Exception::class)
    suspend fun upload(record: CoffeeRecord)

    /**
     * CoffeeRecord をリモートから削除する。
     *
     * 呼び出し前提: [CoffeeRepositoryImpl] が既にローカル DB からの削除を成功させていること。
     */
    @Throws(Exception::class)
    suspend fun remove(userId: String, id: String)
}
