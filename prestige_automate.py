"""Phase 70: launch game, screenshot prestige flow, close."""
import subprocess, time, os, sys
import pyautogui

SHOTS = "prestige_shots"
os.makedirs(SHOTS, exist_ok=True)

pyautogui.PAUSE        = 0.05
pyautogui.FAILSAFE     = False

def shot(name):
    p = os.path.join(SHOTS, name + ".png")
    img = pyautogui.screenshot()
    img.save(p)
    print(f"  SHOT: {p}")
    return p

# Game window expected at roughly (0,0) for a 900×720 window.
# pyautogui coordinates are absolute screen coords.
# The game launches windowed — find the window offset if needed.

proc = subprocess.Popen([sys.executable, "main.py"], cwd=os.path.dirname(os.path.abspath(__file__)))
print("Game launched, waiting 4s for init...")
time.sleep(4)

# ── Dismiss any daily/offline overlay by pressing ESC or clicking outside ──
# The save has last_login_date=today so no daily overlay should appear.
# Just in case, click the center of the screen first.
pyautogui.click(450, 400)
time.sleep(0.5)
# Press ESC to dismiss any tutorial/overlay
pyautogui.press('escape')
time.sleep(0.5)

# ── PART 1: Near-prestige approach ─────────────────────────────────────────
# First screenshot: locked prestige button with progress bar
# (This save is prestige-READY so button should be glowing; but let's first
#  swap to the near-prestige save for Part 1 observation)
shot("01_initial_state")

# ── Switch to near-prestige save for Part 1 ──────────────────────────────
# Can't reload in-game, so just note current state is prestige-ready.
# The prestige button should be glowing/unlocked (purple glow).
# Take a closeup area screenshot around the button at (208, 440).
shot("02_prestige_button_area")

# ── PART 2: Click prestige button ─────────────────────────────────────────
print("Clicking prestige button at (208, 440)...")
pyautogui.click(208, 440)
time.sleep(0.6)
shot("03_after_prestige_button_click")

# ── The confirm dialog should now be visible ──────────────────────────────
time.sleep(0.3)
shot("04_prestige_confirm_dialog")

# ── PART 3: Click YES ─────────────────────────────────────────────────────
print("Clicking YES at (387, 482)...")
pyautogui.click(387, 482)
time.sleep(0.5)
shot("05_post_prestige_immediate")

# Wait for milestone overlay to appear
time.sleep(1.0)
shot("06_milestone_overlay")

# ── PART 5: Wait for overlay to expire, observe early rebuild state ────────
time.sleep(8.0)
shot("07_post_prestige_clear_state")

# Click on Buildings tab (should be first tab)
# Tab bar is at y ≈ HEADER_H + TAB_H/2 = 116 + 17 = 133; first tab starts around x=420
pyautogui.click(450, 155)
time.sleep(0.3)
shot("08_buildings_tab_post_prestige")

print("\nAll shots done. Closing game in 2s...")
time.sleep(2)
proc.terminate()
proc.wait(timeout=5)
print("Done.")
