"""
slides_markdown.py - マークダウンパーサー

slides.md を解析して SlideData のリストに変換する。
"""

import re
import unicodedata
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class TableData:
    """テーブルデータ"""
    headers: list[str] = field(default_factory=list)
    rows: list[list[str]] = field(default_factory=list)


@dataclass
class SlideData:
    """1スライド分のデータ"""
    layout: str = "bullet_points"
    title: str = ""
    key_message: str = ""
    bullets: list[str] = field(default_factory=list)
    numbered_items: list[dict] = field(default_factory=list)
    columns: list[dict] = field(default_factory=list)
    metrics: list[dict] = field(default_factory=list)
    quote_text: str = ""
    quote_author: str = ""
    faq_items: list[dict] = field(default_factory=list)
    table: Optional[TableData] = None
    image_path: str = ""
    image_alt: str = ""
    description: str = ""
    chart_type: str = ""
    button_text: str = ""
    raw_lines: list[str] = field(default_factory=list)


def char_width(text: str) -> int:
    """文字幅を計算する(全角=2, 半角=1)"""
    width = 0
    for ch in text:
        if unicodedata.east_asian_width(ch) in ('F', 'W'):
            width += 2
        else:
            width += 1
    return width


def truncate_text(text: str, max_width: int) -> str:
    """文字幅制限に合わせてテキストを切り詰める"""
    if char_width(text) <= max_width:
        return text
    result = []
    current_width = 0
    for ch in text:
        cw = 2 if unicodedata.east_asian_width(ch) in ('F', 'W') else 1
        if current_width + cw > max_width - 3:  # 「...」分を確保
            break
        result.append(ch)
        current_width += cw
    return ''.join(result) + '...'


def detect_chart_type(table: TableData) -> str:
    """テーブルデータからグラフ種別を自動判定する"""
    if not table or not table.rows:
        return "horizontal_bar"

    # ラベル列(最初の列)を取得
    labels = [row[0].replace('**', '') for row in table.rows if row]

    # 値を取得(2列目以降)
    values = []
    for row in table.rows:
        for cell in row[1:]:
            clean = cell.replace('**', '').replace('%', '').replace(',', '').strip()
            try:
                values.append(float(clean))
            except ValueError:
                pass

    # %表記チェック
    has_percent = any('%' in cell for row in table.rows for cell in row[1:])

    # 合計が約100かチェック
    if values:
        total = sum(values)
        is_percent_total = 90 <= total <= 110

    if has_percent or (values and 90 <= sum(values) <= 110):
        return "pie"

    # 時系列チェック
    time_patterns = [
        r'^\d{4}$',           # 2021, 2022
        r'^\d{4}年$',         # 2021年
        r'^\d{1,2}月$',       # 1月, 12月
        r'^Q[1-4]$',          # Q1, Q2
        r'^\d{4}/\d{1,2}$',   # 2021/1
        r'^\d{4}-\d{1,2}$',   # 2021-01
    ]
    is_time_series = all(
        any(re.match(p, label) for p in time_patterns)
        for label in labels
    )
    if is_time_series:
        return "bar"

    return "horizontal_bar"


