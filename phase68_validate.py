"""Phase 68 Runtime Validation — reward feedback visibility.

Creates a test save in a mid-game state, launches the game, navigates through
every reward system, and captures screenshots. Restores original save on exit.
"""
import subprocess, time, ctypes, ctypes.wintypes as wt, struct, sys, os, json, shutil

# ── Win32 helpers ──────────────────────────────────────────────────────────────
user32 = ctypes.windll.user32
gdi32  = ctypes.windll.gdi32

def find_window(title, timeout=12.0):
    t = time.time()
    while time.time() - t < timeout:
        hwnd = user32.FindWindowW(None, title)
        if hwnd:
            return hwnd
        time.sleep(0.3)
    return None

def screenshot_window(hwnd, path):
    user32.ShowWindow(hwnd, 9)
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.5)
    r = wt.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(r))
    w, h = r.right - r.left, r.bottom - r.top
    hdc_win = user32.GetDC(hwnd)
    hdc_mem = gdi32.CreateCompatibleDC(hdc_win)
    hbmp    = gdi32.CreateCompatibleBitmap(hdc_win, w, h)
    gdi32.SelectObject(hdc_mem, hbmp)
    user32.PrintWindow(hwnd, hdc_mem, 2)
    bi  = struct.pack('<IiiHHIIiiII', 40, w, -h, 1, 32, 0, w*h*4, 0, 0, 0, 0)
    buf = (ctypes.c_ubyte * (w * h * 4))()
    gdi32.GetDIBits(hdc_mem, hbmp, 0, h, buf, (ctypes.c_char * 40)(*bi), 0)
    gdi32.DeleteObject(hbmp)
    gdi32.DeleteDC(hdc_mem)
    user32.ReleaseDC(hwnd, hdc_win)
    bmp_path = path.replace('.png', '.bmp')
    bmp_size = 54 + w * h * 4
    hdr = (b'BM' + struct.pack('<IHHi', bmp_size, 0, 0, 54) +
           struct.pack('<IiiHHIIiiII', 40, w, h, 1, 32, 0, w*h*4, 0, 0, 0, 0))
    with open(bmp_path, 'wb') as f:
        f.write(hdr); f.write(bytes(buf))
    ps = f"""
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap('{bmp_path}')
$bmp.Save('{path}', [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
"""
    subprocess.run(['powershell', '-Command', ps], capture_output=True)
    os.remove(bmp_path)
    print(f"  [SC] {path} ({w}x{h})")

def click(hwnd, x, y, delay=0.2):
    WM_LBUTTONDOWN = 0x0201
    WM_LBUTTONUP   = 0x0202
    lparam = (y << 16) | (x & 0xFFFF)
    user32.PostMessageW(hwnd, WM_LBUTTONDOWN, 1, lparam)
    time.sleep(0.05)
    user32.PostMessageW(hwnd, WM_LBUTTONUP, 0, lparam)
    time.sleep(delay)

# ── Layout constants (900×720 default) ────────────────────────────────────────
RIGHT_X   = 420
HEADER_H  = 116
TAB_H     = 34
TAB_W     = 76
SUBTAB_W  = 70

def tab_x(idx): return RIGHT_X + idx * TAB_W + TAB_W // 2
def tab_y():    return HEADER_H + TAB_H // 2
def subtab_x(idx): return RIGHT_X + 8 + idx * SUBTAB_W + SUBTAB_W // 2
def subtab_y(): return HEADER_H + TAB_H + 17

# Main tab indices
T_BUILDINGS  = 0
T_EMPIRE     = 1
T_CREW       = 2
T_OPERATIONS = 3
T_STATS      = 4

# Empire sub-tab indices
S_TERRITORY = 0
S_RIVALS    = 1
S_MANAGERS  = 2
S_UPGRADES  = 3

CLICK_CENTER = (190, 246)  # the "click crime" button center


