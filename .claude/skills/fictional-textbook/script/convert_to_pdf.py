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

CSS = """
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
@media print {
    body { max-width: 100%; padding: 0 20px; }
    h1, h2, h3 { page-break-after: avoid; }
    pre, blockquote { page-break-inside: avoid; }
}
"""

def main():
    parser = argparse.ArgumentParser(description="Convert Markdown to PDF using Edge headless.")
    parser.add_argument("input", help="Path to the input Markdown file")
    parser.add_argument("output", nargs="?", help="Path to the output PDF file (optional)")
    args = parser.parse_args()

    md_file = os.path.abspath(args.input)
    if not os.path.exists(md_file):
        print(f"Error: Input file not found: {md_file}")
        sys.exit(1)

    if args.output:
        out_pdf = os.path.abspath(args.output)
    else:
        out_pdf = os.path.splitext(md_file)[0] + ".pdf"

    # Ensure output directory exists
    os.makedirs(os.path.dirname(out_pdf), exist_ok=True)

    print(f"Markdown を読み込み中: {md_file}")
    with open(md_file, encoding="utf-8") as f:
        md_text = f.read()

    print("HTML に変換中...")
    html_body = markdown2.markdown(
        md_text,
        extras=["fenced-code-blocks", "tables", "header-ids", "strike",
                "break-on-newline", "code-friendly"]
    )

    full_html = f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<style>
{CSS}
</style>
</head>
<body>
{html_body}
</body>
</html>"""

    # 一時 HTML ファイルに書き出し
    tmp_html = os.path.join(tempfile.gettempdir(), "fictional_book_tmp.html")
    with open(tmp_html, "w", encoding="utf-8") as f:
        f.write(full_html)
    print(f"HTML 一時ファイル: {tmp_html}")

    print("Edge でPDF変換中... (しばらくかかります)")
    if not os.path.exists(EDGE):
        print(f"Error: Edge executable not found at {EDGE}")
        sys.exit(1)

    cmd = [
        EDGE,
        "--headless",
        "--disable-gpu",
        "--run-all-compositor-stages-before-draw",
        "--print-to-pdf=" + out_pdf,
        "--print-to-pdf-no-header",
        "--no-sandbox",
        "file:///" + tmp_html.replace("\\", "/"),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    
    if result.returncode != 0:
        print("Error during Edge execution:")
        print("stdout:", result.stdout)
        print("stderr:", result.stderr)
        sys.exit(result.returncode)

    if os.path.exists(out_pdf):
        size = os.path.getsize(out_pdf)
        print(f"\n完成: {out_pdf}  ({size:,} bytes)")
    else:
        print("ERROR: PDFファイルが生成されませんでした")
        sys.exit(1)

if __name__ == "__main__":
    main()