def _parse_single_slide(lines: list[str]) -> SlideData:
    """1スライド分の行リストを解析してSlideDataに変換する"""
    slide = SlideData()
    slide.raw_lines = lines

    # layout抽出
    for line in lines:
        m = re.match(r'<!--\s*layout:\s*(\w+)\s*-->', line)
        if m:
            slide.layout = m.group(1)
            break

    # chart_type抽出
    for line in lines:
        m = re.match(r'<!--\s*chart_type:\s*(\w+)\s*-->', line)
        if m:
            slide.chart_type = m.group(1)
            break

    # コメント行を除外したコンテンツ行
    content_lines = [l for l in lines if not l.startswith('<!--')]

    # h1チェック(自動section)
    for line in content_lines:
        if re.match(r'^# [^#]', line):
            slide.layout = "section"
            slide.title = line[2:].strip()
            return slide

    # タイトル、キーメッセージ抽出
    for line in content_lines:
        if line.startswith('## ') and not line.startswith('### '):
            slide.title = line[3:].strip()
        elif line.startswith('### '):
            slide.key_message = line[4:].strip()

    # レイアウト別の解析
    if slide.layout == "title":
        _parse_title(slide, content_lines)
    elif slide.layout == "toc":
        _parse_bullets(slide, content_lines)
    elif slide.layout == "bullet_points":
        _parse_bullets(slide, content_lines)
    elif slide.layout == "numbered_list":
        _parse_numbered_list(slide, content_lines)
    elif slide.layout in ("two_column", "three_column", "four_column"):
        _parse_columns(slide, content_lines)
    elif slide.layout == "metrics":
        _parse_metrics(slide, content_lines)
    elif slide.layout == "quote":
        _parse_quote(slide, content_lines)
    elif slide.layout == "faq":
        _parse_faq(slide, content_lines)
    elif slide.layout == "comparison_table":
        _parse_table(slide, content_lines)
    elif slide.layout == "image_with_text":
        _parse_image_with_text(slide, content_lines)
    elif slide.layout == "chart":
        _parse_table(slide, content_lines)
        if not slide.chart_type and slide.table:
            slide.chart_type = detect_chart_type(slide.table)
    elif slide.layout == "cta":
        _parse_cta(slide, content_lines)
    else:
        # デフォルト: bullet_points として解析
        _parse_bullets(slide, content_lines)

    return slide


def _parse_title(slide: SlideData, lines: list[str]):
    """titleレイアウトの解析"""
    # title ではkey_messageがサブタイトル扱い
    pass


def _parse_bullets(slide: SlideData, lines: list[str]):
    """箇条書きの解析"""
    for line in lines:
        if line.startswith('- '):
            slide.bullets.append(line[2:].strip())


def _parse_numbered_list(slide: SlideData, lines: list[str]):
    """番号付きリストの解析"""
    current_item = None
    for line in lines:
        m = re.match(r'^\d+\.\s+\*\*(.+?)\*\*\s*$', line)
        if m:
            if current_item:
                slide.numbered_items.append(current_item)
            current_item = {"title": m.group(1), "description": ""}
        elif current_item and line.startswith('   ') and line.strip():
            desc = line.strip()
            if current_item["description"]:
                current_item["description"] += "\n" + desc
            else:
                current_item["description"] = desc
    if current_item:
        slide.numbered_items.append(current_item)


def _parse_columns(slide: SlideData, lines: list[str]):
    """カラムレイアウトの解析"""
    current_col = None
    for line in lines:
        if line.startswith('#### '):
            if current_col:
                slide.columns.append(current_col)
            current_col = {"heading": line[5:].strip(), "body": ""}
        elif current_col and line.strip() and not line.startswith('#'):
            if current_col["body"]:
                current_col["body"] += "\n" + line.strip()
            else:
                current_col["body"] = line.strip()
    if current_col:
        slide.columns.append(current_col)


def _parse_metrics(slide: SlideData, lines: list[str]):
    """メトリクスの解析"""
    for line in lines:
        m = re.match(r'^-\s+\*\*(.+?)\*\*\s+(.+)$', line)
        if m:
            slide.metrics.append({
                "value": m.group(1),
                "label": m.group(2).strip()
            })


def _parse_quote(slide: SlideData, lines: list[str]):
    """引用の解析"""
    quote_lines = []
    for line in lines:
        if line.startswith('> '):
            text = line[2:].strip()
            if text.startswith('--') or text.startswith('\u2014'):
                # 著者行
                slide.quote_author = re.sub(r'^[-\u2014]+\s*', '', text).strip()
            else:
                quote_lines.append(text)
    slide.quote_text = '\n'.join(quote_lines)


