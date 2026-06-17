"""Phase 68 Pass 3 — use real mouse movement (SetCursorPos + mouse_event)
so clicks are guaranteed to hit the right positions regardless of DPI scaling."""
import subprocess, time, ctypes, ctypes.wintypes as wt, struct, sys, os, json, shutil

user32 = ctypes.windll.user32
gdi32  = ctypes.windll.gdi32

MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP   = 0x0004
MOUSEEVENTF_MOVE     = 0x0001
MOUSEEVENTF_ABSOLUTE = 0x8000

SM_CXSCREEN = 0
SM_CYSCREEN = 1

def find_window(title, timeout=12.0):
    t = time.time()
    while time.time() - t < timeout:
        hwnd = user32.FindWindowW(None, title)
        if hwnd:
            return hwnd
        time.sleep(0.3)
    return None

def client_to_screen(hwnd, cx, cy):
    """Convert client coordinates to screen coordinates."""
    pt = wt.POINT()
    pt.x = cx; pt.y = cy
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    return pt.x, pt.y

def real_click(hwnd, cx, cy, delay=0.3):
    """Move real mouse to client pos (cx,cy) in hwnd and click."""
    user32.ShowWindow(hwnd, 9)
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.15)
    sx, sy = client_to_screen(hwnd, cx, cy)
    sw = user32.GetSystemMetrics(SM_CXSCREEN)
    sh = user32.GetSystemMetrics(SM_CYSCREEN)
    # mouse_event uses 0-65535 absolute coordinates
    ax = int(sx * 65535 / sw)
    ay = int(sy * 65535 / sh)
    user32.mouse_event(MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE, ax, ay, 0, 0)
    time.sleep(0.05)
    user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.05)
    user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    time.sleep(delay)

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
    cr = wt.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(cr))
    print(f"  [SC] {os.path.basename(path)} win={w}x{h} client={cr.right}x{cr.bottom}")

# ── Layout constants (game client area = 900×720) ──────────────────────────────
RIGHT_X  = 420
HEADER_H = 116
TAB_H    = 34
TAB_W    = 76
SUBTAB_W = 70
CONTENT_TOP_EMPIRE = HEADER_H + TAB_H + 34 + 8  # = 192

def tab_x(i): return RIGHT_X + i * TAB_W + TAB_W // 2
def tab_y():  return HEADER_H + TAB_H // 2
def sub_x(i): return RIGHT_X + 8 + i * SUBTAB_W + SUBTAB_W // 2
def sub_y():  return HEADER_H + TAB_H + 17

T_BUILDINGS  = 0
T_EMPIRE     = 1
T_CREW       = 2
T_OPERATIONS = 3
T_STATS      = 4
S_TERRITORY  = 0
S_RIVALS     = 1
S_MANAGERS   = 2
S_UPGRADES   = 3

SC_DIR      = r"D:\2d_game\phase68_sc"
SAVE_PATH   = r"D:\2d_game\save.json"
BACKUP_PATH = r"D:\2d_game\save.json.phase68bak"
os.makedirs(SC_DIR, exist_ok=True)

def build_save():
    now = time.time()
    drug_start   = now - 270.0   # 270s elapsed of 300s → 30s to go after launch
    casino_start = now - 100.0   # clearly mid-run
    return {
        "balance": 15_000.0, "lifetime_earnings": 500_000.0,
        "prestige_tokens": 4, "influence": 4, "click_count": 100,
        "play_time": 1500.0, "coins_caught": 2, "prestige_count": 0,
        "next_prestige_earnings": 20_000_000.0, "daily_streak": 1,
        "perks_purchased": [], "prestige_branch": None,
        "dragon_patron": None, "dragon_xp": 0, "dragon_ability_cooldowns": {},
        "tutorial_step": 10,
        "shown_milestones": [], "shown_raid_tutorial": True,
        "shown_ops_tutorial": True, "shown_influence_tutorial": True,
        "shown_heat_warning": True, "shown_prestige_tree_tutorial": False,
        "shown_syndicate_tutorial": False, "shown_influence_intro": False,
        "shown_crew_tutorial": True, "shown_territory_tutorial": True,
        "shown_rivals_tutorial": True,
        "peak_income": 250.0, "longest_streak": 1,
        "total_buildings_purchased": 22, "total_territories_captured": 1,
        "total_rivals_defeated": 0, "total_ops_completed": 1,
        "total_heat_generated": 12.0, "total_respect_earned": 0,
        "total_influence_earned": 4, "highest_cash_held": 15_000.0,
        "highest_city_control": 5.0, "city_control_milestones": [],
        "heat": 42.0, "sfx_volume": 0.3, "fps_cap": 60,
        "music_volume": 0.2, "master_volume": 0.7, "mute_all": False,
        "analytics_enabled": False,
        "buildings": [12, 6, 3, 0, 0, 0, 0, 0, 0, 0, 0],
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
            *[{"unlocked": False, "owner": "unclaimed"}] * 18,
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
        "save_timestamp": now - 2.0,
        "last_login_date": time.strftime('%Y-%m-%d'),
        "arms_influence_frac": 0.0, "dragon_red_elim_count": 0,
    }

# Backup + write save
if os.path.exists(SAVE_PATH):
    shutil.copy2(SAVE_PATH, BACKUP_PATH)
with open(SAVE_PATH, 'w') as f:
    json.dump(build_save(), f, indent=2)
print("Test save written. Drug Run completes ~30s after launch.")

