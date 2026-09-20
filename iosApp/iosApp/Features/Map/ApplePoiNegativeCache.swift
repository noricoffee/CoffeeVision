import Foundation
import CoreLocation

/// Apple `.cafe` POI（`MKLocalPointsOfInterestRequest` 由来）のうち、Google Places の
/// `onPoiTapped` ルックアップで「該当なし」だった地点を記録し、以後の周辺カフェ一覧から
/// 除外するネガティブキャッシュ（周辺カフェピンのノイズ除去、2026-07-13）。
///
/// ## 設計方針
///
/// - Apple の POI には安定した ID が無いため、名前完全一致 + 座標近接（30m 以内）の
///   複合キーで一致判定する
/// - `UserDefaults` + JSON（`Codable`）で永続化する。件数は高々 `maxEntryCount` 件のため
///   線形走査で十分（過剰設計を避ける）。ただし**読み出しとデコードは判定ごとに繰り返さない** —
///   一致判定は `snapshot()` で 1 回読み出した [Snapshot] に対して行う
/// - TTL は設けない。Google 側で解決できない POI は恒久的にタップ不能なため、
///   隠したままで整合が取れる（通信エラー等の一時的な失敗はここではキャッシュしない —
///   呼び出し側で `PoiLookupError.isNotFound == true` のときのみ `add` を呼ぶこと）
/// - 上限件数を超えたら最も古いエントリから破棄する（FIFO）
enum ApplePoiNegativeCache {

    fileprivate struct Entry: Codable {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    /// 判定用のスナップショット。
    ///
    /// 1 回の Apple POI 取得（`MKLocalSearch` は最大 50 件返す）の中で POI 1 件ごとに
    /// `UserDefaults` 読み出し + JSON デコード（最大 300 件）を繰り返さないために、
    /// 呼び出し元が先頭で 1 回だけ取得して使い回す（SL-5）。
    struct Snapshot {

        fileprivate let entries: [Entry]

        /// 指定した名前・座標がキャッシュ済み（= 以後非表示にすべき）かどうかを判定する。
        func contains(name: String, coordinate: CLLocationCoordinate2D) -> Bool {
            let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return entries.contains { entry in
                guard entry.name == name else { return false }
                let location = CLLocation(latitude: entry.latitude, longitude: entry.longitude)
                return location.distance(from: target) <= matchRadiusMeters
            }
        }
    }

    private static let userDefaultsKey = "ApplePoiNegativeCache.entries"
    private static let maxEntryCount = 300
    private static let matchRadiusMeters: CLLocationDistance = 30

    /// 現在のキャッシュ内容を 1 回だけ読み出したスナップショットを返す。
    static func snapshot() -> Snapshot {
        Snapshot(entries: loadEntries())
    }

    /// 「該当なし」と判定された POI を追加する。
    ///
    /// 既に一致するエントリがあれば no-op（重複防止）。上限件数を超える場合は
    /// 最も古いエントリから破棄する。
    static func add(name: String, coordinate: CLLocationCoordinate2D) {
        var entries = loadEntries()
        guard !Snapshot(entries: entries).contains(name: name, coordinate: coordinate) else { return }
        entries.append(Entry(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude))
        if entries.count > maxEntryCount {
            entries.removeFirst(entries.count - maxEntryCount)
        }
        saveEntries(entries)
    }

    // MARK: - Private

    private static func loadEntries() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func saveEntries(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}
