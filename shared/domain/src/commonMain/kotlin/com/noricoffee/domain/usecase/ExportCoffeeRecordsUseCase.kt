package com.noricoffee.domain.usecase

import com.noricoffee.domain.export.CoffeeRecordExportEnvelope
import com.noricoffee.domain.export.CoffeeRecordExportMapper
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.first
import kotlinx.datetime.Clock
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * ユーザーの全 [com.noricoffee.domain.CoffeeRecord] を JSON 文字列にエクスポートする UseCase
 * （要件 §7-4 / tasks.md フェーズ 15-E-2）。
 *
 * 写真はメタデータのみ（バイナリ本体は含めない。[com.noricoffee.domain.export.PhotoExportDto] 参照）。
 * iOS 側は [invoke] の戻り値をそのままファイルに書き出し、`ShareLink` 等で共有シートに渡す想定。
 *
 * Swift からの呼び出しシグネチャ（`.swiftinterface` で裏取り済み）:
 * `exportCoffeeRecordsUseCase.invoke(userId: String) async throws -> String`
 * （SKIE は `operator fun invoke` を Swift の `callAsFunction` には変換しない。
 * `DeleteAccountUseCase` 等、他の UseCase も同様に `.invoke(...)` 呼び出しになる）
 *
 * @param coffeeRepository エクスポート対象のコーヒー記録を観測するリポジトリ
 */
class ExportCoffeeRecordsUseCase(
    private val coffeeRepository: CoffeeRepository,
) {

    // encodeDefaults = true: version / tags / photos などデフォルト値のフィールドも常に出力する
    // （既定の false だと version=1 のような「デフォルトと一致する値」がキーごと省略されてしまう）
    private val json = Json {
        prettyPrint = true
        encodeDefaults = true
    }

    /**
     * 指定ユーザーの全コーヒー記録を JSON 文字列として返す。
     *
     * トップレベルは `{ "exportedAt": ..., "version": 1, "records": [...] }` の形（
     * [CoffeeRecordExportEnvelope]）。0 件の場合も `records: []` を含む有効な JSON を返す。
     */
    @Throws(Exception::class)
    suspend operator fun invoke(userId: String): String {
        val records = coffeeRepository.observeAll(userId).first()
        val envelope = CoffeeRecordExportEnvelope(
            exportedAt = Clock.System.now().toString(),
            records = records.map { CoffeeRecordExportMapper.toDto(it) },
        )
        return json.encodeToString(envelope)
    }
}
