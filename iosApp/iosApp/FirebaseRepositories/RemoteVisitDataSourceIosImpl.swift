import Foundation
import FirebaseFirestore
import SharedLogic

/// `com.noricoffee.repository.RemoteVisitDataSource` の iOS 実装。
///
/// Firestore の `users/{uid}/visits/{visitId}` と、その配下のサブコレクション
/// （`coffeeItems` / `foodItems` / `photos`）を扱う。
/// ドキュメント定義は `docs/data-model.md` §3.2 準拠。
///
/// ## 同期戦略
///
/// - **upload**: 親 visit ドキュメント書き込み → 3 つの子コレクション書き直しを **WriteBatch** で原子的に実行。
///   既存子のうち新しい配列に含まれない ID は同じバッチで削除する（差分削除）。
///   1 バッチ 500 オペレーション上限は Phase 2 の想定規模（1 Visit あたり数十件程度）で十分余裕がある
/// - **remove**: 子コレクションの全件削除 → 親 visit 削除（参照整合性を保つため逆順）。
///   こちらも WriteBatch で原子化
/// - **observeChanges**: 案 A（親リスナ + 子は都度 getDocuments）。
///   `visits` コレクションの snapshot 受信ごとに、各 visit の 3 子コレクションを `getDocuments` で取得し、
///   完全な `Visit_` オブジェクトの配列として emit する。
///   親の `updatedAt` が更新されない限り子の単独変更は次回 snapshot まで反映されないが、
///   ViewModel 側で write 時に必ず親の `updatedAt` を更新する規約のため実用上問題ない
///
/// ## SKIE 周りの制約
///
/// SKIE は protocol の **実装側** でも Swift エルゴノミクス（`SkieSwiftFlow<[Visit_]>`
/// 戻り値 / `__upload` + `__remove` の Obj-C 互換 completion handler）を要求してくる。
/// `SkieSwiftFlow` は `_ObjectiveCBridgeable` 経由で `SkieKotlinFlow` から暗黙ブリッジする。
final class RemoteVisitDataSourceIosImpl: NSObject, RemoteVisitDataSource {

    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    // MARK: - Path helpers

    private func visitsCollection(userId: String) -> CollectionReference {
        firestore
            .collection("users")
            .document(userId)
            .collection("visits")
    }

    private func visitDocument(userId: String, visitId: String) -> DocumentReference {
        visitsCollection(userId: userId).document(visitId)
    }

    private func coffeeItemsCollection(userId: String, visitId: String) -> CollectionReference {
        visitDocument(userId: userId, visitId: visitId).collection("coffeeItems")
    }

    private func foodItemsCollection(userId: String, visitId: String) -> CollectionReference {
        visitDocument(userId: userId, visitId: visitId).collection("foodItems")
    }

    private func photosCollection(userId: String, visitId: String) -> CollectionReference {
        visitDocument(userId: userId, visitId: visitId).collection("photos")
    }

    // MARK: - observeChanges

