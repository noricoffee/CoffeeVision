---
name: writing-great-skills
description: Skill（.claude/skills/*）を新規作成・改訂・レビューするときの設計原則リファレンス。invocation の選択、情報階層、leading word、pruning、失敗モードの診断に使う。record-lesson から rules / skill へ昇格させるときにも使う。
---

# Writing Great Skills

skill は確率的なシステムから決定論を絞り出すために存在する。**Predictability（予測可能性）** — 同じ*出力*ではなく、エージェントが毎回同じ*プロセス*を辿ること — が根本の徳であり、以下のあらゆるレバーはそれに仕える。

**太字の用語**は [`GLOSSARY.md`](GLOSSARY.md)（原文英語）で定義されている。完全な意味はそちらを引く。

## Invocation（呼び出し方式）

異なるコストを交換する 2 択:

- **model-invoked** な skill は **description** を保持し、エージェントが自律的に発火でき、*かつ*他の skill からも到達できる（人間が名前を打つのも引き続き可能）。**context load** を支払う — description は毎ターン、コンテキストウィンドウに常駐する。書き方: `disable-model-invocation` を省略し、モデル向けの description をトリガー表現込みで書く（「ユーザーが〜したいとき、〜と言ったときに使う」）
- **user-invoked** な skill は description をエージェントの視界から外す: 人間が名前を打ったときだけ発火し、他の skill からは到達できない。context load はゼロだが、**cognitive load** を支払う: skill の存在を覚えておく索引は*あなた*になる。書き方: `disable-model-invocation: true` を設定し、description は人間向けの 1 行要約にする（トリガー列挙は削る）

model-invocation を選ぶのは、エージェントが自力でその skill に到達すべきとき、または他の skill から到達が必要なときだけ。手で打つときしか発火しないなら user-invoked にして context load を払わない。

user-invoked な skill が記憶できる数を超えたら、積み上がった cognitive load は **router skill** — 他の skill の名前と使いどころを列挙した user-invoked な skill 1 つ — で治す。

## description の書き方

model-invoked の **description** の仕事は 2 つ — skill が何かを述べることと、発火すべき**branch**（分岐）を列挙すること。一語ごとに **context load** が増えるので、description は本文以上に強く刈り込む:

- **leading word を先頭に置く** — description は leading word が invocation の仕事をする場所
- **1 branch につきトリガー 1 つ。** 同じ branch を言い換えただけの同義語は **duplication** — 本当に別の branch だけを残す
- **本文にある自己紹介は削る。** description はトリガーと、「他の skill が〜を必要とするとき」の到達句だけに絞る

## 情報階層

skill は 2 種類のコンテンツ — **steps**（手順）と **reference**（参照資料） — から成り、自由に混ざる: 全部 steps でも、全部 reference でも、両方でもよい。核心の判断は、どちらを使い、それぞれを**情報階層**（エージェントがその内容をどれだけ即座に必要とするかで並べた梯子）のどこに置くか:

1. **ファイル内 step** — SKILL.md 内の順序付きアクション。主たる層: エージェントが何を、どの順でやるか。各 step は **completion criterion**（完了条件）で終わる。*チェック可能*（完了と未完了をエージェントが判別できるか？）にし、重要な所では*網羅的*（「変更リストを出す」ではなく「変更した全モデルを確認済み」）にする — 曖昧な完了条件は **premature completion** を招く
2. **ファイル内 reference** — SKILL.md 内の定義・規則・事実。必要時に参照される。正当にフラットな同格集合（レビューの全規則が同じ段に並ぶ等）であることも多く、それは欠陥ではない。*この skill 自体は全部 reference。*
3. **外出しされた reference** — SKILL.md の外の別ファイルに押し出され、**context pointer** 経由で、pointer が発火したときだけ読まれる

要求水準の高い completion criterion は、steps の有無にかかわらず徹底的な **legwork**（作業内での掘り下げ）を駆動する — 「全 step 完了」が手順を縛るのと同様に、「全規則を適用した」はフラットな reference を縛る。

押し下げが足りないと上部が肥大し、押し下げすぎるとエージェントが実際に必要とする資料が隠れる。その緊張関係が判断のすべて。

**progressive disclosure** は梯子を下る移動 — SKILL.md からリンク先ファイルへ — で、上部の可読性を守る。書き方: skill フォルダ内のリンクされた `.md` ファイルに、中身を表す名前を付ける。skill が複数の使われ方をするとき、その 1 つ 1 つが **branch** — 実行ごとに skill 内の別の経路を辿る。branching は最もクリーンな外出しテスト: 全 branch が必要とするものはインラインに、一部の branch しか到達しないものは pointer の先に。**context pointer** は*ターゲットではなく文言*が、エージェントがいつ・どれだけ確実にその資料へ到達するかを決める。

梯子が*どの深さに置くか*を決めるのに対し、**co-location** は置いた先で*何を隣に置くか*を決める: 1 つの概念の定義・規則・注意点は散らさず 1 見出しの下にまとめ、一部を読めば隣接部も一緒に目に入るようにする。

## 分割の基準

**granularity**（分割の細かさ）は、切るたびに 2 つの load のどちらかを支払う。切ってよいのは切る価値があるときだけ。切り方は 2 つ:

- **invocation で切る** — 独立して発火すべき明確な **leading word** があるとき、または他の skill から到達が必要なとき、model-invoked な skill を切り出す。新しい常駐 description の **context load** を払うので、その独立した到達性が対価に見合うこと
- **sequence で切る** — 目前の step を急がせる誘惑（**post-completion steps** = この先に見えている残りの手順が **premature completion** を誘う）があるとき、steps の連なりを 2 つに割る。後続を視界から消すことで、いまのタスクへの **legwork** を促す

## Pruning（刈り込み）

各意味は **single source of truth** に保つ: 権威ある置き場所を 1 つにし、挙動の変更が 1 箇所の編集で済むようにする。

すべての行を **relevance** で検査する: その行はまだ skill のやることに関与しているか？

そして **no-op** を行単位でなく文単位で狩る: 各文に単体で no-op テスト（デフォルト挙動と比べて何かを変えるか？）をかけ、落ちた文は語句を削るのではなく文ごと消す。アグレッシブに — 落ちた散文の大半は書き直しでなく削除が正解。

## Leading words

**leading word** とは、モデルの事前学習にすでに住んでいるコンパクトな概念で、skill の実行中エージェントがそれで*考える*語（例: *lesson*、*fog of war*、*tracer bullets*）。本文で繰り返されると（強い語なら 1 回でも）分散した定義を蓄積し、最小のトークン数で挙動の一領域全体を錨付けする — モデルが既に持つ事前知識を徴用するからだ。

predictability に二重に仕える。本文では*実行*を錨付けする: その語が現れるたびエージェントは同じ挙動に手を伸ばす。description では*呼び出し*を錨付けする: 同じ語があなたのプロンプト・docs・コードに住んでいれば、エージェントはその共有言語を skill に結び付け、より確実に発火させる。

skill を leading word でリファクタリングする機会を狩る。3 箇所で綴られた三つ組（**duplication**）、1 つの観念を身振りで示すのに 1 文を費やす description — どれも 1 トークンに**畳み込める**箇所だ。例:

- 「速く、決定的で、低オーバーヘッド」→ *tight* — 1 フェーズ内で言い換えられ続けた 1 つの性質を、事前学習済みの 1 語に畳む（*tight* なループ）
- 「信じられるループ」→ *red* — 曖昧なゲートを二値の観測可能状態に変換する（ループがバグで*赤くなる*か、ならないか）

二重に勝てる: トークンが減り、*かつ*エージェントが思考を掛けるフックが鋭くなる。どの skill も leading word で退役させられる言い換えを抱えていると仮定して探しに行く。

## 失敗モード

ユーザーが skill で困っているとき、これで診断する。

- **premature completion** — 本当に終わる前に step を終える。注意が*終わったことにする*方へ滑る。防御は順に: まず completion criterion を研ぐ（安く、局所的）。それが本質的に曖昧で、*かつ*実際に急ぎを観測したときだけ、分割（sequence で切る）で後続 step を隠す
- **duplication** — 同じ意味が複数の場所にある。保守とトークンを浪費し、意味の梯子上の目立ちを実際の順位より膨らませる
- **sediment** — 追加は安全に感じ、削除はリスクに感じるせいで沈殿する古い層。pruning の規律を持たない skill の既定の末路
- **sprawl** — 全行が生きていて重複も無いのに、単に長すぎる skill。可読性・保守性を損ないトークンを浪費する。治療は梯子: **reference** を pointer の先に外出しし、branch や sequence で切って各経路が必要なものだけを運ぶようにする
- **no-op** — モデルがデフォルトでやることを命じる行。何も言わないために load を払っている。テスト: デフォルト挙動と比べて何かを変えるか？ 弱い leading word（エージェントがそこそこ徹底的なのに *be thorough*）は no-op で、直し方は別の技法ではなく、より強い語（*relentless*）
- **negation** — 禁止による操縦は裏目に出る: 「象を考えるな」は象を名指しし、*より*想起させる。**肯定形**でプロンプトする — 目標挙動を記述し、禁じたい挙動を口にしない。肯定形で言い換えられないハードな guardrail だけが禁止形に値し、その場合も「代わりに何をするか」を併記する

---

*出典: [mattpocock/skills](https://github.com/mattpocock/skills) の `writing-great-skills`（MIT License）を日本語化。原典は user-invoked（`disable-model-invocation: true`）だが、本プロジェクトでは親が skill を書く頻度が高いため model-invoked に変更。GLOSSARY.md は用語定義の精度維持のため原文のまま同梱。*
