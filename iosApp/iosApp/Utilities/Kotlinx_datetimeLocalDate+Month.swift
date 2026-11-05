import SharedLogic

// MARK: - Kotlinx_datetimeLocalDate の月を 1〜12 の数値で取り出す

extension Kotlinx_datetimeLocalDate {

    /// 月を 1（1 月）〜12（12 月）の数値で返す。
    ///
    /// kotlinx-datetime 0.8 以降、`month` は `Kotlinx_datetimeMonth`（enum）になり、
    /// 旧 `monthNumber`（`Int32`）は deprecated。Kotlin 側の拡張プロパティ `Month.number`
    /// は Swift に公開されないため、`Kotlinx_datetimeMonth` の宣言順
    /// （`.january` が先頭 = `ordinal == 0`）を利用してここで変換する。
    /// 月の数値が必要な呼び出し側はこの 1 箇所だけを使う。
    var monthValue: Int32 {
        month.ordinal + 1
    }
}
