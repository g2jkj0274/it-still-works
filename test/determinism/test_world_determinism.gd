extends GdUnitTestSuite

## 복셀 월드 결정론 회귀 테스트.
##
## 섬 배치 + 이동·배치·파괴 명령 시퀀스 → N틱 실행 → 같은 월드 상태 해시.
## 이 테스트가 깨지면 결정론이 깨진 것이고 lockstep 멀티플레이 가능성이 사라진다.

const SEED := 20250901
const TOTAL_TICKS := 110

const NORTH := Vector3i(0, -1, 0)
const SOUTH := Vector3i(0, 1, 0)
const EAST := Vector3i(1, 0, 0)
const WEST := Vector3i(-1, 0, 0)

## 아래 시나리오를 SEED 로 TOTAL_TICKS 만큼 돌렸을 때의 상태 해시.
## Godot 4.7.2 / 서로 다른 프로세스 3회 실행에서 동일함을 확인하고 고정했다.
##
## 갱신 이력:
##   742dc8ed... 최초 고정
##   a72acf41... 캐릭터 위치가 서브유닛이 되며 걸음이 여러 틱에 걸치게 됨.
##               명령 간격을 넓히고 총 틱 수를 40 → 110 으로 늘림
##   f4e53348... 재료가 있어야 놓을 수 있게 됨. 먼저 부수고 그 재료로 놓도록 시나리오 수정
##   aa0cfa15... 블록 종류에 문·감지기·작동기가 늘고 회로가 상태에 추가됨
##   되풀이 부품이 늘어 블록 종류와 회로 상태가 바뀜
##   상자 부품이 늘어 블록 종류와 회로 상태가 바뀜
##   갈림길 부품이 늘고 감지기가 조건을 만족할 때만 신호를 내도록 바뀜
##   생존 지표와 위협이 상태에 추가됨
##   밭과 작물이 상태에 추가됨
##   프로토타입 판정용 시작 지급이 켜져 인벤토리 초기값이 바뀜
##
## 이 값이 깨졌다면 시뮬레이션 동작이 바뀐 것이다. 값을 고쳐 통과시키지 말고
## 무엇이 바뀌었는지 먼저 밝힌다.
const GOLDEN_HASH := "5e58107819cdc59ecf8e5b5020a681e80dd2792ec1fa06df491ab28802d29b35"

## 같은 실행이 끝났을 때 캐릭터가 서 있는 칸.
## 해시보다 읽기 쉬워서 이동 규칙이 어긋났을 때 원인을 빨리 좁혀준다.
const GOLDEN_POSITION := Vector3i(32, 32, 2)


## 실행마다 새로 만든다. 명령 객체는 큐가 틱과 순서를 새겨 넣으므로 재사용하지 않는다.
##
## 한 걸음이 여러 틱에 걸치므로 명령 간격을 걸음보다 넓게 둔다. 좁으면 걷는 중에
## 들어온 명령이 무시되어 시나리오가 실제로 아무 데도 가지 않는다.
##
## 재료가 있어야 놓을 수 있으므로 먼저 부수고 그 재료로 놓는다. 빈손으로
## 시작하는 것이 이 게임의 시작이다.
func _scenario() -> Array:
    return [
        [0, BreakBlockCommand.create(Vector3i(32, 31, 1))],
        [6, BreakBlockCommand.create(Vector3i(33, 32, 1))],
        [12, BreakBlockCommand.create(Vector3i(31, 32, 1))],
        [18, PlaceBlockCommand.create(Vector3i(32, 31, 1), BlockType.GROUND)],
        [24, MoveCharacterCommand.create(NORTH)],
        [30, PlaceBlockCommand.create(Vector3i(32, 30, 2), BlockType.GROUND)],
        [36, MoveCharacterCommand.create(NORTH)],
        [42, BreakBlockCommand.create(Vector3i(32, 30, 2))],
        [48, PlaceBlockCommand.create(Vector3i(33, 30, 2), BlockType.GROUND)],
        [54, MoveCharacterCommand.create(EAST)],
        [60, RollValueCommand.create(&"night_roll", 0, 99)],
        [66, BreakBlockCommand.create(Vector3i(33, 30, 2))],
        [72, MoveCharacterCommand.create(SOUTH)],
        [78, MoveCharacterCommand.create(WEST)],
        [84, PlaceBlockCommand.create(Vector3i(32, 32, 2), BlockType.GROUND)],
        [90, MoveCharacterCommand.create(SOUTH)],
        [96, BreakBlockCommand.create(Vector3i(32, 32, 2))],
    ]


func _run(seed_value: int = SEED, scenario: Array = []) -> Simulation:
    var sim := Simulation.new(seed_value)
    IslandBuilder.populate(sim.state)
    for entry: Array in (scenario if not scenario.is_empty() else _scenario()):
        sim.submit_at(entry[1] as SimCommand, int(entry[0]))
    sim.advance(TOTAL_TICKS)
    return sim


func _replay(seed_value: int = SEED, scenario: Array = []) -> String:
    return _run(seed_value, scenario).state_hash()


func test_same_seed_and_commands_produce_same_hash() -> void:
    assert_str(_replay()).is_equal(_replay())


func test_replay_is_stable_across_many_runs() -> void:
    var expected := _replay()
    for i in 4:
        assert_str(_replay()).is_equal(expected)


func test_different_seed_produces_different_hash() -> void:
    assert_str(_replay(SEED)).is_not_equal(_replay(SEED + 1))


func test_scenario_actually_changes_the_world() -> void:
    # 아무 일도 일어나지 않는 시나리오라면 위 동등성 테스트가 아무것도 지키지 못한다.
    var played := _run()
    var untouched := Simulation.new(SEED)
    IslandBuilder.populate(untouched.state)

    assert_str(played.state.grid.digest()).is_not_equal(untouched.state.grid.digest())
    assert_int(played.state.inventory.total()).is_greater(0)

    # 시나리오는 걸어 나갔다가 돌아오므로 끝 위치는 시작과 같을 수 있다.
    # 도중에 실제로 움직였는지를 본다.
    var midway := Simulation.new(SEED)
    IslandBuilder.populate(midway.state)
    for entry: Array in _scenario():
        midway.submit_at(entry[1] as SimCommand, int(entry[0]))
    midway.advance(TOTAL_TICKS / 2)
    assert_bool(midway.state.character.cell() == IslandBuilder.SPAWN).is_false()


func test_dropping_one_command_produces_different_hash() -> void:
    var shortened := _scenario()
    shortened.remove_at(shortened.size() - 1)
    assert_str(_replay(SEED, shortened)).is_not_equal(_replay())


func test_hash_is_independent_of_step_granularity() -> void:
    var coarse := _run()

    var fine := Simulation.new(SEED)
    IslandBuilder.populate(fine.state)
    for entry: Array in _scenario():
        fine.submit_at(entry[1] as SimCommand, int(entry[0]))
    for i in TOTAL_TICKS:
        fine.step()

    assert_str(fine.state_hash()).is_equal(coarse.state_hash())


func test_serialized_command_stream_replays_identically() -> void:
    var restored: Array = []
    for entry: Array in _scenario():
        var text := JSON.stringify((entry[1] as SimCommand).to_dict())
        restored.append([entry[0], SimCommandCodec.from_dict(JSON.parse_string(text))])
    assert_str(_replay(SEED, restored)).is_equal(_replay())


func test_golden_hash_is_unchanged() -> void:
    assert_str(_replay()).is_equal(GOLDEN_HASH)


func test_golden_character_position_is_unchanged() -> void:
    assert_bool(_run().state.character.cell() == GOLDEN_POSITION).is_true()
