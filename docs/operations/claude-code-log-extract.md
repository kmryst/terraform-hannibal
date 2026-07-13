# Claude Codeログ抽出手順

## 概要

Claude Code の JSONL セッションログから user / assistant の会話のみを抽出して Markdown として保存する。
抽出ログは Git に載せず、ローカル専用の `docs/worklogs/claude-code/` 配下へ保存する。
ファイル名には**抽出実行時刻まで含める**（`YYYY-MM-DD-HHMMSS.md`）。

## セッションファイルの場所

```text
~/.claude/projects/-home-gatsby-dev-projects-terraform-hannibal/<session-id>.jsonl
```

セッション ID（UUID）はファイル名から確認する。

```bash
ls -lh ~/.claude/projects/-home-gatsby-dev-projects-terraform-hannibal/*.jsonl
```

## 手順

```bash
TS=$(date +%Y-%m-%d-%H%M%S)
OUT=~/dev/projects/terraform-hannibal/docs/worklogs/claude-code/${TS}.md
mkdir -p "$(dirname "$OUT")"
python3 << 'PY' > "$OUT"
import json, sys
from pathlib import Path
import glob

files = sorted(
    Path.home().glob(".claude/projects/-home-gatsby-dev-projects-terraform-hannibal/*.jsonl"),
    key=lambda p: p.stat().st_mtime
)
if not files:
    sys.exit("No session files found.")

# 最新セッションを対象にする
f = files[-1]

for line in f.read_text(errors="ignore").splitlines():
    try:
        obj = json.loads(line)
    except Exception:
        continue
    if obj.get("type") not in ("user", "assistant"):
        continue
    msg = obj.get("message", {})
    role = msg.get("role", obj["type"])
    content = msg.get("content", "")

    if isinstance(content, list):
        text = "\n".join(
            block.get("text", "") for block in content
            if isinstance(block, dict) and block.get("type") == "text"
        )
    else:
        text = content

    if not text.strip():
        continue

    label = "🧑 User" if role == "user" else "🤖 Assistant"
    print(f"\n## {label}\n\n{text}")
PY
echo "Saved to: $OUT"
```

特定のセッションを指定する場合は、`files[-1]` の代わりに直接パスを指定する。

```bash
# 例: 特定セッションを指定
python3 << 'PY' > "$OUT"
...
f = Path.home() / ".claude/projects/-home-gatsby-dev-projects-terraform-hannibal/35f06daf-5d71-4d14-a54d-ac232ebb6ad1.jsonl"
...
PY
```

## 保存先ルール

- ログは `docs/worklogs/<agent>/YYYY-MM-DD-HHMMSS.md` に置く
- Claude Code の場合は `docs/worklogs/claude-code/YYYY-MM-DD-HHMMSS.md`
- `docs/worklogs/**` は `.gitignore` に入れ、GitHub には載せない
