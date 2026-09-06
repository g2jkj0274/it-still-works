#!/usr/bin/env sh
# 헤드리스 전체 테스트. 인자를 주면 그 경로(res://...)만 돈다.
#   tools/test.sh                      # 전체 (test/)
#   tools/test.sh res://test/unit/foo.gd
# GdUnit4 CLI: addons/gdUnit4/bin/GdUnitCmdTool.gd. 보고서는 reports/ (gitignore).
# 종료 코드 0 = 전부 통과.
cd "$(dirname "$0")/.." || exit 1
TARGET="${1:-test}"
exec godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a "$TARGET" -c --ignoreHeadlessMode
