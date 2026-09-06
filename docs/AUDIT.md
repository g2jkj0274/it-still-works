# AUDIT (M0)

2026-09-06. architect 검토. 대상: 헌법(P1~P12) 교체 직후의 저장소 전체(커밋 `e1f1890` 기준).
이 감사의 "수정안"이 M0 의 legacy 이동 태스크가 되었다.

## 요약 (5줄 이내)
- 저장소는 스펙 v0.2(고정 섬 64×64×24, 값 있는 신호 부품 5종, `BlockType` 열거형)용으로 지어졌고, 헌법(P2 속성 기반·P7 무한 청크·테크트리 1 부품 8종)과 **게임 내용 층은 거의 전부 어긋난다**. `sim/` 43개 파일 중 헌법 그대로 쓸 수 있는 것은 6개(RNG·틱 드라이버·해시·명령 3종)뿐이다.
- P3(결정론)는 잘 지켜져 있다. 시드 안 된 랜덤 0건, `sim/` 안 `delta` 사용 0건, 딕셔너리 순회 의존은 `world_state.gd:97` 한 곳이며 정렬로 방어되어 있다. **결정론 하네스(골든 해시 + 명령 재생 저장)는 그대로 M0 골격의 뼈대가 된다.**
- P2 위반이 `sim/` 13개 파일 41곳에 있다. 전부 `BlockType.is_door/is_lamp/is_furnace/== BlockType.X` 타입 분기다. 회로·명령·위협·도구 규칙이 모두 이 위에 서 있어 부분 수리가 아니라 교체 대상이다.
- P6(화로는 회로 없이 안 돔), P7(고정 섬·스트리밍 없음), P10(몹이 `is_strong_door`만 예외 처리, 소리 반응 없음), P1(값·상자·갈림길이 부품이 아니라 "프로그래밍 원시"), P5(사망 시 인벤토리 절반 손실) 위반이 있다.
- 판정은 **조건부 승인**: `legacy/` 이동 자체는 승인하되, 아래 "재활용 6 + 다듬기 4" 파일을 `legacy/`에 넣지 말고 자리에 남겨 골격을 세울 것. `.gdignore` 처리와 `project.godot` 메인 씬 교체가 조건.

