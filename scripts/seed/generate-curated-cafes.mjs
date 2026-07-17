#!/usr/bin/env node
// 都道府県別おすすめカフェ候補の生成スクリプト（curated-cafes.json を出力）。
//
// Places API (New) v1 の Text Search でエリアごとに候補を集め、評価上位を抽出する。
// 出力 JSON には placeId / name / 座標のみを保存する（評価・レビュー数は選別にのみ使用し
// 保存しない — Places 規約対応。詳細はアプリ側がピンタップ時に getDetails で解決する）。
//
// 出力後は必ず人手で JSON をレビューしてから seed-curated-cafes.mjs で投入する（2 段構成）。
//
// 使い方:
//   PLACES_API_KEY=... node generate-curated-cafes.mjs --prefectures 13
//   PLACES_API_KEY=... node generate-curated-cafes.mjs --prefectures 13,27 --min-rating 4.3 --min-reviews 50
//
// コスト注意: Text Search（Pro SKU）を「2 クエリ × subAreas 数」回呼ぶ。東京（16 エリア）で約 32 回。

import { writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

// JIS X 0401 都道府県コード表。subAreas は検索カバレッジ用の主要エリア（省略時は県名 1 エリア）。
// maxCafes は県ごとの上限（東京はカフェが多いため 100、他県は 30 — フェーズ 19 確定仕様）。
const PREFECTURES = [
  { code: "01", name: "北海道" },
  { code: "02", name: "青森県" },
  { code: "03", name: "岩手県" },
  { code: "04", name: "宮城県" },
  { code: "05", name: "秋田県" },
  { code: "06", name: "山形県" },
  { code: "07", name: "福島県" },
  { code: "08", name: "茨城県" },
  { code: "09", name: "栃木県" },
  { code: "10", name: "群馬県" },
  { code: "11", name: "埼玉県" },
  { code: "12", name: "千葉県" },
  {
    code: "13",
    name: "東京都",
    maxCafes: 100,
    subAreas: [
      "渋谷", "新宿", "清澄白河", "蔵前", "吉祥寺", "銀座", "下北沢",
      "中目黒", "表参道", "神保町", "谷中", "自由が丘", "高円寺", "立川",
      "池袋", "代々木",
    ],
  },
  { code: "14", name: "神奈川県" },
  { code: "15", name: "新潟県" },
  { code: "16", name: "富山県" },
  { code: "17", name: "石川県" },
  { code: "18", name: "福井県" },
  { code: "19", name: "山梨県" },
  { code: "20", name: "長野県" },
  { code: "21", name: "岐阜県" },
  { code: "22", name: "静岡県" },
  { code: "23", name: "愛知県" },
  { code: "24", name: "三重県" },
  { code: "25", name: "滋賀県" },
  { code: "26", name: "京都府" },
  { code: "27", name: "大阪府" },
  { code: "28", name: "兵庫県" },
  { code: "29", name: "奈良県" },
  { code: "30", name: "和歌山県" },
  { code: "31", name: "鳥取県" },
  { code: "32", name: "島根県" },
  { code: "33", name: "岡山県" },
  { code: "34", name: "広島県" },
  { code: "35", name: "山口県" },
  { code: "36", name: "徳島県" },
  { code: "37", name: "香川県" },
  { code: "38", name: "愛媛県" },
  { code: "39", name: "高知県" },
  { code: "40", name: "福岡県" },
  { code: "41", name: "佐賀県" },
  { code: "42", name: "長崎県" },
  { code: "43", name: "熊本県" },
  { code: "44", name: "大分県" },
  { code: "45", name: "宮崎県" },
  { code: "46", name: "鹿児島県" },
  { code: "47", name: "沖縄県" },
];

const DEFAULT_MAX_CAFES = 30;
const DEFAULT_MIN_RATING = 4.4;
const DEFAULT_MIN_REVIEWS = 100;

// 評価・レビュー数は選別にのみ使い、出力には含めない（Places 規約対応）
const FIELD_MASK = [
  "places.id",
  "places.displayName",
  "places.location",
  "places.types",
  "places.formattedAddress",
  "places.rating",
  "places.userRatingCount",
].join(",");

function parseArgs(argv) {
  const args = { minRating: DEFAULT_MIN_RATING, minReviews: DEFAULT_MIN_REVIEWS, prefectures: null };
  for (let i = 2; i < argv.length; i++) {
    switch (argv[i]) {
      case "--prefectures":
        args.prefectures = (argv[++i] ?? "").split(",").map((code) => code.trim()).filter(Boolean);
        break;
      case "--min-rating":
        args.minRating = Number(argv[++i]);
        break;
      case "--min-reviews":
        args.minReviews = Number(argv[++i]);
        break;
      default:
        console.error(`未知の引数: ${argv[i]}`);
        process.exit(1);
    }
  }
  return args;
}

const args = parseArgs(process.argv);
if (!args.prefectures || args.prefectures.length === 0) {
  console.error("--prefectures <JIS コード（カンマ区切り）> を指定してください（例: --prefectures 13,27）");
  process.exit(1);
}
if (!Number.isFinite(args.minRating) || !Number.isFinite(args.minReviews)) {
  console.error("--min-rating / --min-reviews は数値で指定してください");
  process.exit(1);
}
const targets = args.prefectures.map((code) => {
  const pref = PREFECTURES.find((entry) => entry.code === code);
  if (!pref) {
    console.error(`未知の都道府県コード: ${code}`);
    process.exit(1);
  }
  return pref;
});

const apiKey = process.env.PLACES_API_KEY;
if (!apiKey) {
  console.error("PLACES_API_KEY が未設定です");
  process.exit(1);
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function searchText(query) {
  const response = await fetch("https://places.googleapis.com/v1/places:searchText", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": apiKey,
      "X-Goog-FieldMask": FIELD_MASK,
    },
    body: JSON.stringify({
      textQuery: query,
      languageCode: "ja",
      maxResultCount: 20,
      // cafe タイプはシーシャラウンジ・猫カフェ等も含む広いカテゴリのため、
      // コーヒー主体の coffee_shop（Google マップ表記「コーヒーショップ」）に厳格に絞る
      includedType: "coffee_shop",
      strictTypeFiltering: true,
    }),
  });
  if (!response.ok) {
    throw new Error(`searchText 失敗 (${response.status}): ${await response.text()}`);
  }
  const body = await response.json();
  return body.places ?? [];
}

