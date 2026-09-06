# TESTING

- 전체: `tools/test.sh` (Git Bash) 또는 `tools\test.cmd` (cmd). 종료 코드 0 이면 전부 통과.
- 일부: `tools/test.sh res://test/unit/test_x.gd`
- 결정론: `tools/determinism.sh` — 결정론 회귀 스위트를 서로 다른 프로세스에서 2회. 둘 다 "0 errors | 0 failures" 여야 통과. 스위트의 `GOLDEN_HASH` 가 시드+명령 → 2000틱 → 해시를 못박는다.
- 성능: `tools/perf.sh` — M3 에서 회로 부품이 생기면 만든다(부품 1000개, 틱당 5ms 예산).
- 엔진: Godot 4.7.2 (`godot` 가 PATH 에 있어야 한다). GdUnit4 CLI 는 `addons/gdUnit4/bin/GdUnitCmdTool.gd`.
- 보고서: `reports/report_N/` (gitignore). M0 골격 기준 98 케이스 · 약 2초. (legacy 이전에는 894 케이스 · 3분.)
- 헤드리스 실행 확인: `godot --headless --path . --quit`
- **`.godot/` 를 지운 뒤에는 `godot --headless --path . --import` 를 먼저** 돌려 전역 클래스 캐시를 만든다. 런타임 모드(`--quit`)는 캐시를 만들지 않아 곧바로 돌리면 "Could not find type Simulation" 이 난다. legacy 와 무관한 캐시 부재 문제다.
- `legacy/` 는 `.gdignore` 로 스캔에서 빠진다. `tools/test.sh` 는 `-a test` 만 훑으므로 `legacy/test/` 는 돌지 않는다.
