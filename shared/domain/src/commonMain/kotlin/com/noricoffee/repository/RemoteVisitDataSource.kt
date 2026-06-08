package com.noricoffee.repository

import com.noricoffee.domain.Visit
import kotlinx.coroutines.flow.Flow

/**
 * Firestore（または同等のリモート KVS）への薄いアダプタ。
 *
 * - `commonMain` には interface のみを置き、実装は各プラットフォームの公式 SDK で行う
 *   （iOS は `iosApp/FirebaseRepositories/`、Android は `shared/data-firebase/androidMain`）
 * - 本データソースは UI から **直接参照されない**。`VisitRepositoryImpl` が
 *   `LocalVisitRepository` と本データソースを合成して、UI には [VisitRepository] 1 本だけを見せる
 *
 * ## 設計方針
 *
 * - [observeChanges] は Firestore リスナを `Flow` として公開する。`VisitRepositoryImpl` が
 *   それを購読し、ローカル DB に upsert することでローカル DB を Single Source of Truth として保つ
 * - [upload] / [remove] は **書き込み順序を「ローカル → リモート」に保つために**
 *   `VisitRepositoryImpl` から **ローカル書き込み成功後に** 呼ばれる契約とする
 * - リモートのリトライ・オフラインキューイングは各プラットフォームの Firestore SDK の
 *   オフライン永続化に委ね、本層では独自キューを持たない
 *   （[docs/architecture.md](../../../../../docs/architecture.md) §永続化方針 参照）
 *
 * 失敗時は例外を投げる（Kotlin 流儀。Swift 側は `NSError` として受け取れる）。
 */
interface RemoteVisitDataSource {

    /**
     * リモート側の変更を観測する。
     *
     * - 各要素は **指定 userId の全 Visit のスナップショット**（差分ではなく全体）を返す
     * - `VisitRepositoryImpl` はこの Flow を購読してローカル DB を更新する
     * - サインアウト等で購読が無効になったら、購読側スコープのキャンセルに任せる
     */
    fun observeChanges(userId: String): Flow<List<Visit>>

    /**
     * Visit をリモートに書き込む（作成・更新の両方）。
     *
     * 呼び出し前提: `VisitRepositoryImpl` が既にローカル DB への upsert を成功させていること。
     */
    @Throws(Exception::class)
    suspend fun upload(visit: Visit)

    /**
     * Visit をリモートから削除する。
     *
     * 呼び出し前提: `VisitRepositoryImpl` が既にローカル DB からの削除を成功させていること。
     */
    @Throws(Exception::class)
    suspend fun remove(userId: String, id: String)
}
