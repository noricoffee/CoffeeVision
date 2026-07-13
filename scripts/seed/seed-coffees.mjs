#!/usr/bin/env node
// アプリのエクスポート JSON（ExportCoffeeRecordsUseCase / envelope version 1）を
// Firestore `users/{uid}/coffees` へ投入する開発用スクリプト。
// ドキュメント ID = record.id で set() する冪等 upsert（再実行 = 上書き更新）。
//
// エクスポート JSON → Firestore ドキュメントの変換規則は CoffeeFirestoreMapper
// （docs/data-model.md §`users/{uid}/coffees`）に合わせる:
//   - null フィールドはキーごと省略（エクスポートは null キーも書き出すため投入時に落とす）
//   - createdAt / updatedAt は ISO-8601 文字列 → Firestore Timestamp（ミリ秒精度に切り詰め）
//   - photos は常に空配列（画像ファイルは端末ローカルのみで、メタデータだけ投入しても解決不能）
//   - userId は --uid で必ず上書き（別アカウントのエクスポートも自分の uid に付け替えて投入できる）
//
// 使い方:
//   検証のみ:  node seed-coffees.mjs --dry-run export.json   （firebase-admin 不要）
//   本番投入:  GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//              node seed-coffees.mjs --uid <firebase-auth-uid> export.json

import { readFile } from "node:fs/promises";

// shared/domain の enum 名と一致させること（CoffeeFirestoreMapper が enum 名逆引きするため）
const BREW_METHODS = ["Espresso", "HandDrip", "NelDrip", "FrenchPress", "AeroPress", "Syphon", "ColdBrew", "Other"];
const PROCESSING_METHODS = ["Natural", "Washed", "Honey", "Anaerobic", "Other"];
const ROAST_LEVELS = ["Light", "Cinnamon", "Medium", "High", "City", "FullCity", "French", "Italian"];

const TASTING_KEYS = ["sweetness", "body", "acidity", "flavor", "aftertaste"];
const VISITED_ON_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

// ─────────────────────────────────────────────────
// 引数処理
// ─────────────────────────────────────────────────

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const uidIndex = args.indexOf("--uid");
const uid = uidIndex !== -1 ? args[uidIndex + 1] : null;
const positional = args.filter(
  (a, i) => a !== "--dry-run" && a !== "--uid" && (uidIndex === -1 || i !== uidIndex + 1),
);

if (positional.length !== 1) {
  console.error("使い方: node seed-coffees.mjs [--dry-run] [--uid <firebase-auth-uid>] <export.json>");
  process.exit(1);
}
if (!dryRun && (typeof uid !== "string" || uid.trim() === "")) {
  console.error("投入には --uid <firebase-auth-uid> が必須です（--dry-run では省略可）");
  process.exit(1);
}

const envelope = JSON.parse(await readFile(positional[0], "utf8"));

// ─────────────────────────────────────────────────
// バリデーション（エクスポート envelope v1 の想定を機械的に確認）
// ─────────────────────────────────────────────────

const errors = [];

if (envelope.version !== 1) {
  errors.push(`envelope: version が 1 ではない（${envelope.version}）`);
}
if (!Array.isArray(envelope.records)) {
  errors.push("envelope: records が配列ではない");
}

const isNonEmptyString = (v) => typeof v === "string" && v.trim() !== "";
const isIsoInstant = (v) => typeof v === "string" && !Number.isNaN(Date.parse(v));

const seenIds = new Set();
for (const [index, record] of (envelope.records ?? []).entries()) {
  const where = `[${index}] ${record.id ?? "(id なし)"}`;

  for (const field of ["id", "name", "visitedOn", "brewMethod", "createdAt", "updatedAt"]) {
    if (!isNonEmptyString(record[field])) {
      errors.push(`${where}: ${field} は非空文字列が必須`);
    }
  }
  if (typeof record.notes !== "string") {
    errors.push(`${where}: notes は文字列が必須（空文字は可）`);
  }
  if (isNonEmptyString(record.id)) {
    if (seenIds.has(record.id)) errors.push(`${where}: id が重複`);
    seenIds.add(record.id);
  }
  if (isNonEmptyString(record.visitedOn) && !VISITED_ON_PATTERN.test(record.visitedOn)) {
    errors.push(`${where}: visitedOn は "YYYY-MM-DD" 形式`);
  }
  if (isNonEmptyString(record.brewMethod) && !BREW_METHODS.includes(record.brewMethod)) {
    errors.push(`${where}: brewMethod "${record.brewMethod}" は BrewMethod enum 名ではない`);
  }
  if (record.processing != null && !PROCESSING_METHODS.includes(record.processing)) {
    errors.push(`${where}: processing "${record.processing}" は ProcessingMethod enum 名ではない`);
  }
  if (record.roastLevel != null && !ROAST_LEVELS.includes(record.roastLevel)) {
    errors.push(`${where}: roastLevel "${record.roastLevel}" は RoastLevel enum 名ではない`);
  }
  if (record.rating != null && typeof record.rating !== "number") {
    errors.push(`${where}: rating は数値か null`);
  }
  for (const field of ["createdAt", "updatedAt"]) {
    if (isNonEmptyString(record[field]) && !isIsoInstant(record[field])) {
      errors.push(`${where}: ${field} が ISO-8601 としてパースできない`);
    }
  }
  if (record.tags != null && !Array.isArray(record.tags)) {
    errors.push(`${where}: tags は配列`);
  }
  if (record.cafe != null) {
    if (!isNonEmptyString(record.cafe.placeId)) errors.push(`${where}: cafe.placeId は非空文字列が必須`);
    if (!isNonEmptyString(record.cafe.name)) errors.push(`${where}: cafe.name は非空文字列が必須`);
  }
  // tasting は all-or-nothing（5 要素すべて整数）
  if (record.tasting != null) {
    for (const key of TASTING_KEYS) {
      if (!Number.isInteger(record.tasting[key])) {
        errors.push(`${where}: tasting.${key} は整数が必須（all-or-nothing）`);
      }
    }
  }
}

