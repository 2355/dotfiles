---
name: create-pr
description: PR を作成する。現在のブランチからデフォルトブランチに向けて PR を作成し、PR テンプレートをベースに概要欄を記入する。ユーザが「PR作って」「プルリク作成して」「PR出して」などと言った場合や、Issue 番号を指定して PR 作成を依頼された場合にこのスキルを使用する。
argument-hint: "[issue-url or issue-number]"
---

$ARGUMENTS を元に PR を作成してください。

## 手順

1. 現在のブランチとデフォルトブランチを確認する
   - `gh repo view --json defaultBranchRef -q '.defaultBranchRef.name'` でデフォルトブランチを取得する
   - 現在のブランチがデフォルトブランチと同じ場合はエラーとする

2. PR テンプレートを取得する
   - リポジトリの `.github/PULL_REQUEST_TEMPLATE.md` を Read ツールで読む
   - テンプレートが存在しない場合はデフォルトの構成（Summary, Issues, etc.）で作成する

3. $ARGUMENTS が与えられた場合
   - Issue の情報を `gh issue view` で取得する
   - PR タイトルは Issue と同じタイトルにする
   - テンプレートの Issues 欄に $ARGUMENTS の issue-url を記入する

4. $ARGUMENTS が与えられていない場合
   - `git log` でデフォルトブランチとの差分コミットを確認する
   - コミット内容から適切な PR タイトルを生成する

5. PR 本文を作成する
   - テンプレートをベースに、コミット内容やコード差分を読み取って概要欄を記入する
   - `git diff <default-branch>...HEAD` で変更内容を把握する
   - 本文には以下の観点を明記する
     - **コード差分の要約**: 何をどう変えたか
     - **設計の意図**: なぜこの構造にしたか
     - **トレードオフの判断**: 何を捨てて何を取ったか
     - **変更の影響範囲**: この変更がどこに波及するか

6. PR を作成する
   - `gh pr create` コマンドで PR を作成する
   - 作成後、PR の URL をユーザに報告する
