# iOSDC 2026 トーク作業ファイル — 数値⇄言葉、双方向変換 × Foundation Models

CoffeeVision の分析機能を題材にした iOSDC プロポーザル／登壇準備の集約ファイル。
ここを正本として進める（初期検討は `~/.claude/plans/iosdc-foundationmodel-moonlit-moore.md`）。

> **今回の提出方針（2026-06-26 更新）**
> - **LT（5分）単独で提出**する。20分版は今回は出さず、巻末「§A 将来案」に保管。
> - 主題は **「コーヒーの好みを“数値⇄言葉”の双方向で変換する」**（順＝データ→言葉 / 逆＝言葉→データ）。
> - 背骨のメッセージは **「決定的なコード（正確な計算・集計）と確率的な LLM（曖昧な自然文の解釈・生成）を、`@Generable` という一つの境界面で双方向に縫い合わせる」**。
> - 順方向は実装済み（テスト47件）。**逆方向は本トークのために PoC＋デモUI を新規実装**（§5・ios-engineer 委譲）。
> - スコープは Foundation Models / Swift 側に完全に絞る（KMP・SKIE・共通層は出さない）。

---

## 1. 主題と狙い

コーヒーの「好み」を、**数値と言葉の間で双方向に変換**する実装の話。

- **順（データ→言葉）**: 多数の記録（★/5軸/産地…）を自前集計 → LLM が「**やや酸味のある浅煎りを好む傾向のカフェ探求者**」と言語化。
- **逆（言葉→データ）**: 自由な感想「**フルーティで軽い、酸味がきれい**」→ LLM が **5軸の数値（好みベクトル）** へ構造化 → コードで検索・レコメンドに使える。

背骨: **決定的なコード（計算・集計）と確率的な LLM（自然文の解釈・生成）を、`@Generable` という一つの境界面で双方向につなぐ。**
そして「**`@Generable` に5軸が“ある/ない”が、そのまま変換の向きを表す**」という対比が主役（順＝出力は語り口だけ＝5軸なし／逆＝出力は抽出スキーマ＝5軸あり）。

> **スコープ厳守**: アプリの実体は KMP だが、KMP・SKIE・共通層の文脈は**一切出さない**。
> 「集計は KMP」ではなく「集計は**アプリ側の通常の Swift ロジック**」として語る。

---

## 2. タイトル

- **第一候補**: 数値と言葉を行き来する — Foundation Models でコーヒーの「好み」を双方向に変換する
- 対案（対比を前面に）: 「★4.2」⇄「酸味が好き」— `@Generable` でつなぐオンデバイス LLM の双方向変換
- 対案（設計論を前面に）: 型で縫う、数値と言葉 — オンデバイス LLM × `@Generable` の双方向設計

> 確定タスク: §9 TODO 参照。第一候補で出す想定。

---

## 3. CFP 提出用 概要文

> レビュー指摘（2026-06-25）を反映済: ①導入で「なぜ重要か」を明示 ②Foundation Models / `@Generable` を一言で補足 ③目的から実装への橋渡しを明示 ④見せるコード例を予告 ⑤「このLTでは」へ表記統一。

### 本命（LT 用・約600字）
> 「★4.2」「甘味4.1・酸味2.9…」——コーヒーの味は、いまや数値で細かく記録できます。でも、数値の束をいくら眺めても「自分はどんなコーヒーが好きなのか」は見えてきません。逆に「フルーティで軽いのが好き」と言葉で言われても、アプリはそれを検索条件には使えない。数値と言葉、どちらか一方では足りない——両方を自由に行き来できたら。それがこのトークのテーマです。
>
> iOS 26 で Apple が提供する **Foundation Models** は、端末の中だけで動く大規模言語モデル（オンデバイス LLM）です。サーバーに何も送らず、文章の生成も、自然文からの情報抽出もこなします。
>
> このLTでは、訪れたカフェのコーヒー体験を記録するアプリを題材に、好みを「**数値→言葉**」「**言葉→数値**」の両方向に変換する実装を5分で見せます。鍵は、両方向とも同じ仕組みで書けること——出力の構造を Swift のコードで LLM に指示するマクロ `@Generable` です。順方向は、自前で集計した数値を「やや酸味のある浅煎りを好む傾向ですね」と言語化。逆方向は、自由に書いた感想を5軸の数値へ構造化します。
>
> 設計の核心は「**決定的なコード（正確な計算）と確率的な LLM（曖昧な自然文）を、型で縫い合わせる**」こと。`@Generable` に5軸が「あるか/ないか」が、そのまま変換の向きを表す——という対比までお見せします。オンデバイス完結なのでプライバシーも安心。LLM を「丸投げせずに」組み込みたい iOS エンジニア向けです。

