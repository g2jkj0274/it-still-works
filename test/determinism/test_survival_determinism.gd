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
##   섬에 저절로 난 작물이 놓여 격자가 바뀜 (첫날 밤에 손으로 닿게 하려고)
##   광석 자원지가 가운데 솟은 더미가 되어 격자가 바뀜 (멀리서 보이게)
##   세계의 세로가 16 → 24 로 늘고, 지표가 기복을 타며 그 아래가 돌·광맥·동굴이 됨
##   위협이 나오는 거리에 위 한계가 생겨 자리 고르기가 바뀜 (다가오는 것이 보이게)
const GOLDEN_HASH := "0d5e96735fdf1946643e31703fe465ae021a9cc740ee9f3a910cbadffb3e153e"


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
