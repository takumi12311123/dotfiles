---
name: web-research
description: |
  Multi-source web research with cross-verification. Searches with Claude Code (WebSearch),
  then cross-verifies findings with both Codex CLI and Gemini CLI in parallel.
  Checks information freshness and flags contradictions.
metadata:
  context: research, documentation, library, api, investigation
  auto-trigger: false
---

# Web Research with Cross-Verification

## Purpose

**外部2者検証リサーチ**: Claude Codeが一次調査を行い、その結果をCodexとGeminiの
2つの外部サービスで独立に検証する。情報の最新性・正確性をクロスチェックする。

## When to Use

- ライブラリ・フレームワークの調査
- API仕様の確認
- ベストプラクティスの調査
- エラーの原因調査
- 技術選定の情報収集
- 最新バージョン・変更点の確認

## Verification Result Schema

Codex と Gemini は同一のJSONスキーマで結果を返す。
以下がスキーマ定義（両者共通）:

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

### Step 1: Claude Code Primary Search

WebSearchで主要な検索を実施:

```
WebSearch: "[query] [current year]"
WebSearch: "[query] latest version"
WebSearch: "[query] official documentation"
```

検索結果から以下を抽出:
- 主要な事実・情報
- バージョン番号
- 公式ドキュメントURL
- 最終更新日（わかる場合）

### Step 2: Parallel Cross-Verification

**Codex と Gemini を並列でバックグラウンド実行**

Claude Codeの検索結果と参照URLを含めて、それぞれ独立に検証させる。

**Codex検証 (Subagent / Background Task):**

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

## Claude Codeの調査結果
[Claude Codeの検索結果をここに挿入]

## 参照URL
[Claude Codeが参照したURLリストをここに挿入]

## あなたのタスク

重要: Claude Codeの調査結果を鵜呑みにせず、参照URLを実際に開いて内容を確認してください。
Codex sandboxではWeb閲覧はできませんが、提供された情報の論理的整合性と
あなた自身の知識に基づいて独立に検証してください。

1. 上記の調査結果の正確性を、あなた自身の知識と照合して検証してください
2. 参照URLが信頼できるソースか確認してください
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
  # --output-schema guarantees valid JSON; validate with python3 as fallback
  if python3 -c "import json; json.load(open('$CODEX_OUT'))" 2>/dev/null; then
    cat "$CODEX_OUT"
  else
    echo "$FALLBACK"
  fi
fi
rm -f "$CODEX_OUT"
```

**Gemini検証 (Subagent / Background Task):**

```bash
GEMINI_OUT=$(mktemp "${TMPDIR:-/tmp}/gemini-research.XXXXXX")
FALLBACK='{"verification_status":"error","freshness":"uncertain","freshness_detail":"Gemini検証に失敗","confirmed_facts":[],"contradictions":[],"missing_info":[],"additional_findings":[],"recommended_sources":[]}'

# macOS-compatible timeout (array for zsh compatibility)
if command -v gtimeout >/dev/null 2>&1; then TIMEOUT_CMD=(gtimeout 300)
elif command -v timeout >/dev/null 2>&1; then TIMEOUT_CMD=(timeout 300)
else TIMEOUT_CMD=(); fi

"${TIMEOUT_CMD[@]}" gemini -m gemini-3-pro-preview -o json \
  -p "$(cat <<PROMPT
# Web Research Cross-Verification

すべての出力は日本語で記述してください。

重要: あなたはGemini CLIとして実行されています。Web検索はデフォルトで有効です。
プロンプト内の情報だけでなく、必ず独自にWeb検索を行い最新情報を取得してください。

## Claude Codeの調査結果
[Claude Codeの検索結果をここに挿入]

## 参照URL
[Claude Codeが参照したURLリストをここに挿入]

## あなたのタスク

1. 上記の調査トピックについて、独自にWeb検索で最新情報を確認してください
2. 参照URLの内容を直接確認してください
3. Claude Codeの調査結果と突き合わせてください
4. 以下の観点でチェックしてください:
   - 情報は最新か？（公式サイトの最新情報と一致するか）
   - バージョン番号は正確か？
   - deprecatedなAPIやパターンが含まれていないか？

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
        # CLI v0.32+ format: {session_id, response (string), stats}
        resp = data['response']
        parsed = extract_json(resp) if isinstance(resp, str) else resp
        assert 'verification_status' in parsed
        print(json.dumps(parsed))
    elif isinstance(data, dict) and 'verification_status' in data:
        print(json.dumps(data))
    elif isinstance(data, list):
        # Legacy format: list of response objects
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

### Step 3: Merge & Analyze Results

Codex/Geminiの外部検証結果を統合して信頼度を判定。
**全ての入力を正規化してからマージする。**

