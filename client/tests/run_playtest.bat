@echo off
setlocal
set "ROOT=%~dp0..\.."
call "%ROOT%\tools\godot.cmd" --headless --path "%ROOT%\client" res://tests/Playtest.tscn
exit /b %ERRORLEVEL%
