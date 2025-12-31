# ⚠️ CRITICAL: Mandatory Pre-Confirmation Review Gate

**YOU MUST FOLLOW THIS SEQUENCE EVERY TIME:**

```
┌─────────────────────────────────────┐
│ 1. Complete implementation/design   │
├─────────────────────────────────────┤
│ 2. STOP - Do NOT ask user yet      │
├─────────────────────────────────────┤
│ 3. Run codex-review SKILL           │
│    (automatic, no user trigger)     │
├─────────────────────────────────────┤
│ 4. Fix blocking issues (loop)       │
├─────────────────────────────────────┤
│ 5. Achieve ok: true status          │
├─────────────────────────────────────┤
│ 6. NOW present to user with review  │
└─────────────────────────────────────┘
```

## When to Trigger (Automatic Detection)

Run `codex-review` SKILL **automatically before** asking for user confirmation in these situations:

- After creating design documents
- After creating implementation plans (PLANS.md)
- After completing code implementation
- Before `git commit`
- Before creating PR
- Before saying "これでいいですか?" or "確認してください"

## Forbidden Patterns

**NEVER DO THIS:**
- ❌ Complete implementation → "これでいいですか?" (NO codex-review)
- ❌ Skip codex-review and ask user directly
- ❌ Present to user with blocking issues remaining

**ALWAYS DO THIS:**
- ✅ Complete implementation → codex-review → Fix issues → ok: true → "Codexレビュー完了、これでいいですか?"

## Self-Check Before User Confirmation

Before presenting ANYTHING to user, verify:
```
[ ] Did I run codex-review SKILL?
[ ] Did I fix all blocking issues?
[ ] Is review status ok: true?
[ ] Did I include review summary in my response?
```

If ANY checkbox is unchecked → Run codex-review first, then present.

## Presentation Format to User

When presenting after successful review:

```markdown
## [タイトル] ✅

[実装・設計内容の説明]

### Codexレビュー結果
- **ステータス**: ✅ ok
- **反復回数**: 2/5
- **修正項目**:
  1. [修正内容1]
  2. [修正内容2]
- **Advisory(参考)**: [任意対応の指摘があれば]

この内容で進めてよろしいですか?
```

When blocking issues remain after max iterations:

```markdown
## [タイトル] ⚠️

[内容説明]

### Codexレビュー結果
- **ステータス**: ⚠️ 未解決issue残存
- **反復回数**: 5/5 (上限到達)

### 未解決のBlocking Issues
1. `file.py:42-45`
   - **問題**: [問題の説明]
   - **推奨**: [推奨される対応]

これらを解決してから進めるべきですが、どうしますか?
```

---

# Development Philosophy

## Test-Driven Development (TDD)

- As a general rule, development is done using Test-Driven Development (TDD)
- Begin by writing tests based on expected inputs and outputs
- Do not write any implementation code at this stage—only prepare the tests
- Run the tests and confirm that they fail
- Commit once it's confirmed that the tests are correctly written
- Then proceed with the implementation to make the tests pass
- During implementation, do not modify the tests; keep fixing the code
- Repeat the process until all tests pass

---

# Core Rules

- Please make sure to consult the user whenever you plan to use an implementation method or technique that hasn't been used in other files
- For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially

---

# Library Installation Policy

**NEVER add or download libraries without explicit user permission.**

This includes but is not limited to:
- `go mod download` / `go get`
- `yarn add` / `npm install` / `npm i`
- `pip install`
- `composer install`
- `bundle install`
- Any other package manager commands

**Exception:** If a library is absolutely necessary for the task, you MUST ask the user for permission first before installing or adding any dependencies.

---

# Frontend Development Rule

- Avoid creating a new component if the requirement can be met with minor modifications to an existing component

---

# Codex Collaboration Framework

## Role Division
- **Claude Code**: Implementation, orchestration, user interaction
- **Codex**: Review (read-only sandbox), design consultation, debugging assistance

## When to Involve Codex

### 1. Automatic Review (via codex-review SKILL)
- **ALWAYS** before user confirmation (mandatory)
- After design/implementation completion
- Before git commit/PR

### 2. Design Consultation (via codex-design SKILL)
- Complex architectural decisions
- Introducing new patterns not used in codebase
- Performance-critical implementations
- 3+ architectural options to choose from

### 3. Collaborative Debugging
- Stuck on same issue for 15+ minutes
- 3+ different approaches tried without success
- Unclear error messages requiring deep analysis

## Collaboration Protocol

```
┌────────────────────────────────────────────┐
│ Claude Code: Draft implementation          │
├────────────────────────────────────────────┤
│ Codex: Review in read-only sandbox         │
├────────────────────────────────────────────┤
│ Claude Code: Fix blocking issues           │
├────────────────────────────────────────────┤
│ Codex: Re-review (iterate until ok: true)  │
├────────────────────────────────────────────┤
│ Claude Code: Present to user with summary  │
├────────────────────────────────────────────┤
│ User: Final approval                       │
└────────────────────────────────────────────┘
```

## Context Optimization Strategy

- **Skills**: Keep only summaries in main context, load details on execution
- **Subagents**: Use separate context windows for parallel processing
- **Codex**: Offload deep analysis to reduce Claude Code context consumption
- **Results**: Only return concise summaries to main context

---

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
- **codex-review**: 実装完了時の自動レビュー

## 実装戦略

### 1. タスク管理
- TodoWriteツールで全タスクを事前に分解・記録
- 各タスクに推定時間を設定(最大30分/タスク)
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
  - **codex-reviewを通過しているか**

### 4. AI エージェントとの協調作業
- **設計相談**: 複雑な設計判断が必要な場合
  - `codex-design` SKILLで設計方針を相談
- **コードレビュー**: 実装完了後(自動)
  - `codex-review` SKILLで品質チェック
  - フィードバックを受けて改善
- **問題解決**: エラーや予期しない動作の場合
  - Codexと協調デバッグセッション
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
  - Codexレビュー: ✅ ok (反復: 2/5)

## 未完了タスク
- [ ] タスク名: 理由と推奨アクション

## 発生した問題
- 問題の詳細と試みた解決策

## Codexレビューサマリ
- 総レビュー回数: 5回
- 平均反復: 2.4/5
- 未解決issue: なし

## 次のステップ
- 推奨される次のアクション
```
