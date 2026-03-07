---
name: codex-review
description: |
  MANDATORY quality gate. Run this skill BEFORE: (1) asking user "Is this okay?", (2) git commit, (3) creating PR, (4) presenting any implementation or design to user. Codex reviews in read-only sandbox, iterates until ok:true. NEVER skip this step.
---

# Codex Automatic Review Gate

## 🎯 Purpose

**自動レビューゲート**: Automatically executed before Claude Code asks for user confirmation.
Quality gate ensuring all blocking issues are resolved before presenting to user.

## 📋 Execution Flow

### Step 0: Pre-Review Analysis

```bash
# Determine scope of changes
git diff HEAD --stat
git diff HEAD --name-status --find-renames

# Identify changed files and line counts
# This determines review strategy (small/medium/large)
```

### Step 1: Scope-Based Review Strategy

| Scope | Criteria | Strategy |
|-------|----------|----------|
| small | ≤3 files, ≤100 lines | Single comprehensive review |
| medium | 4-10 files, 100-500 lines | Architecture review → Detailed review |
| large | >10 files, >500 lines | Architecture → Parallel detailed reviews → Cross-check |

### Step 2: Execute Codex Review

**Critical: Codex runs in read-only sandbox for safety**

```bash
codex exec -m gpt-5.4 --sandbox read-only "$(cat <<'EOF'
# Review Request

## Context
[Claude Code provides implementation summary in Japanese]

## Changed Files
[List of modified files with line counts]

## Review Focus Areas
- **Correctness**: Logic errors, edge cases, null handling
- **Security**: Vulnerabilities, input validation, authentication/authorization
- **Performance**: Bottlenecks, inefficient algorithms, resource leaks
- **Maintainability**: Code readability, consistency with existing patterns, comments
- **Testing**: Test coverage, test quality, missing test cases

## Previous Review Notes
[Notes from previous iteration, if any]

## Required Output Format (JSON only, in Japanese)

必ず以下のJSON形式で出力してください:

{
  "ok": boolean,  // blocking issue がなければ true
  "phase": "arch|detail|cross-check",
  "summary": "レビュー全体のサマリ(日本語)",
  "issues": [
    {
      "severity": "blocking|advisory",
      "category": "correctness|security|perf|maintainability|testing|style",
      "file": "path/to/file",
      "lines": "42-45",
      "problem": "問題の具体的な説明(日本語)",
      "recommendation": "修正案(コード例を含む、日本語)"
    }
  ],
  "notes_for_next_review": "次回レビュー時の引き継ぎ事項(日本語)"
}

**Severity Guidelines:**
- **blocking**: Must be fixed. Even one blocking issue → ok: false
- **advisory**: Recommended improvement. Does not affect ok status

**Category Definitions:**
- correctness: Logic errors, incorrect behavior
- security: Security vulnerabilities, unsafe practices
- perf: Performance issues, inefficiency
- maintainability: Code quality, readability, pattern consistency
- testing: Missing tests, inadequate coverage
- style: Code style, naming conventions (usually advisory)
EOF
)"
```

**Important: Wait for Codex completion**

- Poll every 60 seconds (max 20 times = 20 minutes)
- Progress log: `[Codexレビュー中] Poll 5/20 (経過時間: 5分)...`
- Do NOT proceed to other tasks while waiting
- On timeout: Split files and retry

### Step 3: Review Iteration Loop

```python
max_iterations = 5
current_iteration = 0

while current_iteration < max_iterations:
    # Execute Codex review
    review_result = execute_codex_review()

    if review_result["ok"] == True:
        # ✅ Review passed - proceed to user presentation
        break

    # Fix all blocking issues
    blocking_issues = [
        issue for issue in review_result["issues"]
        if issue["severity"] == "blocking"
    ]

    for issue in blocking_issues:
        # Claude Code fixes the issue
        fix_issue(issue)

    # Run tests if available
    run_project_tests()

    # Increment iteration counter
    current_iteration += 1

    # If tests fail twice consecutively, stop iteration
    if consecutive_test_failures >= 2:
        break

# After loop completion
if review_result["ok"]:
    present_to_user_with_success_summary()
else:
    present_to_user_with_unresolved_issues()
```

### Step 4: Large Scope - Parallel Subagent Reviews

When scope is "large" (>10 files, >500 lines):

**Split into groups:**
```
Group 1: Authentication related files (3 files)
Group 2: API layer files (4 files)
Group 3: Database layer files (5 files)
Group 4: UI components (4 files)
```

**Launch parallel Subagents:**
```javascript
// Launch 3-5 Subagents in parallel
const subagent_reviews = await Promise.all([
  launch_subagent({ group: 1, files: auth_files }),
  launch_subagent({ group: 2, files: api_files }),
  launch_subagent({ group: 3, files: db_files }),
  launch_subagent({ group: 4, files: ui_files })
]);

// Each Subagent executes Codex review independently
// Results are aggregated for cross-check
```

