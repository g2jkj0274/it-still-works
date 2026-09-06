extends GdUnitTestSuite

## 복셀 격자의 경계·저장·다이제스트 검증.


func test_grid_size_matches_spec() -> void:
    assert_int(VoxelGrid.SIZE_X).is_equal(64)
    assert_int(VoxelGrid.SIZE_Y).is_equal(64)
    assert_int(VoxelGrid.SIZE_Z).is_equal(24)
    assert_int(VoxelGrid.CELL_COUNT).is_equal(64 * 64 * 24)


func test_new_grid_is_empty() -> void:
    var grid := VoxelGrid.new()
    assert_int(grid.get_block(Vector3i(0, 0, 0))).is_equal(BlockType.EMPTY)
    assert_int(grid.get_block(Vector3i(63, 63, 15))).is_equal(BlockType.EMPTY)
    assert_bool(grid.is_solid(Vector3i(10, 10, 0))).is_false()


func test_set_and_get_block() -> void:
    var grid := VoxelGrid.new()
    assert_bool(grid.set_block(Vector3i(1, 2, 3), BlockType.ORE)).is_true()
    assert_int(grid.get_block(Vector3i(1, 2, 3))).is_equal(BlockType.ORE)
    assert_bool(grid.is_solid(Vector3i(1, 2, 3))).is_true()


func test_index_is_unique_per_cell() -> void:
    var seen: Dictionary = {}
    for pos in [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(63, 63, 15)]:
        var index := VoxelGrid.index_of(pos)
        assert_bool(seen.has(index)).is_false()
        seen[index] = true
        assert_int(index).is_between(0, VoxelGrid.CELL_COUNT - 1)


func test_out_of_bounds_is_not_inside() -> void:
    for pos in [Vector3i(-1, 0, 0), Vector3i(0, -1, 0), Vector3i(0, 0, -1), Vector3i(64, 0, 0), Vector3i(0, 64, 0), Vector3i(0, 0, VoxelGrid.SIZE_Z)]:
        assert_bool(VoxelGrid.is_inside(pos)).is_false()


func test_out_of_bounds_write_is_rejected() -> void:
    var grid := VoxelGrid.new()
    assert_bool(grid.set_block(Vector3i(64, 0, 0), BlockType.ORE)).is_false()
    assert_bool(grid.set_block(Vector3i(0, 0, -1), BlockType.ORE)).is_false()


func test_out_of_bounds_read_is_empty_and_not_free() -> void:
    var grid := VoxelGrid.new()
    assert_int(grid.get_block(Vector3i(-5, 0, 0))).is_equal(BlockType.EMPTY)
    assert_bool(grid.is_free(Vector3i(-5, 0, 0))).is_false()


func test_unknown_block_type_is_rejected() -> void:
    var grid := VoxelGrid.new()
    assert_bool(grid.set_block(Vector3i(0, 0, 0), 99)).is_false()
    assert_bool(grid.set_block(Vector3i(0, 0, 0), -1)).is_false()


func test_writing_same_value_is_not_a_change() -> void:
    var grid := VoxelGrid.new()
    grid.set_block(Vector3i(1, 1, 1), BlockType.WOOD)
    var version := grid.version()
    assert_bool(grid.set_block(Vector3i(1, 1, 1), BlockType.WOOD)).is_false()
    assert_int(grid.version()).is_equal(version)


func test_version_increases_on_change() -> void:
    var grid := VoxelGrid.new()
    var version := grid.version()
    grid.set_block(Vector3i(1, 1, 1), BlockType.WOOD)
    assert_int(grid.version()).is_greater(version)


func test_neighbouring_cells_do_not_alias() -> void:
    var grid := VoxelGrid.new()
    grid.set_block(Vector3i(5, 5, 5), BlockType.ORE)
    for offset in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
        assert_int(grid.get_block(Vector3i(5, 5, 5) + offset)).is_equal(BlockType.EMPTY)


func test_identical_grids_share_digest() -> void:
    var a := VoxelGrid.new()
    var b := VoxelGrid.new()
    a.set_block(Vector3i(3, 4, 5), BlockType.GROUND)
    b.set_block(Vector3i(3, 4, 5), BlockType.GROUND)
    assert_str(a.digest()).is_equal(b.digest())


func test_digest_reacts_to_any_cell() -> void:
    var grid := VoxelGrid.new()
    var before := grid.digest()
    grid.set_block(Vector3i(63, 63, 15), BlockType.GROUND)
    assert_str(grid.digest()).is_not_equal(before)


func test_surface_cell_is_exposed_and_buried_cell_is_not() -> void:
    var grid := VoxelGrid.new()
    var center := Vector3i(10, 10, 5)
    for offset in [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
        grid.set_block(center + offset, BlockType.ORE)
    assert_bool(grid.is_exposed(center)).is_false()
    assert_bool(grid.is_exposed(center + Vector3i(1, 0, 0))).is_true()


func test_empty_cell_is_never_exposed() -> void:
    assert_bool(VoxelGrid.new().is_exposed(Vector3i(10, 10, 5))).is_false()
