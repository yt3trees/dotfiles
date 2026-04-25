---
name: image-to-pptx
description: Reproduce a slide image as an editable PowerPoint (.pptx) file. Use this skill when the user attaches a slide image (PNG/JPEG/screenshot) and asks to "convert to pptx", "reproduce this slide", "trace this image to PowerPoint", "make this image editable", or similar. Distinct from pptx-generator (which creates new slides from text materials) — this skill recreates an existing visual exactly.
---

# image-to-pptx

添付されたスライド画像を、編集可能な PowerPoint (.pptx) として忠実に再現する。

## 前提

- python-pptx, Pillow が必要 (`pip install python-pptx pillow`)
- レンダリング比較には LibreOffice が便利 (Windows: `winget install TheDocumentFoundation.LibreOffice`)

## ワークフロー

### 1. 元画像の要素分解

スライド全体を以下の要素に分解して把握する。

- 背景
- タイトル
- メッセージボックス
- 左カード / 右カード
- 見出し
- 金額・数値表示
- 箇条書き
- 水色バー (中段帯)
- 注意喚起バー
- 下部結論ボックス
- ページ番号
- アイコン類

### 2. 要素ごとの再現ルール

| 要素 | 再現方法 |
|------|---------|
| テキスト | PowerPoint の編集可能テキストボックス |
| 枠・線・帯・カード・背景装飾 | PowerPoint の図形 (Shape) |
| アイコン・イラスト | 元画像から PNG/JPEG で切り出して挿入 |

- SVG は使用しない
- スライド全体を 1 枚画像として貼り付けない

### 3. アイコンの切り出し

元画像から対象アイコン部分を Pillow でトリミングし PNG として保存して挿入する。  
切り出しが困難な場合は画像生成ツールで補う。SVG には変換しない。

```python
from PIL import Image
img = Image.open("source.png")
icon = img.crop((left, top, right, bottom))
icon.save("icon_name.png")
```

### 4. スライドサイズ

- 16:9 固定
- 幅 13.333 inch / 高さ 7.5 inch (python-pptx: `Inches(13.333)` / `Inches(7.5)`)

### 5. テキスト・色・余白の忠実再現

- テキストは元画像から正確に転記 (誤字・全角半角・数字・句読点を合わせる)
- 文字が折り返されないようテキストボックス幅を調整する
- 代表色の参考値:
  - 濃紺 (本文) : `#1E3A5F` 付近
  - 明るい青 (強調) : `#4A6FA5` 付近
  - 薄い水色 (帯) : `#D6EAF8` 付近
  - 薄いグレー (背景) : `#F5F5F5` 付近
- 角丸カードには `shape.adjustments` で角丸を設定する

### 6. レンダリング → 比較 → 修正

PPTX 作成後は必ずレンダリング画像を出力し、元画像と目視比較する。

```bash
# LibreOffice で PNG に変換
soffice --headless --convert-to png output.pptx --outdir ./render/
```

- 最低 1 回は修正サイクルを回す
- 明らかに崩れている状態で納品しない

### 7. 比較チェックリスト

- タイトルの位置とサイズ
- メッセージ枠の位置と高さ
- 左右カードの位置・幅・高さ
- 見出しアイコンの位置
- 金額表示のサイズ
- 右カード内の箇条書きの行間
- 中段バーの高さ
- 注意喚起バーの位置
- 下部結論ボックスの位置・高さ・文字サイズ
- ページ番号
- 文字折り返しがないか
- 余白の違和感

### 8. 最終チェック

- SVG ファイルが PPTX 内に含まれていないこと
- スライド全体が背景画像化されていないこと
- テキストが PowerPoint 上で編集できること
- 図形が個別に選択できること

## 納品要件

- 編集可能な .pptx ファイル
- SVG なし
- 1 枚画像化なし
- テキスト編集可能
- 元画像と比較して大きな崩れがない状態
