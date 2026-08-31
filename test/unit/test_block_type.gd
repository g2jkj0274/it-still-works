extends GdUnitTestSuite

## 블록 종류 정의 검증.


func test_empty_is_zero_so_a_fresh_grid_is_empty() -> void:
    assert_int(BlockType.EMPTY).is_equal(0)


func test_empty_is_not_solid() -> void:
    assert_bool(BlockType.is_solid(BlockType.EMPTY)).is_false()


func test_terrain_blocks_are_solid() -> void:
    for type in [BlockType.GROUND, BlockType.STONE, BlockType.WOOD]:
        assert_bool(BlockType.is_solid(type)).is_true()


func test_all_types_are_distinct_and_contiguous() -> void:
    var types := [BlockType.EMPTY, BlockType.GROUND, BlockType.STONE, BlockType.WOOD]
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