print("\nLaunching game...")
proc = subprocess.Popen(['python', 'main.py'], cwd=r'D:\2d_game')
hwnd = find_window("Idle Empire", timeout=15)
if not hwnd:
    proc.terminate(); sys.exit("Window not found")
print(f"  hwnd={hwnd}")

# Print client area info for debugging
time.sleep(2.5)
cr = wt.RECT()
user32.GetClientRect(hwnd, ctypes.byref(cr))
wr = wt.RECT()
user32.GetWindowRect(hwnd, ctypes.byref(wr))
print(f"  Window: {wr.right-wr.left}x{wr.bottom-wr.top} | Client: {cr.right}x{cr.bottom}")
cx_off, cy_off = client_to_screen(hwnd, 0, 0)
print(f"  Client origin at screen ({cx_off}, {cy_off})")

# ── Title screen ────────────────────────────────────────────────────────────────
screenshot_window(hwnd, f"{SC_DIR}/p3_00_title.png")

# Find where Continue button actually is in client space by probing around (450, ~404)
print("\nClicking CONTINUE (real mouse at client 450, 404)...")
real_click(hwnd, 450, 404, delay=2.0)
screenshot_window(hwnd, f"{SC_DIR}/p3_01_after_continue.png")

# If still on title, try a wider y range
cr2 = wt.RECT()
user32.GetClientRect(hwnd, ctypes.byref(cr2))
print(f"  Client after click: {cr2.right}x{cr2.bottom}")

# Dismiss overlays
for _ in range(3):
    real_click(hwnd, 450, 500, delay=0.4)
time.sleep(0.5)
screenshot_window(hwnd, f"{SC_DIR}/p3_02_game_loaded.png")

# ── Operations tab ─────────────────────────────────────────────────────────────
print("\n[OPS] Navigating to Operations tab...")
real_click(hwnd, tab_x(T_OPERATIONS), tab_y(), delay=0.8)
screenshot_window(hwnd, f"{SC_DIR}/p3_03_ops_running_timer.png")

print("  Waiting 35s for Drug Run to complete...")
time.sleep(18)
screenshot_window(hwnd, f"{SC_DIR}/p3_04_ops_mid_wait.png")
time.sleep(18)
screenshot_window(hwnd, f"{SC_DIR}/p3_05_ops_ready_collect.png")

# Collect — button is at right edge of row 1
# Ops rows start at HEADER_H+TAB_H+8 = 158, each ~110px; center of row 1 = ~213
# The COLLECT button is on the far right (around x=858)
print("  Collecting Drug Run...")
real_click(hwnd, 858, 213, delay=1.0)
screenshot_window(hwnd, f"{SC_DIR}/p3_06_ops_collected.png")
time.sleep(0.8)
screenshot_window(hwnd, f"{SC_DIR}/p3_07_ops_post_collect_notif.png")

# ── Territory ──────────────────────────────────────────────────────────────────
print("\n[TERRITORY]")
real_click(hwnd, tab_x(T_EMPIRE), tab_y(), delay=0.4)
time.sleep(0.2)
real_click(hwnd, sub_x(S_TERRITORY), sub_y(), delay=0.8)
screenshot_window(hwnd, f"{SC_DIR}/p3_08_territory.png")

# ── Upgrades ───────────────────────────────────────────────────────────────────
print("\n[UPGRADES]")
real_click(hwnd, sub_x(S_UPGRADES), sub_y(), delay=0.6)
screenshot_window(hwnd, f"{SC_DIR}/p3_09_upgrades_before.png")
# Click first available upgrade row at content top + ~40px
real_click(hwnd, RIGHT_X + 240, CONTENT_TOP_EMPIRE + 40, delay=0.8)
screenshot_window(hwnd, f"{SC_DIR}/p3_10_upgrades_after_buy.png")

# ── Rivals ─────────────────────────────────────────────────────────────────────
print("\n[RIVALS]")
real_click(hwnd, sub_x(S_RIVALS), sub_y(), delay=0.6)
screenshot_window(hwnd, f"{SC_DIR}/p3_11_rivals.png")

# ── Stats (rank display) ───────────────────────────────────────────────────────
print("\n[STATS]")
real_click(hwnd, tab_x(T_STATS), tab_y(), delay=0.6)
screenshot_window(hwnd, f"{SC_DIR}/p3_12_stats.png")

# ── Buildings + click feedback ─────────────────────────────────────────────────
print("\n[BUILDINGS]")
real_click(hwnd, tab_x(T_BUILDINGS), tab_y(), delay=0.4)
screenshot_window(hwnd, f"{SC_DIR}/p3_13_buildings.png")
for _ in range(20):
    real_click(hwnd, 190, 246, delay=0.07)
time.sleep(0.3)
screenshot_window(hwnd, f"{SC_DIR}/p3_14_click_feedback.png")

# ── Crew ───────────────────────────────────────────────────────────────────────
print("\n[CREW]")
real_click(hwnd, tab_x(T_CREW), tab_y(), delay=0.5)
screenshot_window(hwnd, f"{SC_DIR}/p3_15_crew.png")

print("\nDone. Terminating...")
proc.terminate()
time.sleep(0.8)

if os.path.exists(BACKUP_PATH):
    shutil.copy2(BACKUP_PATH, SAVE_PATH)
    os.remove(BACKUP_PATH)
    print("Save restored.")

print(f"\nFiles:")
for fn in sorted(os.listdir(SC_DIR)):
    if fn.startswith('p3_') and fn.endswith('.png'):
        p = os.path.join(SC_DIR, fn)
        print(f"  {fn}: {os.path.getsize(p):,}b")
