# 週次振り返り（KPT）を作成する

先週月曜〜日曜の `~/work/nippo/` の日報・GitHub PR・Jira issue を集約し、KPT（Keep / Problem / Try）形式の振り返りを `~/work/nippo/{先週月曜の日付}-week.md` に書き出す。

引数で開始日（月曜）を指定可能。例: `/nippo-weekly-retro 2026-06-01`。省略時は今日から見て直近の月曜始まりの週（＝先週）を対象にする。

## 実行内容

### Phase 1: 期間の決定

- `$ARGUMENTS` に `YYYY-MM-DD` 形式の月曜日付があればそれを開始日とする。なければ「今日を含むかどうかに関わらず直近で完了した月〜日の週」を計算する。
  - 例: 今日が 2026-06-08（月）なら 2026-06-01（月）〜2026-06-07（日）
  - 例: 今日が 2026-06-12（金）なら 2026-06-01（月）〜2026-06-07（日）
- 開始日（月）と終了日（日）を以後 `START` / `END` として保持する。

### Phase 2: データ収集（並列）

以下を並列実行する。

1. **日報の読み込み**
   - `~/work/nippo/YYYY-MM-DD.md` のうち `START`〜`END` の範囲のファイルを Read する。存在しない日付はスキップ（後段でも警告しない）。
2. **GitHub PR の検索**
   - `gh search prs --author=@me --updated=${START}..${END} --json number,title,url,state,repository,createdAt,updatedAt,closedAt --limit 50`
   - ※ `mergedAt` は `gh search prs` の対応外。代わりに `state` と `closedAt` を見る。
3. **Jira issue の検索**
   - `mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql` を使う。
   - JQL: `assignee = currentUser() AND updated >= "${START}" AND updated <= "${END}" ORDER BY updated DESC`
   - cloudId は `mcp__claude_ai_Atlassian__getAccessibleAtlassianResources` で取得（複数ある場合は `oned.atlassian.net` を優先）。

### Phase 3: ユーザへの提示と対話

集約データをユーザに提示してから、Keep / Problem の候補を `AskUserQuestion` で聞く。

- 提示する内容:
  - **開発タスク表**（Jira / 内容 / PR / state）。Jira キーがあれば PR タイトル等から抽出して該当 issue と紐付ける（PR タイトル先頭の `DEV-XX` / ブランチ名・本文に含まれる Jira キー）。
  - PR タイトルに Jira キーが含まれない PR は **別表（「その他の PR」など）** に分ける。
  - 日報から拾った学びの一覧（後で詳細化する）。
- `AskUserQuestion` で Keep / Problem の候補を multi-select で聞く。候補は実績から自動抽出する（例: 「N タスク中 M 件 merge 完了」「open のまま残った PR」「nippo に書かれた所感」など）。
- **Problem 項目は深堀りする**: 「なぜそうなったか」「再発防止のヒント」を 1〜2 問追加で聞き、Try の素材にする。

### Phase 4: 出力ファイルの生成

`~/work/nippo/{START}-week.md` に以下の構造で Write する（既存ファイルがあれば上書きしてよいか確認）。

```markdown
# 週次サマリー {START} 〜 {END}

## やったこと

### 開発タスク（Jira / PR 紐付け）

| Jira | 内容 | PR | 状態 |
| --- | --- | --- | --- |
| [DEV-XXX](https://oned.atlassian.net/browse/DEV-XXX) | ... | [#NNNN](https://github.com/<owner>/<repo>/pull/NNNN) | merged / open |

### その他の PR（Jira 紐付けなし）

| 内容 | PR |
| --- | --- |
| ... | [#NNNN](...) |

## 学んだこと

（日報から拾ったトピックごとに H3 セクションを作る。各セクションは **後から見返しても何のことか分かる粒度** で 3〜6 行程度書く。「何を理解したか」だけでなく「なぜそうなっているか」「どこに効くか」まで含める）

### {トピック1}
- ...

### {トピック2}
- ...

## うまく行ったこと（Keep）

- ...

## 改善すべき点（Problem）

- **{要点}**
  - {状況}
  - {何がよくなかったか}

## トライ（Try）

- **{次にやること（具体的なアクション）}**
  - {誰に / いつ / どうやって}
```

### Phase 5: プレビュー → 承認 → commit & push

1. 生成したファイルのパスと内容のプレビュー（ファイルの中身そのもの）をユーザに提示する。
2. 「この内容で commit & push してよいですか？」と明示的に確認する。
3. 承認が取れた場合のみ以下を実行:
   - `cd ~/work/nippo`
   - `git add ~/work/nippo/{START}-week.md`
   - `git commit -m "{START}-week.md"`
   - `git push`
4. 承認が得られなかった場合は commit せずに終了し、ユーザの修正指示を待つ。

## 重要な作法

- **Jira キーは必ずリンク化する**。`DEV-XXX` 単体での記載は避け、`[DEV-XXX](https://oned.atlassian.net/browse/DEV-XXX)` の形にする。PR 番号も `[#NNNN](URL)` の形でリンクにする。
- **「学んだこと」は要約せず詳細に書く**。日報の生メモを引き写すのではなく、トピックごとに整理して、「読み返したときに当時の理解が再現できる」レベルまで書き起こす。圧縮しすぎない。
- **未作成の日報がある日は無視して進める**。代わりに PR / Jira の情報でカバーする。データが薄い日は無理にコメントを足さない。
- **Problem には必ず対応する Try を書く**。Problem だけ書いて Try を空にしない。
- **ユーザが追加した Other 項目は最優先で反映する**。AskUserQuestion で `Other` 経由で入った内容は、候補よりも本人の言葉に近いので原文を活かす。
- **作業中の進捗は短く 1 行ずつ報告する**。データ収集中はサイレントにしない。
- **commit & push はユーザの承認後にのみ行う**。承認前に勝手にコミットしない。
