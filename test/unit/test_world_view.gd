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


func test_sync_rebuilds_only_when_the_grid_changes() -> void:
    var grid := _grid()
    var view := _view(grid)
    var builds := view.build_count()
    view.sync()
    assert_int(view.build_count()).is_equal(builds)

    grid.set_block(Vector3i(3, 3, 1), BlockType.WOOD)
    view.sync()
    assert_int(view.build_count()).is_equal(builds + 1)


func test_each_block_type_has_its_own_colour() -> void:
    var colours: Array = []
    for type in [BlockType.GROUND, BlockType.STONE, BlockType.WOOD]:
        var colour := WorldView.colour_of(type)
        assert_bool(colours.has(colour)).is_false()
        colours.append(colour)
