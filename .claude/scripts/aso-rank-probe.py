#!/usr/bin/env python3
"""App Store 検索での CoffeeVision の見え方を定点観測する。

iTunes Search API を語ごとに叩き、①総ヒット件数 ②CoffeeVision の順位
③上位 5 件の評価数中央値（= 競合の厚み）を出す。

⚠ **iTunes Search API のランキングは App Store アプリ内の検索結果とは別アルゴリズム**。
   ここでの順位は「インデックスされているか」「競合がどれくらい厚いか」の目安であり、
   実際の検索順位の正本ではない。doc に順位を事実として書かないこと。

使い方:
    python3 .claude/scripts/aso-rank-probe.py                    # 計測して表示
    python3 .claude/scripts/aso-rank-probe.py --save out.json    # 結果を保存
    python3 .claude/scripts/aso-rank-probe.py --compare base.json  # 前回との差分
"""

import argparse
import json
import statistics
import sys
import time
import urllib.parse
import urllib.request

APP_ID = 6788339362
ENDPOINT = "https://itunes.apple.com/search?term={term}&country=jp&entity=software&limit=100&lang=ja_jp"

# 定点観測する語。ベースライン（2026-08-31）との比較を成立させるため、
# 語の削除・改名はしない（追加のみ）。
TERMS = [
    # 主要な検索意図（2026-08-31 時点で全滅）
    "コーヒー記録", "コーヒー 記録", "カフェ 記録", "カフェ 記録 アプリ",
    "コーヒー ノート", "テイスティング", "テイスティングノート", "カフェ巡り",
    "コーヒー", "カフェ", "焙煎", "コーヒー豆 管理", "コーヒーログ", "カフェ ノート",
    # 順位が付いていた語
    "コーヒー 好み", "コーヒーマップ", "シングルオリジン", "喫茶 記録",
    "コーヒー テイスティング", "カフェ 手帳", "コーヒー手帳", "コーヒー 日記",
    "珈琲 記録", "ハンドドリップ", "スペシャルティコーヒー",
    # 候補として監視する語
    "カフェ 日記", "コーヒー レビュー", "行きたいカフェ", "喫茶店 記録",
    "コーヒー 管理", "抽出 記録", "味覚 記録", "カフェ 保存", "コーヒー 好み 分析",
]


def fetch(term):
    url = ENDPOINT.format(term=urllib.parse.quote(term))
    raw = urllib.request.urlopen(url, timeout=30).read().decode("utf-8")
    # 一部アプリの description に生の制御文字が混ざるため strict=False
    return json.loads(raw, strict=False)


def probe(terms):
    rows = []
    for term in terms:
        try:
            data = fetch(term)
        except Exception as exc:  # noqa: BLE001 — 1 語の失敗で全体を止めない
            print(f"  ! {term}: {exc}", file=sys.stderr)
            continue
        results = data["results"]
        rank = next((i for i, a in enumerate(results, 1) if a.get("trackId") == APP_ID), None)
        ratings = [a.get("userRatingCount", 0) for a in results[:5]]
        rows.append({
            "term": term,
            "total": data["resultCount"],
            "rank": rank,
            "rival_ratings_median": int(statistics.median(ratings)) if ratings else 0,
            "top3": [a["trackName"] for a in results[:3]],
        })
        time.sleep(0.3)
    return rows


def lookup_self():
    url = f"https://itunes.apple.com/lookup?id={APP_ID}&country=jp&lang=ja_jp"
    raw = urllib.request.urlopen(url, timeout=30).read().decode("utf-8")
    app = json.loads(raw, strict=False)["results"][0]
    return {k: app.get(k) for k in
            ("trackName", "version", "currentVersionReleaseDate", "releaseDate",
             "userRatingCount", "averageUserRating")}


def render(rows, self_info, baseline=None):
    base = {r["term"]: r for r in baseline["rows"]} if baseline else {}
    print(f"アプリ名 : {self_info['trackName']}")
    print(f"バージョン: {self_info['version']}  評価 {self_info['userRatingCount']} 件"
          f" / {self_info['averageUserRating']}")
    if baseline:
        print(f"比較対象 : {baseline['measured_at']}（評価 {baseline['self']['userRatingCount']} 件）")
    print()
    header = f"{'語':<24}{'件数':>5}{'順位':>7}{'競合評価数':>8}"
    print(header + ("   前回比" if baseline else ""))
    print("-" * (len(header) + (8 if baseline else 0)))
    for r in sorted(rows, key=lambda x: (x["rank"] is None, x["rank"] or 0)):
        rank = str(r["rank"]) if r["rank"] else "圏外"
        line = f"{r['term']:<24}{r['total']:>5}{rank:>7}{r['rival_ratings_median']:>8}"
        if baseline and r["term"] in base:
            old = base[r["term"]]["rank"]
            new = r["rank"]
            if old == new:
                line += "     ―"
            elif old is None:
                line += f"   NEW ({new}位)"
            elif new is None:
                line += f"   ↓ 圏外へ ({old}位)"
            else:
                line += f"   {'↑' if new < old else '↓'} {old}→{new}"
        print(line)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--save", metavar="FILE", help="結果を JSON で保存")
    parser.add_argument("--compare", metavar="FILE", help="保存済み JSON との差分を表示")
    args = parser.parse_args()

    baseline = None
    if args.compare:
        with open(args.compare, encoding="utf-8") as fh:
            baseline = json.load(fh)

    self_info = lookup_self()
    rows = probe(TERMS)
    render(rows, self_info, baseline)

    if args.save:
        payload = {
            "measured_at": time.strftime("%Y-%m-%d"),
            "self": self_info,
            "rows": rows,
        }
        with open(args.save, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=2)
        print(f"\n保存: {args.save}")


if __name__ == "__main__":
    main()
