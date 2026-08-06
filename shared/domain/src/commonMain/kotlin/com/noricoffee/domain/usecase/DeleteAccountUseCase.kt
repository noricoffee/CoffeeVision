package com.noricoffee.domain.usecase

import com.noricoffee.repository.AuthRepository
import com.noricoffee.repository.CoffeeRepository
import com.noricoffee.repository.SavedCafeRepository
import kotlinx.coroutines.flow.first

/**
 * アカウント削除 UseCase。
 *
 * ## 処理の順序（厳密に守ること）
 * 1. [SavedCafeRepository.observeAll] で対象 uid の全 SavedCafe を 1 スナップショット取得し、
 *    [SavedCafeRepository.delete] で個別削除
 * 2. [CoffeeRepository.observeAll] で対象 uid の全 CoffeeRecord を 1 スナップショット取得し、
 *    [CoffeeRepository.delete] で個別削除（ローカル DB + Firestore 両方を処理する
 *    合成実装 [com.noricoffee.repository.CoffeeRepositoryImpl] が担う）
 * 3. [AuthRepository.deleteUserProfile] で Firestore `users/{uid}` ルートドキュメントを削除
 * 4. [AuthRepository.deleteAuthUser] で Auth ユーザー本体を削除
 *
 * サブコレクション（1, 2）→ ルートドキュメント（3）→ Auth ユーザー（4）の順序は仕様である:
 * - Firestore はルートドキュメントを削除してもサブコレクションをカスケード削除しないため、
 *   サブコレクションは必ずルートドキュメントより先に消す
 * - Firestore Security Rules は `request.auth.uid == uid` を要求するため、Auth ユーザー削除後は
 *   `users/{uid}` 配下に一切アクセスできなくなる。ルートドキュメント削除（3）は必ず
 *   Auth ユーザー削除（4）より先でなければならない（逆順にすると `users/{uid}` が永久に孤児化する）
 *
 * ## 写真ファイルの削除について
 * 写真ファイル（端末 Documents 内の PNG / JPEG）の削除は **iOS 側の責務**。
 * KMP 層は Firestore の coffees コレクション（photos 埋め込み配列メタデータのみ）を
 * ドキュメントとして削除するが、実ファイルの削除は `iosApp` の PhotoFileStore が担うため、
 * 本 UseCase では扱わない。
 *
 * ## bulk 削除の非採用について
 * [CoffeeRepository] / [SavedCafeRepository] に一括削除 API は現時点で存在しない。
 * 全件 `observeAll` → 個別 `delete` の方式で実装する。件数が多い場合は N+1 的なコストが
 * 発生するが、アカウント削除は稀頻度の操作であるため許容する。
 *
 * @param coffeeRepository CoffeeRecord の取得・削除を担うリポジトリ
 * @param savedCafeRepository SavedCafe（「行きたい店」）の取得・削除を担うリポジトリ
 * @param authRepository Auth ユーザー削除を担うリポジトリ
 */
class DeleteAccountUseCase(
    private val coffeeRepository: CoffeeRepository,
    private val savedCafeRepository: SavedCafeRepository,
    private val authRepository: AuthRepository,
) {

    /**
     * 指定ユーザーの全 SavedCafe / CoffeeRecord を削除し、Firestore ルートドキュメントを消してから
     * Auth ユーザーを削除する。
     *
     * 途中で例外が発生した場合はそのまま上位（ViewModel の `try`/`catch`）へ伝播させ、
     * 後続のステップは実行しない。特に 3 が失敗したときに 4 を実行しないことが重要で、
     * ルートドキュメントを消せないまま Auth ユーザーを消すと `users/{uid}` が永久に孤児化する。
     *
     * @param userId 削除対象ユーザーの uid
     */
    @Throws(Exception::class)
    suspend operator fun invoke(userId: String) {
        // 1. SavedCafe（「行きたい店」）を全削除
        val savedCafes = savedCafeRepository.observeAll(userId).first()
        for (savedCafe in savedCafes) {
            savedCafeRepository.delete(userId, savedCafe.cafe.placeId)
        }

        // 2. 現在の全 CoffeeRecord を 1 スナップショットで取得して個別削除
        //    （CoffeeRepositoryImpl が local + remote 両方を処理する）
        val records = coffeeRepository.observeAll(userId).first()
        for (record in records) {
            coffeeRepository.delete(userId, record.id)
        }

        // 3. Firestore users/{uid} ルートドキュメントの削除
        //    サブコレクション（1, 2）が消え切ってから呼ぶこと（カスケード削除されないため）
        authRepository.deleteUserProfile()

        // 4. Auth ユーザー本体の削除（ルートドキュメント削除より必ず後）
        //    写真ファイル（端末ローカル）の削除は iOS 側 PhotoFileStore が担うため、ここでは行わない
        authRepository.deleteAuthUser()
    }
}
