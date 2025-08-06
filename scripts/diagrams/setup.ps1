Write-Host "=== NestJS Hannibal 3 AWS構成図生成セットアップ ===" -ForegroundColor Green

Write-Host "1. Python環境確認中..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version
    Write-Host "Python確認済み: $pythonVersion" -ForegroundColor Cyan
} catch {
    Write-Error "Python未インストール: https://python.org からインストールしてください"
    exit 1
}

Write-Host "2. Diagramsライブラリインストール中..." -ForegroundColor Yellow
pip install -r requirements.txt

Write-Host "3. Graphvizインストール確認中..." -ForegroundColor Yellow
try {
    $graphvizVersion = dot -V 2>&1
    Write-Host "Graphviz確認済み: $graphvizVersion" -ForegroundColor Green
} catch {
    Write-Warning "Graphviz未インストール"
    Write-Host "インストール方法: winget install graphviz" -ForegroundColor Cyan
}

Write-Host "4. 出力ディレクトリ作成中..." -ForegroundColor Yellow
$outputDir = "..\..\docs\architecture\diagrams"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force
    Write-Host "出力ディレクトリ作成: $outputDir" -ForegroundColor Cyan
} else {
    Write-Host "出力ディレクトリ確認済み: $outputDir" -ForegroundColor Green
}

Write-Host "=== セットアップ完了 ===" -ForegroundColor Green
Write-Host "次のステップ: python generate_aws_diagram.py" -ForegroundColor Cyan