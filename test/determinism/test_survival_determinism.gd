extends GdUnitTestSuite

## 생존 결정론 회귀 테스트.
##
## 밤이 오고 위협이 나와 돌아다니는 구간을 그대로 못박는다.
## 위협이 나타나는 자리는 시드 고정 난수로 고르므로, 난수를 쓰는 순서가
## 흔들리면 이 값이 먼저 깨진다.

const SEED := 20250901

## 낮의 끝에서 시작해 밤을 한동안 겪는다.
const START_TICK := DayCycle.DAY_TICKS - 40
const RUN_TICKS := 400

## Godot 4.7.2 / 서로 다른 프로세스 3회 실행에서 동일함을 확인하고 고정했다.
##
## 갱신 이력: 묶음 부품이 늘어 블록 종류가 하나 늘고, 묶음 설계도 목록이 상태에 추가됨
##   제작법이 생겨 시작 지급을 껐다. 빈손으로 시작하므로 인벤토리 초기값이 바뀜
const GOLDEN_HASH := "147a64235837a11da2313bf3855122d54c50512a296ad66b73d867f0ceba2f93"


func _scenario() -> Array:
    return [
        [START_TICK + 10, MoveCharacterCommand.create(Vector3i(0, -1, 0))],
        [START_TICK + 30, MoveCharacterCommand.create(Vector3i(1, 0, 0))],
        [START_TICK + 90, MoveCharacterCommand.create(Vector3i(0, 1, 0))],
        [START_TICK + 150, MoveCharacterCommand.create(Vector3i(-1, 0, 0))],
    ]


func _run(seed_value: int = SEED, scenario: Array = []) -> Simulation:
    var sim := Simulation.new(seed_value)
    IslandBuilder.populate(sim.state)
    sim.advance(START_TICK)

    for entry: Array in (scenario if not scenario.is_empty() else _scenario()):
        sim.submit_at(entry[1] as SimCommand, int(entry[0]))
    sim.advance(RUN_TICKS)
    return sim


func _replay(seed_value: int = SEED, scenario: Array = []) -> String:
    return _run(seed_value, scenario).state_hash()


func test_same_seed_and_commands_produce_same_hash() -> void:
    assert_str(_replay()).is_equal(_replay())


func test_different_seed_puts_threats_elsewhere() -> void:
    assert_str(_replay(SEED)).is_not_equal(_replay(SEED + 1))


func test_night_actually_falls_during_the_run() -> void:
    var played := _run()
    assert_bool(DayCycle.is_night(played.current_tick())).is_true()
    assert_int(played.state.threats.count()).is_greater(0)


func test_hash_is_independent_of_step_granularity() -> void:
    var coarse := _run()

    var fine := Simulation.new(SEED)
    IslandBuilder.populate(fine.state)
    for i in START_TICK:
        fine.step()
    for entry: Array in _scenario():
        fine.submit_at(entry[1] as SimCommand, int(entry[0]))
    for i in RUN_TICKS:
        fine.step()

    assert_str(fine.state_hash()).is_equal(coarse.state_hash())


func test_golden_hash_is_unchanged() -> void:
    assert_str(_replay()).is_equal(GOLDEN_HASH)
