import SwiftUI

// MARK: - ToastBanner

/// エラートースト本体。下部（タブバーの上）スライドインで表示される非致命エラー通知バナー。
///
/// - SF Symbol `exclamationmark.triangle.fill`（orange）+ メッセージ Text を横並び
/// - `.regularMaterial` 背景 + 角丸 12pt + 軽い shadow で地図 / コンテンツ上に浮遊表示
/// - タップまたは下方向 DragGesture で `onDismiss()` を呼ぶ（手動消去）
private struct ToastBanner: View {

    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        // タップで即時消去
        .onTapGesture {
            onDismiss()
        }
        // 下方向スワイプで消去
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 0 {
                        onDismiss()
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(String(localized: "タップして閉じる"))
    }
}

// MARK: - ErrorToastModifier

/// エラートーストを下部（タブバーの上）overlay で表示する ViewModifier。
///
/// - `message != nil` のとき `.overlay(alignment: .bottom)` で `ToastBanner` を表示
/// - 自動消去: `.task(id: message)` で `message` 変化時に前タスクを自動キャンセルし、
///   4 秒後に `onDismiss()` を呼ぶ
/// - `@Environment(\.accessibilityReduceMotion)` が true のときは opacity のみで遷移
/// - 表示時に `AccessibilityNotification.Announcement` を投稿して VoiceOver に通知する
private struct ErrorToastModifier: ViewModifier {

    let message: String?
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // トーストバナーを SafeArea 内の下部（タブバーの上）に overlay する。
            // `.ignoresSafeArea()` を持つコンテンツ（Map 等）でも safeAreaInset で押し下げを
            // 避けるため overlay を採用し、コンテンツ自体のレイアウトは変えない。
            .overlay(alignment: .bottom) {
                if let message {
                    ToastBanner(message: message, onDismiss: onDismiss)
                        .padding(.bottom, 8)
                        .transition(toastTransition)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: message != nil)
            // 自動消去タスク: message 変化のたびに前のタスクをキャンセルして再スタート
            .task(id: message) {
                guard message != nil else { return }
                try? await Task.sleep(for: .seconds(4))
                // キャンセルされていなければ（= 4秒経過で自然終了）dismiss を呼ぶ
                guard !Task.isCancelled else { return }
                onDismiss()
            }
            // VoiceOver への通知: message が変化したとき（非 nil になったとき）アナウンス
            .onChange(of: message) { _, newMessage in
                if let newMessage {
                    AccessibilityNotification.Announcement(newMessage).post()
                }
            }
    }

    /// Reduce Motion 対応: true なら opacity のみ、false なら下スライド + opacity。
    private var toastTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        } else {
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        }
    }
}

// MARK: - View Extension

extension View {

    /// エラートーストを下部（タブバーの上）に表示する。
    ///
    /// - Parameters:
    ///   - message: 表示するエラーメッセージ。`nil` のときは非表示。
    ///   - onDismiss: トーストを消去するときに呼ばれるクロージャ（message を nil にする処理を渡す）。
    func errorToast(message: String?, onDismiss: @escaping () -> Void) -> some View {
        self.modifier(ErrorToastModifier(message: message, onDismiss: onDismiss))
    }
}

// MARK: - Preview（短文）

#Preview("短文エラー") {
    @Previewable @State var message: String? = "同期に失敗しました"

    Color(.systemBackground)
        .ignoresSafeArea()
        .errorToast(message: message) {
            message = nil
        }
        .safeAreaInset(edge: .top) {
            Button("トーストを表示") {
                message = "同期に失敗しました"
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
}

// MARK: - Preview（長文折り返し）

#Preview("長文折り返し") {
    @Previewable @State var message: String? = "周辺のカフェを読み込めませんでした。ネットワーク接続を確認してから再度お試しください。"

    Color(.systemBackground)
        .ignoresSafeArea()
        .errorToast(message: message) {
            message = nil
        }
        .safeAreaInset(edge: .top) {
            Button("トーストを表示") {
                message = "周辺のカフェを読み込めませんでした。ネットワーク接続を確認してから再度お試しください。"
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
}
