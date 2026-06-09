package com.noricoffee.repository

import app.cash.sqldelight.coroutines.asFlow
import app.cash.sqldelight.coroutines.mapToList
import app.cash.sqldelight.coroutines.mapToOneOrNull
import com.noricoffee.db.AppDatabase
import com.noricoffee.db.toDomain
import com.noricoffee.db.toRow
import com.noricoffee.domain.Visit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlin.coroutines.CoroutineContext

class LocalVisitRepository(
    private val db: AppDatabase,
    private val ioContext: CoroutineContext = Dispatchers.Default,
) : VisitRepository {

    override fun observeAll(userId: String): Flow<List<Visit>> =
        db.visitQueries.selectAll(userId)
            .asFlow()
            .mapToList(ioContext)
            .map { rows -> rows.map { assembleVisit(it) } }

    override fun observeById(id: String): Flow<Visit?> =
        db.visitQueries.selectById(id)
            .asFlow()
            .mapToOneOrNull(ioContext)
            .map { row -> row?.let { assembleVisit(it) } }

    override fun observeByCafe(userId: String, placeId: String): Flow<List<Visit>> =
        db.visitQueries.selectByCafe(userId, placeId)
            .asFlow()
            .mapToList(ioContext)
            .map { rows -> rows.map { assembleVisit(it) } }

    override suspend fun save(visit: Visit) {
        val visitRow = visit.toRow()
        db.transaction {
            db.visitQueries.upsert(
                id = visitRow.id,
                user_id = visitRow.user_id,
                cafe_place_id = visitRow.cafe_place_id,
                cafe_name = visitRow.cafe_name,
                cafe_address = visitRow.cafe_address,
                cafe_latitude = visitRow.cafe_latitude,
                cafe_longitude = visitRow.cafe_longitude,
                cafe_photo_references = visitRow.cafe_photo_references,
                cafe_website_url = visitRow.cafe_website_url,
                cafe_maps_url = visitRow.cafe_maps_url,
                visited_on = visitRow.visited_on,
                ambiance = visitRow.ambiance,
                rating = visitRow.rating,
                notes = visitRow.notes,
                created_at = visitRow.created_at,
                updated_at = visitRow.updated_at,
            )

            db.coffeeItemQueries.deleteByVisit(visit.id)
            visit.coffees.forEachIndexed { index, coffee ->
                val row = coffee.toRow(visit.id, index)
                db.coffeeItemQueries.upsert(
                    id = row.id,
                    visit_id = row.visit_id,
                    name = row.name,
                    brew_method = row.brew_method,
                    origin = row.origin,
                    variety = row.variety,
                    processing = row.processing,
                    roast_level = row.roast_level,
                    cup = row.cup,
                    rating = row.rating,
                    notes = row.notes,
                    sort_order = row.sort_order,
                )
            }

            db.foodItemQueries.deleteByVisit(visit.id)
            visit.foods.forEachIndexed { index, food ->
                val row = food.toRow(visit.id, index)
                db.foodItemQueries.upsert(
                    id = row.id,
                    visit_id = row.visit_id,
                    name = row.name,
                    rating = row.rating,
                    notes = row.notes,
                    sort_order = row.sort_order,
                )
            }

            db.photoQueries.deleteByVisit(visit.id)
            visit.photos.forEachIndexed { index, photo ->
                val row = photo.toRow(visit.id, index)
                db.photoQueries.upsert(
                    id = row.id,
                    visit_id = row.visit_id,
                    file_name = row.file_name,
                    local_path = row.local_path,
                    remote_url = row.remote_url,
                    width = row.width,
                    height = row.height,
                    created_at = row.created_at,
                    sort_order = row.sort_order,
                )
            }
        }
    }

    override suspend fun delete(userId: String, id: String) {
        // userId は SQLDelight 側で行レベルセキュリティを将来追加する際に使う想定。
        // 現状は id のみで削除する。
        db.transaction {
            db.coffeeItemQueries.deleteByVisit(id)
            db.foodItemQueries.deleteByVisit(id)
            db.photoQueries.deleteByVisit(id)
            db.visitQueries.deleteById(id)
        }
    }

    private fun assembleVisit(row: com.noricoffee.db.Visit): Visit {
        val coffees = db.coffeeItemQueries.selectByVisit(row.id).executeAsList().map { it.toDomain() }
        val foods = db.foodItemQueries.selectByVisit(row.id).executeAsList().map { it.toDomain() }
        val photos = db.photoQueries.selectByVisit(row.id).executeAsList().map { it.toDomain() }
        return row.toDomain(coffees = coffees, foods = foods, photos = photos)
    }
}