if (errors.length > 0) {
  console.error(`バリデーション失敗（${errors.length} 件）:`);
  for (const error of errors) console.error(`  - ${error}`);
  process.exit(1);
}
console.log(`バリデーション OK: ${envelope.records.length} 件`);

// ─────────────────────────────────────────────────
// エクスポート DTO → Firestore ドキュメント変換
// ─────────────────────────────────────────────────

// null / undefined の値を持つキーを落とす（Firestore 規約: nullable フィールドはキーごと省略）
const dropNullKeys = (obj) =>
  Object.fromEntries(Object.entries(obj).filter(([, v]) => v != null));

// toTimestamp: ISO-8601 文字列 → Firestore Timestamp（dry-run では文字列のまま表示用に通す）
function toDocument(record, userId, toTimestamp) {
  const doc = dropNullKeys({
    id: record.id,
    userId,
    visitedOn: record.visitedOn,
    notes: record.notes,
    name: record.name,
    brewMethod: record.brewMethod,
    rating: record.rating,
    origin: record.origin,
    variety: record.variety,
    processing: record.processing,
    roastLevel: record.roastLevel,
    cup: record.cup,
    brewRecipe: record.brewRecipe,
    tags: record.tags ?? [],
    // 画像ファイルは端末ローカルのみ。メタデータだけ投入しても fileName が解決できないため常に空
    photos: [],
    createdAt: toTimestamp(record.createdAt),
    updatedAt: toTimestamp(record.updatedAt),
  });
  if (record.cafe != null) {
    doc.cafe = dropNullKeys({
      placeId: record.cafe.placeId,
      name: record.cafe.name,
      address: record.cafe.address,
      latitude: record.cafe.latitude,
      longitude: record.cafe.longitude,
      photoReferences: record.cafe.photoReferences ?? [],
      websiteUrl: record.cafe.websiteUrl,
      mapsUrl: record.cafe.mapsUrl,
    });
  }
  if (record.tasting != null) {
    doc.tasting = {
      sweetness: record.tasting.sweetness,
      body: record.tasting.body,
      acidity: record.tasting.acidity,
      flavor: record.tasting.flavor,
      aftertaste: record.tasting.aftertaste,
    };
  }
  return doc;
}

if (dryRun) {
  const sample = envelope.records[0];
  if (sample != null) {
    console.log("変換サンプル（先頭 1 件、createdAt / updatedAt は投入時に Timestamp 化）:");
    console.log(JSON.stringify(toDocument(sample, uid ?? "(--uid で指定)", (iso) => iso), null, 2));
  }
  console.log("--dry-run のため投入はスキップ");
  process.exit(0);
}

// ─────────────────────────────────────────────────
// 投入
// ─────────────────────────────────────────────────

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error("GOOGLE_APPLICATION_CREDENTIALS が未設定です（サービスアカウント鍵のパスを指定してください）");
  process.exit(1);
}

const { initializeApp, applicationDefault } = await import("firebase-admin/app");
const { getFirestore, Timestamp } = await import("firebase-admin/firestore");

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

// kotlinx Instant.toString はナノ秒精度がありうるが、Date.parse でミリ秒に切り詰めて許容（dev 用途）
const toTimestamp = (iso) => Timestamp.fromDate(new Date(iso));

const coffeesRef = db.collection("users").doc(uid).collection("coffees");
const documents = envelope.records.map((record) => toDocument(record, uid, toTimestamp));

// Firestore の batch 上限 500 件ごとに分割
for (let start = 0; start < documents.length; start += 500) {
  const batch = db.batch();
  for (const doc of documents.slice(start, start + 500)) {
    batch.set(coffeesRef.doc(doc.id), doc);
  }
  await batch.commit();
}
console.log(`投入完了: users/${uid}/coffees に ${documents.length} 件を upsert`);
console.log("実機はサインイン中のリスナーが自動反映します（アプリ起動中なら即時、未起動なら次回起動時）");
