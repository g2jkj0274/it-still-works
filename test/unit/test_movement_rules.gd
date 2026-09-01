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


func test_eight_walking_directions_are_horizontal() -> void:
    assert_int(MovementRules.DIRECTIONS.size()).is_equal(8)
    var seen: Array = []
    for dir: Vector3i in MovementRules.DIRECTIONS:
        assert_int(dir.z).is_equal(0)
        assert_int(absi(dir.x)).is_less_equal(1)
        assert_int(absi(dir.y)).is_less_equal(1)
        assert_bool(dir == Vector3i.ZERO).is_false()
        assert_bool(seen.has(dir)).is_false()
        assert_bool(MovementRules.is_direction(dir)).is_true()
        seen.append(dir)


func test_diagonals_are_told_apart_from_straight_steps() -> void:
    assert_bool(MovementRules.is_diagonal(Vector3i(1, 1, 0))).is_true()
    assert_bool(MovementRules.is_diagonal(Vector3i(1, 0, 0))).is_false()


func test_vertical_and_oversized_steps_are_not_directions() -> void:
    for dir in [Vector3i(0, 0, 1), Vector3i.ZERO, Vector3i(2, 0, 0), Vector3i(1, 1, 1)]:
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
        assert_bool(MovementRules.resolve_walk(grid, start, dir) == start + dir).is_true()


func test_non_direction_does_not_move() -> void:
    var grid := _flat()
    var start := Vector3i(4, 4, 1)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(2, 0, 0)) == start).is_true()


func test_a_diagonal_step_crosses_both_axes() -> void:
    var grid := _flat()
    var start := Vector3i(4, 4, 1)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(1, 1, 0)) == Vector3i(5, 5, 1)).is_true()


func test_a_diagonal_needs_both_sides_open() -> void:
    # 한쪽이 막혀 있으면 모서리를 뚫고 지나가는 꼴이 된다.
    var grid := _flat()
    var start := Vector3i(4, 4, 1)
    grid.set_block(Vector3i(5, 4, 1), BlockType.STONE)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(1, 1, 0)) == start).is_true()


func test_a_diagonal_is_refused_when_the_other_side_is_blocked() -> void:
    var grid := _flat()
    var start := Vector3i(4, 4, 1)
    grid.set_block(Vector3i(4, 5, 1), BlockType.STONE)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(1, 1, 0)) == start).is_true()


func test_a_diagonal_is_refused_when_the_corner_itself_is_blocked() -> void:
    var grid := _flat()
    var start := Vector3i(4, 4, 1)
    grid.set_block(Vector3i(5, 5, 1), BlockType.STONE)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(1, 1, 0)) == start).is_true()


func test_diagonals_do_not_climb_ledges() -> void:
    # 대각선으로는 턱을 오르지 않는다. 같은 높이로만 건넌다.
    var grid := _with_ledge(1)
    var start := Vector3i(4, 4, 1)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(-1, 1, 0)) == start).is_true()


func test_a_diagonal_into_the_void_is_refused() -> void:
    var grid := _flat()
    var corner := Vector3i(PLATFORM - 1, PLATFORM - 1, 1)
    assert_bool(MovementRules.resolve_walk(grid, corner, Vector3i(1, 1, 0)) == corner).is_true()


func test_two_tall_wall_blocks_the_step() -> void:
    var grid := _with_ledge(2)
    var start := Vector3i(4, 4, 1)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(-1, 0, 0)) == start).is_true()


func test_one_tall_ledge_is_climbed() -> void:
    var grid := _with_ledge(1)
    var start := Vector3i(4, 4, 1)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(-1, 0, 0)) == Vector3i(3, 4, 2)).is_true()


func test_climbing_needs_headroom() -> void:
    var grid := _with_ledge(1)
    grid.set_block(Vector3i(4, 4, 3), BlockType.GROUND)
    var start := Vector3i(4, 4, 1)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(-1, 0, 0)) == start).is_true()


func test_stepping_off_a_ledge_walks_out_over_the_drop() -> void:
    # 걸음은 같은 높이로 나간다. 떨어지는 것은 시뮬레이션이 뒤이어 처리한다.
    var grid := _with_ledge(1)
    var start := Vector3i(3, 4, 2)
    assert_bool(MovementRules.resolve_walk(grid, start, Vector3i(1, 0, 0)) == Vector3i(4, 4, 2)).is_true()
    assert_bool(MovementRules.settle(grid, Vector3i(4, 4, 2)) == Vector3i(4, 4, 1)).is_true()


func test_walking_into_the_void_is_refused() -> void:
    # 딛을 곳이 없는 칸으로는 나가지 않는다. 섬 밖으로 걸어 나가는 것을 막는다.
    var grid := _flat()
    var edge := Vector3i(PLATFORM - 1, 4, 1)
    assert_bool(MovementRules.resolve_walk(grid, edge, Vector3i(1, 0, 0)) == edge).is_true()


func test_walking_out_of_the_grid_is_refused() -> void:
    var grid := _flat()
    var corner := Vector3i(0, 0, 1)
    assert_bool(MovementRules.resolve_walk(grid, corner, Vector3i(-1, 0, 0)) == corner).is_true()
