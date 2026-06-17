"""Capture the Idle Empire window to screenshot.png using System.Drawing."""
import ctypes, ctypes.wintypes as wt, struct, time, sys

user32 = ctypes.windll.user32
gdi32  = ctypes.windll.gdi32

hwnd = user32.FindWindowW(None, "Idle Empire")
print(f"hwnd: {hwnd}")
if not hwnd:
    sys.exit("Window not found")

user32.ShowWindow(hwnd, 9)
user32.SetForegroundWindow(hwnd)
time.sleep(0.6)

r = wt.RECT()
user32.GetWindowRect(hwnd, ctypes.byref(r))
w, h = r.right - r.left, r.bottom - r.top
print(f"size: {w}x{h}")

hdc_win = user32.GetDC(hwnd)
hdc_mem = gdi32.CreateCompatibleDC(hdc_win)
hbmp    = gdi32.CreateCompatibleBitmap(hdc_win, w, h)
gdi32.SelectObject(hdc_mem, hbmp)
user32.PrintWindow(hwnd, hdc_mem, 2)

# Pull raw BGRA pixels
bi  = struct.pack('<IiiHHIIiiII', 40, w, -h, 1, 32, 0, w*h*4, 0, 0, 0, 0)
buf = (ctypes.c_ubyte * (w * h * 4))()
gdi32.GetDIBits(hdc_mem, hbmp, 0, h, buf, (ctypes.c_char * 40)(*bi), 0)
gdi32.DeleteObject(hbmp)
gdi32.DeleteDC(hdc_mem)
user32.ReleaseDC(hwnd, hdc_win)

# Write BMP file (simpler, no channel swap needed — BMP is native BGRA)
bmp_file_size = 54 + w * h * 4
bmp_header = (
    b'BM' +
    struct.pack('<IHHi', bmp_file_size, 0, 0, 54) +
    struct.pack('<IiiHHIIiiII', 40, w, h, 1, 32, 0, w*h*4, 0, 0, 0, 0)
)
with open('screenshot.bmp', 'wb') as f:
    f.write(bmp_header)
    # BMP is bottom-up, GetDIBits with -h gives top-down, so write as-is
    f.write(bytes(buf))
print("BMP saved, converting to PNG...")

# Convert via PowerShell System.Drawing
import subprocess
ps = r"""
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap('D:\2d_game\screenshot.bmp')
$bmp.Save('D:\2d_game\screenshot.png', [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host 'PNG done'
"""
result = subprocess.run(['powershell', '-Command', ps], capture_output=True, text=True)
print(result.stdout.strip())
if result.returncode != 0:
    print(result.stderr[:200])
