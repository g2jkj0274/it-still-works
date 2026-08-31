extends GdUnitTestSuite

## 격자 단위 이동 판정 검증. 전부 정수 연산이며 상태를 바꾸지 않는다.

const PLATFORM := 8


## z=0 에 8x8 지면을 깐 격자. 캐릭터는 z=1 에 선다.
func _flat() -> VoxelGrid:
    var grid := VoxelGrid.new()
    for y in PLATFORM:
        for x in PLATFORM:
            grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
    return grid


## x <= 3 구간을 [param height] 칸만큼 더 쌓아 단을 만든다.
func _with_ledge(height: int) -> VoxelGrid:
    var grid := _flat()
    for y in PLATFORM:
        for x in 4:
            for z in range(1, height + 1):
                grid.set_block(Vector3i(x, y, z), BlockType.GROUND)
    return grid


func test_four_walking_directions_are_horizontal_units() -> void:
    assert_int(MovementRules.DIRECTIONS.size()).is_equal(4)
    for dir: Vector3i in MovementRules.DIRECTIONS:
        assert_int(dir.z).is_equal(0)
        assert_int(absi(dir.x) + absi(dir.y)).is_equal(1)
        assert_bool(MovementRules.is_direction(dir)).is_true()


func test_diagonal_and_vertical_are_not_directions() -> void:
    for dir in [Vector3i(1, 1, 0), Vector3i(0, 0, 1), Vector3i.ZERO, Vector3i(2, 0, 0)]:
        assert_bool(MovementRules.is_direction(dir)).is_false()


func test_body_needs_two_free_cells() -> void:
    var grid := _flat()
    assert_bool(MovementRules.can_occupy(grid, Vector3i(2, 2, 1))).is_true()
    grid.set_block(Vector3i(2, 2, 2), BlockType.GROUND)
    assert_bool(MovementRules.can_occupy(grid, Vector3i(2, 2, 1))).is_false()


func test_support_comes_from_the_cell_below() -> void:
    var grid := _flat()
    assert_bool(MovementRules.is_supported(grid, Vector3i(2, 2, 1))).is_true()
    assert_bool(MovementRules.is_supported(grid, Vector3i(2, 2, 5))).is_false()


func test_settle_drops_to_the_ground() -> void:
    var grid := _flat()
    assert_bool(MovementRules.settle(grid, Vector3i(2, 2, 9)) == Vector3i(2, 2, 1)).is_true()


func test_settle_never_falls_out_of_the_grid() -> void:
    var grid := VoxelGrid.new()
    assert_int(MovementRules.settle(grid, Vector3i(2, 2, 9)).z).is_equal(0)


func test_walking_moves_one_cell_in_each_direction() -> void:
    var grid := _flat()
    var start := Vector3i(4, 4, 1)
    for dir: Vector3i in MovementRules.DIRECTIONS:
        assert_bool(MovementRules.resolve_step(grid, start, dir) == start + dir).is_true()


func test_non_direction_does_not_move() -> void:
    var grid := _flat()
    var start := Vector3i(4, 4, 1)
    assert_bool(MovementRules.resolve_step(grid, start, Vector3i(1, 1, 0)) == start).is_true()


func test_two_tall_wall_blocks_the_step() -> void:
    var grid := _with_ledge(2)
    var start := Vector3i(4, 4, 1)
    assert_bool(MovementRules.resolve_step(grid, start, Vector3i(-1, 0, 0)) == start).is_true()


func test_one_tall_ledge_is_climbed() -> void:
    var grid := _with_ledge(1)
    var start := Vector3i(4, 4, 1)
    assert_bool(MovementRules.resolve_step(grid, start, Vector3i(-1, 0, 0)) == Vector3i(3, 4, 2)).is_true()


func test_climbing_needs_headroom() -> void:
    var grid := _with_ledge(1)
    grid.set_block(Vector3i(4, 4, 3), BlockType.GROUND)
    var start := Vector3i(4, 4, 1)
    assert_bool(MovementRules.resolve_step(grid, start, Vector3i(-1, 0, 0)) == start).is_true()


func test_stepping_off_a_ledge_drops_down() -> void:
    var grid := _with_ledge(1)
    var start := Vector3i(3, 4, 2)
    assert_bool(MovementRules.resolve_step(grid, start, Vector3i(1, 0, 0)) == Vector3i(4, 4, 1)).is_true()


func test_walking_into_the_void_is_refused() -> void:
    # 딛을 곳이 없는 칸으로는 나가지 않는다. 섬 밖으로 걸어 나가는 것을 막는다.
    var grid := _flat()
    var edge := Vector3i(PLATFORM - 1, 4, 1)
    assert_bool(MovementRules.resolve_step(grid, edge, Vector3i(1, 0, 0)) == edge).is_true()


func test_walking_out_of_the_grid_is_refused() -> void:
    var grid := _flat()
    var corner := Vector3i(0, 0, 1)
    assert_bool(MovementRules.resolve_step(grid, corner, Vector3i(-1, 0, 0)) == corner).is_true()
