"""Markdown-to-LaTeX and Markdown-to-HTML renderers for letter bodies.

Uses mistune v3 to parse CommonMark + GFM tables/strikethrough into an AST,
then walks the tree to produce LaTeX or HTML output suitable for clinical
correspondence.

Unsupported elements (images, code blocks, footnotes) are rendered as
escaped plain text rather than silently dropped.
"""

import re
from html import escape as html_escape

import mistune


def _create_parser() -> mistune.Markdown:
    """Create a mistune parser that returns AST tokens."""
    return mistune.create_markdown(
        renderer=None,
        plugins=["table", "strikethrough"],
    )


# ---------------------------------------------------------------------------
# LaTeX renderer
# ---------------------------------------------------------------------------

_LATEX_SPECIAL = [
    # Order matters: backslash first to avoid double-escaping
    ("\\", r"\textbackslash{}"),
    ("{", r"\{"),
    ("}", r"\}"),
    ("$", r"\$"),
    ("&", r"\&"),
    ("%", r"\%"),
    ("#", r"\#"),
    ("_", r"\_"),
    ("~", r"\textasciitilde{}"),
    ("^", r"\textasciicircum{}"),
]


def _escape_latex(text: str) -> str:
    """Escape special LaTeX characters."""
    if not text:
        return ""
    # Two-pass for chars whose replacements contain braces
    _BS = "\x00BS\x00"
    _TI = "\x00TI\x00"
    _CA = "\x00CA\x00"
    text = text.replace("\\", _BS)
    text = text.replace("~", _TI)
    text = text.replace("^", _CA)
    for char, repl in _LATEX_SPECIAL[1:8]:  # { } $ & % # _
        text = text.replace(char, repl)
    text = text.replace(_BS, r"\textbackslash{}")
    text = text.replace(_TI, r"\textasciitilde{}")
    text = text.replace(_CA, r"\textasciicircum{}")
    return text


_URL_RE = re.compile(r"(https?://\S+)")


def _escape_latex_with_urls(text: str) -> str:
    """Escape LaTeX special chars, but wrap bare URLs in \\url{}.

    \\url{} handles its own escaping, so URLs must not be double-escaped.
    """
    segments = _URL_RE.split(text)
    parts = []
    for i, seg in enumerate(segments):
        if i % 2 == 1:
            # Matched URL — \url handles escaping internally
            parts.append(f"\\url{{{seg}}}")
        else:
            parts.append(_escape_latex(seg))
    return "".join(parts)


def _render_latex_children(children: list[dict]) -> str:
    """Recursively render inline children to LaTeX."""
    parts = []
    for token in children:
        t = token["type"]
        if t == "text":
            parts.append(_escape_latex_with_urls(token["raw"]))
        elif t == "strong":
            inner = _render_latex_children(token["children"])
            parts.append(f"\\textbf{{{inner}}}")
        elif t == "emphasis":
            inner = _render_latex_children(token["children"])
            parts.append(f"\\textit{{{inner}}}")
        elif t == "strikethrough":
            inner = _render_latex_children(token["children"])
            parts.append(f"\\sout{{{inner}}}")
        elif t == "softbreak":
            parts.append(" ")
        elif t == "linebreak":
            parts.append(r" \\")
        elif t == "link":
            url = token.get("attrs", {}).get("url", "")
            inner = _render_latex_children(token["children"])
            # If link text matches URL, just use \url; otherwise show text
            if inner.strip() == _escape_latex(url.strip()):
                parts.append(f"\\url{{{url}}}")
            else:
                parts.append(f"{inner} (\\url{{{url}}})")
        elif t == "block_text":
            parts.append(_render_latex_children(token["children"]))
        else:
            # Fallback: render raw text if present
            if "raw" in token:
                parts.append(_escape_latex_with_urls(token["raw"]))
            elif "children" in token:
                parts.append(_render_latex_children(token["children"]))
    return "".join(parts)


