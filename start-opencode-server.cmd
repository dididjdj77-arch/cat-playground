@echo off
setlocal

REM Run from this folder (project root)
cd /d "%~dp0"

REM Start OpenCode server (no auto-browser)
opencode serve --hostname 0.0.0.0 --port 3333

endlocal
