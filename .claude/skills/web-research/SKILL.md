---
name: web-research
description: |
  Delegated web research: Gemini does primary search, Codex cross-verifies.
  Claude Code only merges and presents results (zero context window consumption).
metadata:
  context: research, documentation, library, api, investigation
  auto-trigger: false
---

# Web Research (Gemini + Codex)

## Purpose

**外部2者リサーチ**: Geminiが一次調査（Web検索）、Codexが検証。
Claude Codeは結果のマージと提示のみ行い、コンテキストを消費しない。

## When to Use

- ライブラリ・フレームワークの調査
- API仕様の確認
- ベストプラクティスの調査
- エラーの原因調査
- 技術選定の情報収集
- 最新バージョン・変更点の確認

## Research Result Schema

Gemini と Codex は同一のJSONスキーマで結果を返す。

### Field Definitions

| Field | Type | Values |
|-------|------|--------|
| verification_status | string | `"confirmed"`, `"partially_confirmed"`, `"contradicted"`, `"error"` |
| freshness | string | `"current"`, `"outdated"`, `"uncertain"` |
| freshness_detail | string | 自由記述（日本語） |
| confirmed_facts | string[] | 確認できた事実のリスト |
| contradictions | object[] | `{claim, correction, source}` |
| missing_info | string[] | 欠落している重要情報 |
| additional_findings | string[] | 追加で見つかった情報 |
| recommended_sources | string[] | 推奨ドキュメントURL |

### Example (valid JSON)

```json
{
  "verification_status": "partially_confirmed",
  "freshness": "current",
  "freshness_detail": "公式ドキュメントの最新バージョンと一致することを確認",
  "confirmed_facts": ["React 19がstable版としてリリース済み"],
  "contradictions": [
    {
      "claim": "useEffectは非推奨",
      "correction": "useEffectは非推奨ではなく、特定ケースでuseを推奨",
      "source": "https://react.dev/reference/react/use"
    }
  ],
  "missing_info": ["Server Componentsに関する記述がない"],
  "additional_findings": ["React Compilerが実験的に利用可能"],
  "recommended_sources": ["https://react.dev/blog"]
}
```

### Error Fallback (valid JSON)

```json
{
  "verification_status": "error",
  "freshness": "uncertain",
  "freshness_detail": "検証に失敗しました",
  "confirmed_facts": [],
  "contradictions": [],
  "missing_info": [],
  "additional_findings": [],
  "recommended_sources": []
}
```

## Execution Flow

### Step 1: Gemini Primary Research (Background)

Gemini CLIでWeb検索による一次調査を実行。
**Claude CodeはWebSearch/WebFetchを使わない。**

Launch as background Agent task with Bash:

```bash
GEMINI_OUT=$(mktemp "${TMPDIR:-/tmp}/gemini-research.XXXXXX")
FALLBACK='{"verification_status":"error","freshness":"uncertain","freshness_detail":"Gemini調査に失敗","confirmed_facts":[],"contradictions":[],"missing_info":[],"additional_findings":[],"recommended_sources":[]}'

# macOS-compatible timeout (array for zsh compatibility)
if command -v gtimeout >/dev/null 2>&1; then TIMEOUT_CMD=(gtimeout 300)
elif command -v timeout >/dev/null 2>&1; then TIMEOUT_CMD=(timeout 300)
else TIMEOUT_CMD=(); fi

"${TIMEOUT_CMD[@]}" gemini -m gemini-3-pro-preview -o json \
  -p "$(cat <<PROMPT
# Web Research: Primary Investigation

すべての出力は日本語で記述してください。

重要: あなたはGemini CLIとして実行されています。Web検索はデフォルトで有効です。
必ず独自にWeb検索を行い最新情報を取得してください。

## 調査トピック
[ユーザーのリサーチクエリをここに挿入]

## あなたのタスク

1. 上記トピックについて、Web検索で最新の公式情報を収集してください
2. 以下を重点的に調査:
   - 最新バージョン・リリース情報
   - 公式ドキュメントURL
   - ベストプラクティス・推奨パターン
   - deprecatedな機能・破壊的変更
3. 情報の鮮度（いつの情報か）を明記してください

以下のJSON形式で正確に出力してください（コードブロックなし、JSONのみ）。

## Example Output
{
  "verification_status": "confirmed",
  "freshness": "current",
  "freshness_detail": "2026年3月時点の最新情報と一致",
  "confirmed_facts": ["事実1", "事実2"],
  "contradictions": [],
  "missing_info": [],
  "additional_findings": ["Web検索で見つかった追加情報"],
  "recommended_sources": ["https://example.com/docs"]
}
PROMPT
)" > "$GEMINI_OUT" 2>/dev/null

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || [ ! -s "$GEMINI_OUT" ]; then
  echo "$FALLBACK"
  rm -f "$GEMINI_OUT"
  exit 0
fi

# Parse Gemini JSON output
# Gemini CLI -o json returns: {"session_id": ..., "response": "<json-string>", "stats": ...}
PARSED=$(python3 -c "
import json, sys, re

FALLBACK = '{\"verification_status\":\"error\",\"freshness\":\"uncertain\",\"freshness_detail\":\"Gemini出力のパース失敗\",\"confirmed_facts\":[],\"contradictions\":[],\"missing_info\":[],\"additional_findings\":[],\"recommended_sources\":[]}'

try:
    data = json.load(open('$GEMINI_OUT'))
except Exception:
    print(FALLBACK); sys.exit(0)

def extract_json(text):
    match = re.search(r'\x60\x60\x60json?\s*(\{.*?\})\s*\x60\x60\x60', text, re.DOTALL)
    if match:
        return json.loads(match.group(1))
    return json.loads(text.strip())

try:
    if isinstance(data, dict) and 'response' in data:
        resp = data['response']
        parsed = extract_json(resp) if isinstance(resp, str) else resp
        assert 'verification_status' in parsed
        print(json.dumps(parsed))
    elif isinstance(data, dict) and 'verification_status' in data:
        print(json.dumps(data))
    elif isinstance(data, list):
        for item in reversed(data):
            try:
                text = item['response']['candidates'][0]['content']['parts'][0]['text']
                parsed = extract_json(text)
                assert 'verification_status' in parsed
                print(json.dumps(parsed)); break
            except: continue
        else:
            print(FALLBACK)
    else:
        print(FALLBACK)
except Exception:
    print(FALLBACK)
" 2>/dev/null) || PARSED="$FALLBACK"

echo "$PARSED"
rm -f "$GEMINI_OUT"
```

