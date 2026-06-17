import AuthenticationServices
import SharedLogic
import SwiftUI
import UIKit

// MARK: - AccountView

/// アカウント管理画面。
///
/// - 匿名ユーザー: Apple でサインイン（アカウント引き継ぎ）ボタンを表示
/// - アップグレード済み: プロバイダ / メールアドレスを表示、サインアウト可能
/// - 共通: アカウント削除（確認ダイアログ → 写真全消去 + AppState リブート）
///
/// `AccountViewModelBridge` に依存し、AppState への参照は
/// `resetAndRebootstrap()` を呼ぶためにクロージャで受け取る。
struct AccountView: View {

    @State var viewModel: AccountViewModelBridge

    /// サインアウト / 削除完了後に AppState をリセットして再起動するコールバック。
    var onResetRequested: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false

    /// Sign in with Apple フローのコーディネータ。
    /// nonce 生成と ASAuthorization ラッピングを担当する。
    @State private var coordinator = AppleSignInCoordinator()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                dangerSection
            }
            .navigationTitle(String(localized: "アカウント"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "完了")) {
                        dismiss()
                    }
                    .accessibilityLabel(String(localized: "アカウント画面を閉じる"))
                }
            }
            .overlay {
                if viewModel.isProcessing {
                    processingOverlay
                }
            }
            .alert(
                String(localized: "エラー"),
                isPresented: Binding(
                    get: { viewModel.error != nil },
                    set: { if !$0 { viewModel.onErrorDismissed() } }
                )
            ) {
                Button(String(localized: "OK")) {
                    viewModel.onErrorDismissed()
                }
            } message: {
                Text(viewModel.error ?? "")
            }
            .confirmationDialog(
                String(localized: "サインアウト"),
                isPresented: $showSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "サインアウト"), role: .destructive) {
                    handleSignOut()
                }
                Button(String(localized: "キャンセル"), role: .cancel) {}
            } message: {
                Text(String(localized: "サインアウトすると、このデバイスでの同期が停止されます。"))
            }
            .confirmationDialog(
                String(localized: "アカウントを削除"),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "アカウントを削除"), role: .destructive) {
                    handleDeleteAccount()
                }
                Button(String(localized: "キャンセル"), role: .cancel) {}
            } message: {
                Text(String(localized: "アカウントとすべての記録が完全に削除されます。この操作は取り消せません。"))
            }
        }
        .task {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    // MARK: - アカウントセクション

    @ViewBuilder
    private var accountSection: some View {
        let isAnonymous = viewModel.account?.isAnonymous ?? true

        if isAnonymous {
            anonymousSection
        } else {
            upgradedSection
        }
    }

    /// 匿名ユーザー向け: アカウント引き継ぎ説明 + Apple でサインインボタン。
    ///
    /// `AppleSignInCoordinator` を使うことで rawNonce を適切に管理する。
    /// （`SignInWithAppleButton` の組み込みフローは rawNonce を外部に公開しないため
    ///  Firebase の nonce 検証に対応できない。`coordinator.signIn()` を使う）
    private var anonymousSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "アカウントを引き継ぐ"))
                    .font(.headline)

                Text(String(localized: "Apple ID でサインインすると、複数のデバイス間で記録を同期できます。現在の訪問記録はそのまま引き継がれます。"))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

            Button {
                startAppleSignIn()
            } label: {
                HStack {
                    Image(systemName: "applelogo")
                        .font(.body)
                    Text(String(localized: "Apple でサインイン"))
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(.white)
                .background(Color.primary.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Apple でサインイン"))
            .disabled(viewModel.isProcessing)
        }
    }

    /// アップグレード済みユーザー向け: プロバイダ情報 + サインアウトボタン。
    private var upgradedSection: some View {
        Section(String(localized: "アカウント情報")) {
            if let providerLabel = viewModel.account?.providerLabel {
                let displayName = providerLabel == "apple.com" ? "Apple" : providerLabel
                LabeledContent(
                    String(localized: "サインイン方法"),
                    value: displayName
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "サインイン方法: \(displayName)"))
            }

            if let email = viewModel.account?.email {
                LabeledContent(String(localized: "メールアドレス"), value: email)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "メールアドレス: \(email)"))
            }

            Button(String(localized: "サインアウト")) {
                showSignOutConfirm = true
            }
            .foregroundStyle(.red)
            .accessibilityLabel(String(localized: "サインアウト"))
            .disabled(viewModel.isProcessing)
            .frame(minHeight: 44)
        }
    }

    // MARK: - 危険操作セクション（共通）

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(
                    String(localized: "アカウントを削除"),
                    systemImage: "person.crop.circle.badge.minus"
                )
            }
            .accessibilityLabel(String(localized: "アカウントを削除"))
            .disabled(viewModel.isProcessing)
            .frame(minHeight: 44)
        } footer: {
            Text(String(localized: "アカウントを削除すると、すべての訪問記録と写真も削除されます。"))
                .font(.caption)
        }
    }

    // MARK: - 処理中オーバーレイ

    private var processingOverlay: some View {
        ZStack {
            Color(.systemBackground).opacity(0.6)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                Text(String(localized: "処理中..."))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(String(localized: "処理中"))
    }

    // MARK: - アクションハンドラ

    /// Apple でサインインフローを開始する。
    ///
    /// `AppleSignInCoordinator` 経由で `ASAuthorizationController` を起動し、
    /// 得られた `idToken` / `rawNonce` を ViewModel に渡す。
    /// nonce は coordinator が生成・管理し、Firebase の nonce 検証に使う。
    private func startAppleSignIn() {
        Task { @MainActor in
            guard let anchor = currentPresentationAnchor() else { return }
            do {
                let (idToken, rawNonce) = try await coordinator.signIn(anchor: anchor)
                viewModel.onAppleCredentialReceived(idToken: idToken, rawNonce: rawNonce)
            } catch {
                let nsError = error as NSError
                // ユーザーキャンセル（ASAuthorizationError.canceled == 1001）は無視する
                if nsError.domain == ASAuthorizationError.errorDomain,
                   nsError.code == ASAuthorizationError.canceled.rawValue {
                    return
                }
                print("[AccountView] Apple sign-in error: \(error.localizedDescription)")
            }
        }
    }

    /// 現在アクティブな UIWindow を返す。`ASAuthorizationController` の presentationAnchor に使う。
    private func currentPresentationAnchor() -> ASPresentationAnchor? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }
    }

    /// サインアウト確認後の処理。ViewModel を通じてサインアウトし、完了後に reset。
    private func handleSignOut() {
        viewModel.onSignOutTapped()
        observeProcessingCompletion { [self] in
            onResetRequested()
        }
    }

    /// アカウント削除確認後の処理。ViewModel を通じて削除し、完了後に写真全消去 + reset。
    private func handleDeleteAccount() {
        guard let userId = viewModel.account?.uid else { return }
        viewModel.onDeleteAccountTapped(userId: userId)
        observeProcessingCompletion { [self] in
            // 端末ローカルの写真ディレクトリを全消去（iOS 責務）
            try? PhotoFileStore.deleteAllPhotos()
            onResetRequested()
        }
    }

    /// `isProcessing` が false に変わるまでポーリングで待ち、エラーがなければ `completion` を呼ぶ。
    ///
    /// `@Observable` は Task 内での変化検知が非同期の場合に遅れることがあるため、
    /// 0.1s 間隔で isProcessing を確認するポーリングを採用する。
    /// 最大 30 秒（300 * 0.1s）タイムアウトで無視する。
    private func observeProcessingCompletion(completion: @escaping @Sendable () -> Void) {
        let vm = viewModel
        Task { @MainActor in
            for _ in 0 ..< 300 {
                try? await Task.sleep(for: .milliseconds(100))
                if !vm.isProcessing {
                    if vm.error == nil {
                        completion()
                    }
                    return
                }
            }
        }
    }
}

