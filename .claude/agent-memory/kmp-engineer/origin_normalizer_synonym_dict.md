---
name: origin-normalizer-synonym-dict
description: 産地シノニム正規化 OriginNormalizer 導入時の横断置換箇所と、辞書完全一致方式が壊す既存テストの見つけ方
metadata:
  type: project
---

`shared/domain/src/commonMain/kotlin/com/noricoffee/domain/OriginNormalizer.kt`
（trim + lowercase → シノニム辞書 完全キー一致 → 正規形。辞書外は素通し）を導入したときの記録（2026-07-08）。

## 置換が必要だった箇所（origin 正規化ポイント全 5 + KDoc 1）

- `usecase/BeanProfileMatchUseCase.kt` の origin スコアリング（完全一致 +2 / 部分一致 +1）
- `usecase/BuildCoffeeStatsUseCase.kt` の `buildOriginRanking`（groupBy）と `buildBestOrigin`（groupBy）
  の 2 箇所。**表示ラベルはグループ内最初のレコードの元表記の `trim()` のみ**（正規化後の文字列は使わない）
  という既存仕様は変更しない
- `usecase/ObserveTasteMatchedCafesUseCase.kt` の origin 軸一致判定
- `usecase/PreferredBeanTraitsUseCase.kt` の origin 突合（`hay.contains(needle) || needle.contains(hay)`）
- `usecase/SuggestUnexploredBeansUseCase.kt` は **origin のみ** 置換。`variety` は品種シノニム対象外なので
  従来どおり `trim().lowercase()` のまま残す（origin と variety で正規化方式が異なる非対称実装になる）
- `repository/BeanProfileRepository.kt` の `getByOrigin` KDoc に「シノニム正規化非対応」注記を追加
  （本番呼び出し元ゼロを事前に `grep` で確認してから注記のみに留めた。実装は変更しない）

## 辞書完全一致方式が壊す既存テスト（想定内の regression）

`BeanProfileMatchUseCase` は「入力 origin と `BeanProfile.origin` の contains 部分一致」を score+1 として
持つ。ここに**単語単位のシノニム辞書**を適用すると、**複合語（例: `"Ethiopia Yirgacheffe"`）に対する
部分一致テスト**が壊れる:

- 入力 `"Yirgacheffe"` は辞書完全一致で `"エチオピア"` に変換される
- しかし `profile.origin = "Ethiopia Yirgacheffe"` は複合語で辞書キーに完全一致しないため、
  trim+lowercase の素通し `"ethiopia yirgacheffe"` のまま
- 結果、`"エチオピア".contains("ethiopia yirgacheffe")` も逆方向も false になり、
  従来 score+1 だった組み合わせが score 0 になってテストが落ちる
  （`BeanProfileMatchUseCaseTest` の "origin 部分一致（contains）" テスト、
  `SuggestUnexploredBeansUseCaseTest` の "origin が部分一致のみの BeanProfile も候補に含まれる" テストで実際に発生）

**実データでは起きない**: `scripts/seed/bean-profiles.json` の実 `origin` フィールドは
すべて単一の国名（"エチオピア" 等）で複合語は存在しない。テストの複合語シナリオは合成データ由来。
とはいえ既存テストを黙って直さず、親に「辞書完全一致方式の既知トレードオフ」として報告するのが筋
（`docs` 側の仕様確定次第でテスト側を更新するか、辞書マッチングをトークン分割方式に変えるかは親判断）。

## 検証の型

`OriginNormalizer` 単体テストに加え、既存 4 usecase テストクラス（BuildCoffeeStats /
PreferredBeanTraits / SuggestUnexploredBeans / ObserveTasteMatchedCafes）にシノニム名寄せの
横断テストを 1 本ずつ追加するとよい（"Ethiopia" と "エチオピア"/"イルガチェフェ" が同一グループ・
同一マッチ扱いになることを確認）。`./gradlew :shared:domain:testAndroidHostTest --tests "*XxxTest*"`
で対象クラスだけ絞って実行すると regression の切り分けが速い。
