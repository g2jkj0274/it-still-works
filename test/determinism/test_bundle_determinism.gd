extends GdUnitTestSuite

## 묶음 결정론 회귀 테스트.
##
## 회로를 지어 묶고, 묶은 것을 놓고, 하나를 부수는 시나리오를 통째로 못박는다.
## 묶음은 저마다 안쪽 회로를 굴리므로 순회 순서가 흔들리면 곧바로 해시가 갈린다.
##
## 묶음 둘을 나란히 놓는 것은 일부러다. 안쪽 회로가 여럿일 때의 차례를
## 여기서 지킨다.

const SEED := 20250901
const TOTAL_TICKS := 80

const DOOR := Vector3i(32, 30, 2)
const ACTUATOR := Vector3i(33, 30, 2)
const DETECTOR := Vector3i(34, 30, 2)
const BOX := Vector3i(34, 31, 2)

## 묶은 것을 다시 놓을 두 자리. 부품이 빠져나가 비워진 칸을 그대로 쓴다.
const DOOR_BUNDLE := ACTUATOR
const BOX_BUNDLE := DETECTOR

## 아래 시나리오를 SEED 로 TOTAL_TICKS 만큼 돌렸을 때의 상태 해시.
## Godot 4.7.2 / 서로 다른 프로세스 3회 실행에서 동일함을 확인하고 고정했다.
##
## 이 값이 깨졌다면 시뮬레이션 동작이 바뀐 것이다. 값을 고쳐 통과시키지 말고
## 무엇이 바뀌었는지 먼저 밝힌다.
const GOLDEN_HASH := "6e71fe9be0dc13be034e3b3e9f608a20f57a9f8ef58dd7ce7547537d8eeb3e48"


func _cells(values: Array) -> Array[Vector3i]:
    var cells: Array[Vector3i] = []
    for value: Vector3i in values:
        cells.append(value)
    return cells


func _scenario() -> Array:
    return [
        [0, PlaceBlockCommand.create(DOOR, BlockType.DOOR_CLOSED)],
        [2, PlacePartCommand.create(ACTUATOR, BlockType.ACTUATOR)],
        [4, PlacePartCommand.create(DETECTOR, BlockType.DETECTOR,
            PackedInt32Array([DetectorPart.TARGET_PLAYER]))],
        [6, ConnectPartsCommand.create(DETECTOR, ACTUATOR)],
        [8, PlacePartCommand.create(BOX, BlockType.BOX,
            PackedInt32Array([BoxPart.SHAPE_SQUARE]))],
        [10, ConnectPartsCommand.create(DETECTOR, BOX)],

        # 자동문을 통째로 묶는다. 상자로 나가던 배선은 함께 가지 못한다.
        [20, BundlePartsCommand.create(_cells([DETECTOR, ACTUATOR]))],
        [24, PlacePartCommand.create(DOOR_BUNDLE, BlockType.BUNDLE, PackedInt32Array([0]))],

        # 남은 상자도 따로 묶어 값이 드나드는 자리를 준다.
        [30, BundlePartsCommand.create(_cells([BOX]), _cells([BOX]), _cells([BOX]))],
        [34, PlacePartCommand.create(BOX_BUNDLE, BlockType.BUNDLE, PackedInt32Array([1]))],

        [12, MoveCharacterCommand.create(Vector3i(0, -1, 0))],
        [18, MoveCharacterCommand.create(Vector3i(1, 0, 0))],
        [40, MoveCharacterCommand.create(Vector3i(0, 1, 0))],
        [50, MoveCharacterCommand.create(Vector3i(0, 1, 0))],
        [60, MoveCharacterCommand.create(Vector3i(-1, 0, 0))],

        # 부수면 묶음이 손으로 돌아온다. 안에 든 것은 재료로 흩어지지 않는다.
        [70, BreakBlockCommand.create(BOX_BUNDLE)],
    ]


func _stock(sim: Simulation) -> void:
    # 지을 재료를 손에 쥐여 준다. 모으는 과정은 다른 시나리오가 이미 확인한다.
    sim.state.inventory.add(BlockType.DOOR_CLOSED, 4)
    sim.state.inventory.add(BlockType.DETECTOR, 4)
    sim.state.inventory.add(BlockType.ACTUATOR, 4)
    sim.state.inventory.add(BlockType.BOX, 4)


func _run(seed_value: int = SEED, scenario: Array = []) -> Simulation:
    return _run_until(TOTAL_TICKS, seed_value, scenario)


func _run_until(ticks: int, seed_value: int = SEED, scenario: Array = []) -> Simulation:
    var sim := Simulation.new(seed_value)
    IslandBuilder.populate(sim.state)
    _stock(sim)

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


func test_the_scenario_actually_makes_and_places_bundles() -> void:
    # 아무 일도 일어나지 않는 시나리오라면 위 동등성 테스트가 아무것도 지키지 못한다.
    var played := _run()
    assert_int(played.state.bundles.count()).is_equal(2)
    assert_int(played.state.grid.get_block(DOOR_BUNDLE)).is_equal(BlockType.BUNDLE)
    # 하나는 부숴 손으로 돌아왔다.
    assert_int(played.state.grid.get_block(BOX_BUNDLE)).is_equal(BlockType.EMPTY)
    assert_int(played.state.inventory.count_of_bundle(1)).is_equal(1)


func test_the_bundled_auto_door_still_works() -> void:
    # 압축한 것을 다시 놓아도 그대로 돈다. 스펙 §6 의 마지막 검증 단계다.
    const WHILE_NEAR := 56
    assert_int(_run_until(WHILE_NEAR).state.grid.get_block(DOOR)).is_equal(BlockType.DOOR_OPEN)


func test_dropping_the_bundling_changes_the_result() -> void:
    var without: Array = []
    for entry: Array in _scenario():
        if entry[1] is BundlePartsCommand:
            continue
        without.append(entry)
    assert_str(_replay(SEED, without)).is_not_equal(_replay())


func test_hash_is_independent_of_step_granularity() -> void:
    var coarse := _run()

    var fine := Simulation.new(SEED)
    IslandBuilder.populate(fine.state)
    _stock(fine)
    for entry: Array in _scenario():
        fine.submit_at(entry[1] as SimCommand, int(entry[0]))
    for i in TOTAL_TICKS:
        fine.step()

    assert_str(fine.state_hash()).is_equal(coarse.state_hash())


func test_serialized_command_stream_replays_identically() -> void:
    # 묶는 명령도 전송되어야 한다. 설계도는 월드가 들고 있으므로 오가는 것은
    # 고른 칸과 드나드는 자리뿐이다.
    var restored: Array = []
    for entry: Array in _scenario():
        var text := JSON.stringify((entry[1] as SimCommand).to_dict())
        restored.append([entry[0], SimCommandCodec.from_dict(JSON.parse_string(text))])
    assert_str(_replay(SEED, restored)).is_equal(_replay())


func test_golden_hash_is_unchanged() -> void:
    assert_str(_replay()).is_equal(GOLDEN_HASH)
