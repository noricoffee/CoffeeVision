package com.noricoffee.core

/**
 * `shared/core` モジュールの存在を Kotlin/Native のリンク段階まで通すためのマーカー。
 *
 * Phase 2.5（PR1）では `shared/core` はモジュール構造とビルド設定だけを確立する段階で、
 * 実体（AppContainer / Dispatchers ラッパ / DI ヘルパ等）は PR2 で `data-local` の切り出しと
 * 同時に移してくる。Kotlin/Native は **シンボルが 1 つもないモジュール** の framework link で
 * 警告 / エラーを出すことがあるため、空ファイルではなくマーカーオブジェクトを置く。
 *
 * PR2 で実体が入ったらこのマーカーは削除して良い。
 */
internal object CoreMarker
