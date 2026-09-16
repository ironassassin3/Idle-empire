"""Run the randomised chaos soak across seeds (never touches player saves).

Each run drives real player actions against the live shell and fails on any
engine error, non-finite economy value, unstable reload, or a save that cannot
round-trip through JSON.

    python tools/check_chaos_soak.py --godot <godot.exe> [--steps 20000] [--seeds 4]
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--steps", type=int, default=20000)
    parser.add_argument("--seeds", type=int, default=4)
    args = parser.parse_args()

    runtime = ROOT / "_audit/runtime/chaos"
    # The dir only has to exist before the probe writes; Godot itself resolves
    # user:// from application/config/name, which has been renamed once already.
    runtime.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(runtime))

    failures = []
    for seed in range(1, args.seeds + 1):
        # Half the seeds walk the balance up three orders of magnitude at a time:
        # random play alone never reaches the deep-number code paths.
        wealth = "1" if seed % 2 == 0 else "0"
        cmd = [
            args.godot, "--path", str(ROOT / "godot"), "--headless",
            "-s", "res://scripts/tools/chaos_soak.gd", "--",
            "--steps", str(args.steps), "--seed", str(seed), "--wealth", wealth,
        ]
        result = subprocess.run(cmd, env=env, capture_output=True, text=True,
                                encoding="utf-8", errors="replace",
                                timeout=60 + args.steps // 4)
        output = result.stdout + result.stderr
        for line in output.splitlines():
            if line.startswith("[chaos]") or "SCRIPT ERROR" in line:
                print(line)
        if result.returncode or "[chaos] PASS" not in output:
            failures.append(f"seed {seed} (wealth={wealth})")

    if failures:
        print("CHAOS_SOAK FAIL: " + ", ".join(failures))
        return 1
    print(f"CHAOS_SOAK PASS ({args.seeds} seeds x {args.steps} steps)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
