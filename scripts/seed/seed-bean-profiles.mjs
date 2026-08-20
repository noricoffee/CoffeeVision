#!/usr/bin/env node
// Firestore `beanProfiles` への初期データ投入スクリプト。
// ドキュメント ID = beanId で set() する冪等 upsert（再実行 = 上書き更新）。
//
// 使い方:
//   検証のみ:  node seed-bean-profiles.mjs --dry-run   （firebase-admin 不要）
//   本番投入:  GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json node seed-bean-profiles.mjs

import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

// shared/domain の ProcessingMethod enum 名と一致させること（Mapper が enum 名逆引きするため）
const PROCESSING_METHODS = ["Natural", "Washed", "Honey", "Anaerobic", "Other"];

// flavorNotes の統一語彙（正本は docs/data-model.md §3.2）。
// PreferredBeanTraitsUseCase の頻度集計が表記ゆれで割れないよう、語彙外の値は投入前に弾く。
const FLAVOR_VOCABULARY = [
  // フローラル
  "ジャスミン", "ローズ", "フローラル",
  // 柑橘
  "シトラス", "ベルガモット", "レモン", "オレンジ", "グレープフルーツ",
  // 果実
  "アップル", "洋梨", "ピーチ", "アプリコット", "チェリー", "ストロベリー",
  "ブルーベリー", "ラズベリー", "カシス", "ライチ", "マンゴー",
  "パッションフルーツ", "パイナップル", "トロピカルフルーツ", "レーズン", "プルーン",
  // 甘味
  "ハチミツ", "キャラメル", "ブラウンシュガー", "黒糖", "バニラ",
  "メープルシロップ", "チョコレート", "ダークチョコレート",
  // ナッツ
  "アーモンド", "ヘーゼルナッツ", "ナッツ",
  // スパイス・その他
  "シナモン", "スパイス", "紅茶", "ワイン", "ハーブ", "アーシー", "スモーキー",
];

const BEAN_ID_PATTERN = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const KNOWN_FIELDS = ["beanId", "name", "origin", "variety", "processings", "flavorNotes", "description"];

const dir = path.dirname(fileURLToPath(import.meta.url));
const profiles = JSON.parse(await readFile(path.join(dir, "bean-profiles.json"), "utf8"));

const errors = [];
const seenIds = new Set();
profiles.forEach((profile, index) => {
  const where = `[${index}] ${profile.beanId ?? "(beanId なし)"}`;
  for (const field of ["beanId", "name", "origin"]) {
    if (typeof profile[field] !== "string" || profile[field].trim() === "") {
      errors.push(`${where}: ${field} は非空文字列が必須`);
    }
  }
  if (typeof profile.beanId === "string") {
    if (!BEAN_ID_PATTERN.test(profile.beanId)) {
      errors.push(`${where}: beanId は ASCII kebab-case のみ`);
    }
    if (seenIds.has(profile.beanId)) {
      errors.push(`${where}: beanId が重複`);
    }
    seenIds.add(profile.beanId);
  }
  if (profile.variety !== null && (typeof profile.variety !== "string" || profile.variety.trim() === "")) {
    errors.push(`${where}: variety は非空文字列か null`);
  }
  if (!Array.isArray(profile.processings) || profile.processings.length === 0) {
    errors.push(`${where}: processings は非空配列が必須`);
  } else {
    for (const method of profile.processings) {
      if (!PROCESSING_METHODS.includes(method)) {
        errors.push(`${where}: processings "${method}" は ProcessingMethod enum 名ではない`);
      }
    }
  }
  if (!Array.isArray(profile.flavorNotes) || profile.flavorNotes.length === 0) {
    errors.push(`${where}: flavorNotes は非空配列が必須`);
  } else {
    for (const note of profile.flavorNotes) {
      if (!FLAVOR_VOCABULARY.includes(note)) {
        errors.push(`${where}: flavorNotes "${note}" は統一語彙にない`);
      }
    }
  }
  if (profile.description !== null && (typeof profile.description !== "string" || profile.description.trim() === "")) {
    errors.push(`${where}: description は非空文字列か null`);
  }
  for (const key of Object.keys(profile)) {
    if (!KNOWN_FIELDS.includes(key)) {
      errors.push(`${where}: 未知のフィールド "${key}"`);
    }
  }
});

if (errors.length > 0) {
  console.error(`バリデーション失敗（${errors.length} 件）:`);
  for (const error of errors) console.error(`  - ${error}`);
  process.exit(1);
}
console.log(`バリデーション OK: ${profiles.length} 件`);

if (process.argv.includes("--dry-run")) {
  console.log("--dry-run のため投入はスキップ");
  process.exit(0);
}

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error("GOOGLE_APPLICATION_CREDENTIALS が未設定です（サービスアカウント鍵のパスを指定してください）");
  process.exit(1);
}

const { initializeApp, applicationDefault } = await import("firebase-admin/app");
const { getFirestore } = await import("firebase-admin/firestore");

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

// 500 件未満のため単一 batch で足りる
const batch = db.batch();
for (const profile of profiles) {
  batch.set(db.collection("beanProfiles").doc(profile.beanId), profile);
}
await batch.commit();
console.log(`投入完了: beanProfiles に ${profiles.length} 件を upsert`);