const REQUIRED_TYPE = "coffee_shop";
// タイプ誤登録の店がすり抜けたときの保険（名前ベースの除外）
const EXCLUDED_NAME_KEYWORDS = ["シーシャ", "shisha", "hookah", "保護猫", "猫カフェ"];

const output = [];
for (const pref of targets) {
  const subAreas = pref.subAreas ?? [pref.name];
  const maxCafes = pref.maxCafes ?? DEFAULT_MAX_CAFES;
  const candidates = new Map(); // placeId -> place

  for (const area of subAreas) {
    for (const query of [`スペシャルティコーヒー ${area}`, `コーヒーショップ ${area}`]) {
      console.log(`検索: ${query}`);
      const places = await searchText(query);
      for (const place of places) {
        if (place.id && !candidates.has(place.id)) candidates.set(place.id, place);
      }
      await sleep(200); // レート制御
    }
  }

  const selected = [...candidates.values()]
    .filter((place) => {
      const types = place.types ?? [];
      if (!types.includes(REQUIRED_TYPE)) return false; // coffee_shop 以外（カフェ全般・ホテル等）を除外
      const lowerName = (place.displayName?.text ?? "").toLowerCase();
      if (EXCLUDED_NAME_KEYWORDS.some((keyword) => lowerName.includes(keyword.toLowerCase()))) return false;
      if ((place.rating ?? 0) < args.minRating) return false;
      if ((place.userRatingCount ?? 0) < args.minReviews) return false;
      if (!(place.formattedAddress ?? "").includes(pref.name)) return false; // 県外を除外
      const lat = place.location?.latitude;
      const lng = place.location?.longitude;
      return typeof lat === "number" && typeof lng === "number";
    })
    .sort((a, b) => (b.rating - a.rating) || (b.userRatingCount - a.userRatingCount))
    .slice(0, maxCafes);

  console.log(`${pref.name}: 候補 ${candidates.size} 件 → 採用 ${selected.length} 件（上限 ${maxCafes}）`);
  output.push({
    prefectureCode: pref.code,
    prefectureName: pref.name,
    cafes: selected.map((place) => ({
      placeId: place.id,
      name: place.displayName?.text ?? "",
      latitude: place.location.latitude,
      longitude: place.location.longitude,
    })),
  });
}

const dir = path.dirname(fileURLToPath(import.meta.url));
const outPath = path.join(dir, "curated-cafes.json");
await writeFile(outPath, `${JSON.stringify(output, null, 2)}\n`, "utf8");
console.log(`出力完了: ${outPath}`);
console.log("次の手順: JSON を目視レビューして不適切な候補を削除 → node seed-curated-cafes.mjs --dry-run で検証 → 投入");