## 분류표
| 경로 | 분류 | 근거 |
|---|---|---|
| `addons/gdUnit4/` | 맞음(외부) | GdUnit4 6.2.1. 헌법 기술 스택 고정. |
| `project.godot` | 보류 → 수정 | Godot 4.7 / GL Compatibility 유지. 단 `run/main_scene="res://view/main.tscn"`이 legacy로 가면 깨진다. 빈 씬 또는 새 `view/main.tscn`으로 교체 필수. |
| `CLAUDE.md`, `LOOP.md`, `.claude/agents/*`, `.claude/skills/*` | 맞음 | 헌법·루프·서브에이전트. 단 `builder.md:12-13`이 `data/blocks.json`, `sim/rng.gd`를 가리키는데 둘 다 아직 없다(M0/M1에서 만들 것 — 파일명은 `sim/sim_rng.gd`와 맞출지 DECISIONS에 기록). |
| `tools/test.sh`, `tools/test.cmd`, `docs/TESTING.md` | 맞음 | 헤드리스 실행 명령 확정 = M0 항목 (`e1f1890`). `-a test`로 `test/`만 훑으므로 `legacy/` 아래 테스트는 자동으로 빠진다. |
| `docs/STATE.md`, `DECISIONS.md`, `PRIMITIVES.md`, `SIM_ORDER.md`, `BLOCKERS.md`, `EMERGENCE_LOG.md`, `JOURNAL.md` | 맞음 | 헌법이 요구하는 빈 기억 문서. |
| `docs/spec.md` (v0.2, 1093줄) | 안 맞음 | "마인크래프트를 그대로 한다", 부품 5종 고정, 고정 섬, 화로 회로 의존. 헌법 P1/P2/P6/P7과 정면 충돌. `legacy/docs/`로. |
| `docs/tech-tree.md` | 안 맞음 | 아이템 6단 트리 + "지을 수 있는 장치 17" = 기계 카탈로그. P1/P11(연구 트리 4단계 고정)과 충돌. |
| `SUMMARY.md` (1318줄) | 안 맞음 | 옛 스펙 작업 기록. 역사 자료로 `legacy/`에 보존. |
| `README.md`, `LICENSE`, `.gitignore`, `.gitattributes`, `.editorconfig`, `icon.svg` | 맞음 | 중립. `.gitignore`에 `reports/` 있음(리포트는 미추적, 정상). |
| `reports/` | 맞음(미추적) | GdUnit 출력물. git 밖. 건드릴 것 없음. |
| `assets/kenney_audio/`, `assets/kenney_nature_kit/`, `assets/README.md` | 안 맞음 | P12 "외부 다운로드 금지, 코드로 생성한 픽셀아트". CC0라도 헌법 위반. `legacy/assets/`로. |
| **sim/ — 맞음(그대로)** | | |
| `sim/sim_rng.gd` | 맞음 | 시드 단일 RNG, 정수만 노출, `get_state/set_state`로 해시·저장 가능. P3 그대로. |
| `sim/tick_driver.gd` | 맞음 | 정수 µs 누산 → 틱 수. 실수는 표현 레이어 밖. 단 `:23` 기본 인자가 `Simulation.TICK_INTERVAL_USEC`를 참조 — Simulation을 다듬을 때 상수 위치만 맞출 것. |
| `sim/sim_hash.gd` | 맞음 | 순서 있는 필드 + 길이 접두사 + SHA-256. 딕셔너리 순회 안 함. |
| `sim/sim_command.gd` | 맞음 | `@abstract` 명령 기반. 직렬화 가능. |
| `sim/sim_command_queue.gd` | 맞음 | (틱, 접수 순서) 완전 정렬. 지나간 틱 명령 버리지 않음. |
| `sim/commands/set_value_command.gd`, `add_value_command.gd`, `roll_value_command.gd` | 맞음 | 블록 타입 무관. 결정론 테스트 시나리오용. (`add_value_command.gd:9`의 `delta`는 정수 필드명일 뿐 프레임 델타 아님.) |
| **sim/ — 보류(다듬어 재활용)** | | |
| `sim/simulation.gd` | 보류 | 골격(큐 소비 → 서브시스템 틱 → tick++, 명령 로그 = 저장 형식)은 헌법 그대로. 그러나 `:78-84`가 crops/circuit/threats/vitals/character를 직접 호출. 빈 세계용으로 `step()`을 "명령 적용 + tick++"만 남기고 잘라 낼 것. `SIM_ORDER.md`가 이 함수의 문서가 된다. |
| `sim/world_state.gd` | 보류 | `_values` 딕셔너리 + `sorted_keys()`(String 변환 후 정렬, `:92-94`의 StringName 포인터 순서 함정까지 적어 둠) + `to_hash_fields()`는 재활용. `:18-49` 필드(grid/circuit/vitals/threats/crops/chests/craft)는 제거. |
| `sim/sim_command_codec.gd` | 보류 | 구조는 맞음. `:25-53`의 14종 등록을 3종(set/add/roll)으로 줄여서 유지. |
| `sim/day_cycle.gd` | 보류 | 틱만으로 낮밤 판정, 상태 없음 — M2에서 그대로 쓸 수 있다. 다만 M0 골격에는 불필요. `legacy/`에 두었다가 M2에서 꺼내도 무방. |
| `sim/character_state.gd` | 보류 | 서브유닛 정수 이동(1000/칸, `_floor_div` 음수 처리)은 M1 재활용 가치 높음. 단 `HEIGHT`/`occupies`가 고정 격자 전제. legacy로 보내고 M1에서 꺼낸다. |
| `sim/movement_rules.gd` | 보류 | 8방향 고정 순서 배열, 정수 판정. `VoxelGrid` 인터페이스(`is_free/is_solid`)에 묶여 있어 청크 월드 인터페이스로 갈아끼운 뒤 재활용. legacy로. |
| `sim/save_slot.gd` | 보류 | "시드 + 명령 로그 + 틱 수"만 저장하는 방식은 P3와 정확히 맞는다. 그러나 `:81`이 `IslandBuilder.start`를 부르고, P7(언로드 청크 상태 저장·복원)은 명령 재생만으로는 못 푼다(재생 시간이 무한 세계에선 무제한). M1에서 청크 스냅샷과 결합해 다시 설계. legacy로. |
| **sim/ — 안 맞음** | | |
| `sim/block_type.gd` | 안 맞음 | 열거형 + `is_door/is_lamp/is_furnace/is_strong_door/is_part`(`:176-216`) — P2가 금지한 "타입 이름 분기"의 근원. 속성 테이블(`data/blocks.json`)로 대체. |
| `sim/voxel_grid.gd` | 안 맞음 | `:12-19` 고정 64×64×24, `:4-6` "청크 스트리밍은 없다". P7 위반. 다만 `PackedByteArray` 저장·`digest()`·dirty/changes 기록 패턴은 청크 한 개의 내부 구조로 참고 가치 있음. |
| `sim/island_builder.gd` | 안 맞음 | 수작업 배치 섬. `_noise`(`:335`)가 시드를 전혀 쓰지 않아 시드가 달라도 지형이 같다 → P7 "절차 생성" 요구 위반. |
| `sim/circuit/*.gd` (9개) | 안 맞음 | 값 있는 신호(bool/int/real), 상자·갈림길 = 변수·조건문의 부품화(P1 "부품은 감지/전달/논리/작동 중 하나", 헌법은 on/off 신호). `circuit_part_factory.gd:26-34`, `actuator_part.gd:59-101` 타입 분기(P2). 배선 방식(`link(from,to,port)`)도 전선 블록 기반 헌법과 다름. 다만 `circuit.gd`의 compute/commit/act 3상 분리와 `cell_before` 고정 정렬은 M3에서 설계 참고. |
| `sim/threat.gd`, `sim/threat_field.gd` | 안 맞음 | `threat.gd:132` `is_strong_door` 특별 예외(P10 "몹이 X 블록을 특별히 노린다 예외 금지", P2). 소리 반응 없음, 내구도 없음(P10). `threat_field.gd:76-77` 고정 격자 크기 의존(P7). 위협 `id` 순 순회·시드 RNG 스폰은 참고 가치. |
| `sim/vitals.gd` | 안 맞음(내용은 P9 준수) | 체력+포만도 = P9 그대로. 그러나 `Simulation.TICK_RATE` 참조 외엔 독립적이고 M2 재활용 가능. legacy로 보내고 M2에서 꺼낼 것. |
| `sim/inventory.gd`, `sim/recipe_book.gd`, `sim/tool_rules.gd`, `sim/crop_field.gd`, `sim/chest_field.gd` | 안 맞음 | 전부 `BlockType` 상수와 `match` 분기(`tool_rules.gd:41-45, 68-73`). `recipe_book.gd:180-186` 굽기가 회로 전용(P6). 배열 기반·딕셔너리 회피 원칙은 좋으나 속성 테이블 위에서 다시 써야 한다. |
| `sim/commands/` 나머지 11개 | 안 맞음 | `break_block/place_block/place_part/connect/disconnect/move_item/craft/fill_craft/clear_craft/eat/move_character` — 모두 `BlockType`·`Circuit`·`RecipeBook`·`VoxelGrid` 고정 격자에 묶임. 명령 패턴(`create` 정적 생성자, `write/read_payload` 정수 복원)만 본보기로. |
| **view/ (30개 .gd + main.tscn)** | 안 맞음 | 옛 부품 5종·고정 섬·Kenney 에셋을 그리는 층. `main.gd:61 _physics_process` + `TickDriver` + `Time.get_ticks_usec()` 정수 변환은 재활용 패턴. `palette.gd`의 "명도 0.60↑ 채도 0.45↓" 규칙과 `test_palette.gd`는 P12 톤 검사로 M7에서 재활용. `part_words.gd:4-9`, `part_hint.gd:6-7`은 P4를 지키려 한 흔적이나 렌더 대상 자체가 없어진다. `notice.gd:52 _process(delta)`는 view라 위반 아님. |
| `tools/screenshot_runner.gd`, `tools/screenshot_check.gd` | 안 맞음(러너) / 보류(체크) | 러너는 `GameMain`·옛 부품에 하드코딩(`:48-59`). `screenshot_check.gd`(검은/단색/날아간 화면·차분 판정)는 시뮬레이션 무관 순수 함수라 M7 시각 검증에 그대로 재활용. `tools/_probe_capture.gd.uid`는 본체 없는 고아 파일 — 삭제. |
| `tools/pixelart/` | 없음 | P12가 요구하나 존재하지 않음. M7 태스크. |
| `data/` | 없음 | `data/blocks.json`은 M1 태스크. |
| **test/ — 맞음(그대로)** | | |
| `test/unit/test_sim_rng.gd`, `test_tick_driver.gd`, `test_sim_hash.gd`, `test_sim_command_queue.gd`, `test_sanity.gd` | 맞음 | 재활용 파일과 1:1. |
| `test/determinism/test_determinism_regression.gd` | 보류 → 갱신 | 시나리오가 `SetValue/AddValue/RollValue`만 써서 `Simulation`을 잘라 내면 그대로 돈다. `GOLDEN_HASH`(`:32`)는 해시 대상이 바뀌므로 재고정 필요(이력 주석 형식 유지). `TOTAL_TICKS := 20`(`:10`)을 LOOP.md 완료 조건인 2000으로 올릴 것. |
| `test/unit/test_sim_command.gd`, `test_simulation.gd`, `test_world_state.gd` | 보류 | 일부 케이스가 `MoveCharacterCommand`/그리드/회로를 참조. 남는 명령 3종 케이스만 추려 유지. |
| `test/unit/test_palette.gd`, `test_screenshot_check.gd` | 보류 | 대상 파일이 legacy로 가면 함께 간다. M7에서 되살린다. |
| `test/` 나머지 (determinism 3개, integration 1개, unit 약 55개) | 안 맞음 | 옛 부품·섬·view 테스트. 894개 함수 중 M0에 남는 것은 약 60개. |

