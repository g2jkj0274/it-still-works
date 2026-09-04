extends GdUnitTestSuite

## 회로 결정론 회귀 테스트.
##
## 자동문을 명령으로 짓고 플레이어가 오갔을 때의 상태 해시를 못박는다.
## 신호 전파 순서가 흔들리면 이 값이 먼저 깨진다.

const SEED := 20250901
const TOTAL_TICKS := 90

const DOOR := Vector3i(32, 30, 2)
const ACTUATOR := Vector3i(33, 30, 2)
const DETECTOR := Vector3i(34, 30, 2)
const REPEATER := Vector3i(34, 29, 2)
const LAMP_ACTUATOR := Vector3i(33, 29, 2)
const LAMP_DOOR := Vector3i(32, 29, 2)
const BOX := Vector3i(34, 31, 2)
const BRANCH := Vector3i(33, 31, 2)

## 아래 시나리오를 SEED 로 TOTAL_TICKS 만큼 돌렸을 때의 상태 해시.
## Godot 4.7.2 / 서로 다른 프로세스 3회 실행에서 동일함을 확인하고 고정했다.
##
## 갱신 이력: 묶음 부품이 늘어 블록 종류가 하나 늘고, 묶음 설계도 목록이 상태에 추가됨
##   제작법이 생겨 시작 지급을 껐다. 빈손으로 시작하므로 인벤토리 초기값이 바뀜
##   섬에 저절로 난 작물이 놓여 격자가 바뀜 (첫날 밤에 손으로 닿게 하려고)
const GOLDEN_HASH := "8aae801ec28fc4f47fae061f9e1dfeb4e5bbb8d95c6bab4319728a7ea734ab66"

## 같은 실행이 끝났을 때 문이 어떤 상태인지. 해시보다 읽기 쉽다.
const GOLDEN_DOOR := BlockType.DOOR_CLOSED


func _scenario() -> Array:
    return [
        [0, PlaceBlockCommand.create(DOOR, BlockType.DOOR_CLOSED)],
        [2, PlacePartCommand.create(ACTUATOR, BlockType.ACTUATOR)],
        [4, PlacePartCommand.create(DETECTOR, BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_PLAYER]))],
        [6, ConnectPartsCommand.create(DETECTOR, ACTUATOR)],
        [7, PlaceBlockCommand.create(LAMP_DOOR, BlockType.DOOR_CLOSED)],
        [8, PlacePartCommand.create(LAMP_ACTUATOR, BlockType.ACTUATOR)],
        [9, PlacePartCommand.create(REPEATER, BlockType.REPEATER,
            PackedInt32Array([RepeaterPart.MODE_COUNT, 3, 4]))],
        [10, ConnectPartsCommand.create(DETECTOR, REPEATER)],
        [11, ConnectPartsCommand.create(REPEATER, LAMP_ACTUATOR)],
        [13, PlacePartCommand.create(BOX, BlockType.BOX,
            PackedInt32Array([BoxPart.SHAPE_SQUARE]))],
        [15, ConnectPartsCommand.create(DETECTOR, BOX)],
        [17, PlacePartCommand.create(BRANCH, BlockType.BRANCH,
            PackedInt32Array([BranchPart.MODE_TRUTH, 0]))],
        [19, ConnectPartsCommand.create(BOX, BRANCH)],
        [21, ConnectPartsCommand.create(BRANCH, LAMP_ACTUATOR, BranchPart.PORT_TRUE)],
        [23, ConnectPartsCommand.create(BRANCH, ACTUATOR, BranchPart.PORT_FALSE)],
        [12, MoveCharacterCommand.create(Vector3i(0, -1, 0))],
        [18, MoveCharacterCommand.create(Vector3i(1, 0, 0))],
        [24, MoveCharacterCommand.create(Vector3i(1, 0, 0))],
        [36, MoveCharacterCommand.create(Vector3i(0, 1, 0))],
        [42, MoveCharacterCommand.create(Vector3i(0, 1, 0))],
        [48, MoveCharacterCommand.create(Vector3i(0, 1, 0))],
        [54, MoveCharacterCommand.create(Vector3i(0, 1, 0))],
        [66, DisconnectPartsCommand.create(DETECTOR, ACTUATOR)],
    ]


func _run(seed_value: int = SEED, scenario: Array = []) -> Simulation:
    return _run_until(TOTAL_TICKS, seed_value, scenario)


func _run_until(ticks: int, seed_value: int = SEED, scenario: Array = []) -> Simulation:
    var sim := Simulation.new(seed_value)
    IslandBuilder.populate(sim.state)
    # 지을 재료를 손에 쥐여 준다. 모으는 과정은 다른 시나리오가 이미 확인한다.
    sim.state.inventory.add(BlockType.DOOR_CLOSED, 4)
    sim.state.inventory.add(BlockType.DETECTOR, 4)
    sim.state.inventory.add(BlockType.ACTUATOR, 4)
    sim.state.inventory.add(BlockType.REPEATER, 4)
    sim.state.inventory.add(BlockType.BOX, 4)
    sim.state.inventory.add(BlockType.BRANCH, 4)

    for entry: Array in (scenario if not scenario.is_empty() else _scenario()):
        sim.submit_at(entry[1] as SimCommand, int(entry[0]))
    sim.advance(ticks)
    return sim


func _replay(seed_value: int = SEED, scenario: Array = []) -> String:
    return _run(seed_value, scenario).state_hash()


func test_same_seed_and_commands_produce_same_hash() -> void:
    assert_str(_replay()).is_equal(_replay())


func test_replay_is_stable_across_many_runs() -> void:
    var expected := _replay()
    for i in 4:
        assert_str(_replay()).is_equal(expected)


func test_the_circuit_is_actually_built() -> void:
    var played := _run()
    assert_int(played.state.circuit.part_count()).is_equal(6)
    assert_bool(BlockType.is_door(played.state.grid.get_block(DOOR))).is_true()


func test_dropping_the_wire_changes_the_result() -> void:
    # 시나리오는 끝에서 배선을 걷어내므로 마지막 상태는 어느 쪽이든 같아진다.
    # 배선이 일하고 있는 도중에 견줘야 차이가 드러난다.
    const WHILE_WORKING := 30

    var without_wire: Array = []
    for entry: Array in _scenario():
        if entry[1] is ConnectPartsCommand:
            continue
        without_wire.append(entry)

    var wired := _run_until(WHILE_WORKING)
    var unwired := _run_until(WHILE_WORKING, SEED, without_wire)

    assert_int(wired.state.grid.get_block(DOOR)).is_equal(BlockType.DOOR_OPEN)
    assert_int(unwired.state.grid.get_block(DOOR)).is_equal(BlockType.DOOR_CLOSED)
    assert_str(wired.state_hash()).is_not_equal(unwired.state_hash())


func test_hash_is_independent_of_step_granularity() -> void:
    var coarse := _run()

    var fine := Simulation.new(SEED)
    IslandBuilder.populate(fine.state)
    fine.state.inventory.add(BlockType.DOOR_CLOSED, 4)
    fine.state.inventory.add(BlockType.DETECTOR, 4)
    fine.state.inventory.add(BlockType.ACTUATOR, 4)
    fine.state.inventory.add(BlockType.REPEATER, 4)
    fine.state.inventory.add(BlockType.BOX, 4)
    fine.state.inventory.add(BlockType.BRANCH, 4)
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


func test_golden_door_state_is_unchanged() -> void:
    assert_int(_run().state.grid.get_block(DOOR)).is_equal(GOLDEN_DOOR)
