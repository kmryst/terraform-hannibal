# Codexログ抽出手順

## 概要

CodexのJSONLログから user / assistant の会話のみを抽出してMarkdownとして保存する。
抽出ログは Git に載せず、ローカル専用の `docs/worklogs/<agent>/` 配下へ保存する。
ファイル名には**抽出実行時刻まで含める**（`YYYY-MM-DD-HHMMSS.md`）。同一日内にセッションが伸びたあと再実行しても、過去の抽出ファイルを上書きしない。

## 手順

```bash
TS=$(date +%Y-%m-%d-%H%M%S)
OUT=~/dev/projects/terraform-hannibal/docs/worklogs/codex/${TS}.md
mkdir -p "$(dirname "$OUT")"
jq -r '
  select(.type=="response_item" and .payload.type=="message")
  | select(.payload.role=="user" or .payload.role=="assistant")
  | "\n## " + (if .payload.role=="user" then "🧑 User" else "🤖 Assistant" end)
    + "\n\n"
    + ([.payload.content[].text] | join("\n"))
' ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl \
> "$OUT"
```

`YYYY/MM/DD` は抽出対象セッションの日付（`~/.codex/sessions/` 下のディレクトリ）に合わせる。

## 保存先ルール

- ログは `docs/worklogs/<agent>/YYYY-MM-DD-HHMMSS.md` に置く
- Codex の場合は `docs/worklogs/codex/YYYY-MM-DD-HHMMSS.md`
- `docs/worklogs/**` は `.gitignore` に入れ、GitHub には載せない
