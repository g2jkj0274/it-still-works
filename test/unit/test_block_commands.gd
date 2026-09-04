extends GdUnitTestSuite

## 블록 배치·파괴 명령 검증. 격자 변경은 오직 이 명령들을 통해서만 일어난다.


func _state() -> WorldState:
    var state := WorldState.new(SimRng.new(1))
    for y in 8:
        for x in 8:
            state.grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
    state.character.place_at(Vector3i(4, 4, 1))
    state.character.facing = Vector3i(1, 0, 0)
    return state


func test_place_fills_an_empty_cell() -> void:
    var state := _stocked()
    PlaceBlockCommand.create(Vector3i(5, 4, 1), BlockType.WOOD).apply(state)
    assert_int(state.grid.get_block(Vector3i(5, 4, 1))).is_equal(BlockType.WOOD)


func test_place_refuses_an_occupied_cell() -> void:
    var state := _state()
    PlaceBlockCommand.create(Vector3i(5, 4, 0), BlockType.WOOD).apply(state)
    assert_int(state.grid.get_block(Vector3i(5, 4, 0))).is_equal(BlockType.GROUND)


func test_place_refuses_cells_the_character_stands_in() -> void:
    var state := _state()
    for cell in state.character.occupied_cells():
        PlaceBlockCommand.create(cell, BlockType.WOOD).apply(state)
        assert_bool(state.grid.is_solid(cell)).is_false()


func test_place_refuses_a_floating_cell() -> void:
    # 아무것에도 붙지 않은 칸에는 놓을 수 없다.
    var state := _state()
    PlaceBlockCommand.create(Vector3i(4, 4, 6), BlockType.WOOD).apply(state)
    assert_bool(state.grid.is_solid(Vector3i(4, 4, 6))).is_false()


func test_place_refuses_empty_and_invalid_types() -> void:
    var state := _state()
    for type in [BlockType.EMPTY, BlockType.COUNT, -1]:
        PlaceBlockCommand.create(Vector3i(5, 4, 1), type).apply(state)
        assert_bool(state.grid.is_solid(Vector3i(5, 4, 1))).is_false()


func test_place_refuses_out_of_bounds() -> void:
    var state := _state()
    var before := state.grid.digest()
    PlaceBlockCommand.create(Vector3i(-1, 4, 1), BlockType.WOOD).apply(state)
    assert_str(state.grid.digest()).is_equal(before)


func test_break_clears_a_solid_cell() -> void:
    var state := _state()
    state.grid.set_block(Vector3i(5, 4, 1), BlockType.ORE)
    BreakBlockCommand.create(Vector3i(5, 4, 1)).apply(state)
    assert_int(state.grid.get_block(Vector3i(5, 4, 1))).is_equal(BlockType.EMPTY)


func test_break_on_empty_cell_changes_nothing() -> void:
    var state := _state()
    var before := state.grid.digest()
    BreakBlockCommand.create(Vector3i(5, 4, 3)).apply(state)
    assert_str(state.grid.digest()).is_equal(before)


func test_break_refuses_bedrock() -> void:
    # 섬의 바닥층은 부술 수 없다. 부술 수 있으면 딛을 곳 없는 칸에 갇힌다.
    var state := _state()
    BreakBlockCommand.create(Vector3i(5, 4, VoxelGrid.BEDROCK_Z)).apply(state)
    assert_int(state.grid.get_block(Vector3i(5, 4, VoxelGrid.BEDROCK_Z))).is_equal(BlockType.GROUND)


func test_break_refuses_out_of_bounds() -> void:
    var state := _state()
    var before := state.grid.digest()
    BreakBlockCommand.create(Vector3i(99, 4, 1)).apply(state)
    assert_str(state.grid.digest()).is_equal(before)


func test_block_commands_do_not_consume_randomness() -> void:
    var state := _state()
    var before := state.rng.get_state()
    PlaceBlockCommand.create(Vector3i(5, 4, 1), BlockType.WOOD).apply(state)
    BreakBlockCommand.create(Vector3i(5, 4, 1)).apply(state)
    assert_int(state.rng.get_state()).is_equal(before)


