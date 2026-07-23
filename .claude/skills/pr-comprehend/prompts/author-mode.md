# Author Mode

このモードは **自分 (または AI) が書いた変更を PR 化する前に振り返る** ためのもの。

## 前提

- ローカルブランチに未 push または push 済みだが merge 前の変更がある
- quality-gate から `--mode=author --trigger=<commit|pr>` で呼ばれる
- または手動で `pr-comprehend --mode=author` として呼ぶ

## Extra prompts to inject

Author mode では、Codex ai-risk scan に以下を追加で問う:

```
## Author-mode extra checks

このユーザーは AI 支援でこの変更を書いた可能性が高い。以下を特に警戒せよ:

1. **指示逸脱**: このセッションで依頼されたはずのタスク範囲を超える変更が入っていないか
   (別ファイルの refactor が混入している、命名規則の一括変更が混じっている 等)

2. **元コードの意図的削除**: 削除された行のうち、意味論的に必要そうに見えるものが
   コミットメッセージや変更説明で言及されていないか

3. **設定/依存の忍び込み**: package.json / go.mod / requirements.txt / .env* / config/*
   への変更が本来のタスクに必要か

4. **AI が「よかれと思って」書いた冗長コード**:
   - JSDoc / docstring の大量追加 (元コードに無かったのに)
   - 型注釈の過剰な明示 (推論で十分な箇所)
   - 変数の過剰な rename ("data" → "userDataResponse" 等)

## Output guidance

これらは severity=advisory で ai_risks[] に追加。
ただし「元の意図が明らかに破壊されている」場合は blocking。
```

## Report file naming

```
.claude/pr-review/local-<branch>-<HEAD_hash>.md
```

同じブランチで再度 skill を実行するとファイル名が変わる (HEAD hash 違い) が、
古いレポートは自動削除しない。手動で `.claude/pr-review/` を掃除する。

## Weight rules

- `--trigger=commit` → light digest (Claude 内部要約のみ、Codex/Gemini 不使用)
  - 目的: commit ごとの軽い記録。トークン消費を抑える
- `--trigger=pr` → full digest
  - 目的: PR 作成前の網羅的振り返り。時間もトークンも使う

## Present to user

Full digest の場合、対話提示の最初のメッセージ:

```
📄 PR digest 生成完了 (author mode, full)
   .claude/pr-review/<filename>.md

## 全体像
- 変更ファイル: <N> / 追加行: <+X> / 削除行: <-Y>
- 主な変更: <one_liner>
- 破壊的変更: <あり/なし> (<breaking_changes 上位1件>)
- AI 特有リスク: <High/Med/Low> — <ai_risks 上位1件>

このまま PR を作成しますか? それとも先に digest を確認しますか?
```

Light digest の場合:

```
📝 commit digest 保存 (light mode)
   .claude/pr-review/<filename>.md
   <one_liner>
```

Light は 1 行報告のみ。詳細確認は促さない (commit 頻度が高いので割り込み最小化)。