## 헌법 위반 목록 (파일:줄)
**P1 (기계 아닌 부품)**
- `sim/circuit/box_part.gd:4-13`, `sim/circuit/branch_part.gd:4-27`, `sim/circuit/signal_value.gd:6-11` — 값을 담는 상자·조건 판정 갈림길·bool/int/real 신호. 감지/전달/논리/작동 분류에 들어가지 않는 "변수·조건문"이며, `docs/spec.md:1064` "개념 대응표"가 이를 프로그래밍 개념의 위장으로 명시.
- `docs/tech-tree.md:19` "지을 수 있는 장치 17" — 기계 카탈로그를 설계 산출물로 둠.

**P2 (타입 분기 — sim/ 안)**
- `sim/block_type.gd:165-216` — `is_solid/is_door/is_strong_door/is_furnace/is_lamp/is_light/is_part`가 모두 상수 비교.
- `sim/circuit/actuator_part.gd:59, 63, 77, 91, 101` — `is_furnace`, `!= FURNACE_LIT`, `is_door`, `is_lamp`, `== FIELD`.
- `sim/circuit/circuit_part_factory.gd:26-34` — `part_type == BlockType.DETECTOR/ACTUATOR/REPEATER/BOX/BRANCH` 5분기.
- `sim/circuit/detector_part.gd:55-74` — `match target:` (감지 대상 5분기; 속성 `emits_sound` 등으로 대체 가능).
- `sim/commands/break_block_command.gd:40, 48, 58` — `is_breakable`, `!= EMPTY`, `== CHEST`.
- `sim/commands/place_block_command.gd:28, 42, 46` — `is_placeable`, `== CHEST`, `== FIELD`.
- `sim/commands/place_part_command.gd:33` — `is_part`.
- `sim/commands/fill_craft_command.gd:92` — `!= EMPTY`.
- `sim/inventory.gd:96, 127, 279` — `is_carryable`.
- `sim/island_builder.gd:303, 321` — `!= ROCK`, `== EMPTY`.
- `sim/recipe_book.gd:261, 347, 384` — `== EMPTY`.
- `sim/threat.gd:132` — `is_strong_door`.
- `sim/tool_rules.gd:41-45, 68-73` — `match material` / `match tool` 상수 분기.
- `sim/voxel_grid.gd:98, 158, 162, 180` — `is_valid/== EMPTY/is_solid/is_drawn`.
- `sim/circuit/signal_value.gd:80, 88`은 신호 종류 비교(`kind == KIND_REAL`)로 블록 타입 분기는 아님. 다만 신호 자체가 P1 위반.