### 予備（短縮・約300字 / フォームが短い場合）
> 「★4.2」「酸味2.9…」——コーヒーの味は数値で記録できても、その束から「好み」は見えてきません。逆に「フルーティが好き」と言われても、アプリは検索条件にできない。数値と言葉を自由に行き来したい、それがこのテーマです。iOS 26 の Foundation Models は端末内だけで動くオンデバイス LLM。このLTでは、好みを「数値→言葉」「言葉→数値」の双方向に変換する実装を5分で見せます。鍵は両方向とも同じマクロ `@Generable`（出力構造をコードで指示する仕組み）で書けること。核心は「**決定的なコードと確率的な LLM を型で縫い合わせる**」。`@Generable` に5軸が「ある/ない」が変換の向きを表す対比まで見せます。

### TODO
- [ ] 提出フォーム（fortee）の字数欄を確認し、600字版／300字版のどちらを出すか確定
- [ ] タイトル確定（第一候補を第一に）

---

## 4. 5分版 アウトライン＋スライド構成（双方向・確定版）

全体 約9枚 / 本編約5分。★＝山場。

| # | 枚 | 内容 | 秒 |
|---|----|------|----|
| S1 | 1 | タイトル＋名前＋アプリ1枚。「コーヒーの“好み”を、数値と言葉の間で双方向に変換する話」 | 〜20 |
| S2 ★ | 1 | **デモ①（順）**: 多数の記録（★/5軸グラフ）→「やや酸味のある浅煎りを好む傾向」カード（データ→言葉） | 〜40 |
| S3 ★ | 1 | **デモ②（逆）**: 自由な感想を入力 →「甘味3 / 酸味8 / …浅煎り」の構造化カード（言葉→データ）。「向きが逆なだけ」 | 〜40 |
| S4 ★ | 1 | **原則の図**: コード＝正確な計算 / LLM＝曖昧な自然文。`@Generable` がその境界面。両方向を1枚で | 〜50 |
| S5 | 1 | **順の勘所**: 集計は自前 → 事実だけ文字列で渡す（`buildPrompt`）。出力 `@Generable` は `headline`/`body`＝**語り口に型**（数値は持たせない／再列挙させない instructions） | 〜45 |
| S6 | 1 | **逆の勘所**: 入力は自由文 → `@Generable TastePreference` に5軸。ここでは型が**抽出スキーマ**。API は同じ `respond(to:generating:)` | 〜45 |
| S7 ★ | 1 | **対比**: 同じ `@Generable`、5軸が「出力に無い(順)／ある(逆)」だけ。**型を定義するのはコード、変換するのは LLM** | 〜35 |
| S8 | 1 | まとめ: 数値⇄言葉は一つの蝶番で双方向。決定的コードと確率的 LLM を型で縫う。オンデバイス完結＝プライバシー | 〜35 |
| S9 | 1 | （予備・任意）`body` が SwiftUI `View.body` と名前衝突する小ネタ。尺が余れば S5 に挿す | 〜20 |

- tool calling・availability の詳説・好み判定の統計フル解説（収縮の式・相関・交絡の検定）は**今回扱わない**（§A の 20分将来案へ）。
- 尺が押したら S9 を落とし、S5/S6 をそれぞれ「型を与える対象が違うだけ」で1文に圧縮。

---

## 5. 逆向き（言葉 → データ）PoC の仕様 — ios-engineer 委譲

**結論: 同じ `@Generable` + `respond(to:generating:)` を逆向きに使うだけ。** 本トークのために最小実装する。

### 5.1 インターフェース合意（親が確定 / Swift 側で完結・KMP 変更なし）
- 配置: `iosApp/iosApp/Features/Analysis/`（順方向の `CoffeeInsightProviderIosImpl.swift` と同じ並び）に新規 Swift ファイル。
- 出力スキーマ（PoC・Swift 内で自己完結。KMP / domain には依存しない）:

