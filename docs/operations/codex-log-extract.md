# Codexログ抽出手順

## 概要

CodexのJSONLログから user / assistant の会話のみを抽出してMarkdownとして保存する。

## 手順

```bash
jq -r '
  select(.type=="response_item" and .payload.type=="message")
  | select(.payload.role=="user" or .payload.role=="assistant")
  | "\n## " + (if .payload.role=="user" then "🧑 User" else "🤖 Assistant" end)
    + "\n\n"
    + ([.payload.content[].text] | join("\n"))
' ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl \
> ~/dev/projects/terraform-hannibal/docs/memo/codex-YYYY-MM-DD.md
```