**P3 (결정론)**
- 시드 안 된 랜덤: **없음**. `randi/randf/randomize` 호출은 `sim/sim_rng.gd:42, 47`의 `RandomNumberGenerator` 인스턴스 메서드뿐.
- `delta`/`_process` 의존: `sim/` 안 **없음**. `view/notice.gd:52-55`, `view/main.gd:61`, `tools/screenshot_runner.gd:71`은 표현 레이어(허용).
- 딕셔너리 순회: `sim/world_state.gd:97` `for key in _values.keys()` — 직후 `names.sort()`로 정렬하므로 순서 의존 없음(방어 완료). `sim/` 다른 곳은 전부 `Array`/`PackedByteArray`. `view/part_words.gd:11`, `view/input_controller.gd:32` 딕셔너리는 표현 레이어.
- 시드 미사용: `sim/island_builder.gd:335-338` `_noise`가 시드를 받지 않음 → 시드가 달라도 지형이 같다. P3 위반은 아니나(결정적이긴 함) P7 절차 생성 요구와 어긋남.

**P5 (실패 없음)**
- `sim/simulation.gd:100-106` `_revive_if_fallen` — 사망 시 `inventory.drop_half()`. 마인크래프트식 리스폰이라 해도 "패널티"에 해당해 애매 → 거절 원칙에 따라 위반으로 기록. M2에서 결정하고 DECISIONS에 적을 것.

