# 야간 자율 작업 기록

마지막 갱신: 0단계 완료 시점

## 완료한 단계

### 0. feat/screenshot-verification — 시각 자가검증 ✅

`tools/screenshot_runner.gd` — 게임을 실제로 띄워 단계별 스크린샷을 남기고
명백한 이상을 찾는다. `reports/screenshots/` 에 PNG 와 `REPORT.txt` 저장.

```bash
godot --path . -s res://tools/screenshot_runner.gd
```

이상이 있으면 종료 코드 1.

감지 항목:
- 검은 화면 (평균 밝기 < 0.05)
- 단색 화면 (한 색이 95% 초과 또는 색 종류 8종 미만)
- 캐릭터 미표시 (캐릭터를 켠 화면과 끈 화면을 견줘 실제로 그려졌는지 확인)

현재 결과: 5단계(spawn / walk / place / break / build_tower) 전부 이상 0건.

## 스펙에 없어 스스로 내린 설계 판단

### 스크린샷은 창을 띄워 찍는다

`--headless` 는 렌더링 드라이버가 더미라 `get_image()` 가 null 을 돌려준다.
확인한 사실이며 우회로가 없다. 그래서 이 도구만은 창을 띄우고 돈다.
CI 에서 돌리려면 가상 디스플레이가 필요하다.

### 캐릭터 표시 여부는 색이 아니라 차분으로 본다

팔레트로 찾으면 7단계에서 색을 바꿀 때 같이 깨진다. 캐릭터를 감춘 화면과
견주는 방식이라 색이 바뀌어도 그대로 쓸 수 있다.

## 건너뛴 것

없음.

## 아침에 확인할 것

1. `godot --path . -s res://tools/screenshot_runner.gd` 를 직접 돌려
   `reports/screenshots/*.png` 를 눈으로 볼 것. 도구는 "아무것도 안 나왔다"만
   판정한다. 보기 좋은지는 판정하지 않는다.
