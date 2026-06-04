import Foundation
import FirebaseFirestore
import SharedLogic

/// `com.noricoffee.repository.RemoteVisitDataSource` の iOS 実装。
///
/// Firestore の `users/{uid}/visits/{visitId}` を扱う。
/// 子コレクション（coffeeItems / foodItems / photos）は Phase 2 のスコープ外。
/// 詳細は `docs/data-model.md` §3.2 参照。
///
/// SKIE は protocol の **実装側** でも Swift エルゴノミクス（`SkieSwiftFlow<[Visit_]>`
/// 戻り値 / `__upload` + `__remove` の Obj-C 互換 completion handler）を要求してくる。
/// `SkieSwiftFlow` は `_ObjectiveCBridgeable` 経由で `SkieKotlinFlow` から暗黙ブリッジする。
final class RemoteVisitDataSourceIosImpl: NSObject, RemoteVisitDataSource {

    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    // MARK: - observeChanges

    /// `users/{uid}/visits` の全件スナップショットを Flow として公開する。
    func observeChanges(userId: String) -> SkieSwiftFlow<[Visit_]> {
        var listener: ListenerRegistration?
        let callbackFlow = CallbackFlow<NSArray>(
            onStart: { [firestore] emit in
                listener = firestore
                    .collection("users")
                    .document(userId)
                    .collection("visits")
                    .addSnapshotListener { snapshot, error in
                        if let error {
                            print("[RemoteVisitDataSourceIosImpl] snapshot error: \(error)")
                            return
                        }
                        guard let snapshot else { return }
                        let visits: [Visit_] = snapshot.documents.compactMap { doc in
                            VisitFirestoreMapper.fromDocument(doc.data())
                        }
                        emit(visits as NSArray)
                    }
            },
            onCancel: {
                listener?.remove()
                listener = nil
            }
        )
        // SkieSwiftFlow<[Visit_]> は @_spi(SKIE) の internal init しか持たず、
        // _ObjectiveCBridgeable 経由で `SkieKotlinFlow` から変換する必要がある。
        return SkieSwiftFlow._unconditionallyBridgeFromObjectiveC(
            SkieKotlinFlow(callbackFlow)
        )
    }

    // MARK: - upload

    /// `users/{uid}/visits/{visitId}` に Visit を書き込む。
    ///
    /// SKIE は protocol 実装側でも `__upload(...:completionHandler:)` の Obj-C 形式を要求する。
    ///
    /// TODO Phase 2 後半: 子コレクション（coffeeItems / foodItems / photos）の同期
    func __upload(
        visit: Visit_,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        let document = VisitFirestoreMapper.toDocument(visit)
        firestore
            .collection("users")
            .document(visit.userId)
            .collection("visits")
            .document(visit.id)
            .setData(document, merge: true) { error in
                completionHandler(error)
            }
    }

    // MARK: - remove

    /// `users/{uid}/visits/{visitId}` を削除する。
    func __remove(
        userId: String,
        id: String,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        firestore
            .collection("users")
            .document(userId)
            .collection("visits")
            .document(id)
            .delete { error in
                completionHandler(error)
            }
    }
}
