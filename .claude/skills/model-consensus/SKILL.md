---
name: model-consensus
description: |
  複数モデル (Codex / Gemini / Claude) の指摘を突き合わせ、合意・不一致を判定して
  「PR に出してよい指摘」だけを残す skill。不一致は多数決ではなく、Claude が実コードを読んで
  根拠の強さで裁定する。レビューで change request / comment を出す前に使う。
  「裏取りして」「codex と gemini で確認して」「この指摘は本物か」のときにも使う。
metadata:
  auto-trigger: false
  invoked-by: [review-flow, user]
  companions: [codex-review, gemini-review, prr]
---

# Model Consensus

## Purpose

**単一モデルの指摘をそのままレビューに出すと、幻覚をレビュイーに投げつけることになる。**

この skill は複数モデルの指摘を突き合わせ、次の 3 つに分ける:

| 区分 | 意味 | 行き先 |
|------|------|--------|
| `AGREED` | 両モデルが同じ問題を指摘 | `/prr` の change request 候補 |
| `ADJUDICATED` | 割れたが、Claude が実コードを読んで結論を出せた | 結論に応じて change request / 破棄 |
| `UNRESOLVED` | 実コードを読んでも決着しない（仕様依存・設計論） | ユーザーに提示。**AI は結論を出さない** |

## Process

```
Step 1: 収集   → codex-review / gemini-review を並列実行し、指摘を構造化
Step 2: 突合   → file + 行域 + 論点で同一指摘をマッチング
Step 3: 分類   → AGREED / 不一致
Step 4: 裁定   → 不一致は Claude が実コードを読んで判定 (多数決にしない)
Step 5: 出力   → prr 用の下書きに落とす
```

## Step 1: 収集

```
Agent/Bash で codex-review と gemini-review を並列実行（quality-gate と同じ要領）
```

- 対象が他人の PR の場合は `gh pr diff <番号>` を渡す
- Gemini が使えない場合（CLI 未認証等）は **Codex 単独と明示**し、
  合意判定ができないことを報告する（勝手に「合意」にしない）

各指摘を次の形に正規化する:

```json
{"source":"codex","file":"src/a.go","lines":"42-48","category":"correctness",
 "claim":"listAll() が null を返す場合に nil 参照","severity":"blocking"}
```

## Step 2: 突合

同一指摘とみなす条件:

- `file` が一致し、**行域が重なる**（完全一致は求めない。±5 行程度の揺れは同一扱い）
- かつ `claim` が同じ現象を指している（表現の違いは吸収する）

行が離れていても同じ根本原因を指している場合は、**1 件に統合**して両方の根拠を併記する。

## Step 3: 分類

| 状況 | 判定 |
|------|------|
| 両モデルが指摘 | `AGREED` |
| 片方だけが指摘 | 不一致 → Step 4 |
| 片方が「問題」、他方が明示的に「問題なし」と述べた | 不一致（対立）→ Step 4 |

**片方しか言っていない = 偽物、ではない。** 見落としの可能性があるので必ず Step 4 に送る。

## Step 4: 裁定（ここがこの skill の本体）

**多数決にしない。実コードを読んで根拠の強さで決める。**

各指摘について次を確認する:

1. **再現経路があるか** — その入力・状態に到達する呼び出し元が実在するか（grep で追う）
2. **前提が正しいか** — 「null を返す」等の主張を、当該関数の実装で確認する
3. **既に守られていないか** — 呼び出し元や型で既に防がれていないか
4. **影響** — 起きたとき何が壊れるか（クラッシュ / 誤結果 / 性能 / 可読性のみ）

判定:

| 結論 | 条件 |
|------|------|
| `ADJUDICATED: real` | 到達経路をコード上で示せる。**根拠となる file:line を必ず添える** |
| `ADJUDICATED: false` | 前提が実装と食い違う、または既に防がれている。**その根拠も file:line で示す** |
| `UNRESOLVED` | 仕様・意図に依存し、コードだけでは決まらない |

**根拠を file:line で示せない判定は出さない。** 示せないなら `UNRESOLVED`。

## Step 5: 出力

```markdown
## Model Consensus 結果

対象: PR #123 (codex ✅ / gemini ✅)

### AGREED (change request 候補) — 2 件
1. `src/a.go:42` nil 参照 — codex/gemini 一致
   - 再現: `handler.go:88` が空リストで呼ぶ
   - 提案: `if x == nil { return ErrNotFound }`

### ADJUDICATED — 3 件
| 指摘 | 出所 | 裁定 | 根拠 |
|------|------|------|------|
| ループ内 N+1 クエリ | gemini のみ | real | `repo.go:120` がループ内で発行、呼び出しは 1 件/行 |
| context 未伝播 | codex のみ | false | `client.go:33` で既に伝播済み |

### UNRESOLVED (ユーザー判断) — 1 件
- `src/b.go:10` エラー時に握り潰すかログして継続するか
  - codex: 握り潰しは NG / gemini: 現状の運用なら妥当
  - **判断材料**: この経路はバッチ実行のみ (`cmd/batch.go:44`)。止めるべきかは運用方針次第

### prr 下書き
`.claude/pr-review/prr-draft-pr123.md` に AGREED + ADJUDICATED:real を出力済み
```

### 行き先の確定 (Gate D)

分類して終わりではない。**全指摘に行き先が付くまでがこの skill の責務**。

- `AGREED` / `ADJUDICATED: real` → change request か comment に載せる
- `ADJUDICATED: false` → 破棄し、破棄した事実を報告する
- `UNRESOLVED` → **ユーザーに 4 択で選ばせる**（質問 / change request / comment / 破棄）。
  `AskUserQuestion` を使い、判断材料（コード上の事実）を添える。**AI が代わりに決めない**

行き先の一覧表を `.claude/pr-review/prr-draft-pr<番号>.md` の末尾に残す
（形式は `.claude/rules/flow-gates.md` の Gate D）。

`/prr` への投稿は **ユーザーが行う**（`.claude/rules/comment-policy.md`）。

## Anti-patterns

| NG | 理由 |
|----|------|
| 多数決で決める | 2 モデルが同じ誤解をすることは普通にある |
| 片方だけの指摘を自動で捨てる | 見落としを見落とす |
| 根拠なしで「real」と判定する | 幻覚をレビュイーに投げる |
| UNRESOLVED を無理に結論づける | 仕様判断はユーザーの領分 |
| UNRESOLVED を未処理のまま終端に進む | approve 禁止条件の迂回 (Gate D) |
| Gemini 不在時に「合意」と書く | 合意していない |
| 自動で PR に投稿する | レビューはユーザーが主導する |
