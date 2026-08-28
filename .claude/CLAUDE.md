##############################################################################
#   MANDATORY: QUALITY-GATE - READ THIS FIRST, DO NOT SKIP                  #
##############################################################################

**After Edit/Write/file-modifying Bash → MUST run `quality-gate` skill BEFORE responding.**

1. Complete ALL file edits
2. STOP - run: Skill tool with skill="quality-gate"
3. If fail → fix → re-run (max 5 retries, then notify user)
4. THEN respond to user

⚠️ Responding WITHOUT running quality-gate = violation. Run it NOW.

##############################################################################

# Skills

## Auto Skills

| Skill | Trigger | Description |
|-------|---------|-------------|
| quality-gate | After Edit/Write, before commit/PR | Format/lint/build + context-hygiene (BLOCKING) + codex-review + gemini-review (parallel) + pr-comprehend digest |
| pr-comprehend | Auto via quality-gate on commit (light) / PR (full) | 仕様/影響範囲/AI特有リスク digest を .claude/pr-review/ に保存 |
| context-hygiene | Auto via quality-gate / `/commit` / `/pr` / `/push` | セッション文脈依存テキストの排除 (コードコメント / commit message / PR description) + prr 移送下書き。基準は `.claude/rules/comment-policy.md` |
| latest-docs | Before implementation | Verify latest documentation |
| backend-go | Go implementation | Go backend best practices |
| frontend-design | Figma implementation | Figma to code implementation |
| infra-terraform | Terraform implementation | Terraform best practices |

## Manual Skills

| Skill | Description |
|-------|-------------|
| codex-review | Code review via Codex |
| gemini-review | Code review via Gemini (parallel with codex-review) |
| pr-comprehend | 他人PRの digest (`pr-comprehend <PR番号>`) / ローカルブランチ振り返り (引数なし) |
| web-research | 3者裏取りリサーチ (Claude + Codex + Gemini) |
| test-generator | TDD: Generate tests before implementation |
| security-scan | Security vulnerability scanning |
| spec-agree | 依頼 → 開発案 → 合意済み仕様 (`.claude/specs/<branch>.md`)。実装前の Gate A |
| model-consensus | Codex/Gemini の指摘を突合し、割れたら実コードで裁定。レビュー指摘を出す前に |
| codex-design | Design consultation for complex decisions |
| date-check | Verify current date from system |

## Learning Skills

| Skill | Description |
|-------|-------------|
| explain-impl | 実装解説（問題 → 解決策 → 影響範囲を段階的に、チェックリスト付き） |
| user-scenario | 変更を利用者視点シナリオ (Given/When/Then) + 受け入れ基準 + 仕様の穴に変換 |
| eli5 | 抽象度を変えて説明し直す (ELI5 / ELI14 / ELII / ELIE) |
| grill-me | 理解度を口頭試問で試す（L1 想起 → L4 エッジケース、採点 + 弱点特定） |

## Workflows

作業は 2 つのフローに乗る。**フェーズ順に進み、ゲートで止まる。**
ゲートの成立条件と成果物形式は `.claude/rules/flow-gates.md` が単一の情報源。

### 開発フロー — `/dev-flow <チケット / やりたいこと>`

| # | フェーズ | skill / command | ゲート |
|---|---------|-----------------|--------|
| 1-2 | 依頼 → 開発案 → 仕様調整 | `spec-agree` | **Gate A**: spec に `agreed-by: user` + `agreed-digest` 一致 |
| 3 | TDD 実装 | `test-generator` → 実装 → `quality-gate` | quality-gate (context-hygiene 含む) |
| 4 | 仕様・シナリオ・実装の理解 | `user-scenario` → `explain-impl` →（既定で）`grill-me` | **Gate B**: 各項目に **ユーザー自身の説明** が残っていること |
| 5 | PR 作成 | `/pr` | context-hygiene (BLOCKING) |
| 6 | レビュワー向け補足 | `prr`（下書きは context-hygiene が生成） | 投稿はユーザー |

### レビューフロー — `/review-flow <PR番号>`

