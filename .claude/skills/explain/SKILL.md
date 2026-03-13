---
name: explain
description: GitHub URL を受け取り、該当コードが何をしているかを説明する。まずローカルファイルを確認し、存在しない場合のみ GitHub から取得する。
argument-hint: <github-url>
---

$ARGUMENTS の GitHub URL を解析し、該当コードを説明してください。

## 手順

1. URL からファイルパスと行範囲を抽出する
   - 例: `https://github.com/org/repo/blob/<ref>/path/to/file.rb#L12-L14` → `path/to/file.rb`, 行 12〜14
2. まずローカルファイルを Read ツールで読みに行く
   - ローカルに存在すればそちらを使う
   - 存在しない場合のみ `gh` コマンドで GitHub から取得する
3. 該当行のコードが何をしているかを説明する
   - ユーザの技術背景（TypeScript/Node.js/React に精通）を踏まえ、必要に応じて馴染みのある概念と対比して説明する
