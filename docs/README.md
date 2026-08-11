# docs/ の索引

CoffeeVision の設計・仕様・運用ドキュメントの置き場。ここは **フォルダ全体の地図** と、下記「必読ドキュメント」表に載らない補助ファイルの所在を示す。

**各ファイルの役割の一行説明は [CLAUDE.md「必読ドキュメント」](../CLAUDE.md) の表を正とする**（重複を避けるため本ファイルには複製しない）。コード生成・変更時はまずそちらに従うこと。

---

## 直下（設計・仕様の正本）

コーディング時に従う正本。役割は CLAUDE.md「必読ドキュメント」表を参照：
`architecture` / `coding-conventions` / `ui-ux-guidelines` / `requirements` / `data-model` / `analysis-model` / `kmp-bridge` / `implementation_note` / `tasks` / `app-store-metadata` / `paid-services`。

- **[implementation-note-archive.md](./implementation-note-archive.md)** — `implementation_note.md` から切り出した**凍結済み**の過去分（2026-06 の 36 エントリ + 2026-07 の 73 エントリ）を月見出しで格納。追記しない。他 doc の「implementation_note 2026-06-XX / 2026-07-XX」参照はここを指す。切り出しの運用ルールは `implementation_note.md`「アーカイブ」節。
- **[admob-setup-todo.md](./admob-setup-todo.md)** — AdMob 本番ユニット発行のユーザー作業手順（**一時ファイル・git 非追跡**。完了後に削除）。実装側の切替手順の正本は `iosApp/Configuration/README.md`。

## tasks/ — 進捗と学び

- **[tasks.md](./tasks.md)**（直下）— カテゴリ別タスク・進捗管理。実装 / 設計タスクの正。
- **[tasks/lessons.md](./tasks/lessons.md)** — 再発させたくない落とし穴・お作法（自己改善ループ）。冒頭に**主題別インデックス**あり。追記手順は `record-lesson` skill。
- **[tasks/verification-checklist.md](./tasks/verification-checklist.md)** — 実機 / シミュレータの**目視 QA 項目**（ビルド・自動テストは green 済みが前提。`tasks.md` から 2026-07-08 分離）。
- **[tasks/pr-log.md](./tasks/pr-log.md)** — Phase 1〜初期（〜2026-06-25）の PR 振り返りログ。**凍結済み**（以降は `tasks.md` 完了 / `implementation_note.md` / git log が正）。

## legal/ — 法務ページ原稿

- **[legal/privacy-policy.html](./legal/privacy-policy.html)** / **[legal/support.html](./legal/support.html)** — プライバシーポリシー / サポートページの起草（HTML）。公開・URL 化・プレースホルダ差し替えの残作業は `app-store-metadata.md` と `tasks.md`「リリース準備」を参照。

## talks/ — 登壇資料

- iOSDC 等の LT 原稿。プロダクト仕様とは独立（ドメイン知識の副産物）。
