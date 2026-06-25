import Foundation
import FoundationModels

// MARK: - TastePreference（@Generable 出力スキーマ）

/// 自由記述の感想テキストから抽出するコーヒーの好みベクトル。
///
/// `@Generable` マクロにより Foundation Models への JSON Schema が自動生成される。
/// 各 `@Guide` はモデルへの生成ヒントを与える。
///
/// ## 設計メモ（iOSDC LT §5.1 準拠）
///
/// 順方向（`CoffeeInsightOutput`）と比較:
/// - 順: `headline`/`body` のみ = 5軸を**持たない**（語り口に型を与える）
/// - 逆: 5軸 + `roast` + `summary` = 5軸を**持つ**（抽出スキーマとして型を使う）
/// `@Generable` に5軸が「ある/ない」がそのまま変換の向きを表す。
///
/// ## `body` 命名について
///
/// Swift の `View.body` と同名になるが、構造体プロパティとしては問題ない。
/// ただし `View` を直接実装する型の中でこの構造体を参照する場合は注意（LT S9 ネタ）。
@Generable
struct TastePreference {
    /// 甘味の好みの強さ 1〜10。言及がなければ 5
    @Guide(description: "甘味の好みの強さ 1〜10。言及がなければ 5")
    var sweetness: Int

    /// ボディ（コク）の好みの強さ 1〜10。言及がなければ 5
    @Guide(description: "ボディ（コク）の好みの強さ 1〜10。言及がなければ 5")
    var body: Int

    /// 酸味の好みの強さ 1〜10。言及がなければ 5
    @Guide(description: "酸味の好みの強さ 1〜10。言及がなければ 5")
    var acidity: Int

    /// 風味の華やかさの好み 1〜10。言及がなければ 5
    @Guide(description: "風味の華やかさの好み 1〜10。言及がなければ 5")
    var flavor: Int

    /// 後味の好みの強さ 1〜10。言及がなければ 5
    @Guide(description: "後味の好みの強さ 1〜10。言及がなければ 5")
    var aftertaste: Int

    /// 好む焙煎度。判断できなければ "unknown"
    @Guide(description: "好む焙煎度。判断できなければ \"unknown\"")
    var roast: String

    /// 抽出した好みの一言サマリ（20〜40字）
    @Guide(description: "抽出した好みの一言サマリ（20〜40字）")
    var summary: String
}

// MARK: - TastePreferenceExtractor

/// 自由記述の日本語感想テキストから `TastePreference` を抽出するステートレス型。
///
/// Foundation Models の `@Generable` + `respond(to:generating:)` を逆方向に使い、
/// 言葉（自然文）→ 構造化データ（5軸ベクトル）へ変換する。
///
/// ## 設計
///
/// - `makeIfAvailable()` で `SystemLanguageModel.default.availability` を確認し、
///   `.available` のときだけインスタンスを返す（`CoffeeInsightProviderIosImpl` と同等の availability ガード）
/// - `extract(from:)` は呼ぶたびに新規 `LanguageModelSession` を作る（ステートレス）
/// - 非対応端末では `makeIfAvailable()` が nil を返すため、呼び出し元は nil チェックで
///   デモ UI 自体を表示しない（graceful degradation）
final class TastePreferenceExtractor {

    // MARK: - Factory

    /// `SystemLanguageModel` の可否を確認し、利用可能なときだけインスタンスを返す。
    ///
    /// `CoffeeInsightProviderIosImpl.makeIfAvailable()` と同じパターン。
    /// - Returns: `TastePreferenceExtractor` のインスタンス、非対応端末では nil。
    static func makeIfAvailable() -> TastePreferenceExtractor? {
        guard SystemLanguageModel.default.availability == .available else {
            print("[CoffeeVision] TastePreferenceExtractor: Foundation Models unavailable: \(SystemLanguageModel.default.availability)")
            return nil
        }
        print("[CoffeeVision] TastePreferenceExtractor: Foundation Models available")
        return TastePreferenceExtractor()
    }

    // MARK: - 抽出

    /// 自由記述テキストから `TastePreference` を抽出して返す。
    ///
    /// - Parameter text: ユーザーが入力した自由記述のコーヒー感想（日本語）
    /// - Returns: 抽出された `TastePreference`
    /// - Throws: `LanguageModelSession` のエラー（`LanguageModelError` など）
    func extract(from text: String) async throws -> TastePreference {
        let session = LanguageModelSession(
            instructions: """
            あなたはコーヒーの感想テキストから、その人のコーヒーの好みを構造化データに変換するアシスタントです。
            ユーザーが書いた自由記述の感想テキストを読み、以下のルールで5軸の好みベクトルを抽出してください。

            【抽出ルール】
            1. 各軸（甘味・ボディ・酸味・風味・後味）は 1〜10 の整数で表す。
               - 高い数値 = その要素を「強く好む」または「感じた」
               - 低い数値 = その要素が「弱い・不要」または「苦手」
            2. 言及がない軸は 5（中庸）とする。
            3. 数値は推測でよいが大げさにしない（文章に根拠がある範囲で調整する）。
            4. 焙煎度（roast）は「Light」「Medium」「Dark」等の英語で表す。判断できなければ "unknown"。
            5. summary は 20〜40字の日本語で感想の核心を一言にまとめる。
            6. 数値の再計算や推論の説明は不要。結果だけを返す。
            """
        )

        let prompt = """
        【感想テキスト】
        \(text)
        """

        let response = try await session.respond(
            to: prompt,
            generating: TastePreference.self
        )

        return response.content
    }
}
