import SwiftUI

/// このアプリが利用している OSS ライセンス・サードパーティ SDK 利用規約の一覧画面。
///
/// MVP: 名称 + ライセンス／規約種別の表示まで（全文表示は不要）。
///
/// - Google Mobile Ads SDK / UMP SDK: SPM 配布パッケージの `Package.swift` 自体は Apache 2.0 だが、
///   これはラッパー（バイナリ本体を取得するだけの薄い層）のライセンスであり、実体の
///   `GoogleMobileAds.xcframework`（`https://dl.google.com/googleadmobadssdk/...` から取得する
///   バイナリターゲット）は Google 独自の AdMob 利用規約に準拠する（公式ドキュメントの
///   「Google Mobile Ads SDK の利用は AdMob の利用規約に従う」旨の記載に基づく。2026-08-07 確認）。
///   `Apache 2.0` と誤記しないこと。
/// - Google Places API: SDK として同梱しているのではなく REST API 経由での利用のため、
///   Google Maps Platform 利用規約に準拠する。
struct LicensesView: View {

    // MARK: - OSS エントリ

    private struct OSSEntry: Identifiable {
        let id = UUID()
        let name: String
        let license: String
    }

    private let entries: [OSSEntry] = [
        OSSEntry(name: "Firebase iOS SDK", license: "Apache 2.0"),
        OSSEntry(name: "SQLDelight", license: "Apache 2.0"),
        OSSEntry(name: "Ktor", license: "Apache 2.0"),
        OSSEntry(name: "kotlinx-coroutines", license: "Apache 2.0"),
        OSSEntry(name: "kotlinx-serialization", license: "Apache 2.0"),
        OSSEntry(name: "kotlinx-datetime", license: "Apache 2.0"),
        OSSEntry(name: "SKIE", license: "Apache 2.0"),
        OSSEntry(name: "Google Mobile Ads SDK", license: "AdMob 利用規約（独自条項）"),
        OSSEntry(name: "Google User Messaging Platform (UMP) SDK", license: "AdMob 利用規約（独自条項）"),
        OSSEntry(name: "Google Places API", license: "Google Maps Platform 利用規約"),
    ]

    // MARK: - Body

    var body: some View {
        List(entries) { entry in
            LabeledContent(entry.name) {
                Text(entry.license)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(entry.name)、ライセンス: \(entry.license)")
        }
        .navigationTitle(String(localized: "ライセンス"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LicensesView()
    }
}