    /// `users/{uid}/visits` の全件スナップショットを Flow として公開する。
    ///
    /// 案 A 実装: 親 visit の snapshot listener を 1 本貼り、emit 時に各 visit の
    /// 子コレクション 3 種を `getDocuments` で取得して完全な Visit を構築する。
    func observeChanges(userId: String) -> SkieSwiftFlow<[Visit_]> {
        var listener: ListenerRegistration?
        let firestore = self.firestore
        let dataSource = self // 子取得のためのクロージャに self を渡す

        let callbackFlow = CallbackFlow<NSArray>(
            onStart: { [firestore, dataSource] emit in
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

                        // 各 visit について子コレクションを並列に取得する。
                        // すべての fetch が完了した時点でまとめて emit する。
                        let parentVisits: [Visit_] = snapshot.documents.compactMap { doc in
                            VisitFirestoreMapper.fromDocument(doc.data())
                        }

                        if parentVisits.isEmpty {
                            emit([] as NSArray)
                            return
                        }

                        dataSource.fetchAllChildren(userId: userId, visits: parentVisits) { merged in
                            emit(merged as NSArray)
                        }
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

    /// 親 visit 配列を受けて、各 visit の子コレクション 3 種を並列に取得し、
    /// 完全な `Visit_` 配列にして completion で返す。
    /// 個別の取得失敗はその子配列を空にしてフォールバックし、スナップショット全体を落とさない。
    private func fetchAllChildren(
        userId: String,
        visits: [Visit_],
        completion: @escaping ([Visit_]) -> Void
    ) {
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "RemoteVisitDataSourceIosImpl.children")
        var results: [String: (coffees: [CoffeeItem], foods: [FoodItem], photos: [Photo_])] = [:]

        for visit in visits {
            group.enter()
            fetchChildren(userId: userId, visitId: visit.id) { coffees, foods, photos in
                queue.async {
                    results[visit.id] = (coffees, foods, photos)
                    group.leave()
                }
            }
        }

        group.notify(queue: queue) {
            let merged: [Visit_] = visits.map { visit in
                let bundle = results[visit.id] ?? ([], [], [])
                return Visit_(
                    id: visit.id,
                    userId: visit.userId,
                    cafe: visit.cafe,
                    visitedOn: visit.visitedOn,
                    ambiance: visit.ambiance,
                    rating: visit.rating,
                    notes: visit.notes,
                    photos: bundle.photos,
                    coffees: bundle.coffees,
                    foods: bundle.foods,
                    createdAt: visit.createdAt,
                    updatedAt: visit.updatedAt
                )
            }
            DispatchQueue.main.async {
                completion(merged)
            }
        }
    }

    /// 1 visit について 3 子コレクションを並列取得し、sortOrder 順に並べて返す。
    private func fetchChildren(
        userId: String,
        visitId: String,
        completion: @escaping ([CoffeeItem], [FoodItem], [Photo_]) -> Void
    ) {
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "RemoteVisitDataSourceIosImpl.children.fetch")

        var coffees: [CoffeeItem] = []
        var foods: [FoodItem] = []
        var photos: [Photo_] = []

        group.enter()
        coffeeItemsCollection(userId: userId, visitId: visitId).getDocuments { snapshot, error in
            defer { group.leave() }
            if let error {
                print("[RemoteVisitDataSourceIosImpl] coffeeItems fetch error (\(visitId)): \(error)")
                return
            }
            guard let snapshot else { return }
            let pairs = snapshot.documents.compactMap {
                VisitFirestoreMapper.coffeeItemFromDocument($0.data())
            }
            queue.async {
                coffees = pairs
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .map { $0.item }
            }
        }

        group.enter()
        foodItemsCollection(userId: userId, visitId: visitId).getDocuments { snapshot, error in
            defer { group.leave() }
            if let error {
                print("[RemoteVisitDataSourceIosImpl] foodItems fetch error (\(visitId)): \(error)")
                return
            }
            guard let snapshot else { return }
            let pairs = snapshot.documents.compactMap {
                VisitFirestoreMapper.foodItemFromDocument($0.data())
            }
            queue.async {
                foods = pairs
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .map { $0.item }
            }
        }

        group.enter()
        photosCollection(userId: userId, visitId: visitId).getDocuments { snapshot, error in
            defer { group.leave() }
            if let error {
                print("[RemoteVisitDataSourceIosImpl] photos fetch error (\(visitId)): \(error)")
                return
            }
            guard let snapshot else { return }
            let pairs = snapshot.documents.compactMap {
                VisitFirestoreMapper.photoFromDocument($0.data())
            }
            queue.async {
                photos = pairs
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .map { $0.photo }
            }
        }

        group.notify(queue: queue) {
            completion(coffees, foods, photos)
        }
    }

    // MARK: - upload

    /// `users/{uid}/visits/{visitId}` と子コレクションを Firestore に書き込む。
    ///
    /// 戦略:
    /// 1. 子 3 種について既存ドキュメント ID を `getDocuments` で取得
    /// 2. WriteBatch に「親 set + 新子 set + 新配列に含まれない旧子 ID の delete」を積む
    /// 3. batch.commit を実行
    ///
    /// SKIE は protocol 実装側でも `__upload(...:completionHandler:)` の Obj-C 形式を要求する。
    func __upload(
        visit: Visit_,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        let userId = visit.userId
        let visitId = visit.id

        // 既存子の ID 集合を 3 種同時に取得する。
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "RemoteVisitDataSourceIosImpl.upload")
        var existingCoffeeIds: Set<String> = []
        var existingFoodIds: Set<String> = []
        var existingPhotoIds: Set<String> = []
        var fetchError: Error?

        group.enter()
        coffeeItemsCollection(userId: userId, visitId: visitId).getDocuments { snapshot, error in
            defer { group.leave() }
            if let error {
                queue.async { fetchError = fetchError ?? error }
                return
            }
            let ids = Set((snapshot?.documents ?? []).map { $0.documentID })
            queue.async { existingCoffeeIds = ids }
        }

        group.enter()
        foodItemsCollection(userId: userId, visitId: visitId).getDocuments { snapshot, error in
            defer { group.leave() }
            if let error {
                queue.async { fetchError = fetchError ?? error }
                return
            }
            let ids = Set((snapshot?.documents ?? []).map { $0.documentID })
            queue.async { existingFoodIds = ids }
        }

        group.enter()
        photosCollection(userId: userId, visitId: visitId).getDocuments { snapshot, error in
            defer { group.leave() }
            if let error {
                queue.async { fetchError = fetchError ?? error }
                return
            }
            let ids = Set((snapshot?.documents ?? []).map { $0.documentID })
            queue.async { existingPhotoIds = ids }
        }

        group.notify(queue: queue) { [firestore, weak self] in
            if let fetchError {
                DispatchQueue.main.async { completionHandler(fetchError) }
                return
            }
            guard let self else {
                DispatchQueue.main.async { completionHandler(nil) }
                return
            }

            let batch = firestore.batch()

            // 1. 親 visit ドキュメント
            let parentDoc = self.visitDocument(userId: userId, visitId: visitId)
            batch.setData(VisitFirestoreMapper.toDocument(visit), forDocument: parentDoc, merge: true)

            // 2. coffeeItems
            let coffees = (visit.coffees as? [CoffeeItem]) ?? []
            var newCoffeeIds: Set<String> = []
            for (index, coffee) in coffees.enumerated() {
                newCoffeeIds.insert(coffee.id)
                let doc = self.coffeeItemsCollection(userId: userId, visitId: visitId).document(coffee.id)
                batch.setData(
                    VisitFirestoreMapper.toDocument(coffee, sortOrder: index),
                    forDocument: doc
                )
            }
            for staleId in existingCoffeeIds.subtracting(newCoffeeIds) {
                batch.deleteDocument(
                    self.coffeeItemsCollection(userId: userId, visitId: visitId).document(staleId)
                )
            }

            // 3. foodItems
            let foods = (visit.foods as? [FoodItem]) ?? []
            var newFoodIds: Set<String> = []
            for (index, food) in foods.enumerated() {
                newFoodIds.insert(food.id)
                let doc = self.foodItemsCollection(userId: userId, visitId: visitId).document(food.id)
                batch.setData(
                    VisitFirestoreMapper.toDocument(food, sortOrder: index),
                    forDocument: doc
                )
            }
            for staleId in existingFoodIds.subtracting(newFoodIds) {
                batch.deleteDocument(
                    self.foodItemsCollection(userId: userId, visitId: visitId).document(staleId)
                )
            }

            // 4. photos
            let photos = (visit.photos as? [Photo_]) ?? []
            var newPhotoIds: Set<String> = []
            for (index, photo) in photos.enumerated() {
                newPhotoIds.insert(photo.id)
                let doc = self.photosCollection(userId: userId, visitId: visitId).document(photo.id)
                batch.setData(
                    VisitFirestoreMapper.toDocument(photo, sortOrder: index),
                    forDocument: doc
                )
            }
            for staleId in existingPhotoIds.subtracting(newPhotoIds) {
                batch.deleteDocument(
                    self.photosCollection(userId: userId, visitId: visitId).document(staleId)
                )
            }

            batch.commit { error in
                DispatchQueue.main.async { completionHandler(error) }
            }
        }
    }

