extends GdUnitTestSuite

## 자동문 검증.
##
## 감지기(플레이어) → 작동기(문). 스펙 5절의 첫 번째 조합이다.
##
## 신호는 1틱에 한 부품씩 나아간다. 감지기가 본 것이 문에 닿기까지 두 틱이 걸린다.

const DOOR := Vector3i(8, 4, 1)
const ACTUATOR := Vector3i(8, 5, 1)
const DETECTOR := Vector3i(8, 6, 1)

const NEAR := Vector3i(8, 8, 1)
const FAR := Vector3i(8, 15, 1)


func _sim() -> Simulation:
    var sim := Simulation.new(1)
    for y in 16:
        for x in 16:
            sim.state.grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)

    sim.state.grid.set_block(DOOR, BlockType.DOOR_CLOSED)
    sim.state.grid.set_block(ACTUATOR, BlockType.ACTUATOR)
    sim.state.grid.set_block(DETECTOR, BlockType.DETECTOR)
    sim.state.circuit.add_part(ActuatorPart.create(ACTUATOR))
    sim.state.circuit.add_part(DetectorPart.create(DETECTOR, DetectorPart.TARGET_PLAYER))
    sim.state.circuit.link(DETECTOR, ACTUATOR)

    sim.state.character.place_at(FAR)
    return sim


func _door(sim: Simulation) -> int:
    return sim.state.grid.get_block(DOOR)


func test_door_stays_shut_while_nobody_is_near() -> void:
    var sim := _sim()
    sim.advance(10)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_CLOSED)
    assert_bool(sim.state.grid.is_solid(DOOR)).is_true()


func test_door_opens_when_the_player_comes_near() -> void:
    var sim := _sim()
    sim.state.character.place_at(NEAR)
    sim.advance(5)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_OPEN)
    assert_bool(sim.state.grid.is_solid(DOOR)).is_false()


func test_the_signal_takes_one_tick_per_part() -> void:
    var sim := _sim()
    sim.state.character.place_at(NEAR)

    # 첫 틱: 감지기가 본다. 아직 작동기까지 닿지 않았다.
    sim.step()
    assert_int(_door(sim)).is_equal(BlockType.DOOR_CLOSED)

    # 둘째 틱: 신호가 작동기에 닿아 문이 열린다.
    sim.step()
    assert_int(_door(sim)).is_equal(BlockType.DOOR_OPEN)


func test_door_shuts_again_when_the_player_leaves() -> void:
    var sim := _sim()
    sim.state.character.place_at(NEAR)
    sim.advance(5)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_OPEN)

    sim.state.character.place_at(FAR)
    sim.advance(5)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_CLOSED)


func test_an_unwired_actuator_does_nothing() -> void:
    var sim := _sim()
    sim.state.circuit.unlink(DETECTOR, ACTUATOR)
    sim.state.character.place_at(NEAR)
    sim.advance(10)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_CLOSED)


func test_the_door_never_shuts_on_the_player() -> void:
    # 몸이 블록에 갇히면 안 된다.
    var sim := _sim()
    sim.state.character.place_at(NEAR)
    sim.advance(5)
    sim.state.character.place_at(DOOR)
    sim.advance(10)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_OPEN)


func test_walking_through_an_open_door_is_possible() -> void:
    var sim := _sim()
    sim.state.character.place_at(NEAR)
    sim.advance(5)
    assert_bool(MovementRules.can_occupy(sim.state.grid, DOOR)).is_true()


func test_a_closed_door_blocks_the_way() -> void:
    var sim := _sim()
    sim.advance(5)
    assert_bool(MovementRules.can_occupy(sim.state.grid, DOOR)).is_false()


func test_breaking_the_detector_leaves_the_door_shut() -> void:
    var sim := _sim()
    sim.state.character.place_at(NEAR)
    sim.advance(5)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_OPEN)

    sim.submit(BreakBlockCommand.create(DETECTOR))
    sim.advance(5)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_CLOSED)
    assert_int(sim.state.circuit.part_count()).is_equal(1)
    assert_int(sim.state.circuit.link_count()).is_equal(0)


func test_the_whole_thing_can_be_built_by_commands() -> void:
    # 플레이어가 실제로 만들 수 있어야 한다. 손으로 심어 둔 것만 도는 게 아니다.
    var sim := Simulation.new(1)
    for y in 16:
        for x in 16:
            sim.state.grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
    sim.state.character.place_at(FAR)
    sim.state.inventory.add(BlockType.DOOR_CLOSED, 1)
    sim.state.inventory.add(BlockType.DETECTOR, 1)
    sim.state.inventory.add(BlockType.ACTUATOR, 1)

    sim.submit(PlaceBlockCommand.create(DOOR, BlockType.DOOR_CLOSED))
    sim.submit(PlacePartCommand.create(ACTUATOR, BlockType.ACTUATOR))
    sim.submit(PlacePartCommand.create(DETECTOR, BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_PLAYER])))
    sim.submit_at(ConnectPartsCommand.create(DETECTOR, ACTUATOR), 1)
    sim.advance(5)

    assert_int(sim.state.circuit.part_count()).is_equal(2)
    assert_int(sim.state.circuit.link_count()).is_equal(1)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_CLOSED)

    sim.state.character.place_at(NEAR)
    sim.advance(5)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_OPEN)
