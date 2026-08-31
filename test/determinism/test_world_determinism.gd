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
##
## 이 값이 깨졌다면 시뮬레이션 동작이 바뀐 것이다. 값을 고쳐 통과시키지 말고
## 무엇이 바뀌었는지 먼저 밝힌다.
const GOLDEN_HASH := "a72acf41d2d7cf1ec5707fef66af1f6f9174f940b2aed25353a8a5c44610f068"

## 같은 실행이 끝났을 때 캐릭터가 서 있는 칸.
## 해시보다 읽기 쉬워서 이동 규칙이 어긋났을 때 원인을 빨리 좁혀준다.
const GOLDEN_POSITION := Vector3i(32, 31, 2)


## 실행마다 새로 만든다. 명령 객체는 큐가 틱과 순서를 새겨 넣으므로 재사용하지 않는다.
##
## 한 걸음이 여러 틱에 걸치므로 명령 간격을 걸음보다 넓게 둔다. 좁으면 걷는 중에
## 들어온 명령이 무시되어 시나리오가 실제로 아무 데도 가지 않는다.
func _scenario() -> Array:
    return [
        [0, MoveCharacterCommand.create(NORTH)],
        [6, MoveCharacterCommand.create(NORTH)],
        [12, PlaceBlockCommand.create(Vector3i(33, 30, 2), BlockType.WOOD)],
        [18, PlaceBlockCommand.create(Vector3i(31, 30, 2), BlockType.WOOD)],
        [24, MoveCharacterCommand.create(EAST)],
        [30, BreakBlockCommand.create(Vector3i(33, 30, 2))],
        [36, MoveCharacterCommand.create(SOUTH)],
        [42, MoveCharacterCommand.create(WEST)],
        [48, PlaceBlockCommand.create(Vector3i(32, 32, 2), BlockType.STONE)],
        [54, MoveCharacterCommand.create(SOUTH)],
        [60, PlaceBlockCommand.create(Vector3i(32, 33, 2), BlockType.WOOD)],
        [66, BreakBlockCommand.create(Vector3i(32, 32, 2))],
        [72, MoveCharacterCommand.create(EAST)],
        [78, RollValueCommand.create(&"night_roll", 0, 99)],
        [84, MoveCharacterCommand.create(NORTH)],
        [90, BreakBlockCommand.create(Vector3i(32, 33, 2))],
        [96, MoveCharacterCommand.create(WEST)],
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
    assert_bool(played.state.character.cell() == IslandBuilder.SPAWN).is_false()
    assert_str(played.state.grid.digest()).is_not_equal(untouched.state.grid.digest())


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