**Cross-check prompt (after parallel reviews):**
```
並列レビューが完了しました。以下の横断的な問題を確認してください:

## 各グループのレビュー結果
[Group 1 結果]
[Group 2 結果]
[Group 3 結果]
[Group 4 結果]

## 横断確認事項
- Interface consistency: APIインターフェースの整合性
- Error handling consistency: エラーハンドリングの一貫性
- Authorization coverage: 認可・認証の漏れ
- API compatibility: 既存APIとの互換性
- Cross-cutting concerns: ログ、監視、セキュリティの横断的実装

上記の観点で横断的なblocking issueがあれば指摘してください。
```

## 🚨 Error Handling

### Codex Timeout
1. Split files into half and retry
2. If retry also times out → Skip that section, document in report as "未レビュー"
3. Continue with remaining files

### Codex API Failure
1. Wait 5 seconds and retry once
2. If retry fails → Partial review with unreviewed sections clearly marked
3. Report error details to user

### Test Failures (after fixes)
- 2 consecutive test failures → Stop iteration
- Report test failures to user with context
- Let user decide whether to proceed

## 📊 Output Format to User

### Success Case (ok: true)

```markdown
## [実装内容のタイトル] ✅

[Claude Codeによる実装内容の説明]

### Codexレビュー結果
- **ステータス**: ✅ ok
- **反復回数**: 2/5
- **レビュー規模**: medium (7ファイル、280行)
- **修正項目**:
  1. `auth.py:42-45` - 認可チェックの追加 (security/blocking)
  2. `api.py:128` - nullチェック改善 (correctness/blocking)
  3. `utils.py:89` - エラーハンドリングの統一 (maintainability/blocking)

### Advisory(参考・任意対応)
- `main.py:67` - 関数名が冗長、リファクタ推奨 (style/advisory)
- `config.py:15` - マジックナンバーを定数化推奨 (maintainability/advisory)

### 未レビュー
- なし

この内容で進めてよろしいですか?
```

### Failure Case (ok: false after max iterations)

```markdown
## [実装内容のタイトル] ⚠️

[実装内容の説明]

### Codexレビュー結果
- **ステータス**: ⚠️ 未解決issue残存
- **反復回数**: 5/5 (上限到達)
- **レビュー規模**: small (2ファイル、150行)

### 未解決のBlocking Issues
1. `database.py:89-92` (security/blocking)
   - **問題**: SQLインジェクション脆弱性の可能性
   - **詳細**: ユーザー入力を直接クエリに埋め込んでいます
   - **推奨**: パラメータ化クエリまたはORMを使用してください
   - **対応方針**: [Claude Codeの判断・提案]

2. `auth.py:156-160` (correctness/blocking)
   - **問題**: トークン検証のロジックエラー
   - **詳細**: 期限切れトークンが通過する可能性があります
   - **推奨**: 期限チェックを追加し、テストケースで確認してください
   - **対応方針**: [Claude Codeの判断・提案]

### Advisory(参考)
- `utils.py:45` - ログレベルの見直し推奨 (maintainability/advisory)

これらの問題を解決してから進めるべきですが、どうしますか?
- [A] 問題を修正してから再レビュー
- [B] この状態で一旦確認
- [C] 特定のissueのみ対応
```

### Large Scope with Parallel Reviews

```markdown
## [実装内容のタイトル] ✅

[実装内容の説明]

### Codexレビュー結果
- **ステータス**: ✅ ok
- **反復回数**: 3/5
- **レビュー規模**: large (15ファイル、820行)
- **並列レビュー**: 4グループ、各グループ独立実行

#### グループ別レビューサマリ
1. **認証層** (3ファイル): 1回の修正でok
   - JWT検証ロジックの改善
2. **API層** (4ファイル): 2回の修正でok
   - エラーレスポンス形式の統一
   - 入力バリデーション追加
3. **DB層** (5ファイル): 3回の修正でok
   - トランザクション境界の修正
   - インデックス最適化
4. **UI層** (3ファイル): 1回でok
   - 軽微なアクセシビリティ改善

#### 横断チェック結果
- Interface整合性: ✅ 問題なし
- Error handling一貫性: ✅ 統一済み
- 認可カバレッジ: ✅ 完全
- API互換性: ✅ 破壊的変更なし

### 主な修正項目
1. トランザクション境界の適切な設定 (correctness/blocking)
2. 全APIエンドポイントへの入力バリデーション追加 (security/blocking)
3. エラーレスポンス形式の統一 (maintainability/blocking)

### Advisory(参考)
- いくつかの関数が長すぎる、分割推奨 (maintainability/advisory)

この内容で進めてよろしいですか?
```

