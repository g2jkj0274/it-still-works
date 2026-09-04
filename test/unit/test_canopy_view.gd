extends GdUnitTestSuite

## 나뭇잎 검증.
##
## 시뮬레이션에는 잎이 없다. 줄기 위에 덧그리는 것이므로, **무엇을 나무로
## 볼 것인가**가 이 클래스의 전부다. 사람이 쌓은 담 위에 숲이 생기면 안 된다.

const BASE := Vector3i(20, 20, 1)


func _grid_with_trunk(height: int, at: Vector3i = BASE) -> VoxelGrid:
    var grid := VoxelGrid.new()
    for y in range(15, 26):
        for x in range(15, 26):
            grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
            grid.set_block(Vector3i(x, y, 1), BlockType.GROUND)
    for i in height:
        grid.set_block(at + VoxelGrid.UP * (i + 1), BlockType.WOOD)
    return grid


func _view(grid: VoxelGrid) -> CanopyView:
    var view: CanopyView = auto_free(CanopyView.new())
    add_child(view)
    view.bind(grid)
    view.rebuild()
    return view


func test_a_tree_gets_leaves() -> void:
    assert_int(_view(_grid_with_trunk(3)).crown_count()).is_equal(1)


func test_the_leaves_sit_on_top_of_the_trunk() -> void:
    var view := _view(_grid_with_trunk(3))
    assert_bool(view.crowns()[0] == BASE + VoxelGrid.UP * 3).is_true()


func test_a_stump_gets_nothing() -> void:
    # 한두 칸은 나무가 아니라 발판이다.
    assert_int(_view(_grid_with_trunk(1)).crown_count()).is_equal(0)
    assert_int(_view(_grid_with_trunk(2)).crown_count()).is_equal(0)


func test_a_wall_of_wood_does_not_grow_a_forest() -> void:
    # 사람이 나무로 담을 쌓았을 때 담 위에 숲이 생기면 안 된다.
    var grid := _grid_with_trunk(3)
    for i in 3:
        grid.set_block(BASE + Vector3i(1, 0, 0) + VoxelGrid.UP * (i + 1), BlockType.WOOD)
    assert_int(_view(grid).crown_count()).is_equal(0)


func test_wood_with_a_roof_over_it_is_not_a_tree() -> void:
    var grid := _grid_with_trunk(3)
    grid.set_block(BASE + VoxelGrid.UP * 4, BlockType.ORE)
    assert_int(_view(grid).crown_count()).is_equal(0)


func test_cutting_the_tree_down_takes_the_leaves_with_it() -> void:
    var grid := _grid_with_trunk(3)
    var view := _view(grid)
    assert_int(view.crown_count()).is_equal(1)

    grid.set_block(BASE + VoxelGrid.UP * 3, BlockType.EMPTY)
    view.sync()
    # 두 칸만 남으면 나무가 아니다.
    assert_int(view.crown_count()).is_equal(0)


func test_it_only_grows_again_when_the_world_changes() -> void:
    var view := _view(_grid_with_trunk(3))
    var builds := view.build_count()
    for i in 5:
        view.sync()
    assert_int(view.build_count()).is_equal(builds)


func test_the_view_never_writes_to_the_grid() -> void:
    var grid := _grid_with_trunk(3)
    var before := grid.digest()
    var view := _view(grid)
    for i in 3:
        view.sync()
    assert_str(grid.digest()).is_equal(before)


func test_the_island_starts_with_a_crown_on_every_tree() -> void:
    var state := WorldState.new(SimRng.new(1))
    IslandBuilder.populate(state)
    assert_int(_view(state.grid).crown_count()).is_equal(IslandBuilder.TREES.size())


func test_the_leaves_are_pastel_and_not_the_trunk_colour() -> void:
    var leaf := Palette.LEAF
    assert_float(leaf.v).is_greater_equal(Palette.MIN_VALUE)
    assert_float(leaf.s).is_less_equal(Palette.MAX_SATURATION)

    var wood := Palette.of_block(BlockType.WOOD)
    assert_float(Vector3(
        leaf.r - wood.r, leaf.g - wood.g, leaf.b - wood.b).length()).is_greater(0.12)
