import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Sign in with Apple フローを `async` でラップするコーディネータ。
///
/// ## 使い方
///
/// ```swift
/// let coordinator = AppleSignInCoordinator()
/// let (idToken, rawNonce, authorizationCode) = try await coordinator.signIn(anchor: window)
/// ```
///
/// ## nonce の役割
///
/// Firebase Authentication では CSRF 対策として SHA-256 ハッシュ済みの nonce を
/// Apple サーバーに送り、JWT 内の nonce claim と突き合わせる。
/// - `rawNonce` を生成 → SHA-256 してリクエストに含める
/// - 受け取った idToken と `rawNonce`（平文）を Firebase に渡す
///
/// 参考: Firebase 公式 iOS ドキュメント「Sign in with Apple」
@MainActor
final class AppleSignInCoordinator: NSObject {

    /// nonce 生成からサインイン UI 表示・完了まで非同期で処理する。
    ///
    /// - Parameter anchor: `ASAuthorizationControllerPresentationContextProviding` に渡す `UIWindow`。
    /// - Returns: `(idToken: String, rawNonce: String, authorizationCode: String)` のタプル。
    ///   `authorizationCode` は Apple が発行する使い捨てコード（約 5 分有効）で、
    ///   `Auth.auth().revokeToken(withAuthorizationCode:)` に渡す用途に使う。保存禁止。
    /// - Throws: Apple サインイン失敗 / ユーザーキャンセル時にエラーを throw。
    func signIn(anchor: ASPresentationAnchor) async throws -> (idToken: String, rawNonce: String, authorizationCode: String) {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let rawNonce = generateRandomNonce()
            self.currentNonce = rawNonce
            let hashedNonce = sha256(rawNonce)

            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.email]
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.presentationAnchor = anchor
            controller.performRequests()
        }
    }

    // MARK: - Private

    private var continuation: CheckedContinuation<(idToken: String, rawNonce: String, authorizationCode: String), Error>?
    private var currentNonce: String?
    private var presentationAnchor: ASPresentationAnchor?

    /// 暗号学的に安全なランダム nonce（32 bytes → hex string）を生成する。
    private func generateRandomNonce(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            // SecRandomCopyBytes の失敗はほぼ起きないが、万一のフォールバック
            randomBytes = (0 ..< length).map { _ in UInt8.random(in: 0 ... 255) }
        }
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    /// 文字列を SHA-256 でハッシュし、hex string で返す。
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard
                let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let appleIDTokenData = appleIDCredential.identityToken,
                let idToken = String(data: appleIDTokenData, encoding: .utf8),
                let rawNonce = self.currentNonce
            else {
                let error = NSError(
                    domain: "AppleSignInCoordinator",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Apple サインインの資格情報を取得できませんでした。"]
                )
                self.continuation?.resume(throwing: error)
                self.continuation = nil
                return
            }

            // authorizationCode は Apple が発行する使い捨てコード（約 5 分有効・保存禁止）。
            // revokeToken(withAuthorizationCode:) に渡すために取り出す。
            guard
                let authCodeData = appleIDCredential.authorizationCode,
                let authorizationCode = String(data: authCodeData, encoding: .utf8)
            else {
                let error = NSError(
                    domain: "AppleSignInCoordinator",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Apple の認証コードを取得できませんでした。しばらく待ってから再試行してください。"]
                )
                self.continuation?.resume(throwing: error)
                self.continuation = nil
                return
            }

            self.continuation?.resume(returning: (idToken: idToken, rawNonce: rawNonce, authorizationCode: authorizationCode))
            self.continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            // ユーザーキャンセル（ASAuthorizationError.canceled）もここに来る
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        // @MainActor 上で設定した anchor を返す。
        // nonisolated であっても presentationAnchor は UI スレッドから呼ばれるため安全。
        // Xcode が「nonisolated から MainActor プロパティへのアクセス」を警告する場合は
        // MainActor.assumeIsolated を用いる。
        MainActor.assumeIsolated {
            if let anchor = self.presentationAnchor {
                return anchor
            }
            // フォールバック: foregroundActive な WindowScene の key window を使う。
            // UIWindow() のゼロ引数 init は iOS 26 以降で deprecated のため使わない。
            // presentationAnchor は signIn(anchor:) の呼び出し元が必ず設定するため、
            // このフォールバックパスに到達することは通常ない。
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            let activeScene = scenes.first { $0.activationState == .foregroundActive }
                ?? scenes.first
            if let scene = activeScene,
               let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
            // 最終フォールバック: windowScene を持つ UIWindow を生成する
            if let scene = activeScene {
                return UIWindow(windowScene: scene)
            }
            // ここには到達しない（サインインフロー中は必ず foregroundActive scene が存在する）
            return UIWindow()
        }
    }
}