```swift
@available(iOS 26.0, *)
@Generable
struct TastePreference {
    @Guide(description: "甘味の好みの強さ 1〜10。言及がなければ 5") var sweetness: Int
    @Guide(description: "ボディ（コク）の好みの強さ 1〜10。言及がなければ 5") var body: Int
    @Guide(description: "酸味の好みの強さ 1〜10。言及がなければ 5") var acidity: Int
    @Guide(description: "風味の華やかさの好み 1〜10。言及がなければ 5") var flavor: Int
    @Guide(description: "後味の好みの強さ 1〜10。言及がなければ 5") var aftertaste: Int
    @Guide(description: "好む焙煎度。判断できなければ \"unknown\"") var roast: String
    @Guide(description: "抽出した好みの一言サマリ（20〜40字）") var summary: String
}
```

- 抽出関数（ステートレス・`LanguageModelSession(instructions:).respond(to:generating: TastePreference.self)`）:
  - 入力: ユーザーが自由記述したコーヒーの感想テキスト（日本語）。
  - instructions の要点: 自然文から5軸を 1〜10 で**推定**する／言及のない軸は 5（中庸）にする／数値は推測でよいが大げさにしない／焙煎は判断できなければ `unknown`。
  - 順方向と同じく `makeIfAvailable()` 相当の availability ガードで非対応端末はデモを出さない。
- デモ UI（PoC・スクショ取得が目的）:
  - 最小の SwiftUI 画面: `TextField`（複数行）＋「変換」ボタン → 抽出結果を**5軸カード or レーダー**で表示（既存の5軸表示コンポーネントを流用できるなら流用）。
  - 本番ナビゲーションに恒久配線する必要はない。dev で到達できればよい（既存のデモ導線 or デバッグメニューに1エントリ）。
  - 抽出した `TastePreference` を「→ こう検索できる」とつなぐのは**今回は不要**（概念で口頭一言）。

### 5.2 トークでの見せ方
- S3 で「自由文 → 5軸カード」をデモ。S6 で `TastePreference` の `@Generable` を見せる。
- S7 で順（`CoffeeInsightOutput`：5軸なし）と逆（`TastePreference`：5軸あり）を**並べて**対比。

---

## 6. 実装の出典と実データ（トークの裏付け）

順方向はコミット済（`feature/foundation`: `59f7654` KMP / `d178518` iOS）。
**「計算は自前だからテストできる」をユニットテスト47件で実証できる**のが本トークの強み（順方向）。
逆方向は本トークのために新規実装済み（2026-06-26・未コミット / コミットハッシュは commit 後に追記）。
- 実装ファイル: `iosApp/.../Analysis/TastePreferenceExtractor.swift`（`@Generable TastePreference` + 抽出）・`TastePreferenceConversionView.swift`（デモ UI）・`AnalysisView.swift`（`#if DEBUG` 導線）
- iOS ビルド BUILD SUCCEEDED（新規 warning ゼロ）。実装判断は `docs/implementation_note.md` 2026-06-26 エントリ。

### 好み判定の実際の信号値（DummyCoffeeData 30件・globalMean≈4.0、親が検算）
- `bestOrigin` = **Ethiopia**（評価済4件・平均4.5 / 収縮後4.22）
- `bestRoastLevel` = **Light**（6件・平均4.58 / 収縮後4.32）
- `bestBrewMethod` = **AeroPress**（3件・平均4.5 / 収縮後4.19）
- `dominantTastingAxis` = **Flavor（風味）**（tasting20件・評価と強い正相関）

### 出典マッピング（LT で使うもの）
| ネタ | スライド | 出典 |
|------|---------|------|
| 設計原則「コードは計算/LLM は自然文」 | S4 | `docs/implementation_note.md` 2026-06-19「分析機能の3階層分離」 |
| 順: 数値のプロンプト整形 / 計算させない | S5 | `CoffeeInsightProviderIosImpl.swift` `buildPrompt` / `buildFavoriteSignalsPromptLines` |
| 順: 断定させない instructions（「やや」/交絡） | S5 | 同上 `generateInsight` の instructions |
| 順: `@Generable CoffeeInsightOutput`（5軸なし=語り口に型） | S5/S7 | 同上 `CoffeeInsightOutput` |
| 逆: 自由文→`@Generable TastePreference`（5軸あり=抽出スキーマ） | S3/S6/S7 | **新規実装**（§5・ios-engineer） |
| `@Generable`/`@Guide` と `body` 名前衝突 | S9 | `CoffeeInsightProviderIosImpl.swift` `CoffeeInsightOutput` |
| 順の統計はテストで固定（47件） | 順方向の裏付け | `BuildCoffeeStatsUseCaseTest` / `FavoriteSignalsPersonaTest` |

---

## 7. デモ素材の状況

