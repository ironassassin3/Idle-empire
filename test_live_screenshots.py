"""Phase 64 live screenshot capture.
Launches the game, navigates to key tabs, captures screenshots via Win32."""
import subprocess, time, ctypes, ctypes.wintypes as wt, struct, sys, os

user32 = ctypes.windll.user32
gdi32  = ctypes.windll.gdi32

def find_window(title, timeout=8.0):
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
    time.sleep(0.4)
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
    print(f"  Saved {path} ({w}x{h})")

def click(hwnd, x, y):
    """Send WM_LBUTTONDOWN + WM_LBUTTONUP at client coordinates."""
    WM_LBUTTONDOWN = 0x0201
    WM_LBUTTONUP   = 0x0202
    lparam = y << 16 | x
    user32.PostMessageW(hwnd, WM_LBUTTONDOWN, 1, lparam)
    time.sleep(0.05)
    user32.PostMessageW(hwnd, WM_LBUTTONUP, 0, lparam)
    time.sleep(0.15)

# Layout constants (from ui.py at 900x720)
RIGHT_X   = 420
HEADER_H  = 116
TAB_H     = 34
TAB_W     = 76
SUBTAB_W  = 70

# Tab click positions (center of each tab)
def tab_center(idx):
    return RIGHT_X + 4 + idx * TAB_W + TAB_W // 2, HEADER_H + TAB_H // 2

def subtab_center(idx):
    return RIGHT_X + 8 + idx * SUBTAB_W + SUBTAB_W // 2, HEADER_H + TAB_H + 17

EMPIRE_IDX   = 1   # Buildings=0, Empire=1, Crew=2, Operations=3, Stats=4
RIVALS_IDX   = 1   # Turf=0, Rivals=1, Managers=2, Upgrades=3
SETTINGS_X   = 900 - 36 + 14   # gear icon center x
SETTINGS_Y   = HEADER_H + 4 + 13

# Launch game
print("Launching game...")
proc = subprocess.Popen(['python', 'main.py'], cwd=r'D:\2d_game')

hwnd = find_window("Idle Empire", timeout=10)
if not hwnd:
    proc.terminate()
    sys.exit("Game window not found")
print(f"Found window: {hwnd}")
time.sleep(1.5)  # let it fully render

# Click "New Game" or "Continue" — look for a click at center of title screen
# The Continue button is roughly at center (450, 330)
cx, cy = 450, 330
click(hwnd, cx, cy)   # click Continue / New Game
time.sleep(1.2)

# --- Screenshot 1: Default view (buildings tab) ---
print("Screenshot 1: Default view...")
screenshot_window(hwnd, r'D:\2d_game\sc_1_default.png')

# --- Screenshot 2: Rivals tab ---
print("Screenshot 2: Rivals tab...")
ex, ey = tab_center(EMPIRE_IDX)
click(hwnd, ex, ey)      # click Empire main tab
time.sleep(0.4)
rx, ry = subtab_center(RIVALS_IDX)
click(hwnd, rx, ry)      # click Rivals subtab
time.sleep(0.5)
screenshot_window(hwnd, r'D:\2d_game\sc_2_rivals.png')

# --- Screenshot 3: Settings (gear icon) ---
print("Screenshot 3: Settings/gear...")
click(hwnd, SETTINGS_X, SETTINGS_Y)
time.sleep(0.4)
screenshot_window(hwnd, r'D:\2d_game\sc_3_settings.png')

# --- Screenshot 4: Back to buildings, check prestige panel ---
print("Screenshot 4: Buildings tab (prestige panel visible)...")
bx, by = tab_center(0)  # Buildings
click(hwnd, bx, by)
time.sleep(0.4)
screenshot_window(hwnd, r'D:\2d_game\sc_4_buildings.png')

proc.terminate()
print("Done. Screenshots saved.")
