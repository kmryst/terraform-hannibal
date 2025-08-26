# MP4ファイル結合スクリプト
param(
    [string[]]$InputFiles = @("1.mp4", "2.mp4", "3.mp4"),
    [string]$OutputFile = "merged.mp4"
)

# ファイルリスト作成
$InputFiles | ForEach-Object { "file '$_'" } | Out-File -Encoding utf8 filelist.txt

# MP4結合
ffmpeg -f concat -safe 0 -i filelist.txt -c copy $OutputFile

# 一時ファイル削除
Remove-Item filelist.txt

Write-Host "MP4結合完了: $OutputFile"