| 素材 | 用途スライド | 状況 |
|------|------------|------|
| 分析タブ（5軸グラフ＋好みカード）＝順 | S2 | ⬜ 要スクショ |
| 逆変換 PoC 画面（自由文→5軸カード） | S3 | ✅ 実装済（DEBUG ビルド）→ ⬜ 要スクショ |
| 順 `CoffeeInsightOutput` / 逆 `TastePreference` 並置 | S7 | ⬜ コード清書 |

取得手順（順）: `SEED_DUMMY_DATA=1` の dev Scheme でシミュレータ起動 → 分析タブ。
取得手順（逆）: 上記 dev Scheme（DEBUG ビルド）→ 分析タブを最下部までスクロール → 「逆変換 PoC（LT デモ）」をタップ → 感想文を入力 or サンプルチップ → 「好みに変換」 → 5軸グラフ + summary カード。
※ Foundation Models の推論は **Apple Intelligence 有効な実機**でのみ動作（シミュレータでは availability が `.available` にならず抽出不可）。スクショ取得・抽出品質確認は実機が必要。

---

## 8. コード抜粋ネタ（スライド貼り用に清書する候補）

1. 順: `buildPrompt` / `buildFavoriteSignalsPromptLines` — 集計済み数値を文字列化して渡す（S5）
2. 順: `@Generable struct CoffeeInsightOutput`（`headline`/`body` のみ＝5軸なし）（S5/S7）
3. 逆: `@Generable struct TastePreference`（5軸あり）＋抽出 `respond(to:generating:)`（S6/S7）
4. 対比: 2 と 3 を並べた1枚（S7）

---

## 9. 進捗 / TODO

- [x] 主軸・尺戦略・タイトル候補
- [x] 提出方針確定（LT 単独・主題「数値⇄言葉の双方向」）
- [x] 順方向 実装（KMP 統計＋iOS 連携、テスト47件、コミット済）
- [x] **逆方向 PoC＋デモUI 実装**（§5・ios-engineer / 2026-06-26 BUILD SUCCEEDED・未コミット）
- [ ] **デモ用スクショ取得**（§7・S2 順＋S3 逆。Foundation Models 推論は実機が必要）
- [ ] 逆方向 PoC を commit（ハッシュを §6 に追記）
- [ ] CFP 概要文の字数調整（fortee 制限確認）＋タイトル確定
- [ ] 5分版スライド清書（S1〜S9）
- [ ] 通しリハーサルで尺計測（目標 4.5〜5.0 分）

---

## §A 将来案 — 20分版（二本柱）アウトライン（今回は提出しない）

> LT が通った／別枠で挑戦する場合の素材。LT ⊂ 20分 の入れ子なので一貫性は保てる。
> 二本柱 = ①好みの言語化／双方向変換（＝今回の LT）＋②複数の評価から好みを統計的に判定（収縮・相関・交絡）＋tool calling のデバッグ譚。

全体 約28枚 / 本編約18分（質疑2分）。★＝山場。

| Part | 枚数 | 内容 |
|------|------|------|
| 0 つかみ | 2 | タイトル / デモ（順＋逆の双方向） |
| 1 二層評価 | 3 | 定量(★/5軸)・定性 → サマリ |
| 2 設計の核 ★ | 5 | 丸投げ失敗 → コードは計算/LLM は自然文 → 双方向の図 → buildPrompt → 再列挙させない |
| 3 FM実装の勘所 | 4 | availability → graceful degradation → @Generable(body衝突) → グラウンディング |
| 4 言語化を対話へ ★ | 5 | 対話デモ → Tool定義 → 「呼ばれない」3段階を実機ログで(3枚) → 教訓 |
| 5 好み判定(統計) ★ | 6 | 産地別平均の罠 → サンプルサイズ/信頼区間 → ベイズ収縮 → 相関 → 交絡＝言えないこと → 境界線をLLMが言語化 |
| 6 まとめ | 1 | 双方向＋二本柱を1メッセージに収束 |

詳細スライド（S1〜S20 / P5-1〜P5-6）と尺調整の逃がしは旧版（git 履歴 `aa94ae0` 以前の本ファイル）を参照。20分を本格復活させる際にここへ展開する。

20分用に追加で必要な素材:
- 対話 Q&A スクショ（修正前→後で回答が変わる）＋ tool calling の実機ログ（`SearchCoffeeRecordsTool.call` の `print`）
- 非対応端末スクショ（カード非表示・統計は動く）
- 出典: tool calling 3段階デバッグ = `docs/tasks/lessons.md` 2026-06-21 / `SearchCoffeeRecordsTool.swift`
