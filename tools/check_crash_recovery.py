"""Run isolated Godot save/log regression probes (never touches player saves)."""
import argparse
import os
import re
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def _app_name() -> str:
    """Godot derives user:// from application/config/name, so read it rather
    than hardcoding: the app has been renamed once already."""
    text = (ROOT / "godot/project.godot").read_text(encoding="utf-8")
    match = re.search(r'^config/name="(.+)"', text, re.MULTILINE)
    return match.group(1) if match else "Godot Project"


def main():
    # Probe output can contain bytes a cp1252 console cannot encode (the fuzz
    # cases feed the game control characters on purpose).
    sys.stdout.reconfigure(errors="replace")
    sys.stderr.reconfigure(errors="replace")
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    runtime = ROOT / "_audit/runtime/crash-regression"
    env = dict(os.environ, APPDATA=str(runtime))
    diagnostics = runtime / "Godot/app_userdata" / _app_name() / "diagnostics"
    diagnostics.mkdir(parents=True, exist_ok=True)
    for probe, expected in [
        ("save_recovery_probe", "SAVE_RECOVERY PASS"),
        ("crash_reporter_probe", "CRASH_REPORTER PASS"),
        # Boot-path hardening: a launch loop has to break itself, and no save
        # file contents may raise an error on the way in.
        ("crash_loop_probe", "CRASH_LOOP PASS"),
        ("save_fuzz_probe", "SAVE_FUZZ PASS"),
        ("save_migration_probe", "SAVE_MIGRATION_PROBE PASS"),
        # Display-backed: the safe-mode title screen adds a paragraph and two
        # controls to a panel that was already tight at a phone font boost.
        ("recovery_ui_probe", "RECOVERY_UI PASS"),
        ("shell_smoke", "[shell_smoke] PASS"),
    ]:
        if probe == "crash_reporter_probe":
            (diagnostics / "session.json").write_text('{"status":"running"}')
            (diagnostics / "session.log").write_text("PREVIOUS_SESSION_TEST_EVIDENCE\n")
            (diagnostics / "session.log.old").write_text("")
        cmd = [args.godot, "--path", str(ROOT / "godot")]
        probe_env = env
        if probe == "recovery_ui_probe":
            # Layout only settles with a real (offscreen) window, and the 1.6
            # boost is what a 263dpi phone applies to the same panel.
            cmd += ["--resolution", "720x1280"]
            probe_env = dict(env, CE_FONT_BOOST="1.6")
        elif not args.render or probe != "crash_reporter_probe":
            cmd.append("--headless")
        cmd += ["-s", f"res://scripts/tools/{probe}.gd"]
        result = subprocess.run(cmd, env=probe_env, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=180)
        output = result.stdout + result.stderr
        print(output)
        # GUI executable exit codes alone aren't a sufficient test verdict.
        if result.returncode or expected not in output or "SCRIPT ERROR" in output:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
