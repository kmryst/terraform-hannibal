# PowerShell Command Format Rules

## PowerShell Commands
- PowerShellコマンドは必ず1行で出力してください
- 改行やバックスラッシュ（`）による行継続は使用しないでください
- パイプライン（|）を使用する場合も1行で記述してください

## Examples
Good:
```powershell
Get-ChildItem -Path "C:\temp" -Recurse | Where-Object {$_.Extension -eq ".txt"} | Select-Object Name, Length
```

Bad:
```powershell
Get-ChildItem -Path "C:\temp" -Recurse `
| Where-Object {$_.Extension -eq ".txt"} `
| Select-Object Name, Length
```

## Additional Rules
- AWS CLIコマンドも同様に1行で記述
- 長いコマンドでも可読性より実行しやすさを優先