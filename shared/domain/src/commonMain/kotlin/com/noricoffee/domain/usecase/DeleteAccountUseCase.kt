package com.noricoffee.domain.usecase

import com.noricoffee.repository.AuthRepository
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.first

/**
 * アカウント削除 UseCase。
 *
 * ## 処理の順序
 * 1. [CoffeeRepository.observeAll] で対象 uid の全 CoffeeRecord を 1 スナップショット取得
 * 2. 各 CoffeeRecord を [CoffeeRepository.delete] で個別削除（ローカル DB + Firestore 両方を処理する
 *    合成実装 [com.noricoffee.repository.CoffeeRepositoryImpl] が担う）
 * 3. 全削除完了後に [AuthRepository.deleteAuthUser] を呼んで Auth ユーザー本体を削除
 *
 * ## 写真ファイルの削除について
 * 写真ファイル（端末 Documents 内の PNG / JPEG）の削除は **iOS 側の責務**。
 * KMP 層は Firestore の coffees コレクション（photos 埋め込み配列メタデータのみ）を
 * ドキュメントとして削除するが、実ファイルの削除は `iosApp` の PhotoFileStore が担うため、
 * 本 UseCase では扱わない。
 *
 * ## bulk 削除の非採用について
 * [CoffeeRepository] に一括削除 API は現時点で存在しない。全件 `observeAll` → 個別 `delete` の
 * 方式で実装する。件数が多い場合は N+1 的なコストが発生するが、アカウント削除は
 * 稀頻度の操作であるため許容する。
 *
 * @param coffeeRepository CoffeeRecord の取得・削除を担うリポジトリ
 * @param authRepository Auth ユーザー削除を担うリポジトリ
 */
class DeleteAccountUseCase(
    private val coffeeRepository: CoffeeRepository,
    private val authRepository: AuthRepository,
) {

    /**
     * 指定ユーザーの全 CoffeeRecord を削除してから Auth ユーザーを削除する。
     *
     * 途中で例外が発生した場合はそのまま上位（ViewModel の [kotlinx.coroutines.runCatching]）へ
     * 伝播させる。
     *
     * @param userId 削除対象ユーザーの uid
     */
    @Throws(Exception::class)
    suspend operator fun invoke(userId: String) {
        // 1. 現在の全 CoffeeRecord を 1 スナップショットで取得
        val records = coffeeRepository.observeAll(userId).first()

        // 2. 個別削除（CoffeeRepositoryImpl が local + remote 両方を処理する）
        for (record in records) {
            coffeeRepository.delete(userId, record.id)
        }

        // 3. Auth ユーザー本体の削除
        //    写真ファイル（端末ローカル）の削除は iOS 側 PhotoFileStore が担うため、ここでは行わない
        authRepository.deleteAuthUser()
    }
}
