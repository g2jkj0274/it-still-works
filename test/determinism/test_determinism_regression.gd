extends GdUnitTestSuite

## 결정론 회귀 테스트.
##
## 같은 시드 + 같은 명령 시퀀스 → N틱 실행 → 같은 월드 상태 해시.
## 이 테스트가 깨지면 결정론이 깨진 것이고 lockstep 멀티플레이 가능성이 사라진다.
## 다른 어떤 작업보다 먼저 고친다.

const SEED := 20250901
const TOTAL_TICKS := 2000

## 위 시나리오를 SEED 로 TOTAL_TICKS 만큼 돌렸을 때의 상태 해시.
## Godot 4.7.2 / 서로 다른 프로세스 2회 실행에서 동일함을 확인하고 고정했다.
##
## 갱신 이력:
##   2b530828... 최초 고정
##   c022a3f9... 월드 상태에 복셀 격자와 캐릭터가 추가되어 해시 대상이 늘어남
##   53fd7af9... 캐릭터 위치가 서브유닛이 되고 이동 목표가 상태에 추가됨
##   a94b6b4f... 손에 든 재료가 상태에 추가됨
##   9a40d096... 블록 종류에 문·감지기·작동기가 늘고 회로가 상태에 추가됨
##   되풀이 부품이 늘어 블록 종류와 회로 상태가 바뀜
##   상자 부품이 늘어 블록 종류와 회로 상태가 바뀜
##   갈림길 부품이 늘고 감지기가 조건을 만족할 때만 신호를 내도록 바뀜
##   생존 지표와 위협이 상태에 추가됨
##   밭과 작물이 상태에 추가됨
##   블록 종류에 돌이 늘고 세계의 세로가 16 → 24 가 됨
##   등 블록이 늘어 블록 종류가 둘 늘어남
##   인벤토리가 칸으로 나뉘고 칸마다 쌓이는 한계가 생겨 상태의 짜임이 바뀜
##   궤짝이 늘어 블록 종류가 하나 늘고 그 안에 든 것이 상태에 추가됨
##   묶음을 걷어내 블록 종류가 하나 줄고, 설계도 목록이 상태에서 빠짐
##   재료를 격자에 놓아 만들게 되어 제작 격자가 상태에 추가됨
##   163d462b... M0 legacy 이동으로 격자·캐릭터·회로 등이 상태에서 빠져 해시 대상이 틱·난수원·값만 남고, 틱 수가 20 → 2000 이 됨
##   08c670c2... 청크 월드·로드 중심이 상태에 추가되고 로드 중심 명령이 시나리오에 들어감. 골든이 25 청크 digest 를 포함하므로 data/blocks.json·data/terrain.json 편집 시 골든 갱신. 스냅샷 해시 경로는 블록 변경 명령이 생기는 M1-7 골든이 덮는다
##   6f882498... M1-6a-2: 플레이어 상태 4필드(sub·target·layer·facing) 추가·로드 중심 필드 제거·이동 명령이 시나리오에 들어감. 로드 중심은 플레이어 발 칸에서 유도되고 첫 틱에 스폰 청크 (0,0) 이 로드된다
const GOLDEN_HASH := "6f882498083ec79be4f9bea4ea5fe358cf09ccfb0f6684ea1ed9b0b656b9624e"

## 실행마다 새로 만든다. 명령 객체는 큐가 틱과 순서를 새겨 넣으므로 재사용하지 않는다.
##
## 이동 명령: 첫 걸음은 틱 1 이후(틱 0 은 미로드라 거부된다 — SIM_ORDER 1-M1b). 이 시드의 스폰
## (8,8) 은 북쪽·동쪽이 solid 지대라 (9,8) 로의 첫 걸음(틱 1)은 벽에 거부되고 facing 만 돈다.
## 틱 5,9,…,61 에 (0,1) 15개(칸당 4틱)로 (8,23) — 틱 36 에 청크 (0,1) 로 경계를 넘는다. 틱 65,…,93 에
## (1,0) 8개로 (16,23) — 틱 96 에 청크 (1,1). 틱 100 에 (0,-1) 로 (16,22), 틱 101·102 는 걷는 중이라
## 무시되고 facing 만 (1,1) 로 돈다. 지형(data/terrain.json·blocks.json)이 바뀌면 이 경로도 바뀐다 —
## 골든 갱신 때 아래 `test_scenario_walks_the_player_out_of_the_spawn_chunk` 가 경로를 다시 확인한다.
func _scenario() -> Array:
    var scenario: Array = [
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
    scenario.append([1, MovePlayerCommand.create(1, 0)])
    for i in 15:
        scenario.append([5 + 4 * i, MovePlayerCommand.create(0, 1)])
    for i in 8:
        scenario.append([65 + 4 * i, MovePlayerCommand.create(1, 0)])
    scenario.append([100, MovePlayerCommand.create(0, -1)])
    scenario.append([101, MovePlayerCommand.create(0, -1)])
    scenario.append([102, MovePlayerCommand.create(1, 1)])
    return scenario


func _submit_all(sim: Simulation, scenario: Array) -> void:
    for entry: Array in scenario:
        sim.submit_at(entry[1] as SimCommand, int(entry[0]))


func _replay(seed_value: int = SEED, scenario: Array = []) -> String:
    var sim := Simulation.create_default(seed_value)
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
    var sim := Simulation.create_default(SEED)
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
    var coarse := Simulation.create_default(SEED)
    _submit_all(coarse, _scenario())
    coarse.advance(TOTAL_TICKS)

    var fine := Simulation.create_default(SEED)
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


func test_scenario_walks_the_player_out_of_the_spawn_chunk() -> void:
    # 골든이 청크 경계 넘기(로드·언로드·발 칸 동기화)를 덮는지 확인한다. 걸음 수·방향을 바꿔
    # 스폰 청크 안에 머물게 되면 이 테스트가 먼저 운다.
    var sim := Simulation.create_default(SEED)
    _submit_all(sim, _scenario())
    sim.advance(TOTAL_TICKS)
    assert_bool(sim.state.player.cell() == Vector2i(16, 22)).override_failure_message(
        "플레이어 %s" % sim.state.player.cell()).is_true()
    assert_bool(sim.state.chunks.center() == Vector2i(1, 1)).override_failure_message(
        "중심 %s" % sim.state.chunks.center()).is_true()
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)
    assert_bool(sim.state.chunks.is_loaded(-2, -2)).is_false()
    assert_bool(sim.state.player.is_moving()).is_false()
    assert_bool(sim.state.player.facing == Vector2i(1, 1)).is_true()


func test_golden_hash_is_unchanged() -> void:
    # 위의 동등성 테스트는 한 프로세스 안에서만 비교한다. 이 골든 값은 그
    # 프로세스 바깥, 커밋과 커밋 사이의 변화를 잡는다.
    #
    # 이 값이 깨졌다면 시뮬레이션 동작이 바뀐 것이다. 값을 고쳐 통과시키지 말고
    # 무엇이 바뀌었는지 먼저 밝힌다. 시나리오, 틱 수, 해시에 들어가는 상태의
    # 구성을 의도적으로 바꾼 경우에만 새 값으로 갱신하고 위에 이력을 남긴다.
    assert_str(_replay()).is_equal(GOLDEN_HASH)
