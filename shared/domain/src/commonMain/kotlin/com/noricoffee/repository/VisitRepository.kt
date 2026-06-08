package com.noricoffee.repository

import com.noricoffee.domain.Visit
import kotlinx.coroutines.flow.Flow

interface VisitRepository {
    fun observeAll(userId: String): Flow<List<Visit>>
    fun observeById(id: String): Flow<Visit?>
    fun observeByCafe(userId: String, placeId: String): Flow<List<Visit>>

    suspend fun save(visit: Visit)
    suspend fun delete(userId: String, id: String)
}
