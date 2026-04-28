# Codexログ抽出手順

## 概要

CodexのJSONLログから user / assistant の会話のみを抽出してMarkdownとして保存する。
抽出ログは Git に載せず、ローカル専用の `docs/worklogs/<agent>/YYYY-MM-DD.md` 配下へ保存する。

## 手順

```bash
jq -r '
  select(.type=="response_item" and .payload.type=="message")
  | select(.payload.role=="user" or .payload.role=="assistant")
  | "\n## " + (if .payload.role=="user" then "🧑 User" else "🤖 Assistant" end)
    + "\n\n"
    + ([.payload.content[].text] | join("\n"))
' ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl \
> ~/dev/projects/terraform-hannibal/docs/worklogs/codex/YYYY-MM-DD.md
```

## 保存先ルール

- ログは `docs/worklogs/<agent>/YYYY-MM-DD.md` に置く
- Codex の場合は `docs/worklogs/codex/YYYY-MM-DD.md`
- `docs/worklogs/**` は `.gitignore` に入れ、GitHub には載せない
