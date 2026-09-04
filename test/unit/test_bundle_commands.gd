extends GdUnitTestSuite

## 묶고 놓고 부수는 길 전체를 명령으로만 확인한다.
##
## 입력이 월드를 직접 고치지 않는다. 묶는 것도 명령이다.

const BASE := Vector3i(6, 6, 1)
const EYE := Vector3i(6, 6, 2)
const HAND := Vector3i(7, 6, 2)
const DOOR := Vector3i(8, 6, 2)
const SPOT := Vector3i(6, 8, 2)


func _cells(values: Array) -> Array[Vector3i]:
    var cells: Array[Vector3i] = []
    for value: Vector3i in values:
        cells.append(value)
    return cells


## 감지기 → 작동기 → 문. 자동문 하나가 놓인 월드.
func _world_with_a_door_circuit() -> Simulation:
    var sim := Simulation.new(4242)
    var state := sim.state

    for cell in [BASE, BASE + Vector3i(1, 0, 0), BASE + Vector3i(2, 0, 0), Vector3i(6, 7, 1), Vector3i(6, 8, 1)]:
        state.grid.set_block(cell, BlockType.GROUND)
    state.grid.set_block(DOOR, BlockType.DOOR_CLOSED)

    state.inventory.add(BlockType.DETECTOR, 1)
    state.inventory.add(BlockType.ACTUATOR, 1)

    sim.submit(PlacePartCommand.create(
        EYE, BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_PLAYER])))
    sim.submit(PlacePartCommand.create(HAND, BlockType.ACTUATOR))
    sim.step()
    sim.submit(ConnectPartsCommand.create(EYE, HAND))
    sim.step()
    return sim


func _bundle_the_door_circuit(sim: Simulation) -> void:
    sim.submit(BundlePartsCommand.create(_cells([EYE, HAND])))
    sim.step()


func test_bundling_takes_the_parts_out_of_the_world() -> void:
    var sim := _world_with_a_door_circuit()
    assert_int(sim.state.circuit.part_count()).is_equal(2)

    _bundle_the_door_circuit(sim)
    assert_int(sim.state.circuit.part_count()).is_equal(0)
    assert_int(sim.state.grid.get_block(EYE)).is_equal(BlockType.EMPTY)
    assert_int(sim.state.grid.get_block(HAND)).is_equal(BlockType.EMPTY)


func test_bundling_puts_one_bundle_in_the_hand() -> void:
    var sim := _world_with_a_door_circuit()
    _bundle_the_door_circuit(sim)

    assert_int(sim.state.bundles.count()).is_equal(1)
    assert_int(sim.state.inventory.count_of_bundle(0)).is_equal(1)


func test_bundling_does_not_hand_back_the_parts_it_swallowed() -> void:
    # 부순 것이 아니라 담은 것이다. 재료로 돌아오면 무한히 불릴 수 있다.
    var sim := _world_with_a_door_circuit()
    _bundle_the_door_circuit(sim)
    assert_int(sim.state.inventory.count_of(BlockType.DETECTOR)).is_equal(0)
    assert_int(sim.state.inventory.count_of(BlockType.ACTUATOR)).is_equal(0)


func test_a_bundle_cannot_be_placed_without_holding_one() -> void:
    var sim := _world_with_a_door_circuit()
    _bundle_the_door_circuit(sim)
    sim.state.inventory.take_bundle(0, 1)

    sim.submit(PlacePartCommand.create(SPOT, BlockType.BUNDLE, PackedInt32Array([0])))
    sim.step()
    assert_int(sim.state.circuit.part_count()).is_equal(0)


func test_a_placed_bundle_takes_one_cell_and_one_bundle() -> void:
    var sim := _world_with_a_door_circuit()
    _bundle_the_door_circuit(sim)

    sim.submit(PlacePartCommand.create(SPOT, BlockType.BUNDLE, PackedInt32Array([0])))
    sim.step()

    assert_int(sim.state.circuit.part_count()).is_equal(1)
    assert_int(sim.state.grid.get_block(SPOT)).is_equal(BlockType.BUNDLE)
    assert_int(sim.state.inventory.count_of_bundle(0)).is_equal(0)


