# CLAUDE.md

## Important Rules

- 常に日本語で会話する
- 質問に対しては作業で返さず、まずは回答する
- 推論で仕様を語らず、必ず根拠を示す
- ユーザの指摘を無条件に受け入れない

## Shell Command Execution

- 現在の作業ディレクトリ配下のファイルを操作する際、極力 `cd` や `git -C <絶対パス>` を使わない
  - 不要な permission prompt が発生するため
  - cwd が既にプロジェクト内であれば、`git` や各種コマンドは cwd を基準に動作するので prefix は不要
  - 別ディレクトリで作業する必要があるときのみ `cd` / `git -C` を使う

## GitHub Operations

- GitHubのリソース（リポジトリ、Issue、PR、コード等）を取得する際は、常に gh command を使用する

## Code Style Guidelines

- コードコメントには why を書く
  - what はどうしても見通しが悪い場合にのみ書く
  - セッション文脈の持ち込み禁止。コードだけ読む人に通じるように書く
- 不要な空白は削除する
- 新規ファイルを作成する際は必ず末尾に改行を足す

## Development Philosophy

- t-wada TDD に従い実装を行う

## Auto Review

- コードの実装が一段落したら、ユーザに結果を報告する前にサブエージェントを呼び出しセルフレビューを行う
- レビューで問題が見つかった場合は自分で修正してから報告する

## Commit rules

- コミットメッセージは `<type>: <summary>` の形式で書く
- type には以下のいずれかを使用する
  - feat: 新機能追加
  - fix: バグ修正
  - docs: ドキュメントの更新
  - refactor: リファクタリング
  - perf: パフォーマンス改善
  - test: テストの追加・修正
  - build: ビルド関連の変更
  - ci: CI/CD関連の変更
  - chore: その他の変更
- summary には（可能であれば変更理由も含めて）変更内容を1行程度に簡潔に記載する

## Git Operations

- 自動的にプッシュを行わない

## User 特性

- ユーザは TypeScript/Node.js/React に精通しているが、他言語にはあまり詳しくないので、他言語のコードの説明を求められた際はユーザが得意とする言語と比較しながら説明すること
