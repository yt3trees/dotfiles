#!/usr/bin/env python3
"""
Markdown to PDF converter using markdown2 + Edge headless
Usage: python convert_to_pdf.py input.md [output.pdf]
"""
import os
import sys
import subprocess
import tempfile
import argparse

# Check for markdown2 dependency
try:
    import markdown2
except ImportError:
    print("Error: 'markdown2' library is not installed.")
    print("Please install it using: pip install markdown2")
    sys.exit(1)

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
EBOOK_CONVERT = r"C:\Program Files\Calibre2\ebook-convert.exe"

CSS = """
@page {
    size: A4;
    margin: 18mm 16mm;
    /* ヘッダ・フッタを完全に無効化 */
    @top-left { content: ""; }
    @top-center { content: ""; }
    @top-right { content: ""; }
    @bottom-left { content: ""; }
    @bottom-center { content: ""; }
    @bottom-right { content: ""; }
}
body {
    font-family: "Meiryo", "Yu Gothic", "MS Gothic", sans-serif;
    font-size: 11pt;
    line-height: 1.8;
    color: #1a1a1a;
    max-width: 900px;
    margin: 0 auto;
    padding: 20px 40px;
}
h1 { font-size: 2em; margin-top: 1.5em; border-bottom: 3px solid #2c5282; padding-bottom: 0.3em; }
h2 { font-size: 1.6em; margin-top: 1.8em; border-bottom: 2px solid #4299e1; padding-bottom: 0.2em; color: #2c5282; }
h3 { font-size: 1.25em; margin-top: 1.4em; color: #2b6cb0; }
h4 { font-size: 1.1em; margin-top: 1.2em; color: #2c5282;
     background: #ebf8ff; border-left: 4px solid #4299e1; padding: 6px 12px; }
p { margin: 0.8em 0; text-align: justify; }
code {
    font-family: "Consolas", "Courier New", monospace;
    background: #f0f4f8;
    padding: 2px 5px;
    border-radius: 3px;
    font-size: 0.9em;
}
pre {
    background: #2d3748;
    color: #e2e8f0;
    padding: 16px;
    border-radius: 6px;
    overflow-x: auto;
    font-size: 0.9em;
    line-height: 1.6;
}
pre code { background: none; padding: 0; color: inherit; }
blockquote {
    border-left: 4px solid #bee3f8;
    margin: 1em 0;
    padding: 8px 16px;
    background: #ebf8ff;
    color: #2c5282;
}
ul, ol { padding-left: 1.8em; }
li { margin: 0.4em 0; }
hr { border: none; border-top: 1px solid #cbd5e0; margin: 2em 0; }
table { border-collapse: collapse; width: 100%; margin: 1em 0; }
th { background: #2c5282; color: white; padding: 8px 12px; }
td { border: 1px solid #cbd5e0; padding: 7px 12px; }
tr:nth-child(even) { background: #f7fafc; }
a { color: #2b6cb0; text-decoration: none; }
img { max-width: 100%; max-height: 60vh; height: auto; display: block; margin: 1em auto; object-fit: contain; }
.cover-wrapper { position: relative; display: block; width: 100%; margin: 0; }
.cover-wrapper img { max-height: none; width: 100%; margin: 0; }
.cover-text {
    position: absolute; bottom: 0; left: 0; right: 0;
    background: linear-gradient(transparent, rgba(0,0,0,0.82));
    color: #fff; padding: 60px 36px 36px; text-align: left;
}
.cover-version { font-size: 0.95em; letter-spacing: 0.08em; opacity: 0.85; margin-bottom: 6px; }
.cover-title { font-size: 2.4em; font-weight: bold; line-height: 1.2; margin-bottom: 10px; text-shadow: 0 2px 6px rgba(0,0,0,0.5); }
.cover-subtitle { font-size: 1.0em; opacity: 0.9; margin-bottom: 18px; }
.cover-author { font-size: 1.1em; font-weight: bold; }
.cover-date { font-size: 0.85em; opacity: 0.75; margin-top: 4px; }
.mermaid {
    background: #f7fafc;
    border: 1px solid #cbd5e0;
    border-radius: 6px;
    padding: 16px;
    margin: 1em 0;
    text-align: center;
    page-break-inside: avoid;
}
.mermaid-svg {
    margin: 1em auto;
    text-align: center;
    page-break-inside: avoid;
    overflow-x: auto;
}
.mermaid-svg svg {
    max-width: 100%;
    height: auto;
}
@media print {
    body { max-width: 100%; padding: 0 20px; }
    h1, h2, h3 { page-break-after: avoid; }
    pre, blockquote, .mermaid { page-break-inside: avoid; }
}
"""

