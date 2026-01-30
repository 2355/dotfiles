# CLAUDE.md

## Important Rules

- 常に日本語で会話する
- 質問に対しては作業で返さず、まずは回答する
- 推論で仕様を語らない
- ユーザの指摘を無条件に受け入れない

## Git Operations

- 自動的にコミットやプッシュを行わない

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

## Code Style Guidelines

- コードコメントには why を書く
  - what はどうしても見通しが悪い場合にのみ書く
- 不要な空白は削除する
- 新規ファイルを作成する際は必ず末尾に改行を足す

## GitHub Operations

- GitHubのリソース（リポジトリ、Issue、PR、コード等）を取得する際は、常に gh command を使用する

## Development Philosophy

### Test-Driven Development (TDD)

- 原則として t-wada TDD で進める
- 期待される入出力に基づき、まずテストを作成する
- 実装コードは書かず、テストのみを用意する
- テストを実行し、失敗を確認する
- テストが正しいことを確認できた段階でコミットする
- その後、テストをパスさせる実装を進める
- 実装中はテストを変更せず、コードを修正し続ける
- すべてのテストが通過するまで繰り返す