```python
def normalize_result(result):
    """None、error、不完全なJSONを安全なデフォルトに正規化。型を強制変換する。"""
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

    # Enum fields: validate against allowed values, fallback if invalid
    VALID_STATUS = {"confirmed", "partially_confirmed", "contradicted", "error"}
    VALID_FRESHNESS = {"current", "outdated", "uncertain"}

    status = result.get("verification_status", "error")
    normalized["verification_status"] = status if status in VALID_STATUS else "error"

    freshness = result.get("freshness", "uncertain")
    normalized["freshness"] = freshness if freshness in VALID_FRESHNESS else "uncertain"

    # String field
    detail = result.get("freshness_detail", "")
    normalized["freshness_detail"] = str(detail) if detail else ""

    # Array of strings: ensure list type, filter non-strings
    for key in ["confirmed_facts", "missing_info", "additional_findings", "recommended_sources"]:
        val = result.get(key, [])
        if not isinstance(val, list):
            normalized[key] = []
        else:
            normalized[key] = [str(item) for item in val if isinstance(item, str)]

    # Array of objects (contradictions): validate each item shape
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


def merge_research(codex_result, gemini_result):
    """Codex/Geminiの外部検証結果をマージし、信頼度を判定する。

    Claude Codeの一次調査結果は呼び出し元が保持する（構造化されていないため）。
    この関数は外部2者の検証結果のみを統合する。
    """
    # Normalize all inputs first
    codex = normalize_result(codex_result)
    gemini = normalize_result(gemini_result)

    # Count available sources (non-error)
    sources_available = sum(1 for r in [codex, gemini]
                           if r["verification_status"] != "error")

    # Freshness assessment
    freshness_votes = [
        r["freshness"] for r in [codex, gemini]
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

    # Contradiction detection
    all_contradictions = (
        codex.get("contradictions", []) +
        gemini.get("contradictions", [])
    )

    # Confidence level
    if sources_available == 0:
        confidence = "unverified"
    elif sources_available == 1:
        confidence = "low"
    elif all_contradictions:
        confidence = "low"
    elif all(r["verification_status"] == "confirmed"
             for r in [codex, gemini]
             if r["verification_status"] != "error"):
        confidence = "high"
    else:
        confidence = "medium"

    return {
        "confidence": confidence,
        "sources_available": sources_available,
        "freshness_assessment": freshness_assessment,
        "contradictions": all_contradictions,
        "codex_detail": codex.get("freshness_detail", ""),
        "gemini_detail": gemini.get("freshness_detail", "")
    }
```

### Step 4: Present Results to User

## Output Format

```markdown
## 調査結果: [トピック]

### 信頼度判定
- **総合信頼度**: 高（2者確認済） / 中（1者確認 or 部分一致） / 低（矛盾あり） / 未検証（外部検証失敗）
- **検証ソース数**: N/2
- **情報鮮度**: 最新 / 古い可能性あり / 不明

### 主要な調査結果
[Claude Codeの検索結果ベースの情報]

### クロスチェック結果

#### 一致した情報（信頼度: 高）
- [複数ソースが一致した事実]

#### 追加情報
- **Codex追加**: [Codexのみが指摘した情報]
- **Gemini追加**: [Geminiのみが指摘した情報（Web検索ベース）]

#### 矛盾・相違点（要注意）
| 項目 | Claude Code | Codex | Gemini |
|------|------------|-------|--------|
| [項目] | [主張] | [主張] | [主張] |

#### 情報鮮度チェック
- **Codex判定**: [詳細]
- **Gemini判定**: [詳細]
- **最新バージョン**: [Geminiが検索した最新バージョン情報]

### 推奨ドキュメント
- [URL1] (source: Codex/Gemini)
- [URL2] (source: Codex/Gemini)

### 注意事項
- [矛盾がある場合の注意点]
- [情報が古い可能性がある項目]
```

## Error Handling

**全てのエラーケースでフォールバックJSONを返す。**

### 1者成功 (Codex or Gemini片方のみ)
- 成功したソースの結果を採用
- 信頼度を「中」に設定
- 失敗したソースを明記: `⚠️ [Codex/Gemini]検証に失敗しました`

### 2者成功 (Both Codex and Gemini)
- 通常のマージ処理
- 信頼度は一致度に基づいて判定

### 0者成功 (Both failed)
- Claude Codeの結果のみ提示
- 信頼度を「未検証」と明記
- ユーザーに手動確認を推奨: `⚠️ 外部検証に失敗しました。手動での確認を推奨します`

## Integration with latest-docs

`latest-docs` スキルから呼び出される場合:
- Step 1の検索クエリにバージョン・deprecation関連を追加
- 結果を `latest-docs` のフォーマットに合わせて返却

## Important Reminders

1. **並列実行**: Codex と Gemini は必ず並列で実行する
2. **Gemini の強み活用**: Gemini は WebSearch ツールが使えるため、最新情報の取得に特に有効
3. **参照URL必須**: 検証対象のURLをCodex/Geminiの両方に渡す
4. **矛盾は隠さない**: 3者の結果が矛盾する場合、すべて提示してユーザーに判断を委ねる
5. **鮮度チェック必須**: 情報が最新かどうか必ず確認する
6. **フォールバック保証**: 全エラーケースで有効なJSONを返す
7. **日本語出力**: すべてのユーザー向けテキストは日本語
