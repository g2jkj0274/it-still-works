@echo off
rem 헤드리스 전체 테스트. 인자를 주면 그 경로(res://...)만 돈다. tools/test.sh 와 같다.
cd /d "%~dp0.."
set TARGET=%1
if "%TARGET%"=="" set TARGET=test
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a %TARGET% -c --ignoreHeadlessMode
