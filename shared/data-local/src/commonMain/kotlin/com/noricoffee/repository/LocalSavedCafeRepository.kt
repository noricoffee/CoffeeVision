package com.noricoffee.repository

import app.cash.sqldelight.coroutines.asFlow
import app.cash.sqldelight.coroutines.mapToList
import app.cash.sqldelight.coroutines.mapToOneOrNull
import com.noricoffee.db.AppDatabase
import com.noricoffee.db.toDomain
import com.noricoffee.db.toRow
import com.noricoffee.domain.model.SavedCafe
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlin.coroutines.CoroutineContext

/**
 * SQLDelight を使った [SavedCafeRepository] の純ローカル実装。
 *
 * [LocalCoffeeRepository] と同じ設計方針: キーは `(user_id, place_id)`。
 * `save` は upsert（同一 placeId は上書き）、`delete` は解除に対応する。
 *
 * [com.noricoffee.repository.SavedCafeRepositoryImpl] に [LocalSavedCafeRepository] を
 * [SavedCafeRepository] として注入し、remote との合成は [SavedCafeRepositoryImpl] が担う。
 */
class LocalSavedCafeRepository(
    private val db: AppDatabase,
    private val queryContext: CoroutineContext = Dispatchers.Default,
) : SavedCafeRepository {

    override fun observeAll(userId: String): Flow<List<SavedCafe>> =
        db.savedCafeQueries.selectAll(userId)
            .asFlow()
            .mapToList(queryContext)
            .map { rows -> rows.map { it.toDomain() } }

    override fun observeByPlaceId(userId: String, placeId: String): Flow<SavedCafe?> =
        db.savedCafeQueries.selectByPlaceId(userId, placeId)
            .asFlow()
            .mapToOneOrNull(queryContext)
            .map { row -> row?.toDomain() }

    override suspend fun save(savedCafe: SavedCafe) {
        val row = savedCafe.toRow()
        db.savedCafeQueries.upsert(
            place_id = row.place_id,
            user_id = row.user_id,
            cafe_name = row.cafe_name,
            cafe_address = row.cafe_address,
            cafe_latitude = row.cafe_latitude,
            cafe_longitude = row.cafe_longitude,
            cafe_photo_references = row.cafe_photo_references,
            cafe_photo_attributions = row.cafe_photo_attributions,
            cafe_website_url = row.cafe_website_url,
            cafe_maps_url = row.cafe_maps_url,
            note = row.note,
            saved_at = row.saved_at,
        )
    }

    override suspend fun delete(userId: String, placeId: String) {
        db.savedCafeQueries.deleteByPlaceId(userId, placeId)
    }
}
