extends GdUnitTestSuite

## 밭과 작물 검증.
##
## 밭 블록을 놓으면 심기고, 시간이 지나면 자라고, 다 자라면 작동기가 거둔다.
## 거둔 작물을 먹으면 포만도가 찬다. 이 고리가 닫혀야 생존이 성립한다.

const FIELD := Vector3i(8, 8, 1)
const ACTUATOR := Vector3i(8, 7, 1)
const DETECTOR := Vector3i(8, 6, 1)


func _sim() -> Simulation:
    var sim := Simulation.new(1)
    for y in 16:
        for x in 16:
            sim.state.grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
    sim.state.character.place_at(Vector3i(2, 2, 1))
    return sim


func _with_field(sim: Simulation) -> void:
    sim.state.grid.set_block(FIELD, BlockType.FIELD)
    sim.state.crops.plant(FIELD)


func _grow(sim: Simulation) -> void:
    sim.advance(CropField.MATURE_TICKS + 2)


func test_a_new_field_is_bare() -> void:
    var sim := _sim()
    _with_field(sim)
    assert_bool(sim.state.crops.has_field(FIELD)).is_true()
    assert_bool(sim.state.crops.is_mature(FIELD)).is_false()


func test_crops_grow_with_time() -> void:
    var sim := _sim()
    _with_field(sim)
    sim.advance(100)
    assert_int(sim.state.crops.growth_of(FIELD)).is_greater(0)
    assert_bool(sim.state.crops.is_mature(FIELD)).is_false()


func test_crops_ripen_eventually() -> void:
    var sim := _sim()
    _with_field(sim)
    _grow(sim)
    assert_bool(sim.state.crops.is_mature(FIELD)).is_true()


func test_growth_stops_when_ripe() -> void:
    var sim := _sim()
    _with_field(sim)
    _grow(sim)
    sim.advance(500)
    assert_int(sim.state.crops.growth_of(FIELD)).is_equal(CropField.MATURE_TICKS)


func test_placing_a_field_block_plants_it() -> void:
    var sim := _sim()
    sim.state.inventory.add(BlockType.FIELD, 1)
    sim.submit(PlaceBlockCommand.create(FIELD, BlockType.FIELD))
    sim.advance(2)
    assert_bool(sim.state.crops.has_field(FIELD)).is_true()


func test_breaking_a_field_uproots_it() -> void:
    var sim := _sim()
    _with_field(sim)
    sim.submit(BreakBlockCommand.create(FIELD))
    sim.advance(2)
    assert_bool(sim.state.crops.has_field(FIELD)).is_false()


func test_an_actuator_reaps_a_ripe_field() -> void:
    var sim := _sim()
    _with_field(sim)
    sim.state.grid.set_block(ACTUATOR, BlockType.ACTUATOR)
    sim.state.circuit.add_part(ActuatorPart.create(ACTUATOR))
    sim.state.grid.set_block(DETECTOR, BlockType.DETECTOR)
    sim.state.circuit.add_part(DetectorPart.create(DETECTOR, DetectorPart.TARGET_CROP))
    sim.state.circuit.link(DETECTOR, ACTUATOR)

    _grow(sim)
    sim.advance(5)

    assert_int(sim.state.inventory.count_of(BlockType.CROP)).is_greater_equal(CropField.YIELD)
    assert_bool(sim.state.crops.is_mature(FIELD)).is_false()


func test_an_unripe_field_is_not_reaped() -> void:
    var sim := _sim()
    _with_field(sim)
    sim.state.grid.set_block(ACTUATOR, BlockType.ACTUATOR)
    var actuator := ActuatorPart.create(ACTUATOR)
    sim.state.circuit.add_part(actuator)
    sim.state.grid.set_block(DETECTOR, BlockType.DETECTOR)
    sim.state.circuit.add_part(DetectorPart.create(DETECTOR, DetectorPart.TARGET_PLAYER))
    sim.state.circuit.link(DETECTOR, ACTUATOR)
    sim.state.character.place_at(DETECTOR + Vector3i(1, 0, 0))

    sim.advance(10)
    assert_int(sim.state.inventory.count_of(BlockType.CROP)).is_equal(0)


func test_a_crop_detector_wakes_only_when_ripe() -> void:
    var sim := _sim()
    _with_field(sim)
    sim.state.grid.set_block(DETECTOR, BlockType.DETECTOR)
    sim.state.circuit.add_part(DetectorPart.create(DETECTOR, DetectorPart.TARGET_CROP))

    sim.advance(5)
    assert_bool(sim.state.circuit.part_at(DETECTOR).output.is_present()).is_false()

    _grow(sim)
    assert_bool(sim.state.circuit.part_at(DETECTOR).output.is_present()).is_true()


func test_eating_a_crop_fills_the_belly() -> void:
    var sim := _sim()
    sim.state.inventory.add(BlockType.CROP, 2)
    sim.state.vitals.fullness = 4

    sim.submit(EatCommand.create())
    sim.advance(2)

    assert_int(sim.state.vitals.fullness).is_equal(4 + EatCommand.FULLNESS_PER_CROP)
    assert_int(sim.state.inventory.count_of(BlockType.CROP)).is_equal(1)


func test_eating_nothing_changes_nothing() -> void:
    var sim := _sim()
    sim.state.vitals.fullness = 4
    sim.submit(EatCommand.create())
    sim.advance(2)
    assert_int(sim.state.vitals.fullness).is_equal(4)


func test_eating_never_overfills() -> void:
    var sim := _sim()
    sim.state.inventory.add(BlockType.CROP, 5)
    sim.advance(2)
    for i in 5:
        sim.submit(EatCommand.create())
        sim.advance(2)
    assert_int(sim.state.vitals.fullness).is_less_equal(Vitals.MAX_FULLNESS)


func test_the_survival_loop_closes() -> void:
    # 심고 → 자라고 → 거두고 → 먹는다. 이 고리가 닫혀야 생존이 성립한다.
    var sim := _sim()
    _with_field(sim)
    sim.state.grid.set_block(ACTUATOR, BlockType.ACTUATOR)
    sim.state.circuit.add_part(ActuatorPart.create(ACTUATOR))
    sim.state.grid.set_block(DETECTOR, BlockType.DETECTOR)
    sim.state.circuit.add_part(DetectorPart.create(DETECTOR, DetectorPart.TARGET_CROP))
    sim.state.circuit.link(DETECTOR, ACTUATOR)

    _grow(sim)
    sim.advance(5)
    sim.state.vitals.fullness = 2

    sim.submit(EatCommand.create())
    sim.advance(2)
    assert_int(sim.state.vitals.fullness).is_greater(2)


func test_fields_are_walked_in_a_fixed_order() -> void:
    var forward := CropField.new()
    var backward := CropField.new()
    var cells := [Vector3i(5, 1, 1), Vector3i(1, 5, 1), Vector3i(3, 3, 1)]
    for cell in cells:
        forward.plant(cell)
    for i in cells.size():
        backward.plant(cells[cells.size() - 1 - i])
    assert_str(SimHash.hash_fields(forward.to_hash_fields())).is_equal(
        SimHash.hash_fields(backward.to_hash_fields()))
