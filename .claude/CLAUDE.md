# Workflow multiple execute

https://github.com/d-kuro/gwq
https://github.com/d-kuro/gwq?tab=readme-ov-file#multiple-ai-agent-workflow

# Development Philosophy

# Test-Driven Development (TDD)

- As a general rule, development is done using Test-Driven Development (TDD)
- Begin by writing tests based on the expected inputs and outputs
- Do not write any implementation code at this stage—only prepare the tests
- Run the tests and confirm that they fail
- Commit once it’s confirmed that the tests are correctly written
- Then proceed with the implementation to make the tests pass
- During implementation, do not modify the tests; keep fixing the code
- Repeat the process until all tests pass

# rule

- Please make sure to consult the user whenever you plan to use an implementation method or technique that hasn't been used in other files.
- For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially.

## Library Installation Policy

**NEVER add or download libraries without explicit user permission.**
This includes but is not limited to:

- `go mod download` / `go get`
- `yarn add` / `npm install` / `npm i`
- `pip install`
- `composer install`
- `bundle install`
- Any other package manager commands
  **Exception:** If a library is absolutely necessary for the task, you MUST ask the user for permission first before installing or adding any dependencies.

# Frontend Development Rule

- creating a new component if the requirement can be met with minor modifications to an existing component.

# 深夜自動実装モード (Overnight Auto-Implementation Mode)

## 目的
開発者が不在の深夜帯でも効率的に実装を進められるようにする

## 事前許可済み操作
以下の操作は明示的な許可なしに実行可能:
- **テスト実行**: `npm test`, `go test`, `pytest`, `cargo test` 等
- **ビルド**: `npm run build`, `go build`, `cargo build` 等
- **リント/フォーマット**: `npm run lint`, `golangci-lint`, `rustfmt`, `black` 等
- **型チェック**: `npm run typecheck`, `tsc --noEmit` 等
- **ファイル操作**: src/, tests/, lib/ 配下のファイルの作成・編集
- **git操作**: status, diff, log, branch (commit/pushは除く)
- **ドキュメント生成**: `npm run docs`, `go doc` 等

## 実装戦略

### 1. タスク管理
- TodoWriteツールで全タスクを事前に分解・記録
- 各タスクに推定時間を設定（最大30分/タスク）
- 詰まったタスクはスキップし、次のタスクへ進む

### 2. 進捗管理
- 1時間ごとに進捗をメモリーに保存
- 各チェックポイントで以下を記録:
  - 完了したタスク
  - 現在のタスク
  - 発生した問題
  - 次のアクション

### 3. 自己検証ループ
- 30分ごとに以下を確認:
  - 現在のタスクが元の目的に沿っているか
  - コードが既存のパターンに従っているか
  - テストが通っているか

### 4. AI エージェントとの協調作業
- **実装相談**: 複雑な設計判断が必要な場合
  - `cursor-agent`と実装方針を相談
  - `gemini`に代替アプローチを確認
- **コードレビュー**: 実装完了後
  - 両エージェントにコードレビューを依頼
  - フィードバックを統合して改善
- **問題解決**: エラーや予期しない動作の場合
  - エラー内容を共有して解決策を協議
  - 複数の視点から最適解を導出

### 5. エラーハンドリング
- エラー発生時は3回まで別アプローチで再試行
- 解決不能な場合は詳細なエラーログを残して次へ
- 朝の報告書に未解決事項として記載

### 6. 実装前チェックリスト
実装開始前に必ず確認:
- [ ] 仕様/要件が明確か
- [ ] テストケースが定義されているか
- [ ] 既存コードのパターンを理解したか
- [ ] ロールバック方法が明確か
- [ ] 必要なライブラリは既にインストール済みか

## 報告書フォーマット
朝の報告書には以下を含める:
```markdown
# 深夜実装レポート [日付]

## 完了タスク
- [x] タスク名: 結果の要約

## 未完了タスク
- [ ] タスク名: 理由と推奨アクション

## 発生した問題
- 問題の詳細と試みた解決策

## 次のステップ
- 推奨される次のアクション
```
