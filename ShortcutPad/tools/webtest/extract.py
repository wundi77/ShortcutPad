#!/usr/bin/env python3
"""Zieht die Webseite aus MacHelper/WebAssets.swift nach index.html (für den Browsertest mit mock.js)."""
import pathlib

here = pathlib.Path(__file__).resolve().parent
source = (here.parent.parent / "MacHelper" / "WebAssets.swift").read_text(encoding="utf-8")
start = source.index('#"""\n') + 5
end = source.index('\n"""#', start)
(here / "index.html").write_text(source[start:end] + "\n", encoding="utf-8")
print("index.html geschrieben")
