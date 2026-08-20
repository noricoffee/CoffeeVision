# docs/ の索引

CoffeeVision の設計・仕様・運用ドキュメントの置き場。ここは **フォルダ全体の地図** と、下記「必読ドキュメント」表に載らない補助ファイルの所在を示す。

**各ファイルの役割の一行説明は [CLAUDE.md「必読ドキュメント」](../CLAUDE.md) の表を正とする**（重複を避けるため本ファイルには複製しない）。コード生成・変更時はまずそちらに従うこと。

---

## 直下（設計・仕様の正本）

コーディング時に従う正本。役割は CLAUDE.md「必読ドキュメント」表を参照：
`architecture` / `coding-conventions` / `ui-ux-guidelines` / `requirements` / `data-model` / `analysis-model` / `kmp-bridge` / `implementation_note` / `tasks` / `app-store-metadata` / `paid-services`。

- **[admob-setup-todo.md](./admob-setup-todo.md)** — AdMob 本番ユニットの ID 控え（**git 非追跡**）。実装側の切替手順の正本は `iosApp/Configuration/README.md`。

## archive/ — 凍結したリリース分

**リリースしたバージョンまでの作業ログを、バージョン単位のフォルダに凍結して置く。追記しない。**
現行の doc から切り離すのは、live 側を「今こう動く」だけに保つため。過去分は通読されず、日付や参照 ID で grep されるだけなので、行数閾値（`check-file-size.sh`）も適用しない。

- **[archive/1.0/tasks-archive.md](./archive/1.0/tasks-archive.md)** — `tasks.md` から切り出した完了タスク（1.0 リリースまで）+ 付録として Phase 1〜初期の PR 振り返りログ（旧 `tasks/pr-log.md`）。**フェーズ番号・サブ ID（15-A / SR-1 / UX-1 等）の名指し参照はここを指す**。
- **[archive/1.0/implementation-note-archive.md](./archive/1.0/implementation-note-archive.md)** — `implementation_note.md` から切り出した過去分（2026-06 / 2026-07 / 2026-08 = 1.0 リリースまでの全エントリ）を月見出しで格納。他 doc の「implementation_note 2026-0X-XX」参照はここを指す。切り出しの運用ルールは `implementation_note.md`「アーカイブ」節。

次のリリースでは `archive/1.1/` のように新しいフォルダを切る（既存フォルダには手を入れない）。

## tasks/ — 進捗と学び

- **[tasks.md](./tasks.md)**（直下）— カテゴリ別タスク・進捗管理。実装 / 設計タスクの正。**完了分は `tasks-archive.md` へ凍結移送済み**で、ここに残るのは未完・バックログのみ。
- **[tasks/lessons.md](./tasks/lessons.md)** — 再発させたくない落とし穴・お作法（自己改善ループ）。冒頭に**主題別インデックス**あり。追記手順は `record-lesson` skill。
- **[tasks/verification-checklist.md](./tasks/verification-checklist.md)** — 実機 / シミュレータの**目視 QA 項目**（ビルド・自動テストは green 済みが前提）。バージョンごとに積み、リリースしたら白紙に戻す。

## legal/ — 法務ページ原稿

- **[legal/privacy-policy.html](./legal/privacy-policy.html)** / **[legal/support.html](./legal/support.html)** — プライバシーポリシー / サポートページの本文（HTML）。**GitHub Pages で公開中**（`.github/workflows/pages.yml` が `docs/legal/` のみを配信し、設計 doc は Web 公開しない）。URL は `app-store-metadata.md` §6.4。収集項目や第三者 SDK を変える変更では §6.1 / §6.3 / `PrivacyInfo.xcprivacy` と 4 点セットで整合を取る。

## talks/ — 登壇資料

- iOSDC 等の LT 原稿。プロダクト仕様とは独立（ドメイン知識の副産物）。
