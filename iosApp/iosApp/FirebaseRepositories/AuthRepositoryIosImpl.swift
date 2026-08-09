import Foundation
import FirebaseAuth
import FirebaseFirestore
import SharedLogic

/// `com.noricoffee.repository.AuthRepository` の iOS 実装。
///
/// SKIE は protocol 実装側に「Obj-C 互換シグネチャ（`__` プレフィックスの completion handler 形式）」
/// と「Swift エルゴノミクス形式（`async throws` / `SkieSwiftFlow`）」のどちらかを要求する。
/// 詳細は `docs/kmp-bridge.md` §SKIE の利用 を参照。
///
/// `nonisolated` である理由は他の Kotlin interface 実装と同じ（Kotlin ランタイムが任意スレッドから
/// 呼び出す）。加えて `Features/Account/AccountView.swift` が Swift 側の素のヘルパとしても直接
/// 生成・使用するが、可変状態を保持しないためどちらの呼び出し経路でも安全（SW6-2）。
nonisolated final class AuthRepositoryIosImpl: NSObject, AuthRepository {

    // MARK: - signInAnonymouslyIfNeeded

    /// 既にサインイン済なら現在の uid を即返す。未サインインなら匿名サインインを起こして返す。
    func __signInAnonymouslyIfNeeded(
        completionHandler: @escaping @Sendable (String?, (any Error)?) -> Void
    ) {
        if let uid = Auth.auth().currentUser?.uid {
            completionHandler(uid, nil)
            return
        }
        Auth.auth().signInAnonymously { result, error in
            if let error {
                completionHandler(nil, error)
            } else if let uid = result?.user.uid {
                completionHandler(uid, nil)
            } else {
                completionHandler(
                    nil,
                    NSError(
                        domain: "AuthRepositoryIosImpl",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No uid returned"]
                    )
                )
            }
        }
    }

    // MARK: - observeUserId

    /// Firebase Auth の state listener を Kotlin Flow にブリッジ。
    /// Flow<String?> は SKIE 経由で SkieSwiftOptionalFlow<String> として実装する。
    func observeUserId() -> SkieSwiftOptionalFlow<String> {
        var handle: AuthStateDidChangeListenerHandle?
        // Auth の state listener はエラーを返さない API なので `fail` は使わない。
        let callbackFlow = CallbackFlow<NSString>(
            onStart: { emit, _ in
                handle = Auth.auth().addStateDidChangeListener { _, user in
                    if let uid = user?.uid {
                        emit(uid as NSString)
                    }
                    // サインアウト時の nil emit は今回スコープ外。
                    // 必要になったら CallbackFlow を Optional 対応に拡張する。
                }
            },
            onCancel: {
                if let handle {
                    Auth.auth().removeStateDidChangeListener(handle)
                }
                handle = nil
            }
        )
        // SkieSwiftOptionalFlow<String> は @_spi(SKIE) の internal init しか持たず、
        // _ObjectiveCBridgeable 経由で `SkieKotlinOptionalFlow` から変換する必要がある。
        return SkieSwiftOptionalFlow._unconditionallyBridgeFromObjectiveC(
            SkieKotlinOptionalFlow(callbackFlow)
        )
    }

    // MARK: - observeAccount

    /// Firebase Auth の state listener を Flow<AuthAccount?> としてブリッジ。
    ///
    /// サインイン中は AuthAccount を emit し、サインアウト（nil user）は nil を emit する。
    /// SKIE 実装側は `SkieSwiftOptionalFlow<AuthAccount>` を返す。
    func observeAccount() -> SkieSwiftOptionalFlow<AuthAccount> {
        var handle: AuthStateDidChangeListenerHandle?
        // Auth の state listener はエラーを返さない API なので `fail` は使わない。
        let callbackFlow = CallbackFlowOptional<AuthAccount>(
            onStart: { emitSome, emitNone, _ in
                handle = Auth.auth().addStateDidChangeListener { _, user in
                    if let user {
                        let account = AuthRepositoryIosImpl.makeAuthAccount(from: user)
                        emitSome(account)
                    } else {
                        emitNone()
                    }
                }
            },
            onCancel: {
                if let handle {
                    Auth.auth().removeStateDidChangeListener(handle)
                }
                handle = nil
            }
        )
        return SkieSwiftOptionalFlow._unconditionallyBridgeFromObjectiveC(
            SkieKotlinOptionalFlow(callbackFlow)
        )
    }

    // MARK: - linkWithApple

    /// 現在の匿名アカウントに Sign in with Apple の資格情報をリンクする（アップグレード）。
    ///
    /// uid は変わらない。成功時に更新後の AuthAccount を completion で返す。
    /// `credentialAlreadyInUse` は分かりやすいエラー文言に変換する。
    ///
    /// 将来課題（MVP 対象外）: link 失敗時のサインインフォールバック。
    /// 現状は link のみ試みてエラーを返す。
    func __linkWithApple(
        idToken: String,
        rawNonce: String,
        completionHandler: @escaping @Sendable (AuthAccount?, (any Error)?) -> Void
    ) {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: nil
        )
        guard let currentUser = Auth.auth().currentUser else {
            completionHandler(
                nil,
                NSError(
                    domain: "AuthRepositoryIosImpl",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "サインインセッションが見つかりません。アプリを再起動してください。"]
                )
            )
            return
        }
        currentUser.link(with: credential) { result, error in
            if let error {
                let nsError = error as NSError
                // credentialAlreadyInUse: この Apple ID はすでに別アカウントで使用中
                if nsError.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                    completionHandler(
                        nil,
                        NSError(
                            domain: nsError.domain,
                            code: nsError.code,
                            userInfo: [NSLocalizedDescriptionKey: "この Apple ID はすでに別のアカウントで使用されています。"]
                        )
                    )
                } else {
                    completionHandler(nil, error)
                }
                return
            }
            guard let user = result?.user else {
                completionHandler(
                    nil,
                    NSError(
                        domain: "AuthRepositoryIosImpl",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "アップグレードに失敗しました。"]
                    )
                )
                return
            }
            let account = AuthRepositoryIosImpl.makeAuthAccount(from: user)
            completionHandler(account, nil)
        }
    }

    // MARK: - signOut

    /// Firebase Auth からサインアウトする。
    ///
    /// 呼び出し元（AccountViewModel 経由で AppState）が
    /// `resetAndRebootstrap()` を呼んで新規匿名 uid を確定すること。
    func __signOut(
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        do {
            try Auth.auth().signOut()
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    // MARK: - deleteUserProfile

    /// Firestore `users/{uid}` ルートドキュメント自体を削除する。
    ///
    /// 呼び出し元（DeleteAccountUseCase）は必ず `deleteAuthUser` の**直前**に本メソッドを呼ぶこと。
    /// Firestore はルートドキュメントを削除してもサブコレクション（`coffees` / `savedCafes`）を
    /// カスケード削除しないため、本メソッドを呼ぶ時点でサブコレクションの削除が完了していなければならない。
    /// また、Auth ユーザー削除後は Security Rules（`request.auth.uid == uid`）により
    /// `users/{uid}` に一切到達できなくなるため、順序が逆転するとルートドキュメントが永久に孤児化する。
    func __deleteUserProfile(
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completionHandler(
                NSError(
                    domain: "AuthRepositoryIosImpl",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "サインインセッションが見つかりません。"]
                )
            )
            return
        }
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .delete { error in
                completionHandler(error)
            }
    }

    // MARK: - deleteAuthUser

    /// Firebase Auth からユーザー本体を削除する。
    ///
    /// 呼び出し元 UseCase（DeleteAccountUseCase）が全 Visit 削除済みであることを前提とする。
    /// `requiresRecentLogin` が返った場合は再ログインを促すエラー文言を返す。
    /// 将来課題（MVP 対象外）: 再認証フロー（Apple 資格情報での re-authenticate）。
    func __deleteAuthUser(
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        guard let currentUser = Auth.auth().currentUser else {
            completionHandler(
                NSError(
                    domain: "AuthRepositoryIosImpl",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "サインインセッションが見つかりません。"]
                )
            )
            return
        }
        currentUser.delete { error in
            if let error {
                let nsError = error as NSError
                if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    completionHandler(
                        NSError(
                            domain: nsError.domain,
                            code: nsError.code,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "セキュリティのため、再度サインインしてからアカウントを削除してください。"
                            ]
                        )
                    )
                } else {
                    completionHandler(error)
                }
            } else {
                completionHandler(nil)
            }
        }
    }

    // MARK: - updateAnalyticsConsent

    /// Firestore `users/{uid}` ルートドキュメントに `analyticsConsent` を書き込む。
    ///
    /// ドキュメントが存在しない場合は merge:true により作成される。
    func __updateAnalyticsConsent(
        consent: Bool,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completionHandler(
                NSError(
                    domain: "AuthRepositoryIosImpl",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "サインインセッションが見つかりません。"]
                )
            )
            return
        }
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .setData(["analyticsConsent": consent], merge: true) { error in
                completionHandler(error)
            }
    }

    // MARK: - observeAnalyticsConsent

    /// Firestore `users/{uid}` の `analyticsConsent` フィールドを Flow<Boolean> として観察する。
    ///
    /// ドキュメントが存在しない場合は `false` を emit する（初回ユーザー = 未同意）。
    /// SKIE の要求により `SkieSwiftFlow<KotlinBoolean>` を返す。
    ///
    /// **読み取りエラーは `false` に丸めず Flow を例外終了させる。** 「ドキュメントが無い」と
    /// 「読めなかった」は別の事象で、後者で `false` を emit するのは同意状態の**値の捏造**に
    /// あたる（`permission-denied` が UI 上は「同意していない」として現れてしまう）。
    func observeAnalyticsConsent() -> SkieSwiftFlow<KotlinBoolean> {
        var listenerRegistration: ListenerRegistration?

        let flow = CallbackFlow<KotlinBoolean>(
            onStart: { emit, fail in
                guard let uid = Auth.auth().currentUser?.uid else {
                    emit(KotlinBoolean(value: false))
                    return
                }
                listenerRegistration = Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .addSnapshotListener { snapshot, error in
                        if let error {
                            print("[AuthRepositoryIosImpl] analyticsConsent snapshot error: \(error)")
                            fail(error)
                            return
                        }
                        let consent = snapshot?.data()?["analyticsConsent"] as? Bool ?? false
                        emit(KotlinBoolean(value: consent))
                    }
            },
            onCancel: {
                listenerRegistration?.remove()
                listenerRegistration = nil
            }
        )
        return SkieSwiftFlow._unconditionallyBridgeFromObjectiveC(
            SkieKotlinFlow(flow)
        )
    }

    // MARK: - Apple 再認証 + トークン失効

    /// Apple 再認証（`reauthenticate`）と Apple トークン失効（`revokeToken`）を順次実行する。
    ///
    /// App Store ガイドライン 5.1.1(v) に準拠するため、アカウント削除フローの前段で呼ぶ。
    /// - Parameters:
    ///   - idToken: `AppleSignInCoordinator.signIn(anchor:)` で取得した Apple ID トークン。
    ///   - rawNonce: 同上で取得した rawNonce（平文）。
    ///   - authorizationCode: 同上で取得した Apple 認証コード（使い捨て・保存禁止）。
    /// - Throws: `reauthenticate` または `revokeToken` が失敗した場合にエラーを throw する。
    func reauthenticateAndRevokeAppleToken(
        idToken: String,
        rawNonce: String,
        authorizationCode: String
    ) async throws {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: nil
        )
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(
                domain: "AuthRepositoryIosImpl",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "サインインセッションが見つかりません。アプリを再起動してください。"]
            )
        }
        // 再認証（requiresRecentLogin を解消する）
        try await currentUser.reauthenticate(with: credential)
        // Apple トークンの失効（App Store 5.1.1(v) 要件）
        try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
    }

    // MARK: - Private helpers

    /// Firebase `User` を `AuthAccount` ドメインモデルに変換する。
    private static func makeAuthAccount(from user: User) -> AuthAccount {
        let providerLabel = user.providerData.first?.providerID
        let email = user.providerData.first?.email ?? user.email
        return AuthAccount(
            uid: user.uid,
            isAnonymous: user.isAnonymous,
            providerLabel: providerLabel,
            email: email,
            analyticsConsent: false
        )
    }
}
