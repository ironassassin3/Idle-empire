"""Phase 68 Pass 2 — targeted capture of Operations, Territory, Upgrades, Stats/rank."""
import subprocess, time, ctypes, ctypes.wintypes as wt, struct, sys, os, json, shutil

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
    print(f"  [SC] {os.path.basename(path)} ({w}x{h})")

def click(hwnd, x, y, delay=0.25):
    WM_LBUTTONDOWN = 0x0201
    WM_LBUTTONUP   = 0x0202
    lparam = (y << 16) | (x & 0xFFFF)
    user32.PostMessageW(hwnd, WM_LBUTTONDOWN, 1, lparam)
    time.sleep(0.06)
    user32.PostMessageW(hwnd, WM_LBUTTONUP, 0, lparam)
    time.sleep(delay)

# ── Layout constants ───────────────────────────────────────────────────────────
RIGHT_X  = 420
HEADER_H = 116
TAB_H    = 34
TAB_W    = 76
SUBTAB_W = 70

def tab_x(i): return RIGHT_X + i * TAB_W + TAB_W // 2
def tab_y():  return HEADER_H + TAB_H // 2
def sub_x(i): return RIGHT_X + 8 + i * SUBTAB_W + SUBTAB_W // 2
def sub_y():  return HEADER_H + TAB_H + 17

T_BUILDINGS  = 0
T_EMPIRE     = 1
T_CREW       = 2
T_OPERATIONS = 3
T_STATS      = 4

S_TERRITORY = 0
S_RIVALS    = 1
S_MANAGERS  = 2
S_UPGRADES  = 3

# Ops content area: HEADER_H + TAB_H + 8 = 158; each row ~110px tall
OPS_ROW1_Y = 116 + 34 + 8 + 55   # = 213  (first op row center)
OPS_ROW1_COLLECT_X = 860          # collect button right side of row
OPS_TIMER_X        = 680          # timer text center
# Territory content area
TER_CONTENT_TOP = HEADER_H + TAB_H + 34 + 8   # = 192 (has sub-tab row)
# Upgrades content
UPG_ROW1_Y = TER_CONTENT_TOP + 40   # first upgrade row center

SC_DIR = r"D:\2d_game\phase68_sc"
SAVE_PATH   = r"D:\2d_game\save.json"
BACKUP_PATH = r"D:\2d_game\save.json.phase68bak"

os.makedirs(SC_DIR, exist_ok=True)

