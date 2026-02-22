# OOXML図解ヘルパー(拡張用)

標準15レイアウトで対応できない高度な図解を、OOXML直接操作で作成するためのヘルパー関数群。

## 角丸バー(グラフ用)

棒グラフの棒を角丸にするために、OOXML直接操作で `<a:prstGeom prst="roundRect"/>` を追加する。

```python
from pptx.oxml.ns import qn
from lxml import etree

def set_bar_rounded_rect(bar_point):
    """棒グラフのバーを角丸四角形にする"""
    sp_pr = bar_point.format._element
    # 既存のgeomを削除
    for old in sp_pr.findall(qn('a:prstGeom')):
        sp_pr.remove(old)
    # 角丸四角形を追加
    geom = etree.SubElement(sp_pr, qn('a:prstGeom'))
    geom.set('prst', 'roundRect')
    etree.SubElement(geom, qn('a:avLst'))
```

## 折れ線マーカー

折れ線グラフのマーカーを円形・白枠付きにする。

```python
def set_line_marker(series, color_hex, size_pt=8):
    """折れ線マーカーを円形・白枠付きに設定"""
    marker = series.marker
    marker.style = XL_MARKER_STYLE.CIRCLE
    marker.size = size_pt
    marker.format.fill.solid()
    marker.format.fill.fore_color.rgb = RGBColor.from_string(color_hex)
    marker.format.line.fill.solid()
    marker.format.line.fill.fore_color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    marker.format.line.width = Pt(1.5)
```

## テンプレートスライド削除

テンプレート使用時に既存スライドを削除する。python-pptx はスライド削除APIを提供しないため、XML直接操作が必要。

```python
def remove_all_slides(prs):
    """テンプレートの既存スライドを全削除"""
    sldIdLst = prs.presentation.sldIdLst
    for sldId in list(sldIdLst):
        rId = sldId.get(qn('r:id'))
        prs.part.drop_rel(rId)
        sldIdLst.remove(sldId)
```

## プレースホルダ除去

テンプレートのプレースホルダを除去する。

```python
def remove_placeholders(slide):
    """スライドからプレースホルダを除去"""
    sp_tree = slide.shapes._spTree
    for sp in list(sp_tree):
        if sp.tag.endswith('}sp'):
            ph = sp.find('.//' + qn('p:ph'))
            if ph is not None:
                sp_tree.remove(sp)
```

## 拡張候補(将来実装)

以下の図解パターンは、必要に応じてヘルパー関数を追加して実装可能:

- 円形フロー(Circular Flow)
- シェブロンプロセス(Chevron Process)
- ガントチャート(Gantt Chart)
- 組織図(Organization Chart)
- マトリクス(2x2 Matrix)
- ピラミッド(Pyramid)
- ベン図(Venn Diagram)

これらは `slide_generator_pptx.py` に新しいレイアウト処理メソッドを追加し、`slides_markdown.py` にパーサーを追加することで対応する。