| # | フェーズ | skill / command | ゲート |
|---|---------|-----------------|--------|
| 1-2 | PR 受領 → 把握 | `pr-comprehend <PR番号>` | — |
| 3 | 機械チェック | `gh pr checks` / ローカル実行 | **Gate C**: 実行結果が残っていること（モデルの指摘は Gate C ではない） |
| 4 | 内部実装の読解支援 | `explain-impl <PR番号>`（`eli5` / `user-scenario` / `grill-me`） | **Gate B'**: `pr-head` 基準の理解確認記録 |
| 5 | 指摘の裁定 | `codex-review` + `gemini-review` → `model-consensus` | **Gate D**: 全指摘に行き先が付く（UNRESOLVED はユーザーが決める） |
| 6 | 終端分岐 | `prr`（approve / comment / change request） | 投稿はユーザー |

**ゲートを飛ばせるのはユーザーだけ。** 「軽微だから」と AI が判断して緩めるのは違反。
**理解ゲートはユーザー自身の説明が証跡。** AI が要約を書いて ✅ を付けるのはゲートの偽装。

##############################################################################
#   LEARNING MODE — WHEN EXPLICITLY ENABLED                                  #
##############################################################################

> **デフォルトは通常作業モード**。以下の教師モード指示は、ユーザーが明示的に学習意図を示したとき（後述の Engagement triggers）にのみ有効化される。それ以外のルーチン作業（実装・修正・コミット・PR 作成など）は通常通り簡潔な完了報告で終了すること。

### Engagement triggers (opt-in)

教師モードが**有効になる**条件:

- ユーザーが「教えて」「なんでこうしたの？」「説明して」「learn」などの**学習意図を明示**したとき → 即座に教師モードに切替
- ユーザーが直前のタスク完了後に「ちょっと解説して」「振り返り」など振り返り意図を示したとき
- ユーザーが「クイズ出して」「理解できてるか試して」「仕様を整理して」など理解確認・仕様把握の意図を示したとき
- 上記いずれかが発火した後は、ユーザーが「ok」「完了」「次行こう」など終了意図を示すまで教師モードを維持

教師モードが**有効にならない**ケース（デフォルト）:

- 通常の実装・修正・コミット・PR 作成などのルーチン作業 → 短い完了報告で終了
- ユーザーが学習意図を示していない初回リクエスト → 通常の作業モードで応答

要するに教師モードは opt-in。明示シグナルが無ければ以下の指示は適用しない。

### 教師モード有効時のみ適用される指示

> 以下は **教師モードが有効化された場合に限り** 適用される。デフォルトの通常作業モードでは無視すること。

進め方の詳細は Learning Skills 側に定義済み。ここでは **どの skill に振るか** を決める。

| ユーザーの発話 | 起動する skill |
|---------------|---------------|
| 「解説して」「なんでこうしたの？」「振り返り」「learn」 | `explain-impl` |
| 「どう使われるの」「仕様を整理して」「受け入れ基準」「テスト観点」 | `user-scenario` |
| 「もっと簡単に」「例え話で」「ELI5 / ELI14 / ELII」 | `eli5` |
| 「理解できてるか試して」「クイズ出して」「grill me」「詰めて」 | `grill-me` |

迷ったら `explain-impl` から入る（必要に応じて他 skill へ委譲する設計になっている）。
ユーザーは skill 名を直接指定して呼び出すこともできる（例: `grill-me`、`user-scenario <PR番号>`）。

#### ルータの責務（ここで規定するのはこれだけ）

1. 学習意図を検知したら **必ず上表の skill を起動する**（自前で解説を書き始めない）
2. 起動する skill が複数該当するときは `explain-impl` を選ぶ
3. 日本語で応答する（`.claude/rules/language.md`）
4. ユーザーが「ok」「完了」「次行こう」など終了意図を示すまで教師モードを維持する

進め方（チェックリストの粒度、確認の取り方、クイズ形式、終了条件）は
**各 skill の SKILL.md が単一の情報源**。ここには重複して書かない。

- 深い理解の定着（チェックリスト維持 + 段階確認 + 終了条件）が要るのは `explain-impl` と `grill-me`
- `eli5` と `user-scenario` は単発利用も想定した軽量 skill。教師モードの重い手順を強制しない

##############################################################################
