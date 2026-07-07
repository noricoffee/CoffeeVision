package com.noricoffee.repository

import com.noricoffee.domain.model.SavedCafe
import kotlinx.coroutines.flow.Flow

/**
 * 「行きたい店」（ウィッシュリスト）の永続化 / 取得を担うリポジトリインターフェース。
 *
 * [CoffeeRepository] と同じ 2 段構成をそのまま踏襲する（[data-model.md] §4.3）。
 * UI から見える唯一の API。実装は [com.noricoffee.repository.SavedCafeRepositoryImpl] が
 * [LocalSavedCafeRepository]（SQLDelight）と [RemoteSavedCafeDataSource]（Firestore）を合成して提供する。
 *
 * - **読み取り**: SQLDelight の Flow を Single Source として返す
 * - **書き込み**: ローカル（SQLDelight）→ リモート（Firestore）の順で実施し、UI は即時更新する
 * - キーは `(userId, cafe.placeId)`。保存 = 上書き、解除 = 削除の冪等トグル
 */
interface SavedCafeRepository {

    /** 指定ユーザーの「行きたい店」全件を savedAt 降順で観測する（マップピン / 一覧シート用）。 */
    fun observeAll(userId: String): Flow<List<SavedCafe>>

    /** 指定カフェ（placeId）の保存状態を観測する。未保存の場合は null を emit する（カフェ詳細のトグル状態用）。 */
    fun observeByPlaceId(userId: String, placeId: String): Flow<SavedCafe?>

    /** 「行きたい店」を保存する（同一 placeId は上書き）。 */
    suspend fun save(savedCafe: SavedCafe)

    /** 「行きたい店」を解除する。 */
    suspend fun delete(userId: String, placeId: String)
}
