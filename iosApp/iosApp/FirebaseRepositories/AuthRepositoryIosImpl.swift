import Foundation
import FirebaseAuth
import SharedLogic

/// `com.noricoffee.repository.AuthRepository` の iOS 実装。
///
/// SKIE は protocol 実装側に「Obj-C 互換シグネチャ（`__` プレフィックスの completion handler 形式）」
/// と「Swift エルゴノミクス形式（`async throws` / `SkieSwiftFlow`）」のどちらかを要求する。
/// 詳細は `docs/kmp-bridge.md` §SKIE の利用 を参照。
final class AuthRepositoryIosImpl: NSObject, AuthRepository {

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
        let callbackFlow = CallbackFlow<NSString>(
            onStart: { emit in
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
}