# ── Build test save ────────────────────────────────────────────────────────────
def build_test_save():
    now = time.time()
    # Drug Run duration = 300s; start 285s ago → 15s to completion on game launch
    drug_run_start = now - 285.0
    # Casino Skim: start 240s ago → 240s remaining (so it's clearly mid-run)
    casino_start   = now - 240.0

    return {
        "balance":            8500.0,
        "lifetime_earnings":  480_000.0,
        "prestige_tokens":    4,          # one token below "Associate" (threshold=5)
        "influence":          4,
        "click_count":        120,
        "play_time":          1800.0,
        "coins_caught":       3,
        "prestige_count":     0,
        "next_prestige_earnings": 20_000_000.0,
        "daily_streak":       1,
        "perks_purchased":    [],
        "prestige_branch":    None,
        "dragon_patron":      None,
        "dragon_xp":          0,
        "dragon_ability_cooldowns": {},
        "tutorial_step":      10,         # tutorial done
        "shown_milestones":   [],
        "shown_raid_tutorial": True,
        "shown_ops_tutorial":  True,
        "shown_influence_tutorial": True,
        "shown_heat_warning":  False,     # let it trigger for us
        "shown_prestige_tree_tutorial": False,
        "shown_syndicate_tutorial": False,
        "shown_influence_intro": False,
        "shown_crew_tutorial": True,
        "shown_territory_tutorial": True,
        "shown_rivals_tutorial": True,
        "peak_income":        250.0,
        "longest_streak":     1,
        "total_buildings_purchased": 28,
        "total_territories_captured": 1,
        "total_rivals_defeated": 0,
        "total_ops_completed": 2,
        "total_heat_generated": 24.0,
        "total_respect_earned": 0,
        "total_influence_earned": 4,
        "highest_cash_held":  9000.0,
        "highest_city_control": 5.0,
        "city_control_milestones": [],
        "heat":               57.0,       # above 60% triggers warnings — just below
        "sfx_volume":         0.5,
        "fps_cap":            60,
        "music_volume":       0.3,
        "master_volume":      0.8,
        "mute_all":           False,
        "analytics_enabled":  False,
        # Buildings: [dealers=15, rackets=8, chop_shops=4, 0×8]
        "buildings": [15, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0],
        # Upgrades: first 2 purchased (dealer upgrades), rest unpurchased
        "upgrades": [True, True, False, False, False, False, False, False,
                     False, False, False, False, False, False, False, False,
                     False, False, False, False, False, False, False, False,
                     False, False, False, False, False, False, False, False],
        # Achievements: first few earned
        "achievements": [True, True, False, False, False, False, False, False,
                         False, False, False, False, False, False, False, False,
                         False, False, False, False, False, False, False, False,
                         False, False, False, False, False, False, False, False,
                         False, False, False, False, False, False, False, False],
        # Managers: first one hired
        "managers": [True, False, False, False, False, False, False, False, False, False, False],
        # Territories:
        # 0=South Side (unlocked/player), 1=Downtown (unlocked/player), rest unclaimed
        "territories": [
            {"unlocked": True,  "owner": "player"},    # South Side
            {"unlocked": True,  "owner": "player"},    # Downtown
            {"unlocked": False, "owner": "unclaimed"}, # Industrial
            {"unlocked": False, "owner": "unclaimed"}, # Waterfront
            {"unlocked": False, "owner": "unclaimed"}, # City Hall
            {"unlocked": False, "owner": "unclaimed"}, # Eastside Heights
            {"unlocked": False, "owner": "unclaimed"}, # Sunset Gardens
            {"unlocked": False, "owner": "unclaimed"}, # Millbrook Park
            {"unlocked": False, "owner": "unclaimed"}, # Harbor View
            {"unlocked": False, "owner": "unclaimed"}, # Riverside
            {"unlocked": False, "owner": "unclaimed"}, # Chinatown
            {"unlocked": False, "owner": "unclaimed"}, # North End
            {"unlocked": False, "owner": "unclaimed"}, # Meatpacking
            {"unlocked": False, "owner": "unclaimed"}, # Uptown
            {"unlocked": False, "owner": "unclaimed"}, # Midtown
            {"unlocked": False, "owner": "unclaimed"}, # Financial
            {"unlocked": False, "owner": "unclaimed"}, # Airport
            {"unlocked": False, "owner": "unclaimed"}, # Stadium
            {"unlocked": False, "owner": "unclaimed"}, # University
            {"unlocked": False, "owner": "unclaimed"}, # Warehouse
        ],
        # Rivals: default state
        "rivals": [
            {"turf": 3, "wealth": 1200.0, "power": 45, "aggression": 0.55, "at_war": False, "status": "Active", "last_action": "Expanding territory"},
            {"turf": 2, "wealth": 900.0,  "power": 38, "aggression": 0.45, "at_war": False, "status": "Active", "last_action": "Recruiting enforcers"},
            {"turf": 4, "wealth": 1500.0, "power": 52, "aggression": 0.60, "at_war": False, "status": "Active", "last_action": "Consolidating power"},
            {"turf": 1, "wealth": 600.0,  "power": 28, "aggression": 0.35, "at_war": False, "status": "Weakened","last_action": "Recovering losses"},
            {"turf": 2, "wealth": 800.0,  "power": 35, "aggression": 0.40, "at_war": False, "status": "Active", "last_action": "Building war chest"},
        ],
        # Crew: 5 protection, 3 collection, 2 smuggling — total=10 ≤ 27 buildings
        "crew": {"protection": 5, "collection": 3, "smuggling": 2, "territory": 0, "heat": 0},
        # Operations:
        # [0]=Drug Run: active, 285s elapsed of 300s → 15s from completion
        # [1]=Casino Skim: active, 240s elapsed of 480s → 240s remaining
        # [2-4]: inactive
        "operations": [
            {"active": True,  "start_time": drug_run_start, "reward": 0.0, "completed": False, "collected": False},
            {"active": True,  "start_time": casino_start,   "reward": 0.0, "completed": False, "collected": False},
            {"active": False, "start_time": 0.0,            "reward": 0.0, "completed": False, "collected": False},
            {"active": False, "start_time": 0.0,            "reward": 0.0, "completed": False, "collected": False},
            {"active": False, "start_time": 0.0,            "reward": 0.0, "completed": False, "collected": False},
        ],
        "goals_completed": ["first_building", "first_click"],
        "save_timestamp": now - 5.0,  # 5 seconds ago (fresh load, no offline gap)
        "last_login_date": time.strftime('%Y-%m-%d'),
        "arms_influence_frac": 0.0,
        "dragon_red_elim_count": 0,
    }


