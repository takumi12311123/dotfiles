---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(prr:*), Bash(mkdir:*), Bash(cat:*), Bash(rm:*), Bash(touch:*), Bash(printf:*), Bash(echo:*), Bash(grep:*), Bash(awk:*), Bash(sed:*), Bash(jq:*), Bash(dirname:*), Bash(ls:*), Read, Write, Edit, Skill, AskUserQuestion, Task
description: 他人 / AI の PR を、把握 → 機械チェック → 読解 → approve or change request まで伴走する
argument-hint: "<PR番号 or PR URL>"
---

## Purpose

**AI が書いた PR を人間がレビューするとき、diff を全部読むのは現実的でない。**

このコマンドは「何が変わったか把握 → 機械的に問題を洗う → 読んで理解する →
根拠のある指摘だけ返す」をフェーズ順に進める。

ゲートの成立条件は `.claude/rules/flow-gates.md`、
PR コメントに何を書くかは `.claude/rules/comment-policy.md` が単一の情報源。

## Context

- Target PR: `$ARGUMENTS`
- Repo: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>&1 | head -3`

## Phases

```
1. 受領        PR 番号の解決、diff 取得
2. 把握        pr-comprehend <PR番号> (reviewer mode)
3. 機械チェック gh pr checks / ローカル実行        ── Gate C
4. 読解支援    explain-impl <PR番号>               ── Gate B'
5. 裁定        codex-review + gemini-review → model-consensus
6. 終端分岐    prr で approve / comment / change request（投稿はユーザー）
```

**approve は裁定の後。** 未裁定の指摘を抱えたまま approve しない。

## Phase 1: 受領

```bash
PR=$(printf '%s' "$ARGUMENTS" | grep -oE '[0-9]+$')
gh pr view "$PR" --json number,title,body,author,baseRefName,headRefOid,files,additions,deletions
```

- 引数が無ければユーザーに PR 番号を聞く
- `gh` が失敗したら理由を切り分けて報告する（auth / network / 権限）。**推測で進めない**
- 規模を先に伝える（ファイル数・追加削除行数）。大きい場合は分割レビューを提案する
- `headRefOid` は Gate B' の基準になるので控えておく

## Phase 2: 把握

```
Skill(skill="pr-comprehend", args="<PR番号>")
```

digest（仕様 / 影響範囲 / AI 特有リスク）が `.claude/pr-review/PR<番号>-<slug>.md` に出る。
**PR description と実際の diff の食い違い**（description に無い変更 / 説明されていない副作用）を
必ず 1 セクションとして提示する。

## Phase 3: 機械チェック (Gate C)

判定条件は `.claude/rules/flow-gates.md` の Gate C。要点だけ:

```bash
gh pr checks "$PR"
gh pr view "$PR" --json mergeable,mergeStateStatus
```

- CI が無い / 部分的なら `gh pr checkout "$PR"` して flow-gates の「ローカル実行の内容」表に従い実行する
- 実行できないものは **「未実施」と明記**。✅ にしない
- 自分の変更ではないので **自動修正はしない**

## Phase 4: 読解支援 (Gate B')

```
Skill(skill="explain-impl", args="<PR番号>")
```

`explain-impl` は「まず自分の理解を述べさせる」から始まる。レビュアであるユーザーが
**自分の言葉で PR の要点を説明できる**状態を作るのが目的。

必要に応じて `eli5`（抽象度調整）/ `user-scenario <PR番号>`（利用者視点の妥当性）/
`grill-me <PR番号>`（理解の穴）へ委譲する。

Gate B' の成立条件は `.claude/rules/flow-gates.md`（`pr-head` 基準、ユーザー自身の説明が必須）。
**理解していない PR を approve しない。**

## Phase 5: 裁定

まず 2 モデルを PR diff に対して並列実行する（`quality-gate` と同じ並列要領）:

```
codex-review / gemini-review（対象: gh pr diff <PR番号>）
```

続いて突合と裁定:

```
Skill(skill="model-consensus")
```

`AGREED` / `ADJUDICATED: real` / `ADJUDICATED: false` / `UNRESOLVED` に分類される。
裁定は多数決ではなく **実コードの根拠**（詳細は model-consensus の SKILL.md）。

- Gemini が使えない場合は「Codex 単独」と明示する。合意していないものを合意と書かない
- `UNRESOLVED` はユーザーに判断材料つきで提示する。**AI が結論を出さない**

**Gate D** — 全指摘に行き先が付くまで Phase 6 に進まない。`UNRESOLVED` の行き先
（質問 / change request / comment / 破棄）は **ユーザーが選ぶ**。
判定と記録形式は `.claude/rules/flow-gates.md` の Gate D。

## Phase 6: 終端分岐

裁定結果を踏まえて、ユーザーが 1 つを選ぶ。

| 状況 | prr |
|------|-----|
| blocking な指摘がゼロ、かつ `UNRESOLVED` が全て処理済み | `@prr approve` |
| blocking な指摘がある | `@prr reject`（change request） |
| 指摘はあるが blocking ではない | `@prr comment` |
| `UNRESOLVED` を「質問として出す」にした | `@prr comment` で質問。**approve は保留** |

```bash
prr get <owner>/<repo>/<PR番号>   # エディタで .prr を開く
# 先頭に @prr approve / @prr reject / @prr comment を書いて保存
prr submit <owner>/<repo>/<PR番号>
```

コメント本文は `.claude/rules/comment-policy.md` に従う:
**セッション参照禁止・内容で書く**（NG「codex が指摘していました」/ OK「`listAll()` は該当なしで
null を返すため、`handler.go:88` の空リスト経路で nil 参照になります」）。

下書きは `.claude/pr-review/prr-draft-pr<番号>.md` に出力する。**投稿はユーザーが行う。**
`ADJUDICATED: false` として破棄した指摘は、破棄した事実だけ報告する（PR には出さない）。

## Output (各フェーズ終了時)

```markdown
## Review Flow — Phase <N>: <名前> 完了

- 成果物: <path>
- Gate: ✅ / ⛔（理由）
- 次: Phase <N+1> <名前>
```

## Rules

1. **裁定 (Phase 5) の前に approve しない。** 未裁定の指摘を残したまま終端に進まない
2. **理解していない PR を approve しない**（Gate B'）
3. モデルの指摘をそのまま PR に転記しない。必ず `model-consensus` を通す
4. Gemini が使えない場合は「Codex 単独」と明示する。合意していないものを合意と書かない
5. 投稿（approve / comment / change request）は必ずユーザーが行う
6. 応答は日本語（`.claude/rules/language.md`）
