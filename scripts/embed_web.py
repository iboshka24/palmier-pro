#!/usr/bin/env python3
"""Regenerate Sources/PalmierPro/Server/EmbeddedWebUI.swift from the web UI.

The timeline UI ships both as a bundle resource (Web/timeline.html) and
embedded into the binary, so a single-file distribution still serves the
UI when the binary is moved without its resource directory. Run this after
editing Resources/Web/timeline.html.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HTML = ROOT / "Sources/PalmierPro/Resources/Web/timeline.html"
OUT = ROOT / "Sources/PalmierPro/Server/EmbeddedWebUI.swift"

html = HTML.read_text().rstrip("\n")
assert '"""' not in html, "HTML must not contain triple quotes"
assert "\\" not in html, "HTML must not contain backslashes"

OUT.write_text(
    "#if !os(macOS)\n"
    "/// Timeline UI embedded into the binary so a single-file distribution works\n"
    "/// even when the resource directory is absent. Regenerate from\n"
    "/// Resources/Web/timeline.html via scripts/embed_web.py when the HTML changes.\n"
    "enum EmbeddedWebUI {\n"
    "    static let html: String = \"\"\"\n"
    f"{html}\n"
    "\"\"\"\n"
    "}\n"
    "#endif\n"
)
print(f"wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size} bytes)")
