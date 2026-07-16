#!/usr/bin/env node
// Firestore `curatedCafes` への投入スクリプト（都道府県別おすすめカフェ）。
// ドキュメント ID = prefectureCode（JIS X 0401）で set() する冪等 upsert（再実行 = 上書き更新）。
// データ本体は generate-curated-cafes.mjs が出力し人手レビュー済みの curated-cafes.json。
//
// 使い方:
//   検証のみ:  node seed-curated-cafes.mjs --dry-run   （firebase-admin 不要）
//   本番投入:  GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json node seed-curated-cafes.mjs

import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const PREFECTURE_CODE_PATTERN = /^(0[1-9]|[1-3][0-9]|4[0-7])$/; // JIS X 0401 "01".."47"
const MAX_CAFES = 100; // 東京の上限（フェーズ 19 確定仕様。他県は生成側で 30 に絞る）
// 日本域内チェック（沖ノ鳥島〜択捉島をゆるくカバー）
const LAT_RANGE = [20, 46];
const LNG_RANGE = [122, 154];
const KNOWN_PREF_FIELDS = ["prefectureCode", "prefectureName", "cafes"];
const KNOWN_CAFE_FIELDS = ["placeId", "name", "latitude", "longitude"];

const dir = path.dirname(fileURLToPath(import.meta.url));
const prefectures = JSON.parse(await readFile(path.join(dir, "curated-cafes.json"), "utf8"));

const errors = [];
if (!Array.isArray(prefectures) || prefectures.length === 0) {
  errors.push("ルートは非空配列が必須");
}
const seenCodes = new Set();
(Array.isArray(prefectures) ? prefectures : []).forEach((pref, index) => {
  const where = `[${index}] ${pref.prefectureCode ?? "(コードなし)"}`;
  if (typeof pref.prefectureCode !== "string" || !PREFECTURE_CODE_PATTERN.test(pref.prefectureCode)) {
    errors.push(`${where}: prefectureCode は JIS X 0401 の 2 桁文字列（"01".."47"）が必須`);
  } else if (seenCodes.has(pref.prefectureCode)) {
    errors.push(`${where}: prefectureCode が重複`);
  } else {
    seenCodes.add(pref.prefectureCode);
  }
  if (typeof pref.prefectureName !== "string" || pref.prefectureName.trim() === "") {
    errors.push(`${where}: prefectureName は非空文字列が必須`);
  }
  for (const key of Object.keys(pref)) {
    if (!KNOWN_PREF_FIELDS.includes(key)) errors.push(`${where}: 未知のフィールド "${key}"`);
  }
  if (!Array.isArray(pref.cafes) || pref.cafes.length === 0 || pref.cafes.length > MAX_CAFES) {
    errors.push(`${where}: cafes は 1〜${MAX_CAFES} 件の配列が必須`);
    return;
  }
  const seenPlaceIds = new Set();
  pref.cafes.forEach((cafe, cafeIndex) => {
    const cafeWhere = `${where} cafes[${cafeIndex}] ${cafe.name ?? "(名前なし)"}`;
    if (typeof cafe.placeId !== "string" || cafe.placeId.trim() === "") {
      errors.push(`${cafeWhere}: placeId は非空文字列が必須`);
    } else if (seenPlaceIds.has(cafe.placeId)) {
      errors.push(`${cafeWhere}: placeId が県内で重複`);
    } else {
      seenPlaceIds.add(cafe.placeId);
    }
    if (typeof cafe.name !== "string" || cafe.name.trim() === "") {
      errors.push(`${cafeWhere}: name は非空文字列が必須`);
    }
    if (typeof cafe.latitude !== "number" || cafe.latitude < LAT_RANGE[0] || cafe.latitude > LAT_RANGE[1]) {
      errors.push(`${cafeWhere}: latitude は ${LAT_RANGE[0]}〜${LAT_RANGE[1]} の数値が必須`);
    }
    if (typeof cafe.longitude !== "number" || cafe.longitude < LNG_RANGE[0] || cafe.longitude > LNG_RANGE[1]) {
      errors.push(`${cafeWhere}: longitude は ${LNG_RANGE[0]}〜${LNG_RANGE[1]} の数値が必須`);
    }
    for (const key of Object.keys(cafe)) {
      if (!KNOWN_CAFE_FIELDS.includes(key)) errors.push(`${cafeWhere}: 未知のフィールド "${key}"`);
    }
  });
});

if (errors.length > 0) {
  console.error(`バリデーション失敗（${errors.length} 件）:`);
  for (const error of errors) console.error(`  - ${error}`);
  process.exit(1);
}
const totalCafes = prefectures.reduce((sum, pref) => sum + pref.cafes.length, 0);
console.log(`バリデーション OK: ${prefectures.length} 県 / ${totalCafes} 件`);

if (process.argv.includes("--dry-run")) {
  console.log("--dry-run のため投入はスキップ");
  process.exit(0);
}

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error("GOOGLE_APPLICATION_CREDENTIALS が未設定です（サービスアカウント鍵のパスを指定してください）");
  process.exit(1);
}

const { initializeApp, applicationDefault } = await import("firebase-admin/app");
const { getFirestore, FieldValue } = await import("firebase-admin/firestore");

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

// 47 件以下のため単一 batch で足りる
const batch = db.batch();
for (const pref of prefectures) {
  batch.set(db.collection("curatedCafes").doc(pref.prefectureCode), {
    prefectureCode: pref.prefectureCode,
    prefectureName: pref.prefectureName,
    cafes: pref.cafes,
    updatedAt: FieldValue.serverTimestamp(),
  });
}
await batch.commit();
console.log(`投入完了: curatedCafes に ${prefectures.length} 県 / ${totalCafes} 件を upsert`);