func test_place_and_break_round_trip() -> void:
    var place := PlaceBlockCommand.create(Vector3i(5, 4, 1), BlockType.ORE)
    var restored_place := SimCommandCodec.from_dict(
        JSON.parse_string(JSON.stringify(place.to_dict()))) as PlaceBlockCommand
    assert_object(restored_place).is_not_null()
    assert_bool(restored_place.position == Vector3i(5, 4, 1)).is_true()
    assert_int(restored_place.block_type).is_equal(BlockType.ORE)

    var brk := BreakBlockCommand.create(Vector3i(2, 3, 1))
    var restored_break := SimCommandCodec.from_dict(
        JSON.parse_string(JSON.stringify(brk.to_dict()))) as BreakBlockCommand
    assert_object(restored_break).is_not_null()
    assert_bool(restored_break.position == Vector3i(2, 3, 1)).is_true()


func test_breaking_the_floor_makes_the_character_settle_next_tick() -> void:
    var sim := Simulation.new(1)
    for y in 8:
        for x in 8:
            sim.state.grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
            sim.state.grid.set_block(Vector3i(x, y, 1), BlockType.GROUND)
    sim.state.character.place_at(Vector3i(4, 4, 2))
    sim.submit(BreakBlockCommand.create(Vector3i(4, 4, 1)))
    sim.advance(10)
    assert_bool(sim.state.character.cell() == Vector3i(4, 4, 1)).is_true()


func _stocked() -> WorldState:
    var state := _state()
    state.inventory.add(BlockType.WOOD, 4)
    state.inventory.add(BlockType.ORE, 4)
    return state


func test_placing_spends_a_material() -> void:
    var state := _stocked()
    PlaceBlockCommand.create(Vector3i(5, 4, 1), BlockType.WOOD).apply(state)
    assert_int(state.inventory.count_of(BlockType.WOOD)).is_equal(3)


func test_placing_without_the_material_does_nothing() -> void:
    var state := _state()
    assert_int(state.inventory.count_of(BlockType.WOOD)).is_equal(0)
    PlaceBlockCommand.create(Vector3i(5, 4, 1), BlockType.WOOD).apply(state)
    assert_bool(state.grid.is_solid(Vector3i(5, 4, 1))).is_false()


func test_a_refused_placement_keeps_the_material() -> void:
    # 놓이지 않았는데 재료만 사라지면 손해다.
    var state := _stocked()
    PlaceBlockCommand.create(Vector3i(5, 4, 0), BlockType.WOOD).apply(state)
    assert_int(state.inventory.count_of(BlockType.WOOD)).is_equal(4)


func test_breaking_yields_the_material() -> void:
    var state := _state()
    state.grid.set_block(Vector3i(5, 4, 1), BlockType.ORE)
    BreakBlockCommand.create(Vector3i(5, 4, 1)).apply(state)
    assert_int(state.inventory.count_of(BlockType.ORE)).is_equal(1)


func test_a_refused_break_yields_nothing() -> void:
    var state := _state()
    BreakBlockCommand.create(Vector3i(5, 4, VoxelGrid.BEDROCK_Z)).apply(state)
    assert_int(state.inventory.total()).is_equal(0)


func test_break_then_place_returns_the_same_material() -> void:
    var state := _state()
    state.grid.set_block(Vector3i(5, 4, 1), BlockType.WOOD)
    BreakBlockCommand.create(Vector3i(5, 4, 1)).apply(state)
    PlaceBlockCommand.create(Vector3i(5, 4, 1), BlockType.WOOD).apply(state)
    assert_int(state.grid.get_block(Vector3i(5, 4, 1))).is_equal(BlockType.WOOD)
    assert_int(state.inventory.count_of(BlockType.WOOD)).is_equal(0)
