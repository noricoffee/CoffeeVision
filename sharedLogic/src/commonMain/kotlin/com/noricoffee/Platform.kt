package com.noricoffee

interface Platform {
    val name: String
}

expect fun getPlatform(): Platform