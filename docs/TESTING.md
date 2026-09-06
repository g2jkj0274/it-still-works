# TESTING

- 전체: `tools/test.sh` (Git Bash) 또는 `tools\test.cmd` (cmd). 종료 코드 0 이면 전부 통과.
- 일부: `tools/test.sh res://test/unit/test_x.gd`
- 엔진: Godot 4.7.2 (`godot` 가 PATH 에 있어야 한다). GdUnit4 CLI 는 `addons/gdUnit4/bin/GdUnitCmdTool.gd`.
- 보고서: `reports/report_N/` (gitignore). 실행 시간 약 3분 (894 케이스 기준).
- 헤드리스 실행 확인: `godot --headless --path . --quit`
- `test_rubbish_is_refused` 가 `Parse JSON failed` 를 stderr 에 찍는 것은 의도된 입력이다. 실패가 아니다.
- 결정론 하네스 `tools/determinism.sh` 와 성능 벤치 `tools/perf.sh` 는 M0 에서 만든다.
