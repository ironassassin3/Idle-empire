# Crash diagnostics and launch recovery

Written after the 2026-09-16 tester report: the game crashed ~20 minutes into a
session on a Galaxy S25+, and every launch afterwards closed instantly. Play
Console showed no crash. Nothing in the build could tell us why, and nothing in
the build could break the loop.

Two separate problems, two separate answers.

## 1. The game must never be stuck closed

`CrashReporter` (first autoload, `scripts/autoload/crash_reporter.gd`) writes a
marker file at every phase change of a session:

| Phase | Meaning |
|---|---|
| `boot` | process started, nothing loaded yet |
| `loading_save` | reading or applying a save file |
| `running` | normal play |
| `background` | Android paused the app |
| `clean_exit` | the app closed itself |

A session that survives 20 seconds is marked **healthy**. On the next launch:

- Previous phase was `loading_save` → **the save is quarantined** before anything
  reads it (`save.json` → `save.json.broken`) and the backup is restored. The
  player is told, and nothing is deleted.
- Two launches in a row died before going healthy → **safe mode**: no procedural
  audio, no native ad/billing backend, a recovery notice and a *Repair save*
  button on the title screen.
- A crash *after* a healthy session (the 20-minute case) does **not** trigger
  safe mode — it is reported, not recovered from. Neither does Android
  reclaiming a backgrounded process.

One healthy session clears the tally.

## 2. The next crash has to leave evidence

Everything below lands in `user://diagnostics/` and never leaves the device
unless the player copies it:

- `session.log` — engine errors *with script backtraces*, scene changes, tab and
  overlay navigation, 30-second health samples (FPS, static memory, node and
  object counts), lifecycle marks, and low-memory warnings. Rotates at 128 KB,
  keeps one previous file, and suppresses after 64 errors so a per-frame failure
  cannot fill storage.
- `last_incident.txt` — the whole log from a session that ended without a clean
  exit, plus the phase it died in.

**Getting it from a tester:** *Crash diagnostics* on the title screen (always
present) or Config → DATA → *Crash diagnostics* in game → **Copy report** →
paste into a message. The report names the device, build, previous phase and
failed-launch count.

**What it cannot see:** a native crash before the engine boots, or an Android
kill (OOM/ANR). Those need Play Console → Android vitals (check the **ANRs** tab,
not only Crashes) or `adb logcat` on a connected device. The report says so on
its first line, so nobody reads "no errors" as "no crash".

## What is verified, and how

`python tools/check_crash_recovery.py --godot <godot.exe>` (also inside
`.\device_pass.ps1 smoke`):

| Probe | Proves |
|---|---|
| `crash_loop_probe.gd` | phase counting, safe-mode threshold, save quarantine, repair keeps the file |
| `save_fuzz_probe.gd` | 52 hostile save files — truncated, NaN, wrong types, 20k-element arrays, control bytes — none raises an engine error or leaves the game unplayable |
| `save_recovery_probe.gd` | an interrupted write recovers, and saving afterwards does not destroy the good backup |
| `crash_reporter_probe.gd` | errors captured with source locations, bounded rotation, incident retained |

`python tools/check_chaos_soak.py --godot <godot.exe> --steps 30000 --seeds 6`
drives randomised real player actions against the live shell and fails on any
engine error, non-finite economy value, unstable reload, save that will not
round-trip through JSON, or unbounded object growth.

## Cost

`debug/settings/gdscript/always_track_call_stacks` is on so that release builds
capture script backtraces. It is the reason a tester report names a file and a
line. Turn it off only if a device pass shows it costing frames.
