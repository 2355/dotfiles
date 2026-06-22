---
name: create-pr
description: PR を作成する。現在のブランチから base ブランチ（ユーザに選択させる）に向けて PR を作成し、PR テンプレートをベースに概要欄を記入する。ユーザが「PR作って」「プルリク作成して」「PR出して」などと言った場合や、Issue 番号を指定して PR 作成を依頼された場合にこのスキルを使用する。
argument-hint: "[issue-url or issue-number]"
---

$ARGUMENTS を元に、現在のブランチから draft PR を作成する。

## 手順

1. **前提を確認する**
   - `gh repo view --json defaultBranchRef -q '.defaultBranchRef.name'` でデフォルトブランチを取得する
   - 現在ブランチがデフォルトブランチと同じならエラーで終了する
   - 現在ブランチがリモートに無い、あるいはローカルが先行している場合は `git push -u origin HEAD` で push する

2. **base ブランチをユーザに確認する**
   - `gh pr list --state all --limit 50 --json baseRefName -q '.[].baseRefName' | sort | uniq -c | sort -rn` で過去 PR の base ブランチを使用頻度順に取得する
   - デフォルトブランチを先頭に、過去に使われた branch を頻度順で並べた選択肢を AskUserQuestion で提示する（最大 4 つ、デフォルトブランチには「(Recommended)」を付ける）
   - 候補が 4 つを超える場合は上位 3 つ + 「Other」（手入力）の構成にする
   - 過去 PR が無い場合はデフォルトブランチのみを提示する
   - ユーザが選択した branch を以降の手順で base として使う

3. **PR テンプレートを取得する**
   - `.github/PULL_REQUEST_TEMPLATE.md` を Read ツールで読む
   - 無ければ「概要 / 関連 Issue」の最低限の枠組みを自分で組む

4. **PR タイトルを決める**
   - `$ARGUMENTS` あり: `gh issue view <issue>` で取得した Issue タイトルをそのまま使う
   - `$ARGUMENTS` なし: `git log <base-branch>..HEAD` のコミット内容からタイトルを生成する

5. **PR 本文を書く**
   - `git diff <base-branch>...HEAD` で差分を確認する
   - テンプレートのセクションを埋める。書き方は後述の「本文の指針」に従う
   - `$ARGUMENTS` あれば Issues 欄に Issue URL を記入する

6. **PR を作成する**
   - `gh pr create --draft --base <base-branch>` で draft PR として作成する
   - 作成後、PR の URL をユーザに報告する

## 本文の指針

### 書くこと — 「意図 / 判断」の粒度

- **コード差分の要約**: 何をどう変えたか
- **設計の意図**: なぜこの構造にしたか
- **トレードオフの判断**: 何を捨てて何を取ったか
- **変更の影響範囲**: この変更がどこに波及するか

### 書かないこと — diff に委ねる

「diff を見れば書いてあること」は本文に書かない。個別ファイル名のリスト、関数内部の実装詳細、コード構造の Before / After などは diff 側に委ねる。

### 「レビューしてほしい観点」セクションがある場合

レビュー観点として残すのは、人間の判断 / 経験が必要な事項だけ。grep / Read で確定できることは PR 本文を書く前に自分で調査し、確認済みの事実として本文中に記載する。残った設計判断やトレードオフをレビュー観点に書く。
