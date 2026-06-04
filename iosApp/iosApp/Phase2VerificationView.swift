import SwiftUI

/// Phase 2 の最小動作確認 View。
///
/// - 匿名サインイン後の uid を表示
/// - 「テストデータ書き込み」ボタンで Firestore にダミー Visit を投げる
/// - 状態 / エラーをテキスト表示
///
/// Phase 3 で本格的な VisitList 画面に置き換える想定。`ContentView.swift` は温存。
struct Phase2VerificationView: View {

    @Bindable var state: AppState

    var body: some View {
        NavigationStack {
            Form {
                Section("Auth") {
                    LabeledContent("Status") {
                        Text(statusText)
                            .foregroundStyle(.secondary)
                    }
                    if let uid = state.uid {
                        LabeledContent("uid") {
                            Text(uid)
                                .font(.callout.monospaced())
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                    }
                }

                Section("Firestore 検証") {
                    Button {
                        Task { await state.writeDummyVisit() }
                    } label: {
                        Label("テストデータを書き込む", systemImage: "icloud.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.uid == nil || state.status == .writing)
                    .accessibilityLabel("Firestore にダミー Visit を書き込む")

                    if let id = state.lastWroteVisitId {
                        LabeledContent("最後に書いた id") {
                            Text(id)
                                .font(.callout.monospaced())
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                    }
                }

                if let error = state.lastError {
                    Section("Error") {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("CoffeeVision Phase 2")
            .task {
                await state.bootstrap()
            }
        }
    }

    private var statusText: String {
        switch state.status {
        case .idle: return "Idle"
        case .signingIn: return "Signing in..."
        case .ready: return "Ready"
        case .writing: return "Writing..."
        case .failed: return "Failed"
        }
    }
}
