package com.noricoffee.domain

data class CoffeeItem(
    val id: String,
    val name: String,
    val brewMethod: BrewMethod,
    val origin: String?,
    val variety: String?,
    val processing: ProcessingMethod?,
    val roastLevel: RoastLevel?,
    val cup: String?,
    val rating: Int,
    val notes: String?,
)
