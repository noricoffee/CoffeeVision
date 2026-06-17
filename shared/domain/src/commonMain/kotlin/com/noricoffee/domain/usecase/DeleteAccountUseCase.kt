package com.noricoffee.domain.usecase

import com.noricoffee.repository.AuthRepository
import com.noricoffee.repository.VisitRepository
import kotlinx.coroutines.flow.first

/**
 * アカウント削除 UseCase。
 *
 * ## 処理の順序
 * 1. [VisitRepository.observeAll] で対象 uid の全 Visit を 1 スナップショット取得
 * 2. 各 Visit を [VisitRepository.delete] で個別削除（ローカル DB + Firestore 両方を処理する
 *    既存の合成実装 [com.noricoffee.repository.VisitRepositoryImpl] が担う）
 * 3. 全削除完了後に [AuthRepository.deleteAuthUser] を呼んで Auth ユーザー本体を削除
 *
 * ## 写真ファイルの削除について
 * 写真ファイル（端末 Documents 内の PNG / JPEG）の削除は **iOS 側の責務**。
 * KMP 層は Firestore の photos サブコレクション（メタデータのみ）を Firestore ドキュメントとして
 * 削除するが、実ファイルの削除は `iosApp` の PhotoFileStore が担うため、本 UseCase では扱わない。
 *
 * ## bulk 削除の非採用について
 * [VisitRepository] に一括削除 API は現時点で存在しない。全件 `observeAll` → 個別 `delete` の
 * 方式で実装する。Visit 件数が多い場合は N+1 的なコストが発生するが、アカウント削除は
 * 稀頻度の操作であるため許容する（将来 bulk 削除 API が追加された場合はここを差し替える）。
 *
 * @param visitRepository Visit の取得・削除を担うリポジトリ
 * @param authRepository Auth ユーザー削除を担うリポジトリ
 */
class DeleteAccountUseCase(
    private val visitRepository: VisitRepository,
    private val authRepository: AuthRepository,
) {

    /**
     * 指定ユーザーの全 Visit を削除してから Auth ユーザーを削除する。
     *
     * 途中で例外が発生した場合はそのまま上位（ViewModel の [kotlinx.coroutines.runCatching]）へ
     * 伝播させる。
     *
     * @param userId 削除対象ユーザーの uid
     */
    @Throws(Exception::class)
    suspend operator fun invoke(userId: String) {
        // 1. 現在の全 Visit を 1 スナップショットで取得
        val visits = visitRepository.observeAll(userId).first()

        // 2. 個別削除（VisitRepositoryImpl が local + remote 両方を処理する）
        for (visit in visits) {
            visitRepository.delete(userId, visit.id)
        }

        // 3. Auth ユーザー本体の削除
        //    写真ファイル（端末ローカル）の削除は iOS 側 PhotoFileStore が担うため、ここでは行わない
        authRepository.deleteAuthUser()
    }
}
