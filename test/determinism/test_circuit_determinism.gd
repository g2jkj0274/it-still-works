extends GdUnitTestSuite

## 회로 결정론 회귀 테스트.
##
## 자동문을 명령으로 짓고 플레이어가 오갔을 때의 상태 해시를 못박는다.
## 신호 전파 순서가 흔들리면 이 값이 먼저 깨진다.

const SEED := 20250901
const TOTAL_TICKS := 90

## 무대의 바닥 높이. 아래 [method _level] 이 이 높이로 땅을 고른다.
const FLOOR_Z := 8

const DOOR := Vector3i(32, 30, FLOOR_Z + 1)
const ACTUATOR := Vector3i(33, 30, FLOOR_Z + 1)
const DETECTOR := Vector3i(34, 30, FLOOR_Z + 1)
const REPEATER := Vector3i(34, 29, FLOOR_Z + 1)
const LAMP_ACTUATOR := Vector3i(33, 29, FLOOR_Z + 1)
const LAMP_DOOR := Vector3i(32, 29, FLOOR_Z + 1)
const BOX := Vector3i(34, 31, FLOOR_Z + 1)
const BRANCH := Vector3i(33, 31, FLOOR_Z + 1)

## 아래 시나리오를 SEED 로 TOTAL_TICKS 만큼 돌렸을 때의 상태 해시.
## Godot 4.7.2 / 서로 다른 프로세스 3회 실행에서 동일함을 확인하고 고정했다.
##
## 갱신 이력: 묶음 부품이 늘어 블록 종류가 하나 늘고, 묶음 설계도 목록이 상태에 추가됨
##   제작법이 생겨 시작 지급을 껐다. 빈손으로 시작하므로 인벤토리 초기값이 바뀜
##   섬에 저절로 난 작물이 놓여 격자가 바뀜 (첫날 밤에 손으로 닿게 하려고)
##   광석 자원지가 가운데 솟은 더미가 되어 격자가 바뀜 (멀리서 보이게)
##   세계의 세로가 16 → 24 로 늘고, 지표가 기복을 타며 그 아래가 돌·광맥·동굴이 됨
##   등 블록이 늘어 블록 종류가 둘 늘어남 (스펙 §5 의 자동 조명)
##   인벤토리가 칸으로 나뉘고 칸마다 쌓이는 한계가 생겨 상태의 짜임이 바뀜
##   굤짝이 늘어 블록 종류가 하나 늘고 그 안에 든 것이 상태에 추가됨
##   광맥이 드러난 동굴 벽에 더 잘 들어 격자가 바뀜 (땅속에 들어갈 까닭)
const GOLDEN_HASH := "9d07e3b485961de4620f804c9d1b9e15db8f351b6b090387841d5e5fe4494902"

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
    _level(sim.state.grid, Vector2i(33, 30), 5, FLOOR_Z)
    sim.state.character.place_at(Vector3i(33, 33, FLOOR_Z + 1))
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
    _level(fine.state.grid, Vector2i(33, 30), 5, FLOOR_Z)
    fine.state.character.place_at(Vector3i(33, 33, FLOOR_Z + 1))
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


## 지을 자리를 고르게 다진다.
##
## 지표가 기복을 타므로 이웃 칸의 높이가 저마다 다르다. 시나리오가 특정 칸에
## 부품을 놓아야 하는데 그 자리가 허공이거나 땅속이면 아무것도 놓이지 않는다.
## 지형을 시험하는 시나리오가 아니므로 무대만 평평하게 만들어 둔다.
static func _level(grid: VoxelGrid, centre: Vector2i, reach: int, floor_z: int) -> void:
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            var column := centre + Vector2i(dx, dy)
            for z in range(VoxelGrid.BEDROCK_Z + 1, VoxelGrid.SIZE_Z):
                var kind := BlockType.GROUND if z <= floor_z else BlockType.EMPTY
                grid.set_block(Vector3i(column.x, column.y, z), kind)