def write_pdf_with_reportlab(md_text, out_pdf):
    """Fallback PDF generation when Edge headless print is unavailable."""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import mm
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.cidfonts import UnicodeCIDFont

    pdfmetrics.registerFont(UnicodeCIDFont("HeiseiKakuGo-W5"))
    pdfmetrics.registerFont(UnicodeCIDFont("HeiseiMin-W3"))

    styles = getSampleStyleSheet()
    base = ParagraphStyle(
        "base", parent=styles["Normal"], fontName="HeiseiMin-W3",
        fontSize=10.5, leading=17
    )
    h1 = ParagraphStyle(
        "h1", parent=base, fontName="HeiseiKakuGo-W5",
        fontSize=20, leading=28, spaceBefore=12, spaceAfter=10
    )
    h2 = ParagraphStyle(
        "h2", parent=base, fontName="HeiseiKakuGo-W5",
        fontSize=15, leading=22, spaceBefore=12, spaceAfter=8
    )
    h3 = ParagraphStyle(
        "h3", parent=base, fontName="HeiseiKakuGo-W5",
        fontSize=12, leading=18, spaceBefore=10, spaceAfter=6
    )
    h4 = ParagraphStyle(
        "h4", parent=base, fontName="HeiseiKakuGo-W5",
        fontSize=11, leading=17, spaceBefore=8, spaceAfter=5
    )

    story = []
    for raw_line in md_text.splitlines():
        line = raw_line.rstrip()
        if not line:
            story.append(Spacer(1, 4))
            continue
        if line.strip() == "---":
            story.append(Spacer(1, 8))
            continue

        esc = line.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        if esc.startswith("# "):
            story.append(Paragraph(esc[2:], h1))
        elif esc.startswith("## "):
            story.append(Paragraph(esc[3:], h2))
        elif esc.startswith("### "):
            story.append(Paragraph(esc[4:], h3))
        elif esc.startswith("#### "):
            story.append(Paragraph(esc[5:], h4))
        elif esc.startswith("- "):
            story.append(Paragraph("・" + esc[2:], base))
        else:
            story.append(Paragraph(esc, base))

    doc = SimpleDocTemplate(
        out_pdf, pagesize=A4,
        leftMargin=16 * mm, rightMargin=16 * mm,
        topMargin=14 * mm, bottomMargin=14 * mm
    )
    doc.build(story)