def _heading_command(level: int) -> tuple[str, str]:
    """Map heading level to LaTeX sizing commands.

    Letters don't use \\section — use font size changes instead.
    """
    sizes = {
        1: ("\\vspace{12pt}{\\Large\\bfseries ", "}\\vspace{6pt}"),
        2: ("\\vspace{10pt}{\\large\\bfseries ", "}\\vspace{4pt}"),
        3: ("\\vspace{8pt}{\\bfseries ", "}\\vspace{4pt}"),
    }
    return sizes.get(level, sizes[3])


def render_latex(body: str) -> str:
    """Convert a markdown letter body to LaTeX."""
    if not body:
        return ""

    parser = _create_parser()
    tokens = parser(body)

    parts = []
    for token in tokens:
        t = token["type"]

        if t == "paragraph":
            text = _render_latex_children(token["children"])
            parts.append(text)

        elif t == "heading":
            level = token["attrs"]["level"]
            prefix, suffix = _heading_command(level)
            text = _render_latex_children(token["children"])
            parts.append(f"{prefix}{text}{suffix}")

        elif t == "list":
            ordered = token["attrs"].get("ordered", False)
            env = "enumerate" if ordered else "itemize"
            items = []
            for item in token["children"]:
                item_text = _render_latex_children(item["children"])
                items.append(f"  \\item {item_text}")
            parts.append(
                f"\\begin{{{env}}}[nosep]\n"
                + "\n".join(items)
                + f"\n\\end{{{env}}}"
            )

        elif t == "thematic_break":
            parts.append("\\vspace{6pt}\\hrule\\vspace{6pt}")

        elif t == "table":
            parts.append(_render_latex_table(token))

        elif t == "blank_line":
            continue

        elif t == "block_quote":
            inner = _render_latex_block_tokens(token["children"])
            parts.append(
                "\\begin{quote}\n"
                + inner
                + "\n\\end{quote}"
            )

        else:
            # Unknown block: try to extract text
            if "children" in token:
                parts.append(_render_latex_children(token["children"]))
            elif "raw" in token:
                parts.append(_escape_latex(token["raw"]))

    return "\n\n\\vspace{10pt}\n\n".join(parts)


def _render_latex_block_tokens(tokens: list[dict]) -> str:
    """Render a list of block tokens (for blockquotes, etc.)."""
    parts = []
    for token in tokens:
        t = token["type"]
        if t == "paragraph":
            parts.append(_render_latex_children(token["children"]))
        elif t == "blank_line":
            continue
        elif "children" in token:
            parts.append(_render_latex_children(token["children"]))
    return "\n\n".join(parts)


def _render_latex_table(token: dict) -> str:
    """Render a GFM table to LaTeX tabular."""
    # Collect alignments and rows
    head_cells = token["children"][0]["children"]  # table_head -> cells
    body_rows = token["children"][1]["children"] if len(token["children"]) > 1 else []

    n_cols = len(head_cells)
    aligns = []
    for cell in head_cells:
        a = cell["attrs"].get("align")
        if a == "center":
            aligns.append("c")
        elif a == "right":
            aligns.append("r")
        else:
            aligns.append("l")

    col_spec = " ".join(aligns)

    lines = [f"\\begin{{tabular}}{{{col_spec}}}"]
    lines.append("\\hline")

    # Header
    header_cells = [
        f"\\textbf{{{_render_latex_children(cell['children'])}}}"
        for cell in head_cells
    ]
    lines.append(" & ".join(header_cells) + " \\\\")
    lines.append("\\hline")

    # Body rows
    for row in body_rows:
        row_cells = [
            _render_latex_children(cell["children"])
            for cell in row["children"]
        ]
        lines.append(" & ".join(row_cells) + " \\\\")

    lines.append("\\hline")
    lines.append("\\end{tabular}")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# HTML renderer
# ---------------------------------------------------------------------------

