import Foundation
import Observation
import SharedLogic

/// Phase 2 の最小確認用 App 状態ホルダ。
///
/// - 起動時に Swift 側で `AuthRepositoryIosImpl` / `RemoteVisitDataSourceIosImpl` を組み立て、
///   Kotlin の `AppContainer` に注入する
/// - `AppContainer.startInitialSync()` を呼び、得られた uid を保持する
///
/// Phase 3 で本格的な ViewModel ブリッジに置き換える想定。
@MainActor
@Observable
final class AppState {

    private(set) var container: AppContainer
    private(set) var uid: String?
    private(set) var status: Status = .idle
    private(set) var lastError: String?
    private(set) var lastWroteVisitId: String?

    enum Status: Equatable {
        case idle
        case signingIn
        case ready
        case writing
        case failed
    }

    init() {
        let sqlDriver = DatabaseDriverFactory().create()
        let authRepo = AuthRepositoryIosImpl()
        let remoteDataSource = RemoteVisitDataSourceIosImpl()
        self.container = AppContainer(
            sqlDriver: sqlDriver,
            remoteVisitDataSource: remoteDataSource,
            authRepository: authRepo
        )
    }

    /// 匿名サインイン + 同期購読を起動する。`iOSApp` の `.task` から呼ぶ。
    func bootstrap() async {
        status = .signingIn
        do {
            let uid = try await container.startInitialSync()
            self.uid = uid
            self.status = .ready
            print("[CoffeeVision] startInitialSync succeeded uid=\(uid)")
        } catch {
            self.lastError = error.localizedDescription
            self.status = .failed
            print("[CoffeeVision] startInitialSync failed: \(error)")
        }
    }

    /// Phase 2 検証用のダミー Visit を Firestore に書き込む。
    func writeDummyVisit() async {
        guard let uid else {
            lastError = "uid is nil (not signed in)"
            return
        }
        status = .writing
        let visit = Self.makeDummyVisit(userId: uid)
        do {
            try await container.visitRepository.save(visit: visit)
            self.lastWroteVisitId = visit.id
            self.status = .ready
            print("[CoffeeVision] Wrote dummy visit id=\(visit.id)")
        } catch {
            self.lastError = error.localizedDescription
            self.status = .failed
            print("[CoffeeVision] Write failed: \(error)")
        }
    }

    /// 検証用のダミー Visit を組み立てる。子コレクションは空のまま（Phase 2 スコープ外）。
    private static func makeDummyVisit(userId: String) -> Visit_ {
        let now = Date()
        let epochMs = Int64(now.timeIntervalSince1970 * 1000)
        let instant = Kotlinx_datetimeInstant.Companion.shared.fromEpochMilliseconds(
            epochMilliseconds: epochMs
        )
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let localDate = Kotlinx_datetimeLocalDate(
            year: Int32(components.year ?? 2026),
            monthNumber: Int32(components.month ?? 1),
            dayOfMonth: Int32(components.day ?? 1)
        )

        let cafe = Cafe(
            placeId: "ChIJ_PoC_DUMMY_iOS_VERIFICATION",
            name: "Phase 2 検証ダミーカフェ",
            address: "東京都世田谷区 (dummy)",
            latitude: KotlinDouble(value: 35.6448),
            longitude: KotlinDouble(value: 139.6694),
            photoReferences: [],
            websiteUrl: nil,
            mapsUrl: nil
        )

        return Visit_(
            id: UUID().uuidString,
            userId: userId,
            cafe: cafe,
            visitedOn: localDate,
            ambiance: "Phase 2 動作確認用のダミー Visit",
            rating: 4,
            notes: "iOS シミュレータからの書き込み確認",
            photos: [],
            coffees: [],
            foods: [],
            createdAt: instant,
            updatedAt: instant
        )
    }
}