## 🔧 Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| max_iterations | 5 | Maximum review-fix iterations |
| timeout_minutes | 20 | Codex wait timeout (20 polls × 60s) |
| parallel_max | 5 | Max parallel Subagents for large scope |
| auto_fix | true | Automatically fix blocking issues |
| poll_interval_seconds | 60 | Codex completion check interval |
| max_files_per_subagent | 5 | Files per Subagent in parallel mode |
| max_lines_per_subagent | 300 | Lines per Subagent in parallel mode |

## 🔗 Integration Points

### With PLANS.md
Automatically integrated into implementation milestones:

```markdown
## Phase 1: Authentication Implementation
- [ ] Implement OAuth2 flow
- [ ] Write tests
- [ ] **[AUTO]** codex-review gate ← Automatically inserted
- [ ] User confirmation

## Phase 2: API Development
- [ ] Implement REST endpoints
- [ ] Add input validation
- [ ] **[AUTO]** codex-review gate ← Automatically inserted
- [ ] User confirmation
```

### With Git Hooks (Optional)
Can be integrated with pre-commit hook:

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Check if already reviewed
if [ -f .codex-review-passed ]; then
  exit 0
fi

# Trigger Claude Code to run codex-review
# (Implementation depends on project setup)
```

## 📝 Internal Processing Notes

### Codex Prompt Construction
Claude Code constructs the prompt dynamically based on:
- Changed files and line counts
- Review phase (arch/detail/cross-check)
- Previous review notes
- Project-specific context

### Result Parsing
- Expect JSON output from Codex
- Validate JSON schema before processing
- Handle malformed responses gracefully
- Extract issues by severity for fixing

### Fix Priority
1. **Security** blocking issues (highest priority)
2. **Correctness** blocking issues
3. **Performance** blocking issues (if critical)
4. **Maintainability** blocking issues
5. **Testing** blocking issues
6. Advisory issues (document only, don't fix automatically)

## 📝 Plan Review Mode

When triggered from **ExitPlanMode** (via quality-gate Step 1), Codex reviews the **plan itself** instead of code changes.

### When to Trigger

- quality-gate detects plan mode exit
- Plan file has been written to `.claude/plans/{task-name}.md`

### Plan Review Prompt

```bash
codex exec -m gpt-5.4 --sandbox read-only "$(cat <<'EOF'
# Plan Review Request

## Plan Content
[Contents of .claude/plans/{task-name}.md]

## Review Focus Areas
- **実現可能性**: 計画は技術的に実現可能か？見落としている制約はないか？
- **リスク評価**: 潜在的なリスクや問題点は適切に特定されているか？
- **代替案**: より良いアプローチはないか？
- **影響範囲**: 変更の影響範囲は正確に把握されているか？副作用は？
- **依存関係**: ステップ間の依存関係は正しいか？順序は適切か？
- **テスト戦略**: テスト方針は十分か？

## Required Output Format (JSON only, in Japanese)

{
  "ok": boolean,
  "phase": "plan-review",
  "summary": "計画レビューのサマリ(日本語)",
  "issues": [
    {
      "severity": "blocking|advisory",
      "category": "feasibility|risk|alternative|scope|dependency|testing",
      "section": "計画内の該当セクション",
      "problem": "問題の具体的な説明(日本語)",
      "recommendation": "改善案(日本語)"
    }
  ],
  "suggestions": "計画の改善提案(日本語)"
}

**Severity Guidelines:**
- **blocking**: 計画に致命的な問題。修正が必要 → ok: false
- **advisory**: 改善推奨だが計画として進めることは可能
EOF
)"
```

### Plan Review Iteration

- If `ok: false`: Claude Code revises the plan, re-submits for review
- Max 3 iterations for plan review (lighter than code review)
- If plan passes, present to user for approval via ExitPlanMode

### Output to User (Plan Review)

```markdown
### Codex計画レビュー結果
- **ステータス**: ✅ ok / ⚠️ 要修正
- **反復回数**: 1/3
- **指摘事項**: [修正した項目のリスト]
- **改善提案**: [advisory項目のリスト]
```

## 🎯 Success Criteria

Review is considered successful when:
- ✅ `ok: true` received from Codex
- ✅ All blocking issues resolved
- ✅ Tests pass (if available)
- ✅ No timeouts or API errors
- ✅ Cross-check complete (for large scope)

After success, Claude Code can present to user with confidence.

## ⚠️ Important Reminders

1. **ALWAYS run before user confirmation** - This is mandatory
2. **Output in Japanese** - All user-facing text must be in Japanese
3. **Wait for Codex** - Do not proceed until review completes
4. **Fix blocking only** - Don't auto-fix advisory issues
5. **Document everything** - Include full review summary in user presentation
6. **Never skip** - Even if changes seem trivial, run the review
