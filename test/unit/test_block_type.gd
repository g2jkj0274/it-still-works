extends GdUnitTestSuite

## 블록 종류 정의 검증.


func test_empty_is_zero_so_a_fresh_grid_is_empty() -> void:
    assert_int(BlockType.EMPTY).is_equal(0)


func test_empty_is_not_solid() -> void:
    assert_bool(BlockType.is_solid(BlockType.EMPTY)).is_false()


func test_terrain_blocks_are_solid() -> void:
    for type in [BlockType.GROUND, BlockType.STONE, BlockType.WOOD, BlockType.DOOR_CLOSED]:
        assert_bool(BlockType.is_solid(type)).is_true()


func test_all_types_are_distinct_and_contiguous() -> void:
    var types := [
        BlockType.EMPTY, BlockType.GROUND, BlockType.STONE, BlockType.WOOD,
        BlockType.DOOR_CLOSED, BlockType.DOOR_OPEN, BlockType.DETECTOR, BlockType.ACTUATOR,
        BlockType.REPEATER, BlockType.BOX, BlockType.BRANCH,
    ]
    assert_int(types.size()).is_equal(BlockType.COUNT)
    types.sort()
    for i in types.size():
        assert_int(types[i]).is_equal(i)


func test_validity_range() -> void:
    assert_bool(BlockType.is_valid(BlockType.EMPTY)).is_true()
    assert_bool(BlockType.is_valid(BlockType.COUNT - 1)).is_true()
    assert_bool(BlockType.is_valid(BlockType.COUNT)).is_false()
    assert_bool(BlockType.is_valid(-1)).is_false()


func test_every_type_has_a_name() -> void:
    for type in BlockType.COUNT:
        assert_str(BlockType.name_of(type)).is_not_empty()


func test_open_door_is_not_solid_but_is_still_there() -> void:
    assert_bool(BlockType.is_solid(BlockType.DOOR_OPEN)).is_false()
    assert_bool(BlockType.is_breakable(BlockType.DOOR_OPEN)).is_true()
    assert_bool(BlockType.is_door(BlockType.DOOR_OPEN)).is_true()


func test_closed_door_blocks_the_way() -> void:
    assert_bool(BlockType.is_solid(BlockType.DOOR_CLOSED)).is_true()
    assert_bool(BlockType.is_door(BlockType.DOOR_CLOSED)).is_true()


func test_empty_is_not_breakable() -> void:
    assert_bool(BlockType.is_breakable(BlockType.EMPTY)).is_false()


func test_breaking_an_open_door_yields_a_door() -> void:
    assert_int(BlockType.material_of(BlockType.DOOR_OPEN)).is_equal(BlockType.DOOR_CLOSED)
    assert_int(BlockType.material_of(BlockType.STONE)).is_equal(BlockType.STONE)


func test_parts_are_recognised() -> void:
    assert_bool(BlockType.is_part(BlockType.DETECTOR)).is_true()
    assert_bool(BlockType.is_part(BlockType.ACTUATOR)).is_true()
    assert_bool(BlockType.is_part(BlockType.REPEATER)).is_true()
    assert_bool(BlockType.is_part(BlockType.BOX)).is_true()
    assert_bool(BlockType.is_part(BlockType.BRANCH)).is_true()
    assert_bool(BlockType.is_part(BlockType.WOOD)).is_false()


func test_terrain_is_not_a_part() -> void:
    for type in [BlockType.GROUND, BlockType.STONE, BlockType.WOOD, BlockType.DOOR_CLOSED]:
        assert_bool(BlockType.is_part(type)).is_false()
