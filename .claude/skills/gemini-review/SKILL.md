---
name: gemini-review
description: |
  Gemini-based code review gate. Runs in parallel with codex-review via quality-gate.
  Uses Gemini CLI in non-interactive mode for independent second-opinion review.
metadata:
  auto-trigger: false
---

# Gemini Automatic Review Gate

## Purpose

**独立セカンドオピニオンレビュー**: Codex-reviewと並列実行し、異なるモデル視点でのレビューを提供。
両者の結果を突き合わせることで、見逃しを減らし信頼度を上げる。

## Execution Flow

### Step 1: Execute Gemini Review (Self-Contained)

**Critical: Gemini runs in non-interactive mode with -p flag**

**重要: 機密ファイル除外**
以下のパターンに一致するファイルはGeminiに送信しない:
- `.env`, `.env.*` — 環境変数
- `*.key`, `*.pem` — 鍵・証明書
- `*credentials*`, `*secret*` — 認証情報
- `*.tfvars`, `*.tfstate` — Terraform機密情報

除外されたファイルがある場合、ユーザーに通知する:
`⚠️ 以下のファイルは機密のためGeminiレビューから除外: [file list]`

```bash
ROOT=$(git rev-parse --show-toplevel)
REVIEW_OUT=$(mktemp "${TMPDIR:-/tmp}/gemini-review.XXXXXX")
FALLBACK_JSON='{"ok": false, "phase": "detail", "summary": "Geminiレビュー失敗", "issues": [], "notes_for_next_review": ""}'
SKIPPED_JSON='{"ok": true, "phase": "detail", "summary": "全ファイルが機密のためGeminiレビューをスキップ", "issues": [], "notes_for_next_review": ""}'

# Build file lists (safe vs excluded)
EXCLUDE_PATTERNS='\.env|\.key|\.pem|credentials|secret|\.tfvars|\.tfstate'
ALL_FILES=$(git diff HEAD --name-only -z | tr '\0' '\n')
SAFE_FILES=$(echo "$ALL_FILES" | grep -vE "$EXCLUDE_PATTERNS" || true)
EXCLUDED_FILES=$(echo "$ALL_FILES" | grep -E "$EXCLUDE_PATTERNS" || true)

# Notify about excluded files (caller should display this to user)
if [ -n "$EXCLUDED_FILES" ]; then
  echo "EXCLUDED_FILES=$EXCLUDED_FILES" >&2
fi

# All files excluded → skip (not failure)
if [ -z "$SAFE_FILES" ]; then
  echo "$SKIPPED_JSON"
  rm -f "$REVIEW_OUT"
  exit 0
fi

# Build safe diff from filtered file list (-- prevents flag interpretation)
SAFE_DIFF=$(echo "$SAFE_FILES" | while IFS= read -r file; do git diff HEAD -- "$file"; done)

# macOS-compatible timeout: use array to avoid zsh word-splitting issues
if command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(gtimeout 300)
elif command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout 300)
else
  # No timeout available — run without timeout
  TIMEOUT_CMD=()
fi

"${TIMEOUT_CMD[@]}" gemini -m gemini-3-pro-preview -o json \
  -p "$(cat <<EOF
# Code Review Request

あなたはコードレビューアーです。以下の変更を厳密にレビューしてください。
すべての出力は日本語で記述してください。

## Changed Files
$(echo "$SAFE_FILES" | head -50)

## Diff
$SAFE_DIFF

## Review Focus Areas
- **Correctness**: ロジックエラー、エッジケース、null/undefinedハンドリング
- **Security**: 脆弱性、入力バリデーション、認証・認可
- **Performance**: ボトルネック、非効率なアルゴリズム、リソースリーク
- **Maintainability**: 可読性、既存パターンとの一貫性
- **Testing**: テストカバレッジ、テスト品質、不足テストケース

## Output Format

以下のJSON形式で正確に出力してください（コードブロックなし、JSONのみ）:

## Severity Definitions
- "blocking": 必ず修正が必要。1つでもblockingがあればok: false
- "advisory": 改善推奨。okステータスには影響しない

## Category Values
"correctness", "security", "perf", "maintainability", "testing", "style"

## Example Output
{
  "ok": true,
  "phase": "detail",
  "summary": "変更に問題はありません",
  "issues": [],
  "notes_for_next_review": ""
}

## Example with issues
{
  "ok": false,
  "phase": "detail",
  "summary": "セキュリティ上の問題が見つかりました",
  "issues": [
    {
      "severity": "blocking",
      "category": "security",
      "file": "src/auth.py",
      "lines": "42-45",
      "problem": "SQLインジェクション脆弱性",
      "recommendation": "パラメータ化クエリを使用してください"
    }
  ],
  "notes_for_next_review": "認証周りの再確認が必要"
}

blockingがなければ ok: true としてください。
EOF
)" > "$REVIEW_OUT" 2>/dev/null

EXIT_CODE=$?

# Validate: check exit code, timeout, and non-empty output
if [ $EXIT_CODE -ne 0 ] || [ ! -s "$REVIEW_OUT" ]; then
  echo "$FALLBACK_JSON"
  rm -f "$REVIEW_OUT"
  exit 0
fi

# Parse JSON from output (extract review JSON)
# Gemini CLI -o json returns: {"session_id": ..., "response": "<json-string>", "stats": ...}
PARSED=$(python3 -c "
import json, sys, re

FALLBACK = '{\"ok\": false, \"phase\": \"detail\", \"summary\": \"Gemini出力のJSONパース失敗\", \"issues\": [], \"notes_for_next_review\": \"\"}'

try:
    data = json.load(open('$REVIEW_OUT'))
except Exception:
    print(FALLBACK); sys.exit(0)

def extract_json(text):
    \"\"\"Extract review JSON from text (may contain markdown code blocks).\"\"\"
    match = re.search(r'\x60\x60\x60json?\s*(\{.*?\})\s*\x60\x60\x60', text, re.DOTALL)
    if match:
        return json.loads(match.group(1))
    return json.loads(text.strip())

try:
    if isinstance(data, dict) and 'response' in data:
        # CLI v0.32+ format: {session_id, response (string), stats}
        resp = data['response']
        parsed = extract_json(resp) if isinstance(resp, str) else resp
        assert 'ok' in parsed and 'issues' in parsed
        print(json.dumps(parsed))
    elif isinstance(data, dict) and 'ok' in data:
        # Direct JSON output
        print(json.dumps(data))
    elif isinstance(data, list):
        # Legacy format: list of response objects
        for item in reversed(data):
            try:
                text = item['response']['candidates'][0]['content']['parts'][0]['text']
                parsed = extract_json(text)
                assert 'ok' in parsed and 'issues' in parsed
                print(json.dumps(parsed)); break
            except: continue
        else:
            print(FALLBACK)
    else:
        print(FALLBACK)
except Exception:
    print(FALLBACK)
" 2>/dev/null) || PARSED="$FALLBACK_JSON"

echo "$PARSED"
rm -f "$REVIEW_OUT"
```

