---
name: grilling-on-artifact
description: grilling（設計ツリーに沿って質問を重ね、計画や設計を詰める対話）を、ターミナルではなく claude.ai の artifact 上の質問票で行う。Claude が質問票ページを publish し、ユーザはブラウザで選択肢・自由記述で回答して送信ボタンを押す。送信は Claude セッションに通知され、Claude は次のラウンドの質問を同じページに追加していく。「artifact で grill して」「質問票で詰めて」「ブラウザで回答したい」「grilling を TUI 以外で」「grill-on-artifact」などと言われたとき、または grilling を始める場面で質問が多くなりそうでターミナルでの回答がつらいとユーザが示したときに必ず使う。
---

# grilling-on-artifact

`mattpocock-skills:grilling` の進め方（設計ツリー・frontier・推奨回答つきのラウンド）はそのまま使い、**質問の提示と回答の受け取りだけを artifact に移す**ラッパー。ターミナルで長い質問に番号で答えるのはつらいので、ブラウザ上のフォームで答えてもらう。

## 仕組み（なぜこの構成か）

- **ページは 1 回だけ publish する。** 質問と回答はすべて artifact の `db` に置き、ページは `onSnapshot` で購読している。Claude が ArtifactData で次のラウンドを書き込めば、ページは再読み込みなしで更新される。毎ラウンド HTML を作り直す必要はない。
- **回答の送信は「db 保存 + Claude 宛てコメント」の 2 段構え。** ページは回答を db に保存してから、`comments.sendToClaude()` で「Round N の回答を送信しました」という短い合図を送る。この合図が、アイドル中のこのセッションを起こす唯一の経路になる。artifact の再 publish ではセッションは起きない。合図のコメントは 4KiB 上限なので回答本文は載せず、正本は db とする。
- コメントが届くと、platform が「届きました」という自動返信をスレッドに先に投稿する。Claude が同じ趣旨で返信すると重複として拒否されるため、返信はしない。

ページのテンプレートは `assets/grill.html` にある。中身を読む必要はないが、db のスキーマ（後述）はこのページと一致させること。

## 文章より図を優先する

ターミナルから artifact に移す最大の理由は、**文章だけだと見づらい**ことにある。文字ばかりの質問票では移した意味がない。質問を書くたびに「これは図で見せられないか」をまず考え、できるだけ図を使う。

- **選択肢が構成やフローの違いなら、選択肢ごとに図を付ける**（`optionDiagrams`）。A 案と B 案の図が並べば、文章で差分を説明するより速く伝わる。
- 前提となる現状（いまの構成、データの流れ、画面遷移、状態遷移、時系列）は、質問本文に図を付けて示す（`diagram`）。
- ラウンドの冒頭では、設計ツリーの現在地（決まったこと、いま聞いていること、まだ先のこと）を図にしてよい（`prefaceDiagram`）。
- 合意内容のまとめにも、最終形の全体像を 1 枚添える（`summaryDiagram`）。
- 図を付けた分、`body` の文章は削る。図の説明を文章で繰り返さない。本文は 2〜3 文が目安。

図の種類や描き方に決まりはない。内容に合うもの（構成図、フロー、シーケンス、比較表、ラフな画面スケッチなど）を選ぶ。

図は **SVG 文字列**で db に書く。ページはそれを `<img>` として表示するので、SVG は次の条件を満たす必要がある。
- 外部ファイルを参照しない自己完結した SVG にする（`xmlns="http://www.w3.org/2000/svg"` と `viewBox` を付け、フォントは `font-family="sans-serif"` 程度にする）
- img として読み込まれた SVG には、ページの CSS もテーマ設定も届かない。ページは図を常に**白地**の上に表示するので、SVG は**ライト配色だけ**で描く（濃い文字・線、淡い塗り）。ダークモード用の色分けは書かない。背景は透明のままでよい。
  ```svg
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 200" font-family="sans-serif" font-size="14">
    <rect x="20" y="20" width="160" height="60" rx="6" fill="#eef2fb" stroke="#2c56c9"/>
    <text x="100" y="55" text-anchor="middle" fill="#1b2130">API Gateway</text>
    ...
  </svg>
  ```