func test_breaking_a_bundle_gives_the_same_bundle_back() -> void:
    var sim := _world_with_a_door_circuit()
    _bundle_the_door_circuit(sim)

    sim.submit(PlacePartCommand.create(SPOT, BlockType.BUNDLE, PackedInt32Array([0])))
    sim.step()
    sim.submit(BreakBlockCommand.create(SPOT))
    sim.step()

    assert_int(sim.state.inventory.count_of_bundle(0)).is_equal(1)


func test_a_bundled_auto_door_still_opens_the_door_beside_it() -> void:
    # 압축한 것을 다시 놓으면 그대로 돈다. 스펙 §6 의 마지막 검증 단계다.
    var sim := _world_with_a_door_circuit()
    _bundle_the_door_circuit(sim)

    # 문 옆에 놓는다. 안에 든 감지기와 작동기는 묶음이 놓인 칸에서 세상을 만난다.
    var beside := DOOR + Vector3i(0, 1, 0)
    sim.state.grid.set_block(beside - Vector3i(0, 0, 1), BlockType.GROUND)
    sim.state.character.place_at(beside + Vector3i(0, 1, 0))

    sim.submit(PlacePartCommand.create(beside, BlockType.BUNDLE, PackedInt32Array([0])))
    sim.step()

    for i in 4:
        sim.step()
    assert_int(sim.state.grid.get_block(DOOR)).is_equal(BlockType.DOOR_OPEN)


func test_two_bundles_of_the_same_kind_do_not_share_what_they_hold() -> void:
    var sim := Simulation.new(11)
    var state := sim.state
    var floor_cells := [Vector3i(3, 3, 1), Vector3i(4, 3, 1), Vector3i(5, 3, 1)]
    for cell in floor_cells:
        state.grid.set_block(cell, BlockType.GROUND)

    var box_cell := Vector3i(3, 3, 2)
    state.inventory.add(BlockType.BOX, 1)
    sim.submit(PlacePartCommand.create(
        box_cell, BlockType.BOX, PackedInt32Array([BoxPart.SHAPE_SQUARE])))
    sim.step()

    sim.submit(BundlePartsCommand.create(
        _cells([box_cell]), _cells([box_cell]), _cells([box_cell])))
    sim.step()
    state.inventory.add_bundle(0, 1)

    var left := Vector3i(4, 3, 2)
    var right := Vector3i(5, 3, 2)
    sim.submit(PlacePartCommand.create(left, BlockType.BUNDLE, PackedInt32Array([0])))
    sim.submit(PlacePartCommand.create(right, BlockType.BUNDLE, PackedInt32Array([0])))
    sim.step()

    var first := state.circuit.part_at(left)
    first.compute(state, [SignalValue.of_int(9)])
    first.commit()

    assert_int(first.output.as_int()).is_equal(9)
    assert_bool(state.circuit.part_at(right).output.is_present()).is_false()


func test_a_bundle_command_survives_being_written_and_read_back() -> void:
    var command := BundlePartsCommand.create(
        _cells([EYE, HAND]), _cells([EYE]), _cells([HAND]))
    var wire: Variant = JSON.parse_string(JSON.stringify(command.to_dict()))
    var restored := SimCommandCodec.from_dict(wire) as BundlePartsCommand

    assert_array(restored.cells).is_equal(command.cells)
    assert_array(restored.inputs).is_equal(command.inputs)
    assert_array(restored.outputs).is_equal(command.outputs)


func test_losing_half_the_inventory_takes_bundles_too() -> void:
    var inventory := Inventory.new()
    inventory.add_bundle(0, 5)
    inventory.drop_half()
    assert_int(inventory.count_of_bundle(0)).is_equal(2)


func test_bundles_of_different_makes_never_pile_together() -> void:
    # 묶음은 저마다 안이 다르다. 한 칸에 몰아 쌓으면 무엇이 몇 개인지 알 수 없다.
    var inventory := Inventory.new()
    inventory.add_bundle(0, 2)
    inventory.add_bundle(1, 3)
    assert_int(inventory.count_of_bundle(0)).is_equal(2)
    assert_int(inventory.count_of_bundle(1)).is_equal(3)
    assert_int(inventory.count_of(BlockType.BUNDLE)).is_equal(5)
