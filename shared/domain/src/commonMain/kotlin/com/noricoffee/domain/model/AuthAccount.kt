package com.noricoffee.domain.model

/**
 * Firebase Auth で管理されているアカウント情報。
 *
 * - 匿名サインイン中は [isAnonymous] = true、[providerLabel] / [email] = null
 * - Sign in with Apple でアップグレード済みは [isAnonymous] = false、[providerLabel] = "apple.com"
 *
 * @property uid Firebase Auth の uid（匿名 / 実名ともに不変で一意）
 * @property isAnonymous 匿名アカウントかどうか
 * @property providerLabel サインインプロバイダ識別子（例: "apple.com"）。匿名の場合は null
 * @property email プロバイダが提供するメールアドレス。Apple は非公開リレー含め null になりうる
 */
data class AuthAccount(
    val uid: String,
    val isAnonymous: Boolean,
    val providerLabel: String?,
    val email: String?,
)
