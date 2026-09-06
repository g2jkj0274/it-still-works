#!/usr/bin/env sh
# 결정론 검사: 결정론 회귀 스위트를 서로 다른 프로세스에서 2회 실행한다.
# 스위트 안의 GOLDEN_HASH 가 "시드 + 명령 시퀀스 → 2000틱 → 상태 해시" 를 못박고 있으므로
# 두 프로세스가 모두 통과하면 프로세스 간에도 해시가 같다는 뜻이다.
# 종료 코드 0 = 두 번 다 "0 errors | 0 failures".
cd "$(dirname "$0")/.." || exit 1
SUITE="res://test/determinism/test_determinism_regression.gd"
for run in 1 2; do
  echo "== determinism run $run =="
  OUT=$(godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a "$SUITE" -c --ignoreHeadlessMode 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
  echo "$OUT" | grep -E 'Overall Summary'
  if ! echo "$OUT" | grep -qE 'Overall Summary:.*\| 0 errors \| 0 failures \|'; then
    echo "$OUT" | grep -E 'FAILED|ERROR|Error' | head -20
    echo "determinism run $run: FAILED"; exit 1
  fi
done
echo "determinism: PASS (2 runs, separate processes)"
