#!/usr/bin/env python3
from PIL import Image
import os

# 画像ファイルのサイズを確認
image_path = "../../docs/architecture/diagrams/nestjs-hannibal-3-architecture-20250806_150950.png"

if os.path.exists(image_path):
    with Image.open(image_path) as img:
        width, height = img.size
        print(f"画像サイズ: {width} x {height} pixels")
        print(f"アスペクト比: {width/height:.2f}")
        
        # DPI情報も確認
        dpi = img.info.get('dpi', (72, 72))
        print(f"DPI: {dpi}")
else:
    print("画像ファイルが見つかりません")