def main():
    parser = argparse.ArgumentParser(description="Convert Markdown to PDF or EPUB.")
    parser.add_argument("input", help="Path to the input Markdown file")
    parser.add_argument("output", nargs="?", help="Path to the output file (optional)")
    parser.add_argument("--epub", action="store_true", help="Output EPUB instead of PDF")
    args = parser.parse_args()

    md_file = os.path.abspath(args.input)
    if not os.path.exists(md_file):
        print(f"Error: Input file not found: {md_file}")
        sys.exit(1)

    ext = ".epub" if args.epub else ".pdf"
    if args.output:
        out_file = os.path.abspath(args.output)
    else:
        out_file = os.path.splitext(md_file)[0] + ext

    # Ensure output directory exists
    os.makedirs(os.path.dirname(out_file), exist_ok=True)

    print(f"Markdown を読み込み中: {md_file}")
    with open(md_file, encoding="utf-8") as f:
        md_text = f.read()

    print("HTML に変換中...")
    import re
    import base64
    import urllib.request

    # 表紙メタデータをマークダウン冒頭から抽出
    def parse_cover_meta(text):
        lines = [l.strip() for l in text.splitlines()]
        meta = {"title": "", "version": "", "subtitle": "", "author": "", "date": ""}
        for i, line in enumerate(lines[:20]):
            if line.startswith("# ") and not meta["title"]:
                meta["title"] = line[2:]
            elif line.startswith("## ") and not meta["version"]:
                meta["version"] = line[3:]
            elif line and not line.startswith("#") and not line.startswith("---") and not line.startswith("!"):
                if not meta["subtitle"]:
                    meta["subtitle"] = line
                elif not meta["author"]:
                    meta["author"] = re.sub(r'[📘📗📙📚✍️]', '', line).strip()
                elif not meta["date"]:
                    meta["date"] = line
        return meta

    cover_meta = parse_cover_meta(md_text)

    # 表紙テキストブロック(冒頭〜最初の --- まで)を削除: カバー画像オーバーレイに情報を載せるため不要
    md_text = re.sub(r'\A.*?^---\s*\n', '', md_text, count=1, flags=re.DOTALL | re.MULTILINE)

    # mermaid ブロックを npx mmdc で PNG に変換して base64 埋め込み
    def prerender_mermaid(md):
        counter = [0]
        def replace_mermaid(match):
            mmd_src = match.group(1)
            counter[0] += 1
            tmp_mmd = os.path.join(tempfile.gettempdir(), f"mermaid_{counter[0]}.mmd")
            tmp_png = os.path.join(tempfile.gettempdir(), f"mermaid_{counter[0]}.png")
            with open(tmp_mmd, "w", encoding="utf-8") as f:
                f.write(mmd_src)
            try:
                npx_cmd = "npx.cmd" if os.name == "nt" else "npx"
                r = subprocess.run(
                    [npx_cmd, "--yes", "@mermaid-js/mermaid-cli",
                     "-i", tmp_mmd, "-o", tmp_png,
                     "--scale", "3", "--width", "2400"],
                    capture_output=True, text=True, timeout=60
                )
                if r.returncode == 0 and os.path.exists(tmp_png):
                    with open(tmp_png, "rb") as f:
                        data = base64.b64encode(f.read()).decode("ascii")
                    print(f"  [Mermaid] PNG 変換成功 ({counter[0]})")
                    return f'\n<div class="mermaid-svg"><img src="data:image/png;base64,{data}" style="max-width:100%;height:auto;"></div>\n'
            except Exception as e:
                print(f"  [WARN] Mermaid 変換失敗: {e}")
            return f'```mermaid\n{mmd_src}\n```'

        return re.sub(r'```mermaid\n(.*?)\n```', replace_mermaid, md, flags=re.DOTALL)

    print("Mermaid ブロックを事前レンダリング中...")
    md_text = prerender_mermaid(md_text)

    html_body = markdown2.markdown(
        md_text,
        extras=["fenced-code-blocks", "tables", "header-ids", "strike",
                "break-on-newline", "code-friendly"]
    )

    # mermaid コードブロックを div.mermaid に置換
    html_body = re.sub(
        r'<pre><code class="language-mermaid">(.*?)</code></pre>',
        lambda m: '<div class="mermaid">' + m.group(1).replace('&lt;', '<').replace('&gt;', '>').replace('&amp;', '&') + '</div>',
        html_body,
        flags=re.DOTALL,
    )

    # 画像を base64 データ URI に変換（相対パス → 絶対参照）
    md_dir = os.path.dirname(md_file)
    def embed_image(match):
        src = match.group(1)
        if src.startswith(('http', 'data:', 'file:')):
            return match.group(0)
        abs_path = os.path.normpath(os.path.join(md_dir, src))
        if not os.path.exists(abs_path):
            print(f"  [WARN] 画像が見つかりません: {abs_path}")
            return match.group(0)
        ext = os.path.splitext(abs_path)[1].lower().lstrip('.')
        mime = {'jpg': 'jpeg', 'jpeg': 'jpeg', 'png': 'png', 'gif': 'gif', 'webp': 'webp'}.get(ext, 'png')
        with open(abs_path, 'rb') as f:
            data = base64.b64encode(f.read()).decode('ascii')
        return f'src="data:image/{mime};base64,{data}"'

    html_body = re.sub(r'src="([^"]*)"', embed_image, html_body)

    # 表紙画像 (alt が "表紙:" で始まる最初の img) をオーバーレイラッパーに置換
    def make_cover_overlay(m):
        img_tag = m.group(0)
        t = cover_meta
        overlay_html = f"""<div class="cover-wrapper">
{img_tag}
<div class="cover-text">
  <div class="cover-version">{t['version']}</div>
  <div class="cover-title">{t['title']}</div>
  <div class="cover-subtitle">{t['subtitle']}</div>
  <div class="cover-author">{t['author']}</div>
  <div class="cover-date">{t['date']}</div>
</div>
</div>"""
        return overlay_html

    html_body = re.sub(
        r'<img[^>]+alt="表紙:[^"]*"[^>]*>',
        make_cover_overlay, html_body, count=1
    )

    # mermaid.js をローカルキャッシュ（CDN ではなく file:/// で読み込むことで headless でも確実に実行）
    mermaid_cache = os.path.join(tempfile.gettempdir(), "mermaid.min.js")
    if not os.path.exists(mermaid_cache):
        print("mermaid.js をダウンロード中...")
        try:
            urllib.request.urlretrieve(
                "https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js",
                mermaid_cache
            )
            print(f"  保存: {mermaid_cache}")
        except Exception as e:
            print(f"  [WARN] ダウンロード失敗: {e}")
            mermaid_cache = None

    if mermaid_cache and os.path.exists(mermaid_cache):
        mermaid_js_uri = "file:///" + mermaid_cache.replace("\\", "/")
        mermaid_script_tag = f'<script src="{mermaid_js_uri}"></script>'
    else:
        mermaid_script_tag = '<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>'

    full_html = f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<style>
{CSS}
</style>
{mermaid_script_tag}
<script>
mermaid.initialize({{ startOnLoad: true, theme: 'default', flowchart: {{ htmlLabels: true, useMaxWidth: true }} }});
</script>
</head>
<body>
{html_body}
</body>
</html>"""

    # EPUB 用: body から cover-wrapper ブロックを除去(calibre が別途カバーページを生成するため)
    epub_html = full_html
    if args.epub:
        epub_html = re.sub(
            r'<div class="cover-wrapper">.*?</div>\s*',
            '', epub_html, count=1, flags=re.DOTALL
        )

    # 一時 HTML ファイルに書き出し
    tmp_html = os.path.join(tempfile.gettempdir(), "fictional_book_tmp.html")
    with open(tmp_html, "w", encoding="utf-8") as f:
        f.write(epub_html if args.epub else full_html)
    print(f"HTML 一時ファイル: {tmp_html}")

    if args.epub:
        # EPUB 変換: calibre ebook-convert を使用
        print("calibre で EPUB 変換中...")
        if not os.path.exists(EBOOK_CONVERT):
            print(f"Error: ebook-convert not found at {EBOOK_CONVERT}")
            sys.exit(1)

        # タイトル・著者をマークダウン冒頭から取得
        title = "入門書"
        author = "著者不明"
        for line in md_text.splitlines():
            line = line.strip()
            if line.startswith("# ") and title == "入門書":
                title = line[2:].strip()
            if title != "入門書" and not line.startswith("#") and line and author == "著者不明":
                author = re.sub(r'[📘📗📙📚✍️]', '', line).strip()
                break

        # 表紙画像にテキストをPillowで合成してEPUBカバーを作成
        cover_match = re.search(r'<img[^>]+src="data:image/[^;]+;base64,([^"]+)"', full_html)
        cover_path = None
        if cover_match:
            raw_cover = os.path.join(tempfile.gettempdir(), "epub_cover_raw.png")
            cover_path = os.path.join(tempfile.gettempdir(), "epub_cover.png")
            with open(raw_cover, "wb") as cf:
                cf.write(base64.b64decode(cover_match.group(1)))
            try:
                from PIL import Image, ImageDraw, ImageFont
                img = Image.open(raw_cover).convert("RGBA")
                w, h = img.size

                # 下部グラデーションオーバーレイ
                overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
                draw_ov = ImageDraw.Draw(overlay)
                grad_h = int(h * 0.55)
                for y in range(grad_h):
                    alpha = int(200 * (y / grad_h) ** 1.5)
                    draw_ov.line([(0, h - grad_h + y), (w, h - grad_h + y)],
                                 fill=(0, 0, 0, alpha))
                img = Image.alpha_composite(img, overlay).convert("RGB")
                draw = ImageDraw.Draw(img)
                font_path = r"C:\Windows\Fonts\YuGothB.ttc"
                font_reg_path = r"C:\Windows\Fonts\YuGothM.ttc"
                def load_font(size, bold=True):
                    try:
                        return ImageFont.truetype(font_path if bold else font_reg_path,
                                                  size, index=0)
                    except:
                        return ImageFont.load_default()
                margin = int(w * 0.07)
                # 90%安全マージンで右端へのはみ出しを防止
                max_text_w = int((w - margin * 2) * 0.90)

                def draw_wrapped(drw, text, x, y_start, font, fill):
                    """1文字ずつ測定して折り返す。次のy座標を返す。"""
                    lines, cur = [], ""
                    for ch in text:
                        test = cur + ch
                        bbox = drw.textbbox((0, 0), test, font=font)
                        if bbox[2] > max_text_w and cur:
                            lines.append(cur)
                            cur = ch
                        else:
                            cur = test
                    if cur:
                        lines.append(cur)
                    lh = drw.textbbox((0, 0), "あ", font=font)[3] + int(w * 0.008)
                    for line in lines:
                        drw.text((x, y_start), line, font=font, fill=fill)
                        y_start += lh
                    return y_start + int(w * 0.01)

                y_pos = int(h * 0.52)
                # バージョン
                f_ver = load_font(int(w * 0.038), bold=False)
                y_pos = draw_wrapped(draw, cover_meta["version"], margin, y_pos, f_ver,
                                     (220, 220, 220))
                y_pos += int(w * 0.01)
                # タイトル
                f_title = load_font(int(w * 0.072))
                y_pos = draw_wrapped(draw, cover_meta["title"], margin, y_pos, f_title,
                                     (255, 255, 255))
                y_pos += int(w * 0.015)
                # サブタイトル
                f_sub = load_font(int(w * 0.034), bold=False)
                y_pos = draw_wrapped(draw, cover_meta["subtitle"], margin, y_pos, f_sub,
                                     (200, 220, 255))
                y_pos += int(w * 0.01)
                # 著者
                f_auth = load_font(int(w * 0.042))
                y_pos = draw_wrapped(draw, cover_meta["author"], margin, y_pos, f_auth,
                                     (240, 240, 240))
                # 日付
                f_date = load_font(int(w * 0.030), bold=False)
                draw.text((margin, y_pos), cover_meta["date"], font=f_date,
                          fill=(180, 180, 180))
                img.save(cover_path)
                print("  表紙テキスト合成完了")
            except Exception as e:
                print(f"  [WARN] 表紙テキスト合成失敗: {e}")
                cover_path = raw_cover

        cmd = [
            EBOOK_CONVERT, tmp_html, out_file,
            "--title", title,
            "--authors", author,
            "--language", "ja",
            "--chapter", "//h:h2",
            "--level1-toc", "//h:h2",
            "--level2-toc", "//h:h3",
            "--extra-css", "body{font-family:serif;line-height:1.8;} img{max-width:100%;}",
            "--no-default-epub-cover",
            "--no-svg-cover",
            "--output-profile", "tablet",
        ]
        if cover_path:
            cmd += ["--cover", cover_path]

        result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                                errors="replace", timeout=120)
        if os.path.exists(out_file):
            size = os.path.getsize(out_file)
            print(f"\n完成(EPUB): {out_file}  ({size:,} bytes)")
        else:
            print("ERROR: EPUBファイルが生成されませんでした")
            print(result.stdout[-500:] if result.stdout else "")
            print(result.stderr[-500:] if result.stderr else "")
            sys.exit(1)
        return

    # PDF 変換: Edge headless
    print("Edge でPDF変換中... (しばらくかかります)")
    if not os.path.exists(EDGE):
        print(f"Error: Edge executable not found at {EDGE}")
        sys.exit(1)

    cmd = [
        EDGE,
        "--headless",
        "--disable-gpu",
        "--run-all-compositor-stages-before-draw",
        "--virtual-time-budget=30000",
        "--print-to-pdf=" + out_file,
        "--print-to-pdf-no-header",
        "--no-pdf-header-footer",
        "--no-sandbox",
        "--allow-file-access-from-files",
        "file:///" + tmp_html.replace("\\", "/"),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)

    if os.path.exists(out_file):
        size = os.path.getsize(out_file)
        print(f"\n完成(Edge): {out_file}  ({size:,} bytes)")
        return

    print("Edge経由のPDF生成に失敗しました。ReportLabでフォールバックします。")
    if result.returncode != 0:
        print("Edge stdout:", result.stdout[:500] if result.stdout else "(empty)")
        print("Edge stderr:", result.stderr[:500] if result.stderr else "(empty)")

    try:
        write_pdf_with_reportlab(md_text, out_file)
    except ImportError:
        print("Error: fallback requires 'reportlab'. Install with: pip install reportlab")
        sys.exit(1)

    if os.path.exists(out_file):
        size = os.path.getsize(out_file)
        print(f"\n完成(Fallback): {out_file}  ({size:,} bytes)")
    else:
        print("ERROR: PDFファイルが生成されませんでした")
        sys.exit(1)

if __name__ == "__main__":
    main()