SAVE_PATH = r"D:\2d_game\save.json"
BACKUP_PATH = r"D:\2d_game\save.json.phase68bak"
SC_DIR = r"D:\2d_game\phase68_sc"

os.makedirs(SC_DIR, exist_ok=True)

# ── Backup existing save ───────────────────────────────────────────────────────
if os.path.exists(SAVE_PATH):
    shutil.copy2(SAVE_PATH, BACKUP_PATH)
    print(f"  Backed up save to {BACKUP_PATH}")

# Write test save
with open(SAVE_PATH, 'w') as f:
    json.dump(build_test_save(), f, indent=2)
print("  Test save written.")

# ── Launch game ────────────────────────────────────────────────────────────────
print("\nLaunching game...")
proc = subprocess.Popen(['python', 'main.py'], cwd=r'D:\2d_game')
hwnd = find_window("Idle Empire", timeout=15)
if not hwnd:
    proc.terminate()
    sys.exit("ERROR: Game window not found")
print(f"  Window found: {hwnd}")
time.sleep(2.5)  # let title screen render fully

# ─── PART 1: Title screen → Continue ──────────────────────────────────────────
print("\n--- TITLE SCREEN ---")
screenshot_window(hwnd, f"{SC_DIR}/p68_00_title.png")

# Click "Continue" (center of screen, roughly where button is)
click(hwnd, 450, 330, delay=1.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_01_post_continue.png")

# Dismiss any overlay (offline/daily) by pressing the center area or clicking X
# Wait a moment for overlay to settle
time.sleep(1.0)
screenshot_window(hwnd, f"{SC_DIR}/p68_02_after_load.png")

# Click center to dismiss any overlay
click(hwnd, 450, 420, delay=0.5)
click(hwnd, 450, 420, delay=0.8)
screenshot_window(hwnd, f"{SC_DIR}/p68_03_cleared_overlays.png")

# ─── PART 2: Buildings tab baseline ───────────────────────────────────────────
print("\n--- PART 1: BUILDINGS (default view) ---")
click(hwnd, tab_x(T_BUILDINGS), tab_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_04_buildings_default.png")

# Rapid clicks on crime button to earn cash / check click feedback
print("  Rapid clicking for cash...")
for _ in range(20):
    click(hwnd, CLICK_CENTER[0], CLICK_CENTER[1], delay=0.08)
time.sleep(0.3)
screenshot_window(hwnd, f"{SC_DIR}/p68_05_buildings_post_click.png")

# ─── PART 3: Upgrade purchase ─────────────────────────────────────────────────
print("\n--- PART 3: UPGRADES ---")
click(hwnd, tab_x(T_EMPIRE), tab_y(), delay=0.3)
time.sleep(0.2)
click(hwnd, subtab_x(S_UPGRADES), subtab_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_06_upgrades_before_purchase.png")

# Click the first available (unpurchased) upgrade row — content area starts at y~184
# Upgrades are listed from top of content area; click row 1 at ~y=210 (center of first row)
CONTENT_TOP = HEADER_H + TAB_H + 34 + 8  # empire subtab offset
click(hwnd, RIGHT_X + 240, CONTENT_TOP + 40, delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_07_upgrades_after_purchase.png")

# ─── PART 4: Territory tab ────────────────────────────────────────────────────
print("\n--- PART 2: TERRITORY ---")
click(hwnd, tab_x(T_EMPIRE), tab_y(), delay=0.2)
time.sleep(0.2)
click(hwnd, subtab_x(S_TERRITORY), subtab_y(), delay=0.6)
screenshot_window(hwnd, f"{SC_DIR}/p68_08_territory_overview.png")

# Scroll down to see more districts
click(hwnd, RIGHT_X + 240, CONTENT_TOP + 200, delay=0.4)
screenshot_window(hwnd, f"{SC_DIR}/p68_09_territory_lower.png")

# ─── PART 5: Rivals tab ───────────────────────────────────────────────────────
print("\n--- RIVALS (for faction flavor check) ---")
click(hwnd, subtab_x(S_RIVALS), subtab_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_10_rivals.png")

# ─── PART 6: Crew tab ─────────────────────────────────────────────────────────
print("\n--- CREW TAB ---")
click(hwnd, tab_x(T_CREW), tab_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_11_crew.png")

# ─── PART 7: Operations — check timer state ───────────────────────────────────
print("\n--- PART 1: OPERATIONS (timer state) ---")
click(hwnd, tab_x(T_OPERATIONS), tab_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_12_ops_running.png")

# Now wait for Drug Run to complete (15s left at launch + ~30s navigation = complete)
print("  Waiting 20s for Drug Run to complete...")
time.sleep(20)
screenshot_window(hwnd, f"{SC_DIR}/p68_13_ops_ready_to_collect.png")

# Click collect on Drug Run (first row, Collect button at right of row)
# Ops content starts at HEADER_H + TAB_H + 8 ≈ 158
OPS_CONTENT_TOP = HEADER_H + TAB_H + 8
# Each op row is ~100px tall; first row center y ≈ 158 + 50 = 208
# Collect button is on the right side of row, ~x=850
click(hwnd, 850, OPS_CONTENT_TOP + 50, delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_14_ops_collected.png")

# Post-collection: check if notification appeared
time.sleep(0.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_15_ops_post_collection_notif.png")

# ─── PART 4: Achievements ─────────────────────────────────────────────────────
print("\n--- PART 4: ACHIEVEMENTS ---")
click(hwnd, tab_x(T_STATS), tab_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_16_stats.png")

# Try to go back to buildings and click rapidly to trigger achievements
click(hwnd, tab_x(T_BUILDINGS), tab_y(), delay=0.3)
print("  Clicking rapidly to trigger achievement toasts...")
for _ in range(60):
    click(hwnd, CLICK_CENTER[0], CLICK_CENTER[1], delay=0.05)
time.sleep(0.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_17_achievement_toast.png")

# ─── PART 5: Heat — push over 60% ────────────────────────────────────────────
# Heat was set at 57% — after ops + activity it may be at/over 60%
print("\n--- PART 5: HEAT (check warning state) ---")
screenshot_window(hwnd, f"{SC_DIR}/p68_18_heat_state.png")

# Navigate to buildings to check heat warning in context
click(hwnd, tab_x(T_BUILDINGS), tab_y(), delay=0.3)
screenshot_window(hwnd, f"{SC_DIR}/p68_19_buildings_heat_context.png")

# ─── PART 6: Rank-up (check current rank display + try to trigger) ───────────
# Current prestige_tokens=4; token is earned when... let's check upgrades/goals
print("\n--- PART 6: RANK-UP area ---")
# Go to stats to see current rank display
click(hwnd, tab_x(T_STATS), tab_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_20_stats_rank.png")

# ─── PART 7: Surprise rewards — check income display after all actions ─────────
print("\n--- PART 7: SURPRISE / INCOME DISPLAY ---")
click(hwnd, tab_x(T_BUILDINGS), tab_y(), delay=0.3)
screenshot_window(hwnd, f"{SC_DIR}/p68_21_final_buildings.png")

# Header area (income per second display)
screenshot_window(hwnd, f"{SC_DIR}/p68_22_header_income.png")

# ─── Managers tab ─────────────────────────────────────────────────────────────
print("\n--- MANAGERS ---")
click(hwnd, tab_x(T_EMPIRE), tab_y(), delay=0.2)
time.sleep(0.2)
click(hwnd, subtab_x(S_MANAGERS), subtab_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p68_23_managers.png")

print("\n\nAll screenshots captured. Terminating game...")
proc.terminate()
time.sleep(1.0)

# ── Restore original save ──────────────────────────────────────────────────────
if os.path.exists(BACKUP_PATH):
    shutil.copy2(BACKUP_PATH, SAVE_PATH)
    os.remove(BACKUP_PATH)
    print("  Original save restored.")

print(f"\nScreenshots in: {SC_DIR}")
print("Files:")
for f in sorted(os.listdir(SC_DIR)):
    if f.endswith('.png'):
        fpath = os.path.join(SC_DIR, f)
        print(f"  {f}  ({os.path.getsize(fpath):,} bytes)")
