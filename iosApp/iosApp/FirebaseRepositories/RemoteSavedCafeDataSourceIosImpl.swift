import Foundation
import FirebaseFirestore
import SharedLogic

/// `com.noricoffee.repository.RemoteSavedCafeDataSource` の iOS 実装。
///
/// Firestore の `users/{uid}/savedCafes/{placeId}` コレクションを扱う（フェーズ 15-A）。
/// ドキュメント ID = placeId のため、observe は 1 コレクションリスナで完結し、
/// upload は単一ドキュメント `set`、remove は単一ドキュメント `delete` で済む
/// （`RemoteCoffeeDataSourceIosImpl` と同じ設計方針。`docs/data-model.md` §4.3 準拠）。
///
/// ## SKIE 周りの制約
///
/// `RemoteCoffeeDataSourceIosImpl` と同様、
/// - `observeChanges(userId:)` は `SkieSwiftFlow<[SavedCafe]>` を返す必要がある
/// - `upload` / `remove` は Swift concurrency interop により `__upload` / `__remove` という
///   Obj-C プレフィックス付きシグネチャで実装する（`upload`/`remove` という素の名前は
///   SKIE が生成する `async throws` 版と衝突するため）
final class RemoteSavedCafeDataSourceIosImpl: NSObject, RemoteSavedCafeDataSource {

    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    // MARK: - Path helpers

    private func savedCafesCollection(userId: String) -> CollectionReference {
        firestore
            .collection("users")
            .document(userId)
            .collection("savedCafes")
    }

    private func savedCafeDocument(userId: String, placeId: String) -> DocumentReference {
        savedCafesCollection(userId: userId).document(placeId)
    }

    // MARK: - observeChanges

    /// `users/{uid}/savedCafes` の全件スナップショットを Flow として公開する。
    /// SKIE の要求により `SkieSwiftFlow<[SavedCafe]>` を返す。
    func observeChanges(userId: String) -> SkieSwiftFlow<[SavedCafe]> {
        var listener: ListenerRegistration?
        let firestore = self.firestore

        let callbackFlow = CallbackFlow<NSArray>(
            onStart: { [firestore] emit in
                listener = firestore
                    .collection("users")
                    .document(userId)
                    .collection("savedCafes")
                    .addSnapshotListener { snapshot, error in
                        if let error {
                            print("[RemoteSavedCafeDataSourceIosImpl] snapshot error: \(error)")
                            return
                        }
                        guard let snapshot else { return }

                        let savedCafes: [SavedCafe] = snapshot.documents.compactMap { doc in
                            SavedCafeFirestoreMapper.fromDocument(doc.data(), userId: userId)
                        }
                        emit(savedCafes as NSArray)
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

    /// `users/{uid}/savedCafes/{placeId}` に SavedCafe を書き込む（保存 = set による上書き）。
    /// SKIE の要求により `__upload` プレフィックスを使う。
    func __upload(
        savedCafe: SavedCafe,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        let docData = SavedCafeFirestoreMapper.toDocument(savedCafe)

        savedCafeDocument(userId: savedCafe.userId, placeId: savedCafe.cafe.placeId)
            .setData(docData) { error in
                DispatchQueue.main.async {
                    completionHandler(error)
                }
            }
    }

    // MARK: - __remove

    /// `users/{uid}/savedCafes/{placeId}` を削除する（解除）。
    /// SKIE の要求により `__remove` プレフィックスを使う。
    func __remove(
        userId: String,
        placeId: String,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        savedCafeDocument(userId: userId, placeId: placeId).delete { error in
            DispatchQueue.main.async {
                completionHandler(error)
            }
        }
    }
}
