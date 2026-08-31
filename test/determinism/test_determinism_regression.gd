extends GdUnitTestSuite

## 결정론 회귀 테스트.
##
## 같은 시드 + 같은 명령 시퀀스 → N틱 실행 → 같은 월드 상태 해시.
## 이 테스트가 깨지면 결정론이 깨진 것이고 lockstep 멀티플레이 가능성이 사라진다.
## 다른 어떤 작업보다 먼저 고친다.

const SEED := 20250901
const TOTAL_TICKS := 20

## 위 시나리오를 SEED 로 TOTAL_TICKS 만큼 돌렸을 때의 상태 해시.
## Godot 4.7.2 / 서로 다른 프로세스 3회 실행에서 동일함을 확인하고 고정했다.
##
## 갱신 이력:
##   2b530828... 최초 고정
##   c022a3f9... 월드 상태에 복셀 격자와 캐릭터가 추가되어 해시 대상이 늘어남
##   53fd7af9... 캐릭터 위치가 서브유닛이 되고 이동 목표가 상태에 추가됨
##   a94b6b4f... 손에 든 재료가 상태에 추가됨
##   9a40d096... 블록 종류에 문·감지기·작동기가 늘고 회로가 상태에 추가됨
##   되풀이 부품이 늘어 블록 종류와 회로 상태가 바뀜
const GOLDEN_HASH := "f6e2307d4f5d189ca6923e1b918285f8f878bc179222c5e56b920b9a66b25eb9"

## 실행마다 새로 만든다. 명령 객체는 큐가 틱과 순서를 새겨 넣으므로 재사용하지 않는다.
func _scenario() -> Array:
    return [
        [0, SetValueCommand.create(&"wood", 10)],
        [0, SetValueCommand.create(&"ore", 4)],
        [1, AddValueCommand.create(&"wood", -3)],
        [2, RollValueCommand.create(&"threat_step", 1, 6)],
        [3, AddValueCommand.create(&"ore", 7)],
        [3, RollValueCommand.create(&"threat_step", 1, 6)],
        [5, SetValueCommand.create(&"crop", 2)],
        [8, AddValueCommand.create(&"crop", 5)],
        [8, RollValueCommand.create(&"night_roll", 0, 99)],
        [13, AddValueCommand.create(&"wood", 21)],
    ]


func _submit_all(sim: Simulation, scenario: Array) -> void:
    for entry: Array in scenario:
        sim.submit_at(entry[1] as SimCommand, int(entry[0]))


func _replay(seed_value: int = SEED, scenario: Array = []) -> String:
    var sim := Simulation.new(seed_value)
    _submit_all(sim, scenario if not scenario.is_empty() else _scenario())
    sim.advance(TOTAL_TICKS)
    return sim.state_hash()


func test_same_seed_and_commands_produce_same_hash() -> void:
    assert_str(_replay()).is_equal(_replay())


func test_replay_is_stable_across_many_runs() -> void:
    var expected := _replay()
    for i in 5:
        assert_str(_replay()).is_equal(expected)


func test_different_seed_produces_different_hash() -> void:
    assert_str(_replay(SEED)).is_not_equal(_replay(SEED + 1))


func test_dropping_one_command_produces_different_hash() -> void:
    var shortened := _scenario()
    shortened.remove_at(shortened.size() - 1)
    assert_str(_replay(SEED, shortened)).is_not_equal(_replay())


func test_tick_count_changes_hash() -> void:
    var sim := Simulation.new(SEED)
    _submit_all(sim, _scenario())
    sim.advance(TOTAL_TICKS - 1)
    assert_str(sim.state_hash()).is_not_equal(_replay())


func test_same_tick_command_order_changes_hash() -> void:
    # 같은 틱에 같은 키를 건드리는 두 명령은 순서에 따라 결과가 달라져야 한다.
    var forward: Array = [
        [0, SetValueCommand.create(&"wood", 10)],
        [0, AddValueCommand.create(&"wood", -3)],
    ]
    var backward: Array = [
        [0, AddValueCommand.create(&"wood", -3)],
        [0, SetValueCommand.create(&"wood", 10)],
    ]
    assert_str(_replay(SEED, forward)).is_not_equal(_replay(SEED, backward))


func test_hash_is_independent_of_step_granularity() -> void:
    # 프레임률이 달라져도 같은 틱 수를 지나면 같은 상태여야 한다.
    var coarse := Simulation.new(SEED)
    _submit_all(coarse, _scenario())
    coarse.advance(TOTAL_TICKS)

    var fine := Simulation.new(SEED)
    _submit_all(fine, _scenario())
    for i in TOTAL_TICKS:
        fine.step()

    assert_str(fine.state_hash()).is_equal(coarse.state_hash())


func test_hash_is_independent_of_stringname_intern_order() -> void:
    # StringName 은 만들어진 순서대로 내부에 등록된다. 그 순서가 상태 해시에
    # 새어 들어오면 실행 환경에 따라 해시가 달라진다.
    var before := _replay()
    for i in 64:
        var _noise := StringName("intern_noise_%d" % i)
    assert_str(_replay()).is_equal(before)


func test_serialized_command_stream_replays_identically() -> void:
    # 명령은 직렬화되어 전송된 뒤에도 같은 결과를 내야 한다. lockstep 의 전제다.
    var wire: Array = []
    for entry: Array in _scenario():
        wire.append([entry[0], JSON.stringify((entry[1] as SimCommand).to_dict())])

    var restored: Array = []
    for entry: Array in wire:
        var data: Variant = JSON.parse_string(entry[1])
        restored.append([entry[0], SimCommandCodec.from_dict(data)])

    assert_str(_replay(SEED, restored)).is_equal(_replay())


func test_golden_hash_is_unchanged() -> void:
    # 위의 동등성 테스트는 한 프로세스 안에서만 비교한다. 이 골든 값은 그
    # 프로세스 바깥, 커밋과 커밋 사이의 변화를 잡는다.
    #
    # 이 값이 깨졌다면 시뮬레이션 동작이 바뀐 것이다. 값을 고쳐 통과시키지 말고
    # 무엇이 바뀌었는지 먼저 밝힌다. 시나리오, 틱 수, 해시에 들어가는 상태의
    # 구성을 의도적으로 바꾼 경우에만 새 값으로 갱신하고 위에 이력을 남긴다.
    assert_str(_replay()).is_equal(GOLDEN_HASH)
