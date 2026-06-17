"""Git hook entry point for graphify AST rebuilds (Windows-safe).

ProcessPoolExecutor requires ``if __name__ == '__main__'``; git hooks must not
use ``python -c`` inline scripts. Hooks call: ``python graphify_rebuild.py``
"""
from __future__ import annotations

import os
import sys
from pathlib import Path


def _parse_changed() -> list[Path] | None:
    raw = os.environ.get("GRAPHIFY_CHANGED", "").strip()
    if not raw:
        return None
    paths = [Path(line.strip()) for line in raw.splitlines() if line.strip()]
    return paths or None


def main() -> int:
    from graphify.watch import _apply_resource_limits, _rebuild_code

    watch = Path(".").resolve()
    force = os.environ.get("GRAPHIFY_FORCE", "").lower() in ("1", "true", "yes")
    changed = _parse_changed()
    # Incremental post-commit rebuilds can legitimately shrink node count slightly
    # (re-AST one file); graphify refuses without --force otherwise.
    if changed is not None:
        force = True

    try:
        _apply_resource_limits()
        ok = _rebuild_code(watch, changed_paths=changed, force=force)
        if ok:
            print("[graphify rebuild] Root graph updated in graphify-out/")
            return 0
        print("[graphify rebuild] Skipped or failed (see messages above).", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"[graphify rebuild] Failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
