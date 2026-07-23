You are analyzing a git diff to produce a Japanese specification digest for a human reviewer.

Read the provided diff carefully. Do NOT invent behavior that is not visible in the code.
For anything you inferred (rather than directly observed), prefix with "(推測)".

Output the following two sections in Japanese Markdown:

## 1. 仕様サマリ (What changed)

Break down changes by category. Skip categories with no changes.

### API
- 追加/変更/削除された endpoint、request/response shape、authentication requirement

### UI
- 追加/変更された component、visible behavior change、visual difference

### DB
- Schema change (table, column, index, constraint), migration necessity

### CLI
- Added/changed/removed command, flag, subcommand

### 設定 (config)
- Environment variable, config key, feature flag

### その他
- Internal helper, refactoring, dependency change

### Before → After (振る舞い差分)
List meaningful behavior differences. Format:
- Before: <観察された過去の振る舞い>
  After: <観察された新しい振る舞い>

## 2. 影響範囲マップ (Blast radius)

### 主な呼び出し関係
For each significantly changed file/function, list the callers you can identify from the diff or common convention.
- `<changed_file>::<symbol>` ← called from: `<file1>`, `<file2>` ...

### 破壊的変更 (Breaking changes)
Explicit list. Empty section if none.
- [API shape] ...
- [DB schema] ...
- [Env var] ...
- [CLI flag] ...

### データマイグレーション
- 必要: yes / no
- 必要な場合: マイグレーション手順の概略 + ロールバック可否

---

**Rules**:
- 事実ベースで書く。diff に無い挙動を勝手に補完しない
- 推測は "(推測)" を明記
- 出力はすべて日本語
- 全体で 800 語程度に収める (要約が目的)

The diff follows this instruction below:
