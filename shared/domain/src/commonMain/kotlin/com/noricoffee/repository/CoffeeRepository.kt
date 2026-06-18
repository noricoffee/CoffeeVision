package com.noricoffee.repository

import com.noricoffee.domain.CoffeeRecord
import kotlinx.coroutines.flow.Flow

/**
 * コーヒー記録の永続化 / 取得を担うリポジトリインターフェース。
 *
 * UI から見える唯一の API。実装は [com.noricoffee.repository.CoffeeRepositoryImpl] が
 * [LocalCoffeeRepository]（SQLDelight）と [RemoteCoffeeDataSource]（Firestore）を合成して提供する。
 *
 * - **読み取り**: SQLDelight の Flow を Single Source として返す
 * - **書き込み**: ローカル（SQLDelight）→ リモート（Firestore）の順で実施し、UI は即時更新する
 * - [cafe] が null のレコード（セルフ抽出）も正常に扱う
 */
interface CoffeeRepository {

    /** 指定ユーザーの全コーヒー記録を visitedOn 降順で観測する。 */
    fun observeAll(userId: String): Flow<List<CoffeeRecord>>

    /** 指定 ID のコーヒー記録を観測する。削除済みの場合は null を emit する。 */
    fun observeById(id: String): Flow<CoffeeRecord?>

    /**
     * 指定カフェ（placeId）のコーヒー記録を観測する。
     * cafe が null のレコード（セルフ抽出）はこのクエリに含まれない（意図通り）。
     */
    fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>>

    /** コーヒー記録を保存する（新規・更新 共通）。 */
    suspend fun save(record: CoffeeRecord)

    /** コーヒー記録を削除する。 */
    suspend fun delete(userId: String, id: String)
}
