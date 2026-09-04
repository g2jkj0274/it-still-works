extends GdUnitTestSuite

## 격자 렌더링 검증. 표현 레이어는 시뮬레이션을 읽기만 한다.


func _grid() -> VoxelGrid:
    var grid := VoxelGrid.new()
    for y in 4:
        for x in 4:
            grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
    grid.set_block(Vector3i(1, 1, 1), BlockType.STONE)
    grid.set_block(Vector3i(2, 2, 1), BlockType.WOOD)
    return grid


func _view(grid: VoxelGrid) -> WorldView:
    var view: WorldView = auto_free(WorldView.new())
    add_child(view)
    view.bind(grid)
    view.rebuild()
    return view


func test_every_exposed_block_gets_an_instance() -> void:
    var grid := _grid()
    var view := _view(grid)
    assert_int(view.instance_count(BlockType.STONE)).is_equal(1)
    assert_int(view.instance_count(BlockType.WOOD)).is_equal(1)
    assert_int(view.instance_count(BlockType.GROUND)).is_equal(16)


func test_empty_blocks_are_never_drawn() -> void:
    var view := _view(VoxelGrid.new())
    assert_int(view.total_instance_count()).is_equal(0)


func test_buried_blocks_are_not_drawn() -> void:
    # 5x5x5 덩어리에서 속에 완전히 묻히는 칸은 안쪽 3x3x3 = 27칸이다.
    # 나머지 125 - 27 = 98칸만 그린다.
    var grid := VoxelGrid.new()
    for z in 5:
        for y in 5:
            for x in 5:
                grid.set_block(Vector3i(x, y, z), BlockType.STONE)
    var view := _view(grid)
    assert_int(view.instance_count(BlockType.STONE)).is_equal(98)

    # 한가운데를 파내면 그 칸에 닿은 여섯 칸이 새로 드러난다.
    # 남은 블록 124칸 중 묻힌 칸은 27 - 1 - 6 = 20칸이다.
    grid.set_block(Vector3i(2, 2, 2), BlockType.EMPTY)
    view.rebuild()
    assert_int(view.instance_count(BlockType.STONE)).is_equal(104)


func test_view_never_writes_to_the_grid() -> void:
    var grid := _grid()
    var before := grid.digest()
    var view := _view(grid)
    view.sync()
    view.rebuild()
    assert_str(grid.digest()).is_equal(before)


func test_sync_does_nothing_while_the_grid_stands_still() -> void:
    var grid := _grid()
    var view := _view(grid)
    var builds := view.build_count()
    var patches := view.patch_count()

    for i in 5:
        view.sync()
    assert_int(view.build_count()).is_equal(builds)
    assert_int(view.patch_count()).is_equal(patches)


func test_sync_takes_up_the_change_when_the_grid_moves() -> void:
    var grid := _grid()
    var view := _view(grid)
    view.rebuild()
    var before := view.total_instance_count()

    grid.set_block(Vector3i(3, 3, 1), BlockType.WOOD)
    view.sync()
    assert_bool(view.total_instance_count() != before or view.patch_count() > 0).is_true()


func test_each_block_type_has_its_own_colour() -> void:
    var colours: Array = []
    for type in [BlockType.GROUND, BlockType.STONE, BlockType.WOOD]:
        var colour := WorldView.colour_of(type)
        assert_bool(colours.has(colour)).is_false()
        colours.append(colour)


## --- 바뀐 칸만 고치기 ---
##
## 블록 하나를 놓을 때마다 격자 전체를 훑으면 육만 칸에 백 밀리초가 걸린다.
## 한 프레임이 십육 밀리초이니 놓을 때마다 화면이 멎는다.
##
## 빨라지는 대신 **틀릴 수 있게** 되었다. 그래서 여기서 지키는 것은 하나다 —
## 고쳐 그린 결과가 통째로 다시 그린 결과와 같은가.

func _patched_and_rebuilt_agree(grid: VoxelGrid, view: WorldView) -> void:
    view.sync()
    var patched: Array[int] = []
    for block_type in BlockType.COUNT:
        patched.append(view.instance_count(block_type))

    view.rebuild()
    for block_type in BlockType.COUNT:
        assert_int(view.instance_count(block_type)).override_failure_message(
            "%s: 고쳐 그린 것과 통째로 그린 것이 다르다" % BlockType.name_of(block_type)
        ).is_equal(patched[block_type])


func _small_world() -> VoxelGrid:
    var grid := VoxelGrid.new()
    for y in range(10, 20):
        for x in range(10, 20):
            grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
            grid.set_block(Vector3i(x, y, 1), BlockType.GROUND)
    return grid


func test_placing_one_block_does_not_redraw_everything() -> void:
    var grid := _small_world()
    var view := _view(grid)
    view.rebuild()
    var builds := view.build_count()

    grid.set_block(Vector3i(15, 15, 2), BlockType.WOOD)
    view.sync()

    assert_int(view.build_count()).is_equal(builds)
    assert_int(view.patch_count()).is_greater(0)


func test_patching_agrees_with_redrawing_after_placing() -> void:
    var grid := _small_world()
    var view := _view(grid)
    view.rebuild()

    grid.set_block(Vector3i(15, 15, 2), BlockType.WOOD)
    _patched_and_rebuilt_agree(grid, view)


func test_patching_agrees_with_redrawing_after_breaking() -> void:
    var grid := _small_world()
    var view := _view(grid)
    view.rebuild()

    # 속에 묻혀 있던 이웃이 드러난다. 지운 칸만 보면 놓친다.
    grid.set_block(Vector3i(15, 15, 1), BlockType.EMPTY)
    _patched_and_rebuilt_agree(grid, view)


func test_patching_agrees_after_many_changes() -> void:
    var grid := _small_world()
    var view := _view(grid)
    view.rebuild()

    for i in 12:
        grid.set_block(Vector3i(11 + i % 8, 12 + i % 5, 2), BlockType.STONE)
        view.sync()
    _patched_and_rebuilt_agree(grid, view)


func test_changing_a_block_type_in_place_moves_it_between_layers() -> void:
    var grid := _small_world()
    var view := _view(grid)
    view.rebuild()
    var before := view.instance_count(BlockType.GROUND)

    grid.set_block(Vector3i(15, 15, 1), BlockType.WOOD)
    view.sync()

    assert_int(view.instance_count(BlockType.GROUND)).is_equal(before - 1)
    assert_int(view.instance_count(BlockType.WOOD)).is_equal(1)
    _patched_and_rebuilt_agree(grid, view)


func test_a_whole_new_world_is_drawn_from_scratch() -> void:
    # 섬을 처음 세울 때처럼 한꺼번에 많이 바뀌면 하나씩 고치는 것이 더 비싸다.
    var grid := VoxelGrid.new()
    var view := _view(grid)
    view.rebuild()
    var builds := view.build_count()

    IslandBuilder.build(grid)
    assert_bool(grid.needs_full_redraw()).is_true()
    view.sync()
    assert_int(view.build_count()).is_equal(builds + 1)
