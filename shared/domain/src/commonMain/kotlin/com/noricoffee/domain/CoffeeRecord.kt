package com.noricoffee.domain

import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

data class CoffeeRecord(
    val id: String,                       // UUID v4
    val userId: String,                   // Firebase Auth uid
    val cafe: Cafe?,                      // Places 由来のスナップショット。null = セルフ抽出（自宅等）
    val visitedOn: LocalDate,             // 飲んだ日
    val rating: Double,                    // 0.5..5.0（0.5 刻み）。0.0 = 未評価（sentinel）
    val notes: String,                    // 自由メモ（旧 ambiance / フード等もここに吸収）
    val photos: List<Photo>,
    // --- コーヒー属性（旧 CoffeeItem から昇格）---
    val name: String,                     // コーヒー名（必須）
    val brewMethod: BrewMethod,
    val origin: String?,                  // 産地（国 / エリア）
    val variety: String?,                 // 品種
    val processing: ProcessingMethod?,    // 精製方法
    val roastLevel: RoastLevel?,          // 焙煎度
    val cup: String?,                     // カップの種類 / ブランドメモ
    val tasting: TastingScores,           // テイスティング 5 要素（甘味/ボディ/酸味/風味/後味）。各要素は任意
    // --- メタ ---
    val createdAt: Instant,
    val updatedAt: Instant,
)
