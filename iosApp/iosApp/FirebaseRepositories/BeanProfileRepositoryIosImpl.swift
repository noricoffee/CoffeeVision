import Foundation
import FirebaseFirestore
// `@preconcurrency`: `BeanProfile` は Kotlin data class（SharedLogic）で Sendable 非準拠。
// `__getAll` の `completionHandler` 引数型（`@Sendable` closure）にそのまま登場するため、
// 個別の Sendable 拡張では塞げない（Kotlin 側の型自体を変更できない）。SW6-2。
@preconcurrency import SharedLogic
import os

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
///
/// 詳細は `docs/kmp-bridge.md` §SKIE の利用 を参照。
///
/// ## `nonisolated` である理由（Swift 6 移行 SW6-2）
///
/// `BeanProfileRepository`（Kotlin interface）実装は Kotlin ランタイムが Obj-C ブリッジ経由で
/// 呼び出すため、呼び出し元スレッドは Kotlin コルーチンのディスパッチャ次第で MainActor とは限らない
/// （`docs/kmp-bridge.md` の呼び出し方向の議論参照）。既定 MainActor 分離を無効化し、実態を明示する。
///
/// ## `cache` のスレッド安全性
///
/// `__getAll` の呼び出し元スレッドは上記の通り不定な一方、Firestore の `getDocuments` completion は
/// 既定で main queue から呼ばれる（`FirestoreSettings.dispatchQueue` 未設定時）。つまり `cache` は
/// 異なるスレッドから読み書きされうるため、`OSAllocatedUnfairLock` で保護し、クラス全体を
/// `@unchecked Sendable` にする（ロックが唯一のアクセス経路であることを手動で保証する）。
nonisolated final class BeanProfileRepositoryIosImpl: NSObject, BeanProfileRepository, @unchecked Sendable {

    private let db = Firestore.firestore()
    // メモリキャッシュ: 初回取得後に保持し、以降は Firestore を叩かない
    private let cache = OSAllocatedUnfairLock<[BeanProfile]?>(initialState: nil)

    // MARK: - __getAll

    /// 全豆プロファイルを返す（初回のみ Firestore one-shot get）。
    ///
    /// Kotlin interface: `@Throws(Exception::class) suspend fun getAll(): List<BeanProfile>`
    func __getAll(
        completionHandler: @escaping @Sendable ([BeanProfile]?, (any Error)?) -> Void
    ) {
        if let cached = cache.withLock({ $0 }) {
            completionHandler(cached, nil)
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
            self?.cache.withLock { $0 = profiles }
            completionHandler(profiles, nil)
        }
    }
}

// MARK: - BeanProfileIosMapper

/// Firestore ドキュメント `[String: Any]` を `BeanProfile` に変換するヘルパ。
///
/// Kotlin 側の `BeanProfileFirestoreMapper` と同様のフィールドキー / 変換規則を使う。
/// `processings` は enum name（例: `"Washed"`）で逆引きし、SKIE CaseIterable `.allCases` を使う
/// （Obj-C ヘッダの `.entries` は Swift からは使わない。`docs/kmp-bridge.md` 参照）。
private nonisolated enum BeanProfileIosMapper {

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
