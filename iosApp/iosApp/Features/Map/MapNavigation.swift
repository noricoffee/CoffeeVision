import SharedLogic

// MARK: - ナビゲーションルート

/// マップ → カフェ詳細 への push ナビゲーション引数。
struct CafeDetailRoute: Hashable {
    let placeId: String
    let initialCafe: Cafe?

    // MARK: - Hashable / Equatable
    // Cafe は Kotlin data class（Obj-C クラス）のため Swift の Hashable 自動合成が使えない。
    // placeId だけをキーにする。

    static func == (lhs: CafeDetailRoute, rhs: CafeDetailRoute) -> Bool {
        lhs.placeId == rhs.placeId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(placeId)
    }
}
