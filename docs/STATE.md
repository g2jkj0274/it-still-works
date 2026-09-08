# STATE
마일스톤: M1 (M0 완료 — 빈 세계 2000틱 결정론 통과, 2026-09-06)
진행 중: 없음 — M1-7a 완료·커밋(2026-09-09). 다음은 M1-7b-1 (WorldState.inventory + 해시 필드, 골든 갱신 #1). 7b-1~7c-2 사이에 다른 태스크를 두지 않는다
마지막 통과 테스트: 477/477 (tools/test.sh, 약 119초, 2026-09-09)
마지막 결정론 테스트: 통과 — 6f882498083ec79be4f9bea4ea5fe358cf09ccfb0f6684ea1ed9b0b656b9624e (M1-6a-2 갱신 2026-09-08, 별도 프로세스 3회 일치. M1-6b 4커밋·M1-7a 뒤 불변 재확인 2026-09-09)
이터레이션 수: 14 (10마다 architect 전체 감사 — 10 완료, 다음 감사는 20)

## M1 태스크 (LOOP.md M1)
- [x] M1-1 블록 속성 시스템(P2) + `data/blocks.json` + `sim/block_registry.gd` (2026-09-07, 26 테스트. view 는 M1-5 에서 붙음)
- [x] M1-2 청크 자료구조 `sim/chunk.gd`(16×16×3, 바이트 둘, dirty, digest) (2026-09-07, 27 테스트. 1000청크 채우기+digest 약 0.92ms/청크)
- [x] M1-3 시드 기반 청크 절차 생성 `sim/chunk_generator.gd` + `sim/terrain_table.gd` + `data/terrain.json` (2026-09-07, 54 테스트. 골든 지형 해시 c4ae1a1b…, 청크당 약 1.9ms)
- [x] M1-4a 청크 월드 자료구조 `sim/chunk_world.gd`: LOAD_RADIUS=2, 로드/언로드, 스냅샷 소비+persist, 월드 좌표 조회, 해시 필드 (2026-09-07, 31 테스트. 첫 로드 45ms, 경계 넘기 9~16.5ms, 퍼징 200스텝 위반 0)
- [x] M1-4b WorldState.chunks 필수, Simulation.create/create_default, SetLoadCenterCommand → step() 동기화, 골든 갱신, SIM_ORDER 1-M1 (2026-09-07, 23 테스트. 첫 로드 틱 45~48ms, 경계 넘기 틱 9ms, 빈 틱 2.5µs)
- [x] M1-5a 아이소 투영 + 팔레트 + WorldView.build_cells(바닥 규칙 넷) + 단위 테스트 (2026-09-07, 38 테스트)
- [x] M1-5b main.gd/tscn Node2D 전환, Camera2D, 입력 맵(layer_up/down, move_*), 방향키 → SetLoadCenter 명령, 통합 테스트 (2026-09-08, 21 테스트. 드로우콜 6400→1 삼각형 배열, `층|청크해시` 캐시, refresh 프레임당 1회)
- [x] M1-6 플레이어 이동(명령 경유, 서브유닛 정수 — legacy character_state 참고). architect 분할(2026-09-08), 전부 완료:
  - [x] M1-6a-1 `sim/player_state.gd` + `sim/movement_rules.gd` + 단위 테스트 2개. 기존 파일 불변, 골든 불변. (2026-09-08, 49 테스트. 새 class_name 추가 시 `godot --headless --path . --import` 한 번 필요)
  - [x] M1-6a-2 `MovePlayerCommand`, `SetLoadCenterCommand` 삭제, WorldState.player/registry, step 순서(명령→player.advance→_sync_chunk_center→tick), main.gd 최소 수정(키→방향 화면 기준), 골든 6f882498 (2026-09-08, 22 테스트 증가. 시드 20250901 스폰 (8,8) 북·동이 solid 라 골든 시나리오는 남→동으로 걸어 청크 (1,1) 도달)
  - [x] M1-6b view (2026-09-08, 커밋 넷: 6b-1 revision 표지 / 6b-2a sub_to_screen·PLAYER 색 / 6b-2b 마커·focus_position·층 추적·캐시 키·가드 통일 / 6b-2c 키 누름 유지 틱마다 명령. 49 테스트 증가, 골든 불변)
- [ ] M1-7 채집·배치 명령, 인벤토리. architect 분할(2026-09-09, DECISIONS "채집·배치 규칙" 참조). 7b-1~7c-2 사이에 다른 태스크를 두지 않는다:
  - [x] M1-7a `sim/inventory.gd`(Inventory 칸 9×스택 64, 정규형 amount==0⇔kind==0) + `sim/harvest_rules.gd`(HIT_POWER 1, target_of, can_harvest, is_empty_at, remaining_after_hit) + 단위 테스트 2개. 기존 파일 불변, 골든 불변 (2026-09-09, 37 테스트)
  - [ ] M1-7b-1 `WorldState.inventory`(5인자 _init) + 해시 필드(player 뒤·chunks 앞) + `Simulation._init` 생성. 골든 갱신 #1(필드 10개 추가, 시나리오 불변)
  - [ ] M1-7b-2 `HarvestCommand`(페이로드 없음) + 코덱 등록 + 테스트 + SIM_ORDER 1 에 한 줄. 골든 불변
  - [ ] M1-7b-3 `PlaceBlockCommand(id)` + 코덱 + 테스트 + 골든 시나리오에 채집·배치·언로드·재로드(스냅샷 해시 경로). 골든 갱신 #2
  - [ ] M1-7c-1 view 내구도 표시 `Palette.damaged`(단계마다 다른 색, max 는 원색, 단조) + `build_cells` + 테스트
  - [ ] M1-7c-2 HUD Label·입력 맵(harvest/place/slot_prev/slot_next)·main 제출(이동 우선, 걷는 중·이동 키 눌림이면 채집 안 냄)·가드 needle 추가·통합 테스트
- [ ] M1-8 기초 크래프팅(부품만 — M1 은 레시피 0개, 틀만)
- [ ] M1-9 연구대 부품 + 연구 트리 UI 골격(빈 트리)
- [ ] M1-10 저장/불러오기(시드+명령 로그 + 언로드 청크 스냅샷) — legacy save_slot 참고
- [ ] M1 완료 조건: 걸어서 새 청크 생성 → 저장 → 종료 → 로드 → 동일 상태 테스트

## 남긴 태스크 (builder 보고)
- [x] legacy/ 중첩 평평하게 (legacy/view/view, legacy/test/integration/integration) — 이번 커밋에서 정리
- [x] docs/TESTING.md 갱신 (--import 절차, 98 케이스)
- [x] DECISIONS.md 에 .gdignore 확인 결과
- [ ] tools/perf.sh — M3 에서 부품이 생기면
- [x] DECISIONS 생성기 항목 (e) 정정 — set_center 항목에 정정 줄로 덧붙임
- [ ] M1-5/M7 시각: 지대 격자(8칸)가 축에 정확히 맞아 인공적으로 보인다(tester 지도). 렌더에서 볼 때 거슬리면 격자 좌표에 셀 해시로 ±1 흔들림을 주는 규칙을 architect 검토로 추가 — 생성기 골든이 바뀌므로 DECISIONS 기록
- [x] M1-6 승인 조건(감사 10): `_pending_center` 제거(6a-2), 캐시 키 → `chunks.revision()`(6b-2b). 완료.
- [ ] M1-7 승인 조건(감사 10, P4): `build_cells` 가 내구도 바이트를 그리지 않는다. 채집으로 내구도가 깎이는 순간 P4 위반이므로 M1-7 에 내구도 표시를 포함한다.
- [ ] M1-10 승인 조건(감사 10, P7): `Chunk.clear_dirty()` 는 ChunkWorld 가 `_persist[key] = true` 와 함께만 부른다. 저장이 dirty 를 끄고 persist 를 안 켜면 언로드 때 버려져 저장 파일과 메모리 세계가 갈린다.
- [x] 가드 통일(감사 10): `test_world_view.gd` 가 `res://view` 디렉터리 순회로 sim 변경 메서드 40여 needle 부재를 강제, submit/Input 은 main.gd 에만 (6b-2b). 완료.
- [ ] M1-7 시각(6b-2c 관찰): 시드 20250901 스폰 (8,8) 은 화면 4방향 중 왼쪽만 열려 있고 두 걸음 연속 허용 방향이 없다(지형 지대 경계). 플레이어 QA 때 첫 인상에 걸릴 수 있다 — 스폰 규칙은 DECISIONS 고정이므로 지형 표(ground_zones 밀도) 쪽에서 볼 것. (architect 2026-09-09: M1-7 에서는 지형 표를 손대지 않는다. 채집이 막힌 방향을 뚫으므로 7c-2 뒤 플레이어 QA 로 보고, 걸리면 격자 ±1 흔들림과 묶어 지형 골든 갱신 하나로 따로 간다.)
- [ ] M1-7 (architect, M1-6a 검토): 플레이어 발밑(아래 층) 셀을 채집으로 air 로 만들면 M3 낙하 규칙이 없는 동안 VOID 위에 서게 된다. 발 칸 아래 셀 채집을 거부하거나 그 상태를 명시적으로 결정한다. → 결정(2026-09-09): 목표 = 같은 층 feet+facing 뿐이라 발 칸·아래 층은 정의상 목표가 못 된다. 7a `HarvestRules.target_of` 테스트가 `!= feet` 를 지킨다. 7b-2 에서 닫는다.
- [ ] M1-7 채집 규칙(architect, M1-2 검토): breakable 블록(레지스트리 max>0)의 현재 내구도 0 은 저장 상태로 존재할 수 없다. 0 에 도달한 틱 안에서 air 로 바꾼다. Chunk 는 레지스트리를 모르므로 이 규칙은 채집·몹 파괴 명령 쪽이 지킨다. → 7b-2 HarvestCommand(깨는 apply 안에서 air+add), 7b-3 PlaceBlockCommand(`is_breakable(id)` 가드로 "id≠0 내구도 0" 셀 생성 차단)에서 닫는다.

비고:
- 이 세션 첫 감사는 general-purpose 에이전트에 architect 지시문을 넘겨 돌렸다(에이전트 정의가 세션 시작 뒤 생김). 이후는 architect/builder/tester 타입 사용.
