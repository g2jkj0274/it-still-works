# 소리

- 출처: Kenney — [Impact Sounds](https://kenney.nl/assets/impact-sounds),
  [Interface Sounds](https://kenney.nl/assets/interface-sounds),
  [RPG Audio](https://kenney.nl/assets/rpg-audio)
- 라이선스: **CC0 1.0** (`LICENSE.txt`)

세 팩을 합쳐 280여 개인데 **쓸 것 열셋만 골라 담았다.** 100KB 남짓이다.

| 소리 | 쓰임 |
|---|---|
| `impactMining_000` | 부수기 |
| `impactPlank_medium_000` | 놓기 |
| `footstep_grass_000/002` | 걸음 (번갈아) |
| `doorOpen_1` / `doorClose_1` | 문 여닫힘 |
| `pluck_001` | 배선 잇기 |
| `tick_002` | 신호가 부품을 지남 |
| `confirmation_002` | 만들기 |
| `impactMetal_heavy_000` | 되풀이 과열 |
| `impactPunch_medium_000` | 얻어맞음 |
| `handleSmallLeather` | 먹기 |
| `bong_001` | 해 지고 뜸 |

`view/sound_board.gd` 가 낸다. **시뮬레이션은 소리를 모른다.** 표현 레이어가
상태의 변화를 보고 울린다 — 시뮬레이션에서 재생 함수를 부르면 헤드리스 단독
실행이 깨진다(스펙 §2-4).
