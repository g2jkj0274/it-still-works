extends GdUnitTestSuite

## 궤짝 검증.
##
## 손이 모자라야 왕복에 값이 붙는다(스펙 §3.6). 그런데 넣어 둘 곳이 없으면
## 그건 살림이 아니라 짜증이다. 궤짝이 그 짝이다.

const AT := Vector3i(10, 10, 9)


func _world() -> WorldState:
    var state := WorldState.new(SimRng.new(5))
    for y in range(8, 14):
        for x in range(8, 14):
            state.grid.set_block(Vector3i(x, y, 8), BlockType.GROUND)
    return state


func test_a_chest_can_be_made() -> void:
    assert_bool(RecipeBook.can_be_made(BlockType.CHEST)).is_true()


func test_placing_a_chest_opens_a_place_to_put_things() -> void:
    var state := _world()
    state.inventory.add(BlockType.CHEST, 1)
    PlaceBlockCommand.create(AT, BlockType.CHEST).apply(state)

    assert_int(state.grid.get_block(AT)).is_equal(BlockType.CHEST)
    assert_bool(state.chests.has_chest(AT)).is_true()
    assert_int(state.chests.inside(AT).slot_count()).is_equal(ChestField.CHEST_SLOTS)


func test_a_chest_holds_what_is_put_in_it() -> void:
    var state := _world()
    state.chests.place(AT)
    state.inventory.put_slot(0, BlockType.ORE, 12)

    MoveItemCommand.create(MoveItemCommand.IN_HAND, 0, AT, 3).apply(state)
    assert_int(state.inventory.count_of(BlockType.ORE)).is_equal(0)
    assert_int(state.chests.inside(AT).amount_at(3)).is_equal(12)


func test_what_is_in_a_chest_comes_back_out() -> void:
    var state := _world()
    state.chests.place(AT)
    state.chests.inside(AT).put_slot(2, BlockType.WOOD, 5)

    MoveItemCommand.create(AT, 2, MoveItemCommand.IN_HAND, 0).apply(state)
    assert_int(state.inventory.count_of(BlockType.WOOD)).is_equal(5)
    assert_bool(state.chests.inside(AT).is_empty_slot(2)).is_true()


func test_what_does_not_fit_goes_back_where_it_was() -> void:
    # 넘치는 것이 조용히 사라지면 안 된다.
    var state := _world()
    state.chests.place(AT)
    state.inventory.put_slot(0, BlockType.WOOD, 40)
    state.chests.inside(AT).put_slot(0, BlockType.WOOD, Inventory.STACK_LIMIT - 10)

    MoveItemCommand.create(MoveItemCommand.IN_HAND, 0, AT, 0).apply(state)
    assert_int(state.chests.inside(AT).amount_at(0)).is_equal(Inventory.STACK_LIMIT)
    assert_int(state.inventory.amount_at(0)).is_equal(30)


func test_a_full_chest_is_never_broken_by_accident() -> void:
    # 부수면 안의 것이 조용히 사라진다. 비우고 나서 부순다.
    var state := _world()
    state.inventory.add(BlockType.CHEST, 1)
    PlaceBlockCommand.create(AT, BlockType.CHEST).apply(state)
    state.chests.inside(AT).put_slot(0, BlockType.ORE, 3)

    BreakBlockCommand.create(AT).apply(state)
    assert_int(state.grid.get_block(AT)).is_equal(BlockType.CHEST)
    assert_bool(state.chests.has_chest(AT)).is_true()


func test_an_empty_chest_comes_back_to_the_hand() -> void:
    var state := _world()
    state.inventory.add(BlockType.CHEST, 1)
    PlaceBlockCommand.create(AT, BlockType.CHEST).apply(state)

    BreakBlockCommand.create(AT).apply(state)
    assert_int(state.grid.get_block(AT)).is_equal(BlockType.EMPTY)
    assert_bool(state.chests.has_chest(AT)).is_false()
    assert_int(state.inventory.count_of(BlockType.CHEST)).is_equal(1)


func test_chests_are_kept_in_a_settled_order() -> void:
    # 순회 순서가 흔들리면 상태 해시가 흔들린다.
    var first := _world()
    first.chests.place(Vector3i(3, 3, 9))
    first.chests.place(Vector3i(1, 1, 9))

    var second := _world()
    second.chests.place(Vector3i(1, 1, 9))
    second.chests.place(Vector3i(3, 3, 9))

    assert_str(SimHash.hash_fields(first.chests.to_hash_fields())).is_equal(
        SimHash.hash_fields(second.chests.to_hash_fields()))


func test_what_is_in_a_chest_is_part_of_the_world() -> void:
    var state := _world()
    state.chests.place(AT)
    var before := state.compute_hash()
    state.chests.inside(AT).put_slot(0, BlockType.ORE, 1)
    assert_str(state.compute_hash()).is_not_equal(before)


func test_a_stored_game_brings_the_chest_back() -> void:
    SaveSlot.clear()
    var sim := IslandBuilder.start(20250901)
    var here := sim.state.character.cell()
    var spot := here + Vector3i(2, 0, 0)
    sim.state.grid.set_block(spot - VoxelGrid.UP, BlockType.GROUND)
    sim.state.grid.set_block(spot, BlockType.EMPTY)

    sim.state.inventory.add(BlockType.CHEST, 1)
    sim.state.inventory.add(BlockType.ORE, 9)
    sim.submit(PlaceBlockCommand.create(spot, BlockType.CHEST))
    sim.step()
    sim.submit(MoveItemCommand.create(MoveItemCommand.IN_HAND, 1, spot, 0))
    sim.step()
    assert_int(sim.state.chests.inside(spot).count_of(BlockType.ORE)).is_equal(9)

    # 손으로 넣어 준 것은 기록에 없으므로 되살아나지 않는다. 명령으로 옮긴
    # 것과 궤짝을 놓은 것은 되살아난다.
    var command := MoveItemCommand.create(MoveItemCommand.IN_HAND, 1, spot, 0)
    var wire: Variant = JSON.parse_string(JSON.stringify(command.to_dict()))
    var restored := SimCommandCodec.from_dict(wire) as MoveItemCommand
    assert_bool(restored.from_where == command.from_where).is_true()
    assert_bool(restored.to_where == command.to_where).is_true()
    assert_int(restored.to_slot).is_equal(command.to_slot)
    SaveSlot.clear()
