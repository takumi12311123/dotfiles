---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(mkdir:*), Bash(cat:*), Bash(rm:*), Bash(touch:*), Bash(printf:*), Bash(echo:*), Bash(grep:*), Bash(awk:*), Bash(sed:*), Bash(jq:*), Bash(dirname:*), Bash(ls:*), Read, Write, Edit, Skill, AskUserQuestion, Task
description: 依頼 → 仕様合意 → TDD 実装 → 理解確認 → PR までフェーズ順に伴走する
argument-hint: "<チケット番号 / URL / やりたいことの説明>"
---

## Purpose

依頼から PR までを **フェーズ順に、ゲートで止まりながら** 進める。
各フェーズの中身は既存 skill が持つ。このコマンドの仕事は **順序とゲートの管理** だけ。

ゲートの成立条件・成果物形式は `.claude/rules/flow-gates.md` が単一の情報源。ここで再定義しない。

## Context

- Current branch: !`git branch --show-current`
- Status: !`git status --short`
- Specs: !`grep -l 'status: active' .claude/specs/*.md 2>/dev/null || echo "(none)"`
- Understanding record: !`ls .claude/pr-review/understanding-* 2>/dev/null || echo "(none)"`

## Phases

```
1-2. 仕様合意     spec-agree            ── Gate A で停止
3.   TDD 実装     test-generator → 実装 → quality-gate
4.   理解確認     user-scenario → explain-impl → grill-me  ── Gate B で停止
5.   PR           /pr (context-hygiene が BLOCKING)
6.   レビュー補足  prr 下書きの提示
```

**再入可能**: 既に成果物がある場合はそのフェーズを飛ばして続きから始める。
毎回どのフェーズにいるかを冒頭で宣言すること。

## Phase 1-2: 仕様合意 (Gate A)

```
Skill(skill="spec-agree")
```

引数（チケット番号 / URL / 説明）をそのまま渡す。GitHub issue 番号なら `gh issue view <番号>` で本文を取得してから渡す。

**Gate A** — 成立条件・digest 検証・spec の解決手順（ブランチ改名 / 複数タスク / detached HEAD）は
すべて `.claude/rules/flow-gates.md` の Gate A と「共通: 成果物のキーと再入性」に従う。
ここでは条件を再定義しない。

満たさないうちは **実装に着手しない**。スキップできるのはユーザーが明示したときだけ。

## Phase 3: TDD 実装

1. 受け入れ基準からテストを書く（**実装より先**）:
   ```
   Skill(skill="test-generator")
   ```
   spec の各 AC に対応するテストを作る。AC に無いテストを勝手に増やさない。
2. テストが落ちることを確認する（落ちないテストは検証になっていない）
3. 実装する。spec の非スコープに手を出さない
4. テストを通す
5. 品質ゲート:
   ```
   Skill(skill="quality-gate")
   ```
   `context-hygiene` がここで BLOCKING に効く（コードコメント / commit message）

**仕様とズレたら実装を勝手に変えない。** `spec-agree` に戻って spec を更新してから続ける。

## Phase 4: 理解確認 (Gate B)

順に実施する。目的が違うので 1 つで代替しない。

1. **仕様の再確認** — 実装が spec どおりか、利用者視点で何が変わったか:
   ```
   Skill(skill="user-scenario")
   ```
   spec の受け入れ基準とシナリオを突き合わせ、**差分と仕様の穴**を提示する
2. **内部実装の解説**:
   ```
   Skill(skill="explain-impl")
   ```
3. **理解度の検証**（既定では実施。省略できる条件は flow-gates の Gate B が定義）:
   ```
   Skill(skill="grill-me")
   ```

**Gate B** — 成立条件は `.claude/rules/flow-gates.md`。核心は
**各項目にユーザー自身の説明が引用として残っていること**（AI が書いた要約で埋めるのは偽装）。

満たさないうちは `/pr` を実行しない。ユーザーの明示スキップのみ例外。

## Phase 5: PR

```
/pr
```

`/pr` 側で `context-hygiene` が BLOCKING に働く（PR title / description / コードコメント）。
PR description の背景・スコープは **spec ファイルから引く**（会話からではなく）。

## Phase 6: レビュワー向け補足

`context-hygiene` が `.claude/pr-review/prr-draft-<branch>.md` に移送下書きを出しているので、
その内容と `prr` の使い方を提示する。**投稿はユーザーが行う**。

補足すべき典型:
- 意図的にそうしている箇所（コードに書くほど普遍的でない理由）
- 代替案と却下理由（spec の「設計判断」から引ける）
- 次の PR で消える一時的な処置
- AI が書いた箇所で注意して見てほしいところ

## Output (各フェーズ終了時)

```markdown
## Dev Flow — Phase <N>: <名前> 完了

- 成果物: <path>
- Gate: ✅ 成立 / ⛔ 未成立（理由）
- 次: Phase <N+1> <名前>
```

## Rules

1. **フェーズを飛ばさない。** 飛ばしてよいのはユーザーが明示的にそう言ったときだけ
2. 「軽微だから」を AI が判断してゲートを緩めるのは違反
3. 各フェーズの進め方は各 skill の SKILL.md が単一の情報源。ここには書かない
4. 応答は日本語（`.claude/rules/language.md`）
5. 途中で中断されても、成果物ファイルから状態を復元して再開できること