- 横幅いっぱいに縮尺表示される。スマホ幅でも読めるよう、文字を詰め込みすぎない。
- db の 1 ドキュメントは 256 KiB が上限で、図はラウンドのドキュメントに入る。1 枚は数 KB〜数十 KB に収め、1 ラウンドの合計が上限に近づかないようにする（不要な属性や座標の小数を削る）。

## 手順

### 1. grilling の方法論を読み込む

Skill ツールで `mattpocock-skills:grilling` を呼び出す。質問の作り方、frontier の決め方、事実はサブエージェントで調べ判断だけをユーザに聞くこと、終わりの条件は、すべてそちらに従う。

ただし **「Format a round like so」の Markdown 形式は使わない**。ラウンドは下記スキーマの JSON として db に書く。対応関係は次のとおり。

| grilling | このスキル |
|---|---|
| `❓ **Q1** - **<title>**: <body>` | `questions[].id` / `title` / `body` |
| 複数の選択肢 | `questions[].options`（任意） |
| `➡️ <recommended>` | `questions[].recommended` |
| ユーザの回答を待つ | ターンを終える（ページからの合図で再開する） |

### 2. 質問票ページを用意する

1. テンプレートをスクラッチパッドにコピーし、`__TITLE__` を議題名に置き換える。議題名は 2〜4 語程度の名前にする（例: `認証基盤の移行方針`）。ファイル名は議題ごとに変える。同じパスで publish すると前の質問票を上書きしてしまうため。
   ```bash
   mkdir -p <scratchpad>/grilling-on-artifact
   sed 's/__TITLE__/認証基盤の移行方針/g' <このスキルのディレクトリ>/assets/grill.html > <scratchpad>/grilling-on-artifact/auth-migration.html
   ```
   置換先は HTML の `<title>` と `<h1>` なので、議題名からは `< > & " '` と sed の区切り文字 `/` を取り除いておく。見出しは後で `meta/session.topic` の値で描き直されるが、`<title>` は置換した文字列がそのまま残る。
2. Artifact ツールで publish する。
   - `capabilities: {"db": {}, "comments": {}}`
   - `icon: "chat"`
   - `description` には議題を 1 文で書く
3. 最初のラウンドを書き込む前に `meta/session` を作る（ArtifactData `set`）。
   ```json
   { "topic": "認証基盤の移行方針", "status": "asking" }
   ```
4. `rounds/r01` に第 1 ラウンドを書く（スキーマは後述）。
5. `ArtifactComments` の `action: "watch"`（url なし）で watch の一覧を見て、この artifact の行が **auto-replies armed** になっていることを確かめる。publish 直後はまだ接続中のことがあるので、armed でなければ同じ一覧取得をもう一度だけ行う。それでも armed でなければ、合図では起きられないものとして扱う（次の案内を参照）。
6. ターミナルにはリンクと短い案内だけを出して、**ターンを終える**。
   - armed の場合: 「回答を送信すると自動で続きを出します。最初の送信時にコメント投稿の許可を聞かれるので許可してください」。この許可は artifact ごとに最初の書き込み時にしか聞かれず、そこで閉じるとそのページを開いている間は通知できなくなるため、先に伝えておく。
   - armed でない場合: 「送信後、ターミナルで『回答した』と一言ください」（合図でセッションが起きないため）

ポーリングやスリープで待たない。合図が届けばこのセッションに通知が来る。

### 3. 回答を受け取って次のラウンドを出す

再開のきっかけは 2 通りある。

- 通知（artifact のコメントスレッドへの自動返信の知らせ）が届いた
- ユーザがターミナルで「回答した」などと言った

