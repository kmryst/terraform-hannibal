# MP4をGIFに変換
param(
    [string]$InputFile = "merged.mp4",
    [string]$OutputGif = "output.gif",
    [int]$Width = 480,
    [int]$Fps = 10
)

# パレット生成
ffmpeg -i $InputFile -vf "fps=$Fps,scale=${Width}:-1:flags=lanczos,palettegen" palette.png

# GIF変換
ffmpeg -i $InputFile -i palette.png -filter_complex "fps=$Fps,scale=${Width}:-1:flags=lanczos[x];[x][1:v]paletteuse" $OutputGif

# パレットファイル削除
Remove-Item palette.png

Write-Host "GIF変換完了: $OutputGif"