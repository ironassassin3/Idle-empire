@echo off
python main.py
if errorlevel 1 (
    echo.
    echo The game exited with an error. Check crash.log for details.
    pause
)
