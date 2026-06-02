package com.noricoffee.domain

import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

data class Visit(
    val id: String,
    val userId: String,
    val cafe: Cafe,
    val visitedOn: LocalDate,
    val ambiance: String,
    val rating: Int,
    val notes: String,
    val photos: List<Photo>,
    val coffees: List<CoffeeItem>,
    val foods: List<FoodItem>,
    val createdAt: Instant,
    val updatedAt: Instant,
)
