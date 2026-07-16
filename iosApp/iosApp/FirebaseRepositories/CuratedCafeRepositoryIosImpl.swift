import Foundation
import FirebaseFirestore
import SharedLogic

/// `com.noricoffee.repository.CuratedCafeRepository` の iOS 実装。
///
/// Firestore のグローバルコレクション `curatedCafes/{prefectureCode}` を read-only で参照する。
/// 初回呼び出しで one-shot `getDocuments` し、各ドキュメントの `cafes` 配列を flatten して
/// 1 本のリストにする。以降はメモリキャッシュを返す（snapshotListener 不要）。
///
/// ## SKIE の制約（実装側）
///
/// SKIE の SuspendInterop は「Swift から Kotlin を呼ぶ方向」にしか効かないため、
/// Swift で Kotlin interface を実装する際は Obj-C 互換シグネチャを使う:
/// - `getAll()` → `func __getAll(completionHandler:)`
///
/// `BeanProfileRepositoryIosImpl` と同型のパターン。詳細は `docs/kmp-bridge.md` §SKIE の利用 を参照。
final class CuratedCafeRepositoryIosImpl: NSObject, CuratedCafeRepository {

    private let db = Firestore.firestore()
    // メモリキャッシュ: 初回取得後に保持し、以降は Firestore を叩かない
    private var cache: [CuratedCafe]? = nil

    /// 全都道府県のおすすめカフェを返す（初回のみ Firestore one-shot get）。
    ///
    /// Kotlin interface: `@Throws(Exception::class) suspend fun getAll(): List<CuratedCafe>`
    func __getAll(
        completionHandler: @escaping @Sendable ([CuratedCafe]?, (any Error)?) -> Void
    ) {
        if let cache = cache {
            completionHandler(cache, nil)
            return
        }
        db.collection("curatedCafes").getDocuments { [weak self] snapshot, error in
            if let error = error {
                completionHandler(nil, error)
                return
            }
            let cafes = snapshot?.documents.flatMap { doc in
                CuratedCafeIosMapper.fromDocument(data: doc.data())
            } ?? []
            self?.cache = cafes
            completionHandler(cafes, nil)
        }
    }
}

// MARK: - CuratedCafeIosMapper

/// Firestore ドキュメント `[String: Any]`（`curatedCafes/{prefectureCode}`）を
/// `[CuratedCafe]` に変換するヘルパ。
///
/// Kotlin 側の `CuratedCafeFirestoreMapper` と同じフィールド規則:
/// - ドキュメント直下の `prefectureCode` が欠如していれば空リストを返す
/// - `cafes` 配列の各要素は `placeId` / `name` / `latitude` / `longitude` がすべて必須。
///   いずれか欠如 / 型不一致の要素は skip する（ドキュメント全体は無効にしない）
/// - `latitude` / `longitude` は Firestore 上 `NSNumber`（Int / Double どちらの可能性もある）として
///   受けて `doubleValue` で変換する
private enum CuratedCafeIosMapper {

    static func fromDocument(data: [String: Any]) -> [CuratedCafe] {
        guard let prefectureCode = data["prefectureCode"] as? String else { return [] }
        guard let cafesRaw = data["cafes"] as? [[String: Any]] else { return [] }

        return cafesRaw.compactMap { cafeMap in
            guard
                let placeId = cafeMap["placeId"] as? String,
                let name = cafeMap["name"] as? String,
                let latitude = cafeMap["latitude"] as? NSNumber,
                let longitude = cafeMap["longitude"] as? NSNumber
            else { return nil }

            return CuratedCafe(
                placeId: placeId,
                name: name,
                latitude: latitude.doubleValue,
                longitude: longitude.doubleValue,
                prefectureCode: prefectureCode
            )
        }
    }
}