どちらの場合も同じ流れで進める。

1. ArtifactData `list` で `rounds` を読む。「最新ラウンド」は `n` が最大のドキュメントのこと。`list` は ID 順で返すが、ID はゼロ埋めなので順序は `n` と一致する。その `answers` を取り出し、`version` も控えておく。
   - 最新ラウンドに `answers` がまだ無い場合: 保存が遅れている可能性があるので一度だけ読み直す。それでも無ければ、ユーザにターミナルで状況を伝えて待つ。
2. 通知で起きた場合は、そのスレッドを `ArtifactComments` の `resolve` で閉じる。返信はしない。
3. 回答を解釈する。
   - `choice: "recommended"` → 推奨回答を採用
   - `choice: "option"` → `option` の文字列を採用
   - `choice: "other"` → `note` が回答本体
   - どの選択でも `note` があれば必ず読む。補足、質問、反論が入っている。質問や反論には次のラウンドの `preface` で答える。納得できない反論は鵜呑みにせず、根拠を添えて推奨を維持してよい。
4. grilling に従って frontier を再計算し、次のラウンドを `rounds/rNN`（2 桁ゼロ埋め）に `set` で書く。
5. ターミナルには「Round N を出しました（k 問）」程度の 1 行だけを出して、ターンを終える。議論の中身はページに書く。ターミナルに同じことを書くと、TUI でのやりとりを避けたいという目的に反する。

ユーザがページではなくターミナルで回答してきた場合も受け付ける。その場合は回答を自分で `rounds/rNN` の `answers` に書き込んでおく。書き込みは `update` で行い、手順 1 で控えた `version` を `if_version` に渡す。こうしておくと、ページの決定ログが実際の経緯と食い違わない。

送信ごとにコメントスレッドが 1 本増える。resolve して閉じれば表示は散らからないが、artifact のスレッド数には上限がある。数十ラウンドに及びそうな場合は、論点を分けて別の質問票にすることを提案する。

### 4. 合意内容の確認と終了

frontier が空になったら（grilling の終了条件）:

1. `meta/session` を `get` して `version` を取り、それを `if_version` に渡して `update` する。
   ```json
   {
     "status": "concluding",
     "conclusionNote": "（任意）全体の要約や前提を 1〜3 文で",
     "summary": [ { "title": "認証方式", "decision": "OIDC に一本化。既存セッションは 30 日で失効" } ]
   }
   ```
   `summary` には確定した判断をすべて並べる。後から spec などに起こせる粒度で書く。
2. ページには「この内容で確定」と「この点を詰めたい」のボタンが出る。ユーザが押すと `meta/session.finalFeedback = { confirmed, text, at }` が保存され、合図が届く。
3. 合図を受けたら、そのスレッドを resolve する（返信はしない）。続けて `meta/session` を `get` する。`finalFeedback.text` は、確定・追加要望のどちらでも必ず読む。確定と同時に「ただし○○は後で再検討」のような補足が書かれていることがある。
   - `confirmed: true` → `if_version` を付けて `status: "done"` に更新する。ターミナルに合意内容の要約（summary の箇条書き）を出し、`text` があればそれも添えて終える。ここで初めて grilling の「shared understanding に達した」扱いになる。呼び出し元のフロー（spec 化など）があればそこへ戻る。
   - `confirmed: false` → `text` をもとに追加のラウンドを作る。ArtifactData `batch` で次の 2 つを 1 回で書く。
     - `rounds/rNN` の新規 `set`
     - `meta/session` の `update`（`if_version` 付き）。内容は `{"status": "asking", "finalFeedback": {"__delete__": true}}`

     finalFeedback を消さないと、次の確認画面に古いフィードバックが残ってしまう。

## db スキーマ

ページはこの形を前提に描画する。フィールド名を変えるとページが壊れる。

### `meta/session`