### Step 2: Codex Cross-Verification (Background)

Geminiの調査結果を受け取り、Codexが独立に検証。
**Step 1と並列実行。Geminiの結果が先に返った場合、その内容をCodexに渡す。**
**Geminiがまだ返っていない場合は、トピックのみでCodexに独自調査させる。**

Launch as background Agent task with Bash:

```bash
ROOT=$(git rev-parse --show-toplevel)
CODEX_OUT=$(mktemp "${TMPDIR:-/tmp}/codex-research.XXXXXX")
FALLBACK='{"verification_status":"error","freshness":"uncertain","freshness_detail":"Codex検証に失敗","confirmed_facts":[],"contradictions":[],"missing_info":[],"additional_findings":[],"recommended_sources":[]}'

# macOS-compatible timeout (array for zsh compatibility)
if command -v gtimeout >/dev/null 2>&1; then TIMEOUT_CMD=(gtimeout 300)
elif command -v timeout >/dev/null 2>&1; then TIMEOUT_CMD=(timeout 300)
else TIMEOUT_CMD=(); fi

"${TIMEOUT_CMD[@]}" codex exec --model gpt-5.4 --sandbox read-only \
  --output-schema "$ROOT/.claude/skills/web-research/verification-schema.json" \
  -o "$CODEX_OUT" \
  "$(cat <<PROMPT
# Web Research Cross-Verification

すべての出力は日本語で記述してください。

## 調査トピック
[ユーザーのリサーチクエリをここに挿入]

## Geminiの調査結果（利用可能な場合）
[Geminiの結果をここに挿入。まだ返っていない場合は「Gemini結果なし - 独自に調査してください」]

## あなたのタスク

1. 上記トピックについて、あなた自身の知識で独立に検証してください
2. Geminiの調査結果がある場合は、その正確性を検証してください
3. 以下の観点でチェックしてください:
   - 情報は最新か？（古い情報やdeprecatedな内容が含まれていないか）
   - 事実関係は正確か？
   - 重要な情報の欠落はないか？
   - より良い代替案やアプローチはないか？
PROMPT
)"

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || [ ! -s "$CODEX_OUT" ]; then
  echo "$FALLBACK"
else
  if python3 -c "import json; json.load(open('$CODEX_OUT'))" 2>/dev/null; then
    cat "$CODEX_OUT"
  else
    echo "$FALLBACK"
  fi
fi
rm -f "$CODEX_OUT"
```

### Step 3: Merge & Analyze Results

Gemini/Codexの結果を統合して信頼度を判定。
**Claude Codeはここで初めて結果を受け取る（要約のみ）。**