# ── Test save (fresh state optimised for pass 2) ───────────────────────────────
def build_save():
    now = time.time()
    # Drug Run: 275s elapsed of 300s → 25s to completion
    drug_start  = now - 275.0
    # Casino Skim: 120s elapsed of 480s → clearly mid-run
    casino_start = now - 120.0
    return {
        "balance": 12_000.0,
        "lifetime_earnings": 450_000.0,
        "prestige_tokens": 4,
        "influence": 4,
        "click_count": 80,
        "play_time": 1200.0,
        "coins_caught": 2,
        "prestige_count": 0,
        "next_prestige_earnings": 20_000_000.0,
        "daily_streak": 1,
        "perks_purchased": [],
        "prestige_branch": None,
        "dragon_patron": None,
        "dragon_xp": 0,
        "dragon_ability_cooldowns": {},
        "tutorial_step": 10,
        "shown_milestones": [],
        "shown_raid_tutorial": True,
        "shown_ops_tutorial": True,
        "shown_influence_tutorial": True,
        "shown_heat_warning": True,
        "shown_prestige_tree_tutorial": False,
        "shown_syndicate_tutorial": False,
        "shown_influence_intro": False,
        "shown_crew_tutorial": True,
        "shown_territory_tutorial": True,
        "shown_rivals_tutorial": True,
        "peak_income": 200.0,
        "longest_streak": 1,
        "total_buildings_purchased": 22,
        "total_territories_captured": 1,
        "total_rivals_defeated": 0,
        "total_ops_completed": 1,
        "total_heat_generated": 12.0,
        "total_respect_earned": 0,
        "total_influence_earned": 4,
        "highest_cash_held": 12_000.0,
        "highest_city_control": 5.0,
        "city_control_milestones": [],
        "heat": 45.0,
        "sfx_volume": 0.4,
        "fps_cap": 60,
        "music_volume": 0.2,
        "master_volume": 0.7,
        "mute_all": False,
        "analytics_enabled": False,
        "buildings": [12, 6, 3, 0, 0, 0, 0, 0, 0, 0, 0],
        # First 2 purchased, next available
        "upgrades": [True, True, False, False, False, False, False, False,
                     False, False, False, False, False, False, False, False,
                     False, False, False, False, False, False, False, False,
                     False, False, False, False, False, False, False, False],
        "achievements": [True, False, False, False, False, False, False, False,
                         False, False, False, False, False, False, False, False,
                         False, False, False, False, False, False, False, False,
                         False, False, False, False, False, False, False, False,
                         False, False, False, False, False, False, False, False],
        "managers": [True, False, False, False, False, False, False, False, False, False, False],
        "territories": [
            {"unlocked": True,  "owner": "player"},
            {"unlocked": True,  "owner": "player"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
            {"unlocked": False, "owner": "unclaimed"},
        ],
        "rivals": [
            {"turf": 3, "wealth": 1000.0, "power": 40, "aggression": 0.5, "at_war": False, "status": "Active", "last_action": "Expanding"},
            {"turf": 2, "wealth": 800.0,  "power": 35, "aggression": 0.4, "at_war": False, "status": "Active", "last_action": "Recruiting"},
            {"turf": 4, "wealth": 1200.0, "power": 48, "aggression": 0.6, "at_war": False, "status": "Active", "last_action": "Consolidating"},
            {"turf": 1, "wealth": 500.0,  "power": 25, "aggression": 0.3, "at_war": False, "status": "Weakened","last_action": "Recovering"},
            {"turf": 2, "wealth": 700.0,  "power": 30, "aggression": 0.4, "at_war": False, "status": "Active", "last_action": "Building"},
        ],
        "crew": {"protection": 3, "collection": 3, "smuggling": 2, "territory": 0, "heat": 0},
        "operations": [
            {"active": True,  "start_time": drug_start,   "reward": 0.0, "completed": False, "collected": False},
            {"active": True,  "start_time": casino_start, "reward": 0.0, "completed": False, "collected": False},
            {"active": False, "start_time": 0.0,          "reward": 0.0, "completed": False, "collected": False},
            {"active": False, "start_time": 0.0,          "reward": 0.0, "completed": False, "collected": False},
            {"active": False, "start_time": 0.0,          "reward": 0.0, "completed": False, "collected": False},
        ],
        "goals_completed": ["first_building", "first_click"],
        "save_timestamp": now - 3.0,
        "last_login_date": time.strftime('%Y-%m-%d'),
        "arms_influence_frac": 0.0,
        "dragon_red_elim_count": 0,
    }

if os.path.exists(SAVE_PATH):
    shutil.copy2(SAVE_PATH, BACKUP_PATH)
    print("Save backed up.")
with open(SAVE_PATH, 'w') as f:
    json.dump(build_save(), f, indent=2)
print("Test save written (Drug Run completes in ~25s).")

print("\nLaunching game...")
proc = subprocess.Popen(['python', 'main.py'], cwd=r'D:\2d_game')
hwnd = find_window("Idle Empire", timeout=15)
if not hwnd:
    proc.terminate()
    sys.exit("Window not found")
print(f"  hwnd={hwnd}")
time.sleep(2.8)

# ── Title screen: click CONTINUE at correct Y ──────────────────────────────────
print("\n[TITLE] Screenshot + click Continue...")
screenshot_window(hwnd, f"{SC_DIR}/p2_00_title.png")
click(hwnd, 450, 404, delay=2.0)   # CONTINUE at y~404
screenshot_window(hwnd, f"{SC_DIR}/p2_01_post_continue.png")
# Dismiss any overlay (offline, daily, new event)
for _ in range(3):
    click(hwnd, 458, 500, delay=0.4)
time.sleep(0.5)
screenshot_window(hwnd, f"{SC_DIR}/p2_02_game_loaded.png")

# ── Operations tab: capture running timer state BEFORE completion ──────────────
print("\n[OPS] Navigate to Operations tab...")
click(hwnd, tab_x(T_OPERATIONS), tab_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p2_03_ops_timer_running.png")
print("  Drug Run has ~22s left. Waiting 30s for completion...")
time.sleep(15)
screenshot_window(hwnd, f"{SC_DIR}/p2_04_ops_timer_mid_wait.png")
time.sleep(18)
# Now Drug Run should be complete
screenshot_window(hwnd, f"{SC_DIR}/p2_05_ops_ready.png")

# Click COLLECT on Drug Run (row 1, right side)
print("  Clicking COLLECT on Drug Run...")
click(hwnd, OPS_ROW1_COLLECT_X, OPS_ROW1_Y, delay=0.8)
screenshot_window(hwnd, f"{SC_DIR}/p2_06_ops_post_collect.png")
time.sleep(0.6)
screenshot_window(hwnd, f"{SC_DIR}/p2_07_ops_notif.png")

# ── Territory tab ──────────────────────────────────────────────────────────────
print("\n[TERRITORY] Navigate to Territory...")
click(hwnd, tab_x(T_EMPIRE), tab_y(), delay=0.3)
time.sleep(0.2)
click(hwnd, sub_x(S_TERRITORY), sub_y(), delay=0.6)
screenshot_window(hwnd, f"{SC_DIR}/p2_08_territory_top.png")
# Scroll to see owned vs unclaimed
time.sleep(0.3)
screenshot_window(hwnd, f"{SC_DIR}/p2_09_territory_districts.png")
# Try to click on an unclaimed district to see cost/perk info
click(hwnd, RIGHT_X + 240, TER_CONTENT_TOP + 160, delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p2_10_territory_district_detail.png")

# ── Upgrades tab ──────────────────────────────────────────────────────────────
print("\n[UPGRADES] Navigate to Upgrades...")
click(hwnd, sub_x(S_UPGRADES), sub_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p2_11_upgrades_before.png")
# Buy the first available upgrade
click(hwnd, RIGHT_X + 240, UPG_ROW1_Y, delay=0.6)
screenshot_window(hwnd, f"{SC_DIR}/p2_12_upgrades_after_buy.png")
time.sleep(0.5)
screenshot_window(hwnd, f"{SC_DIR}/p2_13_upgrades_notif.png")

# ── Rivals tab ────────────────────────────────────────────────────────────────
print("\n[RIVALS] Navigate to Rivals...")
click(hwnd, sub_x(S_RIVALS), sub_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p2_14_rivals.png")

# ── Managers tab ──────────────────────────────────────────────────────────────
print("\n[MANAGERS] Navigate to Managers...")
click(hwnd, sub_x(S_MANAGERS), sub_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p2_15_managers.png")

# ── Crew tab ──────────────────────────────────────────────────────────────────
print("\n[CREW] Navigate to Crew...")
click(hwnd, tab_x(T_CREW), tab_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p2_16_crew.png")

# ── Stats tab (rank display) ──────────────────────────────────────────────────
print("\n[STATS] Navigate to Stats...")
click(hwnd, tab_x(T_STATS), tab_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p2_17_stats_rank.png")

# ── Back to buildings: heat + click feedback + prestige button ────────────────
print("\n[BUILDINGS] Final buildings view + heat check...")
click(hwnd, tab_x(T_BUILDINGS), tab_y(), delay=0.4)
screenshot_window(hwnd, f"{SC_DIR}/p2_18_buildings_heat.png")
# Rapid click to trigger click particles and check feedback
for _ in range(15):
    click(hwnd, 190, 246, delay=0.07)
time.sleep(0.3)
screenshot_window(hwnd, f"{SC_DIR}/p2_19_click_feedback.png")

# ── Prestige button state ─────────────────────────────────────────────────────
# Prestige button is at y = HEADER_H + 272 + 22 = ~410
click(hwnd, 190, 342, delay=0.5)   # prestige area
screenshot_window(hwnd, f"{SC_DIR}/p2_20_prestige_button.png")

print("\nDone. Terminating...")
proc.terminate()
time.sleep(0.8)

if os.path.exists(BACKUP_PATH):
    shutil.copy2(BACKUP_PATH, SAVE_PATH)
    os.remove(BACKUP_PATH)
    print("Save restored.")

print(f"\nScreenshots in {SC_DIR}:")
for f in sorted(os.listdir(SC_DIR)):
    if f.startswith('p2_') and f.endswith('.png'):
        p = os.path.join(SC_DIR, f)
        print(f"  {f}  {os.path.getsize(p):,}b")
