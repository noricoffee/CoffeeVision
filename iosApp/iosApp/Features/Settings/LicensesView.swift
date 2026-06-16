import SwiftUI

/// このアプリが利用している OSS ライセンスの一覧画面。
///
/// MVP: 名称 + ライセンス種別の表示まで（全文表示は不要）。
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
