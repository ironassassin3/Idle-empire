"""Mechanical fact-collector for godot-design eval runs.

Produces objective facts per run directory that a grader (or human) turns into
pass/fail. Deliberately dumb: it reports, it does not judge.

Usage:
    python check_run.py <iteration-dir>
Writes <iteration-dir>/mechanical_facts.json and prints a summary.
"""
import json
import re
import struct
import subprocess
import sys
import zlib
from pathlib import Path

REPO = Path(r"D:\2d_game")
DESIGN = REPO / "godot" / "design"
SHOTS = DESIGN / "shots"

# prefix -> (eval dir name, configuration)
PREFIXES = {
    "ev0s_": ("eval-0-legacy-overlay-reskin", "with_skill"),
    "ev0b_": ("eval-0-legacy-overlay-reskin", "without_skill"),
    "ev1s_": ("eval-1-compact-heat-banner", "with_skill"),
    "ev1b_": ("eval-1-compact-heat-banner", "without_skill"),
    "ev2s_": ("eval-2-explore-prestige-backdrop", "with_skill"),
    "ev2b_": ("eval-2-explore-prestige-backdrop", "without_skill"),
}

# Godot .tscn colors are float tuples; .gd may use Color(...) or hex strings.
HEX_RE = re.compile(r'Color\s*\(\s*"?#?[0-9a-fA-F]{6,8}"?\s*\)|#[0-9a-fA-F]{6}\b')
FLOAT_COLOR_RE = re.compile(r"Color\s*\(\s*[\d.]+\s*,\s*[\d.]+\s*,\s*[\d.]+")
GOLD_RE = re.compile(r"GOLD(_BRIGHT)?\b")


def png_size(path: Path):
    """(w, h) from PNG header without external deps."""
    try:
        with open(path, "rb") as f:
            head = f.read(24)
        if head[:8] != b"\x89PNG\r\n\x1a\n":
            return None
        return struct.unpack(">II", head[16:24])
    except Exception:
        return None


def png_distinct_colors(path: Path, cap=64):
    """Distinct pixel count, stdlib-only. A design_preview render whose script
    failed to parse still exits ok and writes a near-empty PNG, so 'a PNG
    exists' does not mean 'the design rendered'. Returns None if undecodable."""
    try:
        raw = path.read_bytes()
        if raw[:8] != b"\x89PNG\r\n\x1a\n":
            return None
        pos, idat, ihdr = 8, bytearray(), None
        while pos < len(raw):
            ln = struct.unpack(">I", raw[pos:pos + 4])[0]
            typ = raw[pos + 4:pos + 8]
            body = raw[pos + 8:pos + 8 + ln]
            if typ == b"IHDR":
                ihdr = struct.unpack(">IIBBBBB", body)
            elif typ == b"IDAT":
                idat += body
            elif typ == b"IEND":
                break
            pos += 12 + ln
        if not ihdr:
            return None
        w, h, depth, ctype, _, _, interlace = ihdr
        if depth != 8 or interlace != 0 or ctype not in (2, 6):
            return None
        ch = 4 if ctype == 6 else 3
        data = zlib.decompress(bytes(idat))
        stride, prev, colors = w * ch, bytearray(w * ch), set()
        for y in range(h):
            off = y * (stride + 1)
            ft = data[off]
            line = bytearray(data[off + 1:off + 1 + stride])
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0
                b = prev[i]
                c = prev[i - ch] if i >= ch else 0
                if ft == 1:
                    line[i] = (line[i] + a) & 0xFF
                elif ft == 2:
                    line[i] = (line[i] + b) & 0xFF
                elif ft == 3:
                    line[i] = (line[i] + ((a + b) >> 1)) & 0xFF
                elif ft == 4:
                    p = a + b - c
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                    pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                    line[i] = (line[i] + pr) & 0xFF
            if y % 8 == 0:  # sample every 8th row; enough to tell blank from art
                for x in range(0, stride, ch * 4):
                    colors.add(bytes(line[x:x + ch]))
                    if len(colors) >= cap:
                        return cap
            prev = line
        return len(colors)
    except Exception:
        return None