def _parse_faq(slide: SlideData, lines: list[str]):
    """FAQ の解析"""
    current_q = None
    current_a_lines = []
    for line in lines:
        m = re.match(r'^\*\*Q:\s*(.+?)\*\*\s*$', line)
        if m:
            if current_q:
                slide.faq_items.append({
                    "question": current_q,
                    "answer": '\n'.join(current_a_lines).strip()
                })
            current_q = m.group(1)
            current_a_lines = []
        elif current_q and line.startswith('A: '):
            current_a_lines.append(line[3:].strip())
        elif current_q and line.strip() and not line.startswith('#'):
            current_a_lines.append(line.strip())
    if current_q:
        slide.faq_items.append({
            "question": current_q,
            "answer": '\n'.join(current_a_lines).strip()
        })


def _parse_table(slide: SlideData, lines: list[str]):
    """テーブルの解析"""
    table_lines = []
    for line in lines:
        if '|' in line and not line.startswith('#'):
            table_lines.append(line.strip())

    if len(table_lines) < 2:
        return

    # ヘッダー行
    headers = [cell.strip() for cell in table_lines[0].split('|') if cell.strip()]

    # セパレータ行をスキップ(2行目)
    rows = []
    for tl in table_lines[2:]:
        cells = [cell.strip() for cell in tl.split('|') if cell.strip()]
        if cells:
            rows.append(cells)

    slide.table = TableData(headers=headers, rows=rows)


def _parse_image_with_text(slide: SlideData, lines: list[str]):
    """画像+テキストの解析"""
    desc_lines = []
    for line in lines:
        m = re.match(r'!\[(.*)?\]\((.+?)\)', line)
        if m:
            slide.image_alt = m.group(1) or ""
            slide.image_path = m.group(2)
        elif line.strip() and not line.startswith('#'):
            desc_lines.append(line.strip())
    slide.description = '\n'.join(desc_lines)


def _parse_cta(slide: SlideData, lines: list[str]):
    """CTAの解析"""
    for line in lines:
        m = re.match(r'^\[(.+?)\]\s*$', line)
        if m:
            slide.button_text = m.group(1)
            break


def parse_markdown(text: str) -> list[SlideData]:
    """マークダウンテキスト全体を解析してSlideDataのリストを返す"""
    # BOM除去
    text = text.lstrip('\ufeff')

    # ---で分割
    raw_slides = re.split(r'\n---\s*\n', text)

    slides = []
    for raw in raw_slides:
        lines = [l.rstrip() for l in raw.strip().split('\n') if l.strip()]
        if not lines:
            continue
        slide = _parse_single_slide(lines)
        slides.append(slide)

    return slides


def parse_markdown_file(filepath: str) -> list[SlideData]:
    """マークダウンファイルを読み込んで解析する"""
    with open(filepath, 'r', encoding='utf-8') as f:
        text = f.read()
    return parse_markdown(text)


if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print("Usage: python slides_markdown.py <markdown_file>")
        sys.exit(1)

    slides = parse_markdown_file(sys.argv[1])
    for i, s in enumerate(slides):
        print(f"\n--- Slide {i+1} ---")
        print(f"  Layout: {s.layout}")
        print(f"  Title: {s.title}")
        if s.key_message:
            print(f"  Key Message: {s.key_message}")
        if s.bullets:
            print(f"  Bullets: {s.bullets}")
        if s.numbered_items:
            print(f"  Numbered Items: {s.numbered_items}")
        if s.columns:
            print(f"  Columns: {s.columns}")
        if s.metrics:
            print(f"  Metrics: {s.metrics}")
        if s.quote_text:
            print(f"  Quote: {s.quote_text}")
        if s.faq_items:
            print(f"  FAQ: {s.faq_items}")
        if s.table:
            print(f"  Table: headers={s.table.headers}, rows={s.table.rows}")
        if s.chart_type:
            print(f"  Chart Type: {s.chart_type}")
        if s.image_path:
            print(f"  Image: {s.image_path}")
        if s.button_text:
            print(f"  Button: {s.button_text}")