**P6 (손으로 끝까지)**
- `sim/circuit/actuator_part.gd:48-72`, `sim/recipe_book.gd:176-179`, `sim/block_type.gd:77-82`, `sim/commands/eat_command.gd:12` — 굽기(`smelt`) 호출자가 작동기뿐(`grep 'smelt('` 결과 1건). 화로가 회로 없이는 돌지 않는다. 스펙 v0.2가 걷어냈다고 적었으나 코드는 남아 있음.

**P7 (무한 청크)**
- `sim/voxel_grid.gd:4-19` — 고정 64×64×24, "청크 스트리밍은 없다".
- `sim/island_builder.gd:12-13, 136-151` — 고정 반지름 29 섬, 고정 스폰 (32,32).
- `sim/threat_field.gd:76-77`, `:94` — `VoxelGrid.SIZE_X/Y/Z`에 스폰 의존.
- `sim/save_slot.gd:81-93` — 명령 재생 전용 저장. 언로드 청크 상태 저장·복원(P7 2항) 구조 없음.

**P10 (밤 몹 규칙)**
- `sim/threat.gd:87-97` — 플레이어 위치로 직진. 소리(`emits_sound`) 반응 없음.
- `sim/threat.gd:132` — 튼튼한 문 특별 예외. "몹이 X 블록을 특별히 노린다/피한다" 예외 금지 위반. 내구도(`breakable`) 없이 `BREAK_TICKS` 후 즉시 파괴(`:136`).