    // MARK: - remove

    /// `users/{uid}/visits/{visitId}` と全子コレクションを削除する。
    ///
    /// 戦略: 子コレクション 3 種の ID を `getDocuments` で取得し、
    /// WriteBatch で「子全削除 + 親削除」を 1 commit にまとめる。
    func __remove(
        userId: String,
        id: String,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "RemoteVisitDataSourceIosImpl.remove")
        var coffeeDocs: [DocumentReference] = []
        var foodDocs: [DocumentReference] = []
        var photoDocs: [DocumentReference] = []
        var fetchError: Error?

        group.enter()
        coffeeItemsCollection(userId: userId, visitId: id).getDocuments { snapshot, error in
            defer { group.leave() }
            if let error {
                queue.async { fetchError = fetchError ?? error }
                return
            }
            let docs = (snapshot?.documents ?? []).map { $0.reference }
            queue.async { coffeeDocs = docs }
        }

        group.enter()
        foodItemsCollection(userId: userId, visitId: id).getDocuments { snapshot, error in
            defer { group.leave() }
            if let error {
                queue.async { fetchError = fetchError ?? error }
                return
            }
            let docs = (snapshot?.documents ?? []).map { $0.reference }
            queue.async { foodDocs = docs }
        }

        group.enter()
        photosCollection(userId: userId, visitId: id).getDocuments { snapshot, error in
            defer { group.leave() }
            if let error {
                queue.async { fetchError = fetchError ?? error }
                return
            }
            let docs = (snapshot?.documents ?? []).map { $0.reference }
            queue.async { photoDocs = docs }
        }

        group.notify(queue: queue) { [firestore, weak self] in
            if let fetchError {
                DispatchQueue.main.async { completionHandler(fetchError) }
                return
            }
            guard let self else {
                DispatchQueue.main.async { completionHandler(nil) }
                return
            }

            let batch = firestore.batch()
            for doc in coffeeDocs { batch.deleteDocument(doc) }
            for doc in foodDocs { batch.deleteDocument(doc) }
            for doc in photoDocs { batch.deleteDocument(doc) }
            batch.deleteDocument(self.visitDocument(userId: userId, visitId: id))

            batch.commit { error in
                DispatchQueue.main.async { completionHandler(error) }
            }
        }
    }
}