```python
def normalize_result(result):
    """None、error、不完全なJSONを安全なデフォルトに正規化。"""
    FALLBACK = {
        "verification_status": "error",
        "freshness": "uncertain",
        "freshness_detail": "結果を取得できませんでした",
        "confirmed_facts": [],
        "contradictions": [],
        "missing_info": [],
        "additional_findings": [],
        "recommended_sources": []
    }

    if result is None or not isinstance(result, dict):
        return dict(FALLBACK)

    normalized = {}

    VALID_STATUS = {"confirmed", "partially_confirmed", "contradicted", "error"}
    VALID_FRESHNESS = {"current", "outdated", "uncertain"}

    status = result.get("verification_status", "error")
    normalized["verification_status"] = status if status in VALID_STATUS else "error"

    freshness = result.get("freshness", "uncertain")
    normalized["freshness"] = freshness if freshness in VALID_FRESHNESS else "uncertain"

    detail = result.get("freshness_detail", "")
    normalized["freshness_detail"] = str(detail) if detail else ""

    for key in ["confirmed_facts", "missing_info", "additional_findings", "recommended_sources"]:
        val = result.get(key, [])
        if not isinstance(val, list):
            normalized[key] = []
        else:
            normalized[key] = [str(item) for item in val if isinstance(item, str)]

    raw_contradictions = result.get("contradictions", [])
    if not isinstance(raw_contradictions, list):
        normalized["contradictions"] = []
    else:
        valid_contradictions = []
        for item in raw_contradictions:
            if isinstance(item, dict) and all(
                k in item and isinstance(item[k], str)
                for k in ("claim", "correction", "source")
            ):
                valid_contradictions.append({
                    "claim": item["claim"],
                    "correction": item["correction"],
                    "source": item["source"]
                })
        normalized["contradictions"] = valid_contradictions

    return normalized


def merge_research(gemini_result, codex_result):
    """Gemini(一次調査)/Codex(検証)の結果をマージし、信頼度を判定する。"""
    gemini = normalize_result(gemini_result)
    codex = normalize_result(codex_result)

    sources_available = sum(1 for r in [gemini, codex]
                           if r["verification_status"] != "error")

    freshness_votes = [
        r["freshness"] for r in [gemini, codex]
        if r["verification_status"] != "error"
    ]

    if not freshness_votes:
        freshness_assessment = "uncertain"
    elif "outdated" in freshness_votes:
        freshness_assessment = "outdated"
    elif all(f == "current" for f in freshness_votes):
        freshness_assessment = "current"
    else:
        freshness_assessment = "uncertain"

    all_contradictions = (
        gemini.get("contradictions", []) +
        codex.get("contradictions", [])
    )

    if sources_available == 0:
        confidence = "unverified"
    elif sources_available == 1:
        confidence = "low"
    elif all_contradictions:
        confidence = "low"
    elif all(r["verification_status"] == "confirmed"
             for r in [gemini, codex]
             if r["verification_status"] != "error"):
        confidence = "high"
    else:
        confidence = "medium"

    return {
        "confidence": confidence,
        "sources_available": sources_available,
        "freshness_assessment": freshness_assessment,
        "contradictions": all_contradictions,
        "gemini_detail": gemini.get("freshness_detail", ""),
        "codex_detail": codex.get("freshness_detail", "")
    }
```

### Step 4: Present Results to User

## Output Format

```markdown
## 調査結果: [トピック]

### 信頼度判定
- **総合信頼度**: 高（2者確認済） / 中（1者確認 or 部分一致） / 低（矛盾あり） / 未検証（外部調査失敗）
- **検証ソース数**: N/2
- **情報鮮度**: 最新 / 古い可能性あり / 不明

### 主要な調査結果（Gemini Web検索）
[Geminiの一次調査結果]

### クロスチェック結果（Codex検証）

#### 一致した情報（信頼度: 高）
- [両者が一致した事実]

#### 追加情報
- **Gemini追加**: [Geminiのみが見つけた情報（Web検索ベース）]
- **Codex追加**: [Codexのみが指摘した情報]

#### 矛盾・相違点（要注意）
| 項目 | Gemini | Codex |
|------|--------|-------|
| [項目] | [主張] | [主張] |

#### 情報鮮度チェック
- **Gemini判定**: [詳細]
- **Codex判定**: [詳細]

### 推奨ドキュメント
- [URL1] (source: Gemini/Codex)
- [URL2] (source: Gemini/Codex)

### 注意事項
- [矛盾がある場合の注意点]
- [情報が古い可能性がある項目]
```

## Error Handling

**全てのエラーケースでフォールバックJSONを返す。**

### 2者成功 (Both Gemini and Codex)
- 通常のマージ処理、信頼度は一致度に基づいて判定

### 1者成功 (Gemini or Codex片方のみ)
- 成功したソースの結果を採用
- 信頼度を「中」に設定
- 失敗したソースを明記

### 0者成功 (Both failed)
- 信頼度を「未検証」と明記
- ユーザーに手動確認を推奨: `⚠️ 外部調査に失敗しました。手動での確認を推奨します`

## Integration with latest-docs

`latest-docs` スキルから呼び出される場合:
- Geminiの検索クエリにバージョン・deprecation関連を追加
- 結果を `latest-docs` のフォーマットに合わせて返却

## Important Reminders

1. **Claude CodeはWebSearch/WebFetchを使わない** - 全てGemini+Codexに委譲
2. **並列実行**: Gemini と Codex は必ずバックグラウンドで並列実行
3. **Gemini = 一次調査**: Web検索で最新情報を取得
4. **Codex = 検証**: Geminiの結果を知識ベースで検証
5. **矛盾は隠さない**: 結果が矛盾する場合、すべて提示してユーザーに判断を委ねる
6. **フォールバック保証**: 全エラーケースで有効なJSONを返す
7. **日本語出力**: すべてのユーザー向けテキストは日本語
