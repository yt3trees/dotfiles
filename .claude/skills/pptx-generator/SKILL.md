---
name: pptx-generator
description: Generate PowerPoint presentations (.pptx) from source materials in the input/ folder. Use this skill when the user asks to "create a PowerPoint", "generate slides", "make a presentation", "convert to PPTX", or when there are files in input/ that need to be turned into a slide deck.
---

# pptx-generator

`input/` フォルダの元資料からPowerPoint(.pptx)を自動生成する。

## ワークフロー

1. 目的確認 - `input/` の全ファイルを読み、ターゲット・ゴール・期待アクションを抽出
2. 構成設計 - キーメッセージ抽出、情報グルーピング、論理構造選択、各スライドの役割決定
3. レイアウト選択 - 15パターンから最適レイアウトを割り当て([layout-selection-guide.md](references/layout-selection-guide.md))
4. テキスト調整 - 文字数制限に合わせて調整([character-limits.md](references/character-limits.md))
5. slides.md出力 - 専用マークダウン記法で `output/slides.md` に出力([layout-rules.md](references/layout-rules.md))
6. PowerPoint生成 - Pythonスクリプトで PPTX 生成

詳細: [workflow.md](references/workflow.md)

## 15レイアウト一覧

| # | レイアウト名 | 用途 |
|---|-------------|------|
| 1 | title | 表紙(紺色背景) |
| 2 | section | セクション区切り(薄グレー背景) |
| 3 | toc | 目次・サマリー |
| 4 | bullet_points | 箇条書き(デフォルト) |
| 5 | numbered_list | 手順・ステップ |
| 6 | two_column | 2つの対比 |
| 7 | three_column | 3つの並列 |
| 8 | four_column | 4つの並列 |
| 9 | metrics | 数値・KPI(2-4個) |
| 10 | quote | 引用 |
| 11 | faq | Q&A |
| 12 | comparison_table | 比較表 |
| 13 | image_with_text | 画像+テキスト |
| 14 | chart | グラフ(bar/horizontal_bar/pie/line) |
| 15 | cta | 行動喚起(薄グレー背景) |

## リファレンス

- [workflow.md](references/workflow.md) - 6ステップワークフロー詳細
- [layout-selection-guide.md](references/layout-selection-guide.md) - 2ステップレイアウト選択フロー
- [layout-rules.md](references/layout-rules.md) - 15レイアウトの定義とマークダウン記法
- [character-limits.md](references/character-limits.md) - 文字数計算ルール、制限表
- [shape-helpers.md](references/shape-helpers.md) - OOXML図解ヘルパー(拡張用)

## slides.md の書き方

- `---` でスライド区切り
- `<!-- layout: xxx -->` でレイアウト指定
- `# 見出し` = section(h1は自動的にsectionレイアウト)
- `## 見出し` = スライドタイトル
- `### 見出し` = キーメッセージ
- `#### 見出し` = カラムヘッダー(two/three/four_column用)
- レイアウト指定なしのデフォルトは bullet_points

詳細な記法例は [layout-rules.md](references/layout-rules.md) を参照。

## PowerPoint 生成コマンド

```bash
cd .claude/skills/pptx-generator/scripts
python slide_generator_pptx.py \
  --config ../config.json \
  --markdown-file ../../../../output/slides.md \
  --output-dir ../../../../output
```

### CLI オプション

| オプション | 説明 | 必須 |
|-----------|------|------|
| --markdown-file | slides.md のパス | Yes |
| --config | config.json のパス | No |
| --title | プレゼンテーションタイトル | No |
| --output-dir | 出力先ディレクトリ | No |
| --template | テンプレート.pptx のパス | No |
| --layout | 特定レイアウトのみ出力(カンマ区切り) | No |

## config.json 構造

```json
{
  "output": { "dir": "output" },
  "font": { "family": "Meiryo UI" },
  "palette": {
    "primary": "#1E3A5F",
    "secondary": "#4A6FA5",
    "accent": "#3AA899",
    "gray": "#999999",
    "text": { "primary": "#333333", "secondary": "#666666", "light": "#FFFFFF" },
    "background": { "primary": "#FFFFFF", "secondary": "#F5F5F5", "dark": "#1E3A5F" },
    "chart": { "line_color_3": "#EDB120" }
  },
  "template": { "pptx_path": "assets/template.pptx" }
}
```

## 依存関係

- Python 3.x
- python-pptx
- lxml
- Pillow(プレースホルダー画像生成用)
