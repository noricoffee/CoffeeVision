package com.noricoffee.repository

import app.cash.sqldelight.coroutines.asFlow
import app.cash.sqldelight.coroutines.mapToList
import app.cash.sqldelight.coroutines.mapToOneOrNull
import com.noricoffee.db.AppDatabase
import com.noricoffee.db.toDomain
import com.noricoffee.db.toRow
import com.noricoffee.domain.CoffeeRecord
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlin.coroutines.CoroutineContext

/**
 * SQLDelight を使った [CoffeeRepository] の純ローカル実装。
 *
 * - photos は [CoffeeRecord] とは別テーブルに保存し、[assembleRecord] で結合する
 * - save は `coffee_record` の upsert + `photo` の再挿入（削除→全挿入）で実現する
 * - delete は `coffee_record` を削除すると FOREIGN KEY (record_id) ON DELETE CASCADE で
 *   関連 photo も自動削除される
 * - cafe が null のレコード（セルフ抽出）も正常に扱う
 *
 * [com.noricoffee.repository.CoffeeRepositoryImpl] に [LocalCoffeeRepository] を
 * [CoffeeRepository] として注入し、remote との合成は [CoffeeRepositoryImpl] が担う。
 */
class LocalCoffeeRepository(
    private val db: AppDatabase,
    private val ioContext: CoroutineContext = Dispatchers.Default,
) : CoffeeRepository {

    override fun observeAll(userId: String): Flow<List<CoffeeRecord>> =
        db.coffeeRecordQueries.selectAll(userId)
            .asFlow()
            .mapToList(ioContext)
            .map { rows -> rows.map { assembleRecord(it) } }

    override fun observeById(id: String): Flow<CoffeeRecord?> =
        db.coffeeRecordQueries.selectById(id)
            .asFlow()
            .mapToOneOrNull(ioContext)
            .map { row -> row?.let { assembleRecord(it) } }

    override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> =
        db.coffeeRecordQueries.selectByCafe(userId, placeId)
            .asFlow()
            .mapToList(ioContext)
            .map { rows -> rows.map { assembleRecord(it) } }

    override suspend fun save(record: CoffeeRecord) {
        val row = record.toRow()
        db.transaction {
            db.coffeeRecordQueries.upsert(
                id = row.id,
                user_id = row.user_id,
                cafe_place_id = row.cafe_place_id,
                cafe_name = row.cafe_name,
                cafe_address = row.cafe_address,
                cafe_latitude = row.cafe_latitude,
                cafe_longitude = row.cafe_longitude,
                cafe_photo_references = row.cafe_photo_references,
                cafe_website_url = row.cafe_website_url,
                cafe_maps_url = row.cafe_maps_url,
                visited_on = row.visited_on,
                rating = row.rating,
                notes = row.notes,
                name = row.name,
                brew_method = row.brew_method,
                origin = row.origin,
                variety = row.variety,
                processing = row.processing,
                roast_level = row.roast_level,
                cup = row.cup,
                created_at = row.created_at,
                updated_at = row.updated_at,
            )

            // photos を再挿入（delete → insert で常に最新状態を保証）
            db.photoQueries.deleteByRecord(record.id)
            record.photos.forEachIndexed { index, photo ->
                val photoRow = photo.toRow(record.id, index)
                db.photoQueries.upsert(
                    id = photoRow.id,
                    record_id = photoRow.record_id,
                    file_name = photoRow.file_name,
                    local_path = photoRow.local_path,
                    remote_url = photoRow.remote_url,
                    width = photoRow.width,
                    height = photoRow.height,
                    created_at = photoRow.created_at,
                    sort_order = photoRow.sort_order,
                )
            }
        }
    }

    override suspend fun delete(userId: String, id: String) {
        // coffee_record を削除すると FOREIGN KEY ON DELETE CASCADE で photo も自動削除される
        db.coffeeRecordQueries.deleteById(id)
    }

    /**
     * [Coffee_record] 行と関連 [Photo] 行を結合して [CoffeeRecord] を組み立てる。
     *
     * N+1 が発生するが、observe は Flow の emit ごとに全件再組み立てするため
     * SQLDelight の設計上これが最もシンプルなパターン。
     */
    private fun assembleRecord(row: com.noricoffee.db.Coffee_record): CoffeeRecord {
        val photos = db.photoQueries.selectByRecord(row.id).executeAsList().map { it.toDomain() }
        return row.toDomain(photos = photos)
    }
}
