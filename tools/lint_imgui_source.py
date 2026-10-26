"""Local, read-only checks for SolarFlare's Haxe ImGui binding conventions.

Checks binding conventions, suspicious trailing cursor seeks, and optional
measured layout reports. Screenshots and scope review remain necessary.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re
import sys


def code_only(source: str) -> str:
    """Hide comments and string contents without changing line/column positions."""
    result = list(source)
    i = 0
    while i < len(source):
        if source.startswith("//", i):
            end = source.find("\n", i)
            end = len(source) if end < 0 else end
        elif source.startswith("/*", i):
            close = source.find("*/", i + 2)
            end = len(source) if close < 0 else close + 2
        elif source[i] in "\"'":
            quote = source[i]
            end = i + 1
            while end < len(source):
                if source[end] == "\\":
                    end += 2
                elif source[end] == quote:
                    end += 1
                    break
                else:
                    end += 1
        else:
            i += 1
            continue
        for n in range(i, min(end, len(source))):
            if result[n] not in "\r\n":
                result[n] = " "
        i = end
    return "".join(result)


def lint(source: str) -> list[tuple[int, str]]:
    code = code_only(source)
    errors: list[tuple[int, str]] = []

    def report(offset: int, message: str) -> None:
        errors.append((code.count("\n", 0, offset) + 1, message))

    for match in re.finditer(r"\bimgui\.Vec2\b", code):
        report(match.start(), "Use imgui.Structs.ImVec2 and ImGui.vec2; imgui.Vec2 is not exposed.")
    imported = bool(re.search(r"\bimport\s+imgui\.Structs\.(?:ImVec2|\*)\s*;", code))
    if not imported:
        for match in re.finditer(r"(?<![\w.])ImVec2\b", code):
            report(match.start(), "Import imgui.Structs.ImVec2 or use its fully qualified name.")
    for match in re.finditer(r"\bImGui[A-Za-z]*(?:Flags|Col|StyleVar|Key)_[A-Za-z0-9_]+\b", code):
        report(match.start(), "Use Haxe enum member spelling (Type.Member), not C++ Type_Member.")
    # Inspect individual table blocks, not a whole file: UiLayout's unrelated
    # percentage constants must not flag its fixed-pixel inlineSplit helper.
    for match in re.finditer(r"\bbeginTable\s*\(", code):
        end = code.find("endTable", match.end())
        if end < 0:
            continue  # callback-owned scopes are reviewed/compiled separately
        block = code[match.start():end]
        if "SizingFixedFit" not in block:
            continue
        if re.search(r"tableSetupColumn\s*\([^;]*?(?:,\s*0\.\d+\b|\b(?:LABEL|CONTROL)_WEIGHT\b)", block):
            report(match.start(), "Fractional table weights require SizingStretchProp; fixed pixel widths use SizingFixedFit.")
    # Conservative: a cursor seek as the last statement in a scope does not
    # submit geometry. This catches the picker restore/EndChild failure, but
    # does not pretend to be a Haxe control-flow analyzer.
    for match in re.finditer(
        r"ImGui\.setCursor(?:Screen)?Pos(?:X|Y)?\s*\([^;]*\)\s*;"
        r"(?=\s*(?:[};]\s*)*(?:ImGui\.end(?:Child|Popup)?\s*\(|"
        r"(?:(?:public|private|static|inline)\s+)*function\b|$))", code
    ):
        report(match.start(), "Trailing cursor seek may extend parent bounds without an item; submit geometry or draw inside an existing item.")

    # --- SPEC §5.4: Mojibake / Non-ASCII String Literal Detection ---
    # In hl-imgui, multibyte UTF-8 (like '·', '×', '—') renders as mojibake ('Â·', 'Ã—')
    # when the font atlas lacks glyph coverage or bytes are indexed directly.
    for match in re.finditer(r"""(?:'([^'\\]*(?:\\.[^'\\]*)*)'|"([^"\\]*(?:\\.[^"\\]*)*)")""", source):
        literal = match.group(1) or match.group(2) or ""
        for char in literal:
            if ord(char) > 127:
                errors.append((source.count("\n", 0, match.start()) + 1,
                               f"Non-ASCII character '{char}' (U+{ord(char):04X}) in UI string. In hl-imgui, multibyte UTF-8 renders as mojibake ('Â·', 'Ã—'). Use ASCII (' - ', ' | ', ' x ')."))
                break

    # --- SPEC §5.1: Action Button Sizing (-1 forbidden) ---
    for match in re.finditer(r"\b(?:UiChrome\.(?:accentButton|ghostButton|gradientButton)|ImGui\.button)\s*\([^,;]+,\s*ImGui\.vec2\s*\(\s*-1\b", code):
        report(match.start(), "Button width -1 is forbidden: action buttons must have explicit compact pixel sizes (e.g. ImGui.vec2(140, 26)) or fit text padding.")

    # --- SPEC §5.3: Heap Allocation Detection in Draw Paths ---
    for match in re.finditer(r"function\s+((?:draw|render)[A-Za-z0-9_]*)\s*\([^)]*\)[^{]*\{", code):
        fn_name = match.group(1)
        start = match.end()
        depth = 1
        i = start
        while i < len(code) and depth > 0:
            if code[i] == '{':
                depth += 1
            elif code[i] == '}':
                depth -= 1
            i += 1
        fn_body = code[start:i]
        for alloc in re.finditer(r"\bnew\s+(?:BoolRef|IntRef|FloatRef|ImVec2|ImVec4)\b", fn_body):
            report(start + alloc.start(), f"Heap allocation in draw path '{fn_name}': retain static buffers/refs instead of allocating per-frame.")

    return sorted(errors, key=lambda e: e[0])


def lint_layout(report: dict) -> list[str]:
    """Audit the same section/row/cell rectangles consumed by the picker view."""
    errors: list[str] = []
    for case in report.get("cases", []):
        name = case.get("name", "layout")

        def fail(message: str) -> None:
            errors.append(f"{name}: {message}")

        width, extent, gap = case["width"], case["contentHeight"], case["gap"]
        columns, minimum = case["columns"], case["minCellWidth"]
        if not all(math.isfinite(v) for v in (width, extent, gap, minimum)) or width <= 0 or extent < 0 or gap < 12 or minimum <= 0:
            fail("invalid canvas dimensions or insufficient gutter")
            continue
        budget = max(1, min(3, math.floor((width + gap) / (minimum + gap))))
        if columns < 1 or columns > budget:
            fail("columns exceed the usable canvas budget")
        if columns < budget and not case.get("textLimited", False):
            fail("unused canvas: more minimum-width columns fit")
        rows, cells = case["rows"], case["cells"]
        bottom = 0
        for i, row in enumerate(rows):
            y, height = row["y"], row["height"]
            if not math.isfinite(y) or not math.isfinite(height) or height <= 0 or abs(y - (bottom + (gap if i else 0))) > 0.05:
                fail("row extent/advance differs from submitted geometry")
            bottom = y + height
        if abs(extent - bottom) > 0.05:
            fail("content extent differs from the final submitted row")
        ids = [c["id"] for c in cells]
        if len(ids) != len(set(ids)) or sorted(ids) != sorted(case["expectedIds"]):
            fail("matching conditions must appear exactly once")
        for c in cells:
            x, y, w, h = (c[k] for k in ("x", "y", "width", "height"))
            if not all(math.isfinite(v) for v in (x, y, w, h)) or x < -0.05 or y < -0.05 or w <= 0 or h <= 0 or x + w > width + 0.05 or y + h > extent + 0.05:
                fail(f"{c['id']}: cell escapes the content canvas")
            if columns > 1 and w + 0.05 < minimum:
                fail(f"{c['id']}: cell is below the font-scaled minimum width")
            t = c["textBounds"]
            if not all(math.isfinite(t[k]) for k in ("x", "y", "width", "height")) or t["width"] < 0 or t["height"] < 0 or t["x"] < x or t["y"] < y or t["x"] + t["width"] > x + w + 0.05 or t["y"] + t["height"] > y + h + 0.05:
                fail(f"{c['id']}: label escapes its cell")
            if not 0 <= c["row"] < len(rows):
                fail(f"{c['id']}: unknown row")
            else:
                row = rows[c["row"]]
                if row["kind"] != "cells" or abs(row["y"] - y) > 0.05 or abs(row["height"] - h) > 0.05:
                    fail(f"{c['id']}: cell differs from its submitted row")
        for i, a in enumerate(cells):
            for b in cells[i + 1:]:
                horizontal = min(a["x"] + a["width"], b["x"] + b["width"]) - max(a["x"], b["x"])
                vertical = min(a["y"] + a["height"], b["y"] + b["height"]) - max(a["y"], b["y"])
                if horizontal > 0.05 and vertical > 0.05:
                    fail(f"overlapping hit targets: {a['id']} / {b['id']}")
                if a["row"] == b["row"] and a["x"] < b["x"] and b["x"] - a["x"] - a["width"] < gap - 0.05:
                    fail(f"insufficient column gutter: {a['id']} / {b['id']}")
    if not report.get("cases"):
        errors.append("layout report contains no cases")
    return errors


def self_test() -> None:
    assert lint('import imgui.Structs.ImVec2; var p:ImVec2=ImGui.vec2(1,2);') == []
    assert lint('var p:imgui.Structs.ImVec2;') == []
    assert len(lint('var p:ImVec2;')) == 1
    assert lint('import imgui.Vec2;')
    assert lint('ImGuiStyleVar_CellPadding;')
    assert lint('// imgui.Vec2\nvar s="ImGuiStyleVar_CellPadding";') == []
    assert lint('/* ImVec2 */ var s=\'imgui.Vec2\';') == []
    assert lint('beginTable("x",2,ImGuiTableFlags.SizingFixedFit); tableSetupColumn("x",0,0.35); endTable();')
    assert lint('var LABEL_WEIGHT=0.35; beginTable("x",2,ImGuiTableFlags.SizingFixedFit); tableSetupColumn("x",0,132); endTable();') == []
    assert lint('beginTable("x",2,ImGuiTableFlags.SizingStretchProp); tableSetupColumn("x",0,0.35); endTable();') == []
    assert lint('ImGui.setCursorPosY(after); } }')
    assert lint('ImGui.setCursorScreenPos(p); ImGui.endChild();')
    assert lint('ImGui.setCursorPosY(y); ImGui.dummy(size); }') == []
    assert lint('// ImGui.setCursorPosY(after);\n}') == []
    # Spec checks
    assert lint('var s = "Selected bar Â· click to edit";')
    assert lint('var s = "Beehive Lozenge Ã—9";')
    assert lint('UiChrome.ghostButton("Fill##bt_pop", ImGui.vec2(-1, 28));')
    assert lint('function drawPreview():Void { var b = new BoolRef(true); }')
    assert lint('function drawPreview():Void { staticRef.set(true); }') == []
    # A real spatial fixture, then perturb each important invariant.
    import copy
    cell = dict(id="a", x=0, y=0, width=224, height=64, row=0,
                textBounds=dict(x=8, y=8, width=120, height=40))
    case = dict(name="test", width=696, contentHeight=64, gap=12, columns=3,
                minCellWidth=224, rows=[dict(kind="cells", y=0, height=64)],
                cells=[cell], expectedIds=["a"])
    assert lint_layout(dict(cases=[case])) == []
    for key, value in [("contentHeight", 65), ("columns", 1), ("gap", 0)]:
        bad = copy.deepcopy(case); bad[key] = value
        assert lint_layout(dict(cases=[bad]))
    bad = copy.deepcopy(case); bad["cells"][0]["textBounds"]["width"] = 300
    assert lint_layout(dict(cases=[bad]))
    bad = copy.deepcopy(case); bad["cells"].append(copy.deepcopy(cell))
    assert lint_layout(dict(cases=[bad]))
    bad = copy.deepcopy(case); bad["cells"][0]["x"] = 680
    assert lint_layout(dict(cases=[bad]))
    bad = copy.deepcopy(case); bad["rows"][0]["height"] = 65
    assert lint_layout(dict(cases=[bad]))
    print("Local ImGui lint self-test: 27 checks passed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--layout-report", action="append", default=[], type=Path,
                        help="Audit geometry exported by the native-free picker layout tests.")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    failed = False
    for path in args.layout_report:
        try:
            report = json.loads(path.read_text(encoding="utf-8-sig"))
            errors = lint_layout(report)
        except (ValueError, KeyError, TypeError) as exc:
            errors = [f"malformed layout report: {exc}"]
        for message in errors:
            print(f"{path}: {message}")
        failed |= bool(errors)
        if not errors:
            print(f"Spatial layout checks PASS ({len(report['cases'])} cases; in-game geometry remains separate)")
    for path in args.paths:
        errors = lint(path.read_text(encoding="utf-8-sig"))
        for line, message in errors:
            print(f"{path}:{line}: {message}")
        failed |= bool(errors)
    if args.paths and not failed:
        print(f"Local ImGui source checks PASS ({len(args.paths)} files; visual layout and scope review remain separate)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
