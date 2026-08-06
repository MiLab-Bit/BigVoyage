@echo off
setlocal
cd /d "%~dp0\.."
if exist "..\tools\godot.cmd" (
  call "..\tools\godot.cmd" --headless --path . res://tests/T3.tscn
) else (
  godot --headless --path . res://tests/T3.tscn
)
exit /b %ERRORLEVEL%