**Important: Wait for Gemini completion**

- Gemini は通常 codex より高速（大規模コンテキスト処理が得意）
- macOS互換タイムアウト（gtimeout/timeout/perlフォールバック）で最大5分に制限
- Progress log: `[Geminiレビュー中] 実行中（最大5分）...`
- On timeout: フォールバックJSONを返し、Codex結果のみで判定

### Step 2: Result Handling

Gemini review does NOT iterate independently. Results are passed back to quality-gate for merged evaluation.

結果は常に以下のスキーマに従う（codex-review/review-schema.json と同一）:
```json
{
  "ok": true,
  "phase": "detail",
  "summary": "...",
  "issues": [],
  "notes_for_next_review": ""
}
```

## Error Handling

**全てのエラーケースでフォールバックJSONを返す。** quality-gateが常に機械的に処理できることを保証する。

### Gemini Timeout (exit code 124)
- フォールバックJSON返却
- Log: `⚠️ Geminiレビューがタイムアウトしました（5分超過）`

### Gemini API Failure (non-zero exit)
- フォールバックJSON返却
- Log: `⚠️ Gemini API呼び出しに失敗しました`

### Empty Output
- フォールバックJSON返却
- Log: `⚠️ Geminiが空の出力を返しました`

### JSON Parse Failure
- フォールバックJSON返却
- Log: `⚠️ Geminiの出力をJSONとしてパースできませんでした`

## Output Format to User

Gemini review results are shown alongside Codex results in quality-gate output:

```markdown
### Geminiレビュー結果
- **ステータス**: ✅ ok / ⚠️ 指摘あり / ❌ 失敗
- **指摘件数**: blocking: N件, advisory: M件

#### Gemini独自の指摘（Codexと一致しない項目）
- `file.py:42` - [問題の説明] (category/severity)
```

## Important Reminders

1. **並列実行**: Codex-reviewと必ず並列で実行する
2. **機密ファイル除外**: `.env`, 鍵, 認証情報は送信前に必ず除外する
3. **フォールバック保証**: 全エラーケースで有効なJSONを返す
4. **非インタラクティブ**: `-p` フラグで実行、`timeout 300` で制限
5. **日本語出力**: すべてのユーザー向けテキストは日本語
6. **マージ判定**: 最終判定はquality-gateが行う