// MARK: - Preview（戦略 B: ダミー Demo View）

/// 匿名ユーザー状態の Preview。
#Preview("匿名ユーザー") {
    AccountViewDemo(isAnonymous: true)
}

/// アップグレード済みユーザー状態の Preview。
#Preview("アップグレード済み") {
    AccountViewDemo(isAnonymous: false)
}

/// Preview 専用のダミー AccountView（Bridge / AppState 依存なし）。
///
/// 本体 `AccountView` は `AccountViewModelBridge` に依存するため、
/// Preview では同等の UI 構造をダミーデータで再現する。
private struct AccountViewDemo: View {

    let isAnonymous: Bool

    @State private var showDeleteConfirm = false
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                if isAnonymous {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("アカウントを引き継ぐ")
                                .font(.headline)
                            Text("Apple ID でサインインすると、複数のデバイス間で記録を同期できます。現在の訪問記録はそのまま引き継がれます。")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)

                        Button {
                        } label: {
                            HStack {
                                Image(systemName: "applelogo")
                                    .font(.body)
                                Text("Apple でサインイン")
                                    .font(.body.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(.white)
                            .background(Color.primary.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Section("アカウント情報") {
                        LabeledContent("サインイン方法", value: "Apple")
                        LabeledContent("メールアドレス", value: "example@privaterelay.appleid.com")
                        Button("サインアウト") {
                            showSignOutConfirm = true
                        }
                        .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("アカウントを削除", systemImage: "person.crop.circle.badge.minus")
                    }
                } footer: {
                    Text("アカウントを削除すると、すべての訪問記録と写真も削除されます。")
                        .font(.caption)
                }
            }
            .navigationTitle("アカウント")
            .navigationBarTitleDisplayMode(.inline)
        }
        .confirmationDialog("サインアウト", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("サインアウト", role: .destructive) {}
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog("アカウントを削除", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("アカウントを削除", role: .destructive) {}
            Button("キャンセル", role: .cancel) {}
        }
    }
}
