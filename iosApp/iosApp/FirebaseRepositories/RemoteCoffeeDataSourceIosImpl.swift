import Foundation
import FirebaseFirestore
import SharedLogic

/// `com.noricoffee.repository.RemoteCoffeeDataSource` の iOS 実装。
///
/// Firestore の `users/{uid}/coffees/{coffeeId}` コレクションを扱う。
/// photos は埋め込み配列として 1 ドキュメントに格納するため、
/// observe は coffees リスナ 1 本で完結し、子コレクションの都度取得は不要。
///
/// ドキュメント定義は `docs/data-model.md` §3.2 準拠。
///
/// ## SKIE 周りの制約
///
/// SKIE は protocol の **実装側** でも Swift エルゴノミクスを要求してくる:
/// - `observeChanges(userId:)` は `SkieSwiftFlow<[CoffeeRecord]>` を返す必要がある
/// - `upload` / `remove` は `__upload` / `__remove` という Obj-C プレフィックス付きシグネチャ
/// `SkieSwiftFlow` は `_ObjectiveCBridgeable` 経由で `SkieKotlinFlow` から暗黙ブリッジする。
///
/// `nonisolated` である理由: `RemoteCoffeeDataSource`（Kotlin interface）実装は Kotlin ランタイムが
/// 任意スレッドから呼び出す。可変状態は保持しない（`firestore` は `let`、`observeChanges` 内の
/// `listener` はメソッドローカルでクロージャに直接キャプチャされるため、クラスの isolation とは無関係）（SW6-2）。
nonisolated final class RemoteCoffeeDataSourceIosImpl: NSObject, RemoteCoffeeDataSource {

    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    // MARK: - Path helpers

    private func coffeesCollection(userId: String) -> CollectionReference {
        firestore
            .collection("users")
            .document(userId)
            .collection("coffees")
    }

    private func coffeeDocument(userId: String, coffeeId: String) -> DocumentReference {
        coffeesCollection(userId: userId).document(coffeeId)
    }

    // MARK: - observeChanges

    /// `users/{uid}/coffees` の全件スナップショットを Flow として公開する。
    ///
    /// photos 埋め込み配列方式のため、リスナ 1 本で完結する。
    /// SKIE の要求により `SkieSwiftFlow<[CoffeeRecord]>` を返す。
    func observeChanges(userId: String) -> SkieSwiftFlow<[CoffeeRecord]> {
        var listener: ListenerRegistration?
        let firestore = self.firestore

        let callbackFlow = CallbackFlow<NSArray>(
            onStart: { [firestore] emit in
                listener = firestore
                    .collection("users")
                    .document(userId)
                    .collection("coffees")
                    .addSnapshotListener { snapshot, error in
                        if let error {
                            print("[RemoteCoffeeDataSourceIosImpl] snapshot error: \(error)")
                            return
                        }
                        guard let snapshot else { return }

                        let records: [CoffeeRecord] = snapshot.documents.compactMap { doc in
                            CoffeeFirestoreMapper.fromDocument(doc.data())
                        }
                        emit(records as NSArray)
                    }
            },
            onCancel: {
                listener?.remove()
                listener = nil
            }
        )

        // `_ObjectiveCBridgeable` 経由で `SkieKotlinFlow` から変換する。
        return SkieSwiftFlow._unconditionallyBridgeFromObjectiveC(
            SkieKotlinFlow(callbackFlow)
        )
    }

    // MARK: - __upload

    /// `users/{uid}/coffees/{coffeeId}` に CoffeeRecord を書き込む（作成・更新共通）。
    ///
    /// photos は埋め込み配列として 1 ドキュメントに set する。
    /// SKIE の要求により `__upload` プレフィックスを使う。
    func __upload(
        record: CoffeeRecord,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        let userId = record.userId
        let coffeeId = record.id
        let docData = CoffeeFirestoreMapper.toDocument(record)

        coffeeDocument(userId: userId, coffeeId: coffeeId).setData(docData) { error in
            DispatchQueue.main.async {
                completionHandler(error)
            }
        }
    }

    // MARK: - __remove

    /// `users/{uid}/coffees/{coffeeId}` を削除する。
    /// SKIE の要求により `__remove` プレフィックスを使う。
    func __remove(
        userId: String,
        id: String,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        coffeeDocument(userId: userId, coffeeId: id).delete { error in
            DispatchQueue.main.async {
                completionHandler(error)
            }
        }
    }
}