**P11 (목표 없음)**
- `view/first_steps.gd:1-20` — 첫 동사를 순서대로 알려주는 단계형 안내. 튜토리얼 부정 주석은 있으나 "단계(`_step`)"가 있으므로 애매 → 위반으로 기록. `view/help_overlay.gd`는 키 목록만이라 허용 범위.

**P12 (코드 생성 픽셀아트)**
- `assets/kenney_audio/*`, `assets/kenney_nature_kit/*`, `assets/README.md:1-3` — 외부 다운로드 에셋.
- `tools/pixelart/` 부재.

**sim→view 의존 방향**
- `sim/` 안에서 `view/`·`Node`·`get_tree`·`preload`·`signal` 참조 **없음**. 43개 파일 전부 `extends RefCounted`(또는 `SimCommand`/`CircuitPart` 상속). `sim/save_slot.gd:24-55`의 `FileAccess/DirAccess/ProjectSettings/JSON`은 엔진 싱글턴이지 노드 트리가 아니라 헤드리스에서 돈다 — 허용.
- 역방향(view→sim 읽기)은 정상. `view/`가 `BlockType` 229회, `VoxelGrid` 28회 등 sim 클래스를 참조.

## 재활용 목록
**M0 골격에 그대로 (파일 위치 유지, 수정 없음)**
1. `sim/sim_rng.gd` + `test/unit/test_sim_rng.gd` — 시드 RNG 싱글턴. `get_state/set_state`로 해시·청크 저장에 이미 대응. (`builder.md`가 `sim/rng.gd`라 부르므로 이름을 하나로 정해 DECISIONS에 기록.)
2. `sim/tick_driver.gd` + `test/unit/test_tick_driver.gd` — 고정 20tps 틱 루프. 정수 µs, 밀림 상한, 이월 검증 테스트 포함.
3. `sim/sim_hash.gd` + `test/unit/test_sim_hash.gd` — 골든 해시 토대.
4. `sim/sim_command.gd`, `sim/sim_command_queue.gd` + `test/unit/test_sim_command_queue.gd` — 명령 객체 패턴·완전 정렬 큐.
5. `sim/commands/set_value_command.gd`, `add_value_command.gd`, `roll_value_command.gd` — 결정론 시나리오용 최소 명령.
6. `tools/test.sh`, `tools/test.cmd`, `docs/TESTING.md` — 헤드리스 실행 명령.

**M0 골격에 다듬어서**
7. `sim/simulation.gd` — `step()`을 "명령 적용 → tick++"로 축소, `_log` 명령 기록 유지. `TICK_RATE/TICK_INTERVAL_USEC` 상수 유지.
8. `sim/world_state.gd` — `tick/rng/_values/sorted_keys/compute_hash/to_hash_fields`만 남김.
9. `sim/sim_command_codec.gd` — 등록 3종으로 축소.
10. `test/determinism/test_determinism_regression.gd` — 시나리오 그대로, `TOTAL_TICKS` 2000, 골든 해시 재고정. `test_hash_is_independent_of_stringname_intern_order`, `test_serialized_command_stream_replays_identically`, `test_same_tick_command_order_changes_hash`는 특히 가치 있음.
11. `view/main.gd:61-79` 패턴 — `_physics_process`에서 `Time.get_ticks_usec()` 차를 `TickDriver.pump`에 넣는 방식. 새 빈 `view/main.gd`에 이 10줄만 옮긴다.
12. `test/integration/test_main_scene.gd:59-63` — "`_process`가 없고 `_physics_process`만 있다" 검사. 새 메인 씬 테스트에 옮긴다.

