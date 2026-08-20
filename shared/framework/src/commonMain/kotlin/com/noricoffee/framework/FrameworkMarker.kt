package com.noricoffee.framework

/**
 * shared/framework は iOS 向けに全 shared モジュールを api + export で再公開するだけの
 * Umbrella レイヤー。自モジュール内シンボルゼロのままだと将来 Kotlin/Native のリンク段階で
 * 空モジュール警告が出る可能性があるため、internal なマーカーを 1 つ置いておく。
 *
 * 用途は実装上の意味を持たない（外部公開しない）。
 */
internal object FrameworkMarker