def scene_files(prefix):
    return sorted(p for p in DESIGN.glob(f"{prefix}*") if p.suffix in (".tscn", ".gd"))


def shot_files(prefix):
    if not SHOTS.exists():
        return []
    return sorted(SHOTS.glob(f"{prefix}*.png"))


def scenes_dir_dirty():
    """Real game scenes must not be touched by any run."""
    out = subprocess.run(
        ["git", "-C", str(REPO), "status", "--porcelain", "godot/scenes", "godot/scripts"],
        capture_output=True, text=True,
    ).stdout.strip()
    return [ln for ln in out.splitlines() if ln.strip()]


def main(iteration_dir):
    iteration = Path(iteration_dir)
    dirty = scenes_dir_dirty()
    facts = {"real_scenes_or_scripts_modified": dirty, "runs": {}}

    for prefix, (eval_name, config) in PREFIXES.items():
        run_dir = iteration / eval_name / config
        out_dir = run_dir / "outputs"
        scenes = scene_files(prefix)
        shots = shot_files(prefix)
        # also count renders the agent copied into its outputs dir
        copied = sorted(out_dir.glob("*.png")) if out_dir.exists() else []
        pngs = shots + copied
        sizes = [png_size(p) for p in pngs]
        sizes = [s for s in sizes if s]

        # A render only counts if it has actual content (see png_distinct_colors).
        renders, blanks, live_sizes = [], [], set()
        for p in pngs:
            wh = png_size(p)
            n = png_distinct_colors(p)
            blank = n is not None and n <= 3
            renders.append({
                "file": p.name,
                "size": f"{wh[0]}x{wh[1]}" if wh else None,
                "distinct_colors": n,
                "blank": blank,
            })
            if blank:
                blanks.append(p.name)
            elif wh:
                live_sizes.add(wh)

        src = ""
        for p in scenes:
            try:
                src += p.read_text(encoding="utf-8", errors="ignore")
            except Exception:
                pass

        report = out_dir / "REPORT.md"
        report_txt = report.read_text(encoding="utf-8", errors="ignore") if report.exists() else ""

        facts["runs"][f"{eval_name}/{config}"] = {
            "prefix": prefix,
            "design_files": [p.name for p in scenes],
            "design_files_exist": bool(scenes),
            "shots_in_shots_dir": [p.name for p in shots],
            "renders_copied_to_outputs": [p.name for p in copied],
            "render_sizes": sorted({f"{w}x{h}" for w, h in sizes}),
            "renders": renders,
            "blank_renders": blanks,
            "has_720x1280": (720, 1280) in live_sizes,
            "has_1080x1920": (1080, 1920) in live_sizes,
            "uses_GameTheme": "GameTheme" in src,
            "uses_GameFonts": "GameFonts" in src,
            "raw_hex_color_hits": len(HEX_RE.findall(src)),
            "raw_float_color_hits": len(FLOAT_COLOR_RE.findall(src)),
            "gold_token_hits": len(GOLD_RE.findall(src)),
            "has_tween": "create_tween" in src or "Tween" in src,
            "report_exists": report.exists(),
            "report_chars": len(report_txt),
            "report_mentions_intent": bool(re.search(r"intent|purpose", report_txt, re.I)),
            "report_mentions_port_notes": bool(re.search(r"port note", report_txt, re.I)),
            "report_mentions_kit_amendment": bool(re.search(r"kit amendment|amendment", report_txt, re.I)),
            "report_mentions_motion": bool(re.search(r"motion|tween|animat", report_txt, re.I)),
        }

    dest = iteration / "mechanical_facts.json"
    dest.write_text(json.dumps(facts, indent=2), encoding="utf-8")
    print(json.dumps(facts, indent=2))
    print(f"\nwrote {dest}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else
         r"D:\2d_game\.claude\skills\godot-design-workspace\iteration-1")
