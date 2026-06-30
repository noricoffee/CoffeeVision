import Foundation
import FirebaseFirestore
import SharedLogic

/// `com.noricoffee.repository.BeanProfileRepository` の iOS 実装。
///
/// Firestore のグローバルコレクション `beanProfiles/{beanId}` を read-only で参照する。
/// 初回呼び出しで one-shot `getDocuments` し、以降はメモリキャッシュを返す（snapshotListener 不要）。
///
/// ## SKIE の制約（実装側）
///
/// SKIE の SuspendInterop は「Swift から Kotlin を呼ぶ方向」にしか効かないため、
/// Swift で Kotlin interface を実装する際は Obj-C 互換シグネチャを使う:
/// - `getAll()` → `func __getAll(completionHandler:)`
/// - `getByOrigin(origin:)` → `func __getByOrigin(origin:completionHandler:)`
///
/// `__getByOrigin` の内部では SKIE が生成した `async throws` 版の `getAll()` を呼ぶことで
/// キャッシュを再利用しクライアントサイドフィルタを適用する。
///
/// 詳細は `docs/kmp-bridge.md` §SKIE の利用 を参照。
final class BeanProfileRepositoryIosImpl: NSObject, BeanProfileRepository {

    private let db = Firestore.firestore()
    // メモリキャッシュ: 初回取得後に保持し、以降は Firestore を叩かない
    private var cache: [BeanProfile]? = nil

    // MARK: - __getAll

    /// 全豆プロファイルを返す（初回のみ Firestore one-shot get）。
    ///
    /// Kotlin interface: `@Throws(Exception::class) suspend fun getAll(): List<BeanProfile>`
    func __getAll(
        completionHandler: @escaping @Sendable ([BeanProfile]?, (any Error)?) -> Void
    ) {
        if let cache = cache {
            completionHandler(cache, nil)
            return
        }
        db.collection("beanProfiles").getDocuments { [weak self] snapshot, error in
            if let error = error {
                completionHandler(nil, error)
                return
            }
            let profiles = snapshot?.documents.compactMap { doc in
                BeanProfileIosMapper.fromDocument(data: doc.data(), beanId: doc.documentID)
            } ?? []
            self?.cache = profiles
            completionHandler(profiles, nil)
        }
    }

    // MARK: - __getByOrigin

    /// 指定産地（trim/lowercase 完全一致）のプロファイルを返す。
    ///
    /// `getAll()` の結果をクライアントサイドでフィルタする（Firestore クエリなし）。
    /// Kotlin interface: `@Throws(Exception::class) suspend fun getByOrigin(origin: String): List<BeanProfile>`
    func __getByOrigin(
        origin: String,
        completionHandler: @escaping @Sendable ([BeanProfile]?, (any Error)?) -> Void
    ) {
        // SKIE が生成した async throws 版の getAll() を呼んでキャッシュを取得する
        Task {
            do {
                let all = try await getAll()
                let normalizedOrigin = origin.trimmingCharacters(in: .whitespaces).lowercased()
                let filtered = all.filter {
                    $0.origin.trimmingCharacters(in: .whitespaces).lowercased() == normalizedOrigin
                }
                completionHandler(filtered, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }
}

// MARK: - BeanProfileIosMapper

/// Firestore ドキュメント `[String: Any]` を `BeanProfile` に変換するヘルパ。
///
/// Kotlin 側の `BeanProfileFirestoreMapper` と同様のフィールドキー / 変換規則を使う。
/// `processings` は enum name（例: `"Washed"`）で逆引きし、SKIE CaseIterable `.allCases` を使う
/// （Obj-C ヘッダの `.entries` は Swift からは使わない。`docs/kmp-bridge.md` 参照）。
private enum BeanProfileIosMapper {

    static func fromDocument(data: [String: Any], beanId: String) -> BeanProfile? {
        guard
            let name = data["name"] as? String,
            let origin = data["origin"] as? String
        else { return nil }

        let variety = data["variety"] as? String
        let description = data["description"] as? String
        let flavorNotes = data["flavorNotes"] as? [String] ?? []

        let processings: [ProcessingMethod] = (data["processings"] as? [String] ?? []).compactMap { str in
            ProcessingMethod.allCases.first { $0.name == str }
        }

        return BeanProfile(
            beanId: beanId,
            name: name,
            origin: origin,
            variety: variety,
            processings: processings,
            flavorNotes: flavorNotes,
            description: description
        )
    }
}