| フィールド | 型 | 書く人 | 意味 |
|---|---|---|---|
| `topic` | string | Claude | 見出しに出す議題名 |
| `status` | `"asking"` \| `"concluding"` \| `"done"` | Claude | ページの表示モード |
| `summary` | `{title, decision}[]` | Claude | 合意内容（concluding 以降） |
| `conclusionNote` | string | Claude | 合意内容の前置き（任意） |
| `summaryDiagram` | `{svg, caption?, alt?}` | Claude | 合意内容の全体像の図（任意） |
| `finalFeedback` | `{confirmed: boolean, text: string, at: string}` | ページ | 確定 / 追加要望 |

### `rounds/rNN`

```json
{
  "n": 2,
  "preface": "前ラウンドの Q3 の補足について: ……（任意。ユーザの質問・反論への返答や、調査結果の共有）",
  "prefaceDiagram": { "svg": "<svg ...>…設計ツリーの現在地…</svg>", "caption": "決定済み 4 / 今回 2 / 未着手 3" },
  "questions": [
    {
      "id": "Q5",
      "title": "既存セッションの扱い",
      "body": "移行時に既存のセッション Cookie をどう扱うか。\n\n- 即時失効させると全員が再ログインになる\n- 並行稼働させると 2 方式の検証コードが残る",
      "diagram": { "svg": "<svg ...>…現在のセッション管理の構成…</svg>", "caption": "現状: Cookie セッションと OIDC が並存", "alt": "…" },
      "options": ["即時失効", "30 日の猶予期間を設けて失効", "期限なしで並行稼働"],
      "optionDiagrams": [ { "svg": "<svg ...>…</svg>" }, { "svg": "<svg ...>…</svg>" }, null ],
      "recommended": "30 日の猶予期間を設けて失効（再ログインの集中を避けつつ、旧コードを期限付きで消せる）"
    }
  ],
  "answers": { "Q5": { "choice": "option", "option": "即時失効", "note": "社内ツールなので再ログインは問題ない" } },
  "answeredAt": "2026-11-16T09:21:03.493Z"
}
```

- `n` は 1 から連番にする。ページは `n` の昇順で並べる。
- `questions` は 1 問以上にする。0 問のラウンドは、何も聞かずに送信できてしまう。
- `id` はラウンドをまたいで通し番号にする（Q1, Q2, … Q5, …）。決定ログで一意に参照できるようにするため。
- `body` と `preface` は軽量 Markdown として描画される。使えるのは空行区切りの段落、`- ` の箇条書き、`` `code` ``、`**太字**` だけ。表や見出しは描画されない。
- `recommended` は 1〜2 文にし、理由を括弧で添える。ページでは「推奨」欄にそのまま出る。
- 図のフィールドは `diagram`（質問本文）、`optionDiagrams`（`options` と同じ順・同じ長さの配列。図の無い選択肢は `null`。長さがずれると別の選択肢に図が付いて見える）、`prefaceDiagram`（ラウンド冒頭）がある。どれも形は `{svg, caption?, alt?}`。`alt` には図の要点を 1 文で書く。
- `options` は選択肢があるときだけ付ける。推奨と同じ内容を選択肢にも入れてよい。ページには常に「推奨どおりでよい」と「その他（補足欄に書く）」の選択肢が出る。
- `answers` と `answeredAt` はページが書く。Claude は新しいラウンドを書くときに含めない。
- 既存ドキュメントへの書き込み（`update` や `set` の上書き）には、直前に読んだ `version` を `if_version` に渡す。

## 注意

- watch を持てるのはメインのセッションだけで、サブエージェントは持てない。このスキルはメインのループで実行する。
- `claude --resume` で再開すると、コメントに返信していた watch は通常復元される。復元されていなければ、`ArtifactComments` の `action: "watch"` に artifact の url を渡して張り直す。
- ページは非公開（オーナーのみ閲覧可）で publish される。他の人にも答えてもらう場合は、ユーザ自身がページの Share メニューで共有する必要がある。
