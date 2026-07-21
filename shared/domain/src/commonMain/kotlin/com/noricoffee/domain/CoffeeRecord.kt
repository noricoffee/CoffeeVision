package com.noricoffee.domain

import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

data class CoffeeRecord(
    val id: String,                       // UUID v4
    val userId: String,                   // Firebase Auth uid
    val cafe: Cafe?,                      // Places 由来のスナップショット。null = セルフ抽出（自宅等）
    val visitedOn: LocalDate,             // 飲んだ日
    val rating: Double?,                   // 0.5..5.0（0.5 刻み）。null = 未評価（2026-07-12 B-4 で 0.0 sentinel を廃止）
    val notes: String,                    // 自由メモ（旧 ambiance / フード等もここに吸収）
    val photos: List<Photo>,
    // --- コーヒー属性（旧 CoffeeItem から昇格）---
    val name: String,                     // コーヒー名（必須）
    val brewMethod: BrewMethod,
    val origin: String?,                  // 産地（国名）。ドロップダウン選択（CoffeeOriginCatalog）。「ブレンド」/「その他で入力した国名」も可。null = 未選択。2026-07-22 に自由入力 → 国ドロップダウン化
    val region: String?,                  // エリア / 農園（任意自由入力。例「イルガチェフェ」「ウエウエテナンゴ」）。origin から分離（2026-07-22 追加）。表示専用で分析には使わない
    val variety: String?,                 // 品種
    val processing: ProcessingMethod?,    // 精製方法
    val roastLevel: RoastLevel?,          // 焙煎度
    val cup: String?,                     // カップの種類 / ブランドメモ
    val brewRecipe: String?,              // 抽出レシピ（豆量 / 湯量 / 湯温 / 時間などの自由メモ）。フェーズ 15-E 追加。セルフ抽出向け
    val tasting: TastingScores?,           // テイスティング 5 要素。null = 未記入。記入する場合は 5 要素すべて必須（all-or-nothing）
    val tags: List<String> = emptyList(),  // ユーザー定義タグ（例: "ラテアート", "浅煎り"）
    // --- メタ ---
    val createdAt: Instant,
    val updatedAt: Instant,
)