**이후 마일스톤에서 `legacy/`에서 꺼낼 것**
- M1: `character_state.gd` 서브유닛 정수 이동·`_floor_div`; `movement_rules.gd` 8방향 고정 순서; `voxel_grid.gd`의 `PackedByteArray + digest() + dirty/changes` 패턴(청크 1개 내부용); `save_slot.gd`의 "시드+명령 로그" 형식(청크 스냅샷과 결합); `sim_view_coords.gd`, `isometric_camera.gd`, `screen_directions.gd`(아이소 좌표·8방향 화면 매핑, 헌법 무관).
- M2: `day_cycle.gd`(틱만으로 낮밤), `vitals.gd`(체력+포만도, P9 그대로), `threat_field.gd`의 id 순 순회·시드 RNG 스폰 띠.
- M3: `circuit.gd`의 compute/commit/act 3상 분리와 `cell_before` 고정 정렬, `repeater_part.gd`의 `_armed` 엣지 트리거·잔여 틱 해시 필드.
- M7: `view/palette.gd` 파스텔 경계 상수 + `test_palette.gd` 톤 검사; `tools/screenshot_check.gd` + `test_screenshot_check.gd`(순수 함수, 그대로); `tools/screenshot_runner.gd`의 "캐릭터 켜고 끈 차분" 판정 아이디어; `view/ui_theme.gd`.

## legacy/ 이동 방법
1. **디렉터리 구성**: `legacy/sim/`, `legacy/view/`, `legacy/test/`, `legacy/tools/`, `legacy/assets/`, `legacy/docs/`(spec.md, tech-tree.md), `legacy/SUMMARY.md`. `git mv`로 옮겨 이력을 잇는다. `.uid` 사이드카 파일은 반드시 `.gd`와 함께 옮긴다(따로 두면 uid 캐시가 어긋난다).
2. **빌드에서 제외**: `legacy/.gdignore`(빈 파일) 하나를 둔다. Godot 4 공식 문서 기준으로 `.gdignore`가 있는 폴더와 그 하위는 에디터 파일시스템 스캔·임포트에서 제외된다 — 이 부분은 확신함. 그 결과 (a) 그 안의 `class_name`은 전역 클래스 캐시(`.godot/global_script_class_cache.cfg`)에 등록되지 않으므로 새 `sim/sim_rng.gd`와 `legacy/sim/sim_rng.gd`가 같은 `class_name SimRng`를 가져도 충돌하지 않는다 — **이 부분은 강한 추측(공식 문서가 class_name 충돌을 직접 언급하지는 않음)**. (b) 헤드리스 `godot --headless --path . --quit`과 GdUnit CLI도 같은 스캔을 쓰므로 legacy 스크립트를 파싱하지 않을 것 — 추측.
3. **확인 절차(추측을 사실로 바꾸는 방법)**: 이동 후 `.godot/`를 지우고(`.gitignore`에 있으므로 안전) `godot --headless --path . --quit`을 돌려 "Class X hides a global script class" 류 오류가 0건인지 본다. 오류가 나면 `.gdignore`가 class_name 충돌을 막지 못하는 것이므로, 그때는 legacy 안 `.gd`를 `.gd.txt`로 이름을 바꾸거나 legacy를 저장소 밖 브랜치(`legacy/v0.2` 태그)로 빼는 대안을 쓴다.
4. **주의**: `.gdignore` 아래 파일은 `load("res://legacy/...")`로도 열리지 않을 가능성이 크다(추측). 재활용은 "복사해서 꺼내기"이지 "참조"가 아니어야 한다. 또한 `.gdignore` 폴더는 익스포트에서도 빠진다고 알고 있음(추측, M7에서 확인).
5. **`project.godot`**: `run/main_scene`을 새 `res://view/main.tscn`(빈 Node3D + `_physics_process` 틱 펌프)으로 바꾼다. 안 바꾸면 헤드리스 실행이 씬을 못 찾아 실패한다.
6. **GdUnit4**: `tools/test.sh`가 `-a test`만 훑으므로 `legacy/test/`는 자동으로 빠진다. `reports/`는 미추적 그대로.
7. **고아 파일**: `tools/_probe_capture.gd.uid` 삭제. `.claude/agents/builder.md:12-13`의 `data/blocks.json`, `sim/rng.gd` 경로는 M1/M0에서 실제 파일명과 맞춘다.
8. **문서**: `docs/spec.md`를 옮기면 옛 CLAUDE.md 규칙("부품 목록 변경은 spec.md에서만")을 아직 참조하는 곳이 없는지 grep — 새 헌법은 `PRIMITIVES.md`로 대체하므로 남는 참조는 legacy 안뿐이어야 한다.

