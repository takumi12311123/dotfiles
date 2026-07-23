# Self-Recap Mode

このモードは **自分のローカルブランチをマージ前に振り返る** ためのもの。
Author mode に近いが、想定シチュエーションが違う:
- Author mode: これから PR にする直前
- Self-recap mode: PR は作成済み or ローカルで熟成中、時間が経って「何やってたっけ?」となった状態

## 前提

- ローカルブランチに変更あり (base branch と diff がある)
- `pr-comprehend` (引数なし) で呼び出す
- quality-gate からは呼ばれない (これは手動専用)

## Extra prompts to inject

Self-recap mode では、Codex ai-risk scan に以下を追加で問う:

```
## Self-recap-mode extra checks

このユーザーはこのブランチの変更を書いてから時間が経過している可能性が高い。
「自分でやったが忘れていること」を思い出せるように digest を書け。

1. **コミット間の一貫性**:
   - `git log` を確認できる範囲で、各コミットのメッセージと実際の diff が
     整合しているか
   - コミットメッセージに書かれていない変更がまとめて 1 コミットに混入していないか

2. **最初の意図との乖離**:
   - 最初のコミット (base の直後) と最後のコミット (HEAD) を比べて、
     途中でアプローチを変えた形跡があるか
   - 変えた場合、古いアプローチの残骸が残っていないか (dead_code として ai_risks[] に)

3. **忘れやすい前提**:
   - 環境変数の設定、DB migration の適用、依存パッケージのインストールなど
     マージ前に必ず必要な準備を `open_questions[]` に列挙

## Output guidance

- one_liner は「時間が経ったユーザーが 5 秒で思い出せる」ような要約に
- ai_risks[] の severity は Author mode と同基準
```

## Report file naming

Author mode と同じ命名。
```
.claude/pr-review/local-<branch>-<HEAD_hash>.md
```

## Present to user

```
📄 self-recap digest 生成完了
   .claude/pr-review/local-<branch>-<hash>.md

## このブランチで何をしていたか
<one_liner>

## 変更全体像
- 変更ファイル: <N> / <+X -Y lines>
- 最初のコミット: <first commit hash + subject>
- 最新のコミット: <HEAD hash + subject>
- 破壊的変更: <あり/なし>
- 途中でアプローチ変更: <あり/なし>

## 次にやるべきこと (推測)
<open_questions から抜粋>

詳しく見ますか?
1. 仕様サマリ
2. 影響範囲
3. リスク評価
4. AI 特有リスク / 忘れ物
5. マージ前チェックリスト
6. オープン質問
0. スキップ
```
