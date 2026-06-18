package com.noricoffee.repository

/**
 * Kotlin の [com.noricoffee.domain.CoffeeRecord] ドメインモデル ↔
 * Firestore ドキュメント `Map<String, Any?>` を変換するヘルパ（Phase 2 で実装予定）。
 *
 * ## Phase 2 で実装すること
 * - `toDocument(record: CoffeeRecord)`: CoffeeRecord → Firestore ドキュメント変換
 *   - cafe は任意（null の場合はキーごと省略）
 *   - photos は埋め込み配列として保存（localPath は端末固有値のため除外、remoteUrl も除外）
 *   - enum は Kotlin の `name` 文字列で保存
 *   - createdAt / updatedAt は Firestore Timestamp
 * - `fromDocument(data: Map<String, Any>)`: Firestore ドキュメント → CoffeeRecord 変換
 *   - cafe キーが欠如していたら cafe = null（セルフ抽出）
 *   - photos は埋め込み配列から取得（localPath は常に null）
 *
 * ## Firestore コレクション構造
 * `users/{uid}/coffees/{coffeeId}` — 子サブコレクションは持たない
 * photos は `CoffeeRecord` ドキュメントに埋め込み配列として保存する
 */
object CoffeeFirestoreMapper {
    // TODO(Phase 2): 上記コメントに従って実装する
}