## 판정
판정: 조건부 승인
위반:
- P1 — `sim/circuit/box_part.gd`, `branch_part.gd`, `signal_value.gd`: 값·변수·조건문을 부품으로 둠; `docs/tech-tree.md`: 장치 17종 카탈로그.
- P2 — `sim/` 13개 파일 41곳(`block_type.gd:165-216`, `actuator_part.gd:59-101`, `circuit_part_factory.gd:26-34`, `detector_part.gd:55-74`, `tool_rules.gd:41-73` 등)의 타입 상수 분기.
- P5 — `sim/simulation.gd:104` 사망 시 인벤토리 절반 손실(애매 → 위반 처리).
- P6 — `sim/circuit/actuator_part.gd:48-72`, `recipe_book.gd:176-186`: 굽기가 회로 전용.
- P7 — `sim/voxel_grid.gd:12-19`, `island_builder.gd:12-13`, `threat_field.gd:76-94`, `save_slot.gd:81-93`: 고정 섬, 청크 없음, 시드 무관 지형.
- P10 — `sim/threat.gd:87-136`: 소리 반응 없음, `is_strong_door` 특별 예외, 내구도 없음.
- P11 — `view/first_steps.gd`: 단계형 안내(애매 → 위반 처리).
- P12 — `assets/kenney_*`: 외부 에셋; `tools/pixelart/` 부재.
- P3 — 없음. sim→view 역방향 의존 — 없음.
수정안:
1. `legacy/`로 옮기되 **다음 6개는 자리에 남긴다**: `sim/sim_rng.gd`, `sim/tick_driver.gd`, `sim/sim_hash.gd`, `sim/sim_command.gd`, `sim/sim_command_queue.gd`, `sim/commands/{set_value,add_value,roll_value}_command.gd` 및 짝 테스트 `test/unit/test_{sim_rng,tick_driver,sim_hash,sim_command_queue,sanity}.gd`.
2. **다음 4개는 남기되 잘라 낸다**: `sim/simulation.gd`(step = 명령 적용 + tick++), `sim/world_state.gd`(tick/rng/_values/해시만), `sim/sim_command_codec.gd`(3종), `test/determinism/test_determinism_regression.gd`(TOTAL_TICKS 2000, 골든 해시 재고정 + 이력 주석). 잘라 낸 원본은 `legacy/sim/`에도 복사해 둔다.
3. `legacy/.gdignore`를 두고 `.godot/` 삭제 후 `godot --headless --path . --quit`으로 전역 클래스 충돌 0건을 확인한다. 충돌이 나면 위 "legacy/ 이동 방법 3"의 대안으로 간다. 이 확인 결과를 DECISIONS.md에 적는다.
4. `project.godot`의 `run/main_scene`을 새 빈 `view/main.tscn`으로 바꾸고, `view/main.gd`는 `_physics_process` + `TickDriver` 펌프 10줄만 둔다. `_process`가 없음을 검사하는 테스트를 함께 둔다.
5. `tools/_probe_capture.gd.uid` 삭제.
6. `docs/SIM_ORDER.md`에 축소된 `Simulation.step()` 순서(1. 큐에서 이번 틱 명령을 접수 순으로 적용 2. tick += 1)를 적는다. `docs/STATE.md` 갱신.
7. `docs/spec.md`·`tech-tree.md`·`SUMMARY.md`·`assets/`는 `legacy/`로. `README.md` 한 줄 설명("circuits keep your island alive")은 "섬" 전제라 헌법 한 줄 정의로 바꾼다.
8. M0 완료 조건은 "빈 세계 2000틱 결정론 통과"이므로 위 1~6이 끝나면 `tester`가 `tools/test.sh`로 확인한다. `builder.md:12-13`의 `data/blocks.json`·`sim/rng.gd` 경로 불일치는 M1 시작 전에 파일명 결정과 함께 DECISIONS.md에 적는다.
