import SharedLogic

// MARK: - ドメイン enum の日本語表示ラベル
//
// `BrewMethod` / `RoastLevel` / `ProcessingMethod` / `TastingAxis` を画面表示用の
// 日本語へ変換する唯一の定義。**同じ変換をローカルな private 関数として再実装しないこと。**
//
// ## なぜ 1 箇所に集約するか
//
// 2026-08-08 のレビュー時点で、同じ対応表が 18 箇所に手写しされていた
// （roast 6 / brew 7 / tasting 4 / processing 1）。値は全一致していたが
// `String(localized:)` の有無は既に割れており、Kotlin の enum にケースが増えたら
// 18 箇所を直す必要があった。しかも**漏れてもコンパイルエラーにならず**、
// `default: return name` が黙って英語の enum 名を返す作りだった。
//
// ## 2 つの入り口
//
// - `localizedLabel`（インスタンスプロパティ）: enum を持っているとき。
//   `switch` が全ケースを網羅するため、**Kotlin 側に enum ケースが増えると
//   コンパイルエラーになる**（`default` を書かないのはそのため。`.claude/rules/swift-ios.md`）
// - `localizedLabel(forName:)`（static）: Kotlin の `name` 文字列しか無いとき。
//   `CategoryStat.label` など、KMP の集計結果が enum ではなく `String` で降ってくる経路で使う。
//   解決できない値は**そのまま返す**（旧データや未知ケースを握り潰さない）
//
// ## ここに置いてはいけないもの
//
// **LLM が生成した文字列の変換**（`TastePreferenceConversionView.localizedRoast`）。
// あちらは入力が `RoastLevel.name` ではなく Foundation Models の自由出力で、
// `"unknown"` → 「不明」を持ち、プロンプトが `RoastLevel` に存在しない `"Dark"` も
// 指示している。見た目が似ていても対応表の定義域が違うので統合しない。
//
// ## `nonisolated` である理由
//
// 呼び出し元に `nonisolated` なもの（`CoffeeInsightProviderIosImpl` = Kotlin ランタイムが
// 任意スレッドから呼ぶ / `SearchCoffeeRecordsTool` = Foundation Models のツール実行）が
// 含まれる。既定 MainActor 分離のままだと extension も暗黙 `@MainActor` になり、
// そこから呼べない（移行時に実際 8 件のコンパイルエラーが出た）。
// 引数だけから決まる純粋関数で共有可変状態を持たないため分離は不要
// （`PhotoFileStore` と同じ判断。`.claude/rules/swift-ios.md` SW6-3）。

// MARK: - BrewMethod

nonisolated extension BrewMethod {

    /// 抽出方法の日本語ラベル。
    var localizedLabel: String {
        switch self {
        case .espresso:    return String(localized: "エスプレッソ")
        case .handDrip:    return String(localized: "ハンドドリップ")
        case .nelDrip:     return String(localized: "ネルドリップ")
        case .frenchPress: return String(localized: "フレンチプレス")
        case .aeroPress:   return String(localized: "エアロプレス")
        case .syphon:      return String(localized: "サイフォン")
        case .coldBrew:    return String(localized: "コールドブリュー")
        case .other:       return String(localized: "その他")
        }
    }

    /// Kotlin の `BrewMethod.name`（例 `"HandDrip"`）を日本語ラベルへ変換する。
    /// 解決できない値はそのまま返す。
    static func localizedLabel(forName name: String) -> String {
        allCases.first { $0.name == name }?.localizedLabel ?? name
    }
}

// MARK: - RoastLevel

nonisolated extension RoastLevel {

    /// 焙煎度の日本語ラベル。
    var localizedLabel: String {
        switch self {
        case .light:    return String(localized: "ライト")
        case .cinnamon: return String(localized: "シナモン")
        case .medium:   return String(localized: "ミディアム")
        case .high:     return String(localized: "ハイ")
        case .city:     return String(localized: "シティ")
        case .fullCity: return String(localized: "フルシティ")
        case .french:   return String(localized: "フレンチ")
        case .italian:  return String(localized: "イタリアン")
        }
    }

    /// Kotlin の `RoastLevel.name`（例 `"FullCity"`）を日本語ラベルへ変換する。
    /// 解決できない値はそのまま返す。
    static func localizedLabel(forName name: String) -> String {
        allCases.first { $0.name == name }?.localizedLabel ?? name
    }
}

// MARK: - ProcessingMethod

nonisolated extension ProcessingMethod {

    /// 精製方法の日本語ラベル。
    var localizedLabel: String {
        switch self {
        case .natural:   return String(localized: "ナチュラル")
        case .washed:    return String(localized: "ウォッシュド")
        case .honey:     return String(localized: "ハニー")
        case .anaerobic: return String(localized: "アナエロビック")
        case .other:     return String(localized: "その他")
        }
    }

    /// Kotlin の `ProcessingMethod.name`（例 `"Anaerobic"`）を日本語ラベルへ変換する。
    /// 解決できない値はそのまま返す。
    static func localizedLabel(forName name: String) -> String {
        allCases.first { $0.name == name }?.localizedLabel ?? name
    }
}

// MARK: - TastingAxis

nonisolated extension TastingAxis {

    /// テイスティング 5 軸の日本語ラベル（Blue Bottle「Elements of Coffee Tasting」準拠）。
    var localizedLabel: String {
        switch self {
        case .sweetness:  return String(localized: "甘味")
        case .body:       return String(localized: "ボディ")
        case .acidity:    return String(localized: "酸味")
        case .flavor:     return String(localized: "風味")
        case .aftertaste: return String(localized: "後味")
        }
    }
}
