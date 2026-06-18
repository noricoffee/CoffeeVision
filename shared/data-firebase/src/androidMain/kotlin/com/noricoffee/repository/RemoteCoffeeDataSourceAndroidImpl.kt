package com.noricoffee.repository

import com.noricoffee.domain.CoffeeRecord
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow

/**
 * Firestore の Android 実装（Phase 2 で本実装予定）。
 *
 * Phase 1 では `CoffeeRecord` / `RemoteCoffeeDataSource` I/F のコンパイルを通すためのスタブ。
 * Firestore の新コレクション構造 `users/{uid}/coffees/{coffeeId}` への完全移行は Phase 2 で実装する。
 *
 * ## Phase 2 で実装すること
 * - `observeChanges`: `users/{uid}/coffees` の snapshotListener を callbackFlow で公開し、
 *   `CoffeeFirestoreMapper.fromDocument` で [CoffeeRecord] に変換して emit する
 * - `upload`: `users/{uid}/coffees/{coffeeId}` への単一ドキュメント set（photos は埋め込み配列）
 * - `remove`: `users/{uid}/coffees/{coffeeId}` の単一ドキュメント delete
 */
class RemoteCoffeeDataSourceAndroidImpl : RemoteCoffeeDataSource {

    override fun observeChanges(userId: String): Flow<List<CoffeeRecord>> {
        // TODO(Phase 2): Firestore の users/{uid}/coffees コレクションを購読して CoffeeRecord を emit する
        return emptyFlow()
    }

    @Throws(Exception::class)
    override suspend fun upload(record: CoffeeRecord) {
        // TODO(Phase 2): users/{uid}/coffees/{coffeeId} への単一ドキュメント set
        // photos は埋め込み配列として保存する（サブコレクションは使わない）
    }

    @Throws(Exception::class)
    override suspend fun remove(userId: String, id: String) {
        // TODO(Phase 2): users/{uid}/coffees/{id} の単一ドキュメント delete
    }
}