def _render_html_children(children: list[dict]) -> str:
    """Recursively render inline children to HTML."""
    parts = []
    for token in children:
        t = token["type"]
        if t == "text":
            parts.append(html_escape(token["raw"]))
        elif t == "strong":
            inner = _render_html_children(token["children"])
            parts.append(f"<strong>{inner}</strong>")
        elif t == "emphasis":
            inner = _render_html_children(token["children"])
            parts.append(f"<em>{inner}</em>")
        elif t == "strikethrough":
            inner = _render_html_children(token["children"])
            parts.append(f"<del>{inner}</del>")
        elif t == "softbreak":
            parts.append(" ")
        elif t == "linebreak":
            parts.append("<br>")
        elif t == "link":
            href = html_escape(token.get("attrs", {}).get("url", ""))
            inner = _render_html_children(token["children"])
            parts.append(f'<a href="{href}">{inner}</a>')
        elif t == "block_text":
            parts.append(_render_html_children(token["children"]))
        else:
            if "raw" in token:
                parts.append(html_escape(token["raw"]))
            elif "children" in token:
                parts.append(_render_html_children(token["children"]))
    return "".join(parts)


def render_html(body: str) -> str:
    """Convert a markdown letter body to HTML."""
    if not body:
        return ""

    parser = _create_parser()
    tokens = parser(body)

    parts = []
    for token in tokens:
        t = token["type"]

        if t == "paragraph":
            text = _render_html_children(token["children"])
            parts.append(f"<p>{text}</p>")

        elif t == "heading":
            level = token["attrs"]["level"]
            text = _render_html_children(token["children"])
            parts.append(f"<h{level}>{text}</h{level}>")

        elif t == "list":
            ordered = token["attrs"].get("ordered", False)
            tag = "ol" if ordered else "ul"
            items = []
            for item in token["children"]:
                item_text = _render_html_children(item["children"])
                items.append(f"  <li>{item_text}</li>")
            parts.append(f"<{tag}>\n" + "\n".join(items) + f"\n</{tag}>")

        elif t == "thematic_break":
            parts.append("<hr>")

        elif t == "table":
            parts.append(_render_html_table(token))

        elif t == "blank_line":
            continue

        elif t == "block_quote":
            inner = _render_html_block_tokens(token["children"])
            parts.append(f"<blockquote>\n{inner}\n</blockquote>")

        else:
            if "children" in token:
                text = _render_html_children(token["children"])
                parts.append(f"<p>{text}</p>")
            elif "raw" in token:
                parts.append(f"<p>{html_escape(token['raw'])}</p>")

    return "\n\n".join(parts)


def _render_html_block_tokens(tokens: list[dict]) -> str:
    """Render block tokens inside a blockquote."""
    parts = []
    for token in tokens:
        t = token["type"]
        if t == "paragraph":
            parts.append(f"<p>{_render_html_children(token['children'])}</p>")
        elif t == "blank_line":
            continue
        elif "children" in token:
            parts.append(_render_html_children(token["children"]))
    return "\n".join(parts)


def _render_html_table(token: dict) -> str:
    """Render a GFM table to HTML."""
    head_cells = token["children"][0]["children"]
    body_rows = token["children"][1]["children"] if len(token["children"]) > 1 else []

    lines = ["<table>", "<thead>", "<tr>"]
    for cell in head_cells:
        align = cell["attrs"].get("align")
        style = f' style="text-align: {align}"' if align else ""
        text = _render_html_children(cell["children"])
        lines.append(f"  <th{style}>{text}</th>")
    lines.extend(["</tr>", "</thead>", "<tbody>"])

    for row in body_rows:
        lines.append("<tr>")
        for cell in row["children"]:
            align = cell["attrs"].get("align")
            style = f' style="text-align: {align}"' if align else ""
            text = _render_html_children(cell["children"])
            lines.append(f"  <td{style}>{text}</td>")
        lines.append("</tr>")

    lines.extend(["</tbody>", "</table>"])
    return "\n".join(lines)
