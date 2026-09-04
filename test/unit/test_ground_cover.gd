extends GdUnitTestSuite

## 땅에 깔린 풀·꽃·잔돌 검증.
##
## 꾸밈이지만 규칙은 그대로다. 표현이 난수를 당겨 쓰면 그 순간 결정론이 깨지고,
## 표현이 격자를 고치면 시뮬레이션을 되돌아 미는 셈이 된다.


func _grid() -> VoxelGrid:
    var grid := VoxelGrid.new()
    for y in range(10, 26):
        for x in range(10, 26):
            grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
            grid.set_block(Vector3i(x, y, 1), BlockType.GROUND)
    return grid


func _cover(grid: VoxelGrid) -> GroundCover:
    var cover: GroundCover = auto_free(GroundCover.new())
    add_child(cover)
    cover.bind(grid)
    cover.rebuild()
    return cover


func test_every_kind_has_a_model_that_loaded() -> void:
    # 파일이 없거나 가져오기에 실패하면 여기서 걸린다.
    for entry: Array in GroundCover.KINDS:
        assert_object(GroundCover.mesh_of(entry[0])).is_not_null()


func test_something_actually_grows() -> void:
    var cover := _cover(_grid())
    assert_int(cover.kind_count()).is_equal(GroundCover.KINDS.size())
    assert_int(cover.total_instance_count()).is_greater(0)


func test_the_same_island_grows_the_same_thing_every_time() -> void:
    # 난수가 아니라 칸 좌표에서 뽑는다. 실행마다 같은 자리에 같은 것이 난다.
    var first := _cover(_grid())
    var second := _cover(_grid())
    assert_int(second.total_instance_count()).is_equal(first.total_instance_count())


func test_bare_rock_and_wood_stay_bare() -> void:
    # 흙 윗면에만 난다. 돌 위에 풀이 나면 자원지가 흐려진다.
    var grid := VoxelGrid.new()
    for y in range(10, 26):
        for x in range(10, 26):
            grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
            grid.set_block(Vector3i(x, y, 1), BlockType.STONE)
    assert_int(_cover(grid).total_instance_count()).is_equal(0)


func test_nothing_grows_under_a_block() -> void:
    var grid := _grid()
    for y in range(10, 26):
        for x in range(10, 26):
            grid.set_block(Vector3i(x, y, 2), BlockType.WOOD)
    assert_int(_cover(grid).total_instance_count()).is_equal(0)


func test_building_on_the_grass_clears_what_grew_there() -> void:
    var grid := _grid()
    var cover := _cover(grid)
    var before := cover.total_instance_count()
    assert_int(before).is_greater(0)

    # 절반만 덮는다. 덮인 쪽의 풀은 사라지고 나머지는 그대로다.
    for y in range(10, 18):
        for x in range(10, 26):
            grid.set_block(Vector3i(x, y, 2), BlockType.STONE)
    cover.sync()

    var after := cover.total_instance_count()
    assert_int(after).is_less(before)
    assert_int(after).is_greater(0)


func test_piling_more_earth_lifts_the_grass_instead_of_killing_it() -> void:
    # 흙 위에 흙을 놓으면 그 위가 새 지면이다. 풀은 사라지지 않고 올라선다.
    var grid := _grid()
    var cover := _cover(grid)
    var before := cover.total_instance_count()

    for y in range(10, 26):
        for x in range(10, 26):
            grid.set_block(Vector3i(x, y, 2), BlockType.GROUND)
    cover.sync()
    assert_int(cover.total_instance_count()).is_greater(0)
    assert_bool(cover.total_instance_count() != before).is_true()


func test_it_only_grows_again_when_the_ground_changes() -> void:
    var grid := _grid()
    var cover := _cover(grid)
    var builds := cover.build_count()
    for i in 5:
        cover.sync()
    assert_int(cover.build_count()).is_equal(builds)


func test_the_cover_never_writes_to_the_grid() -> void:
    var grid := _grid()
    var before := grid.digest()
    var cover := _cover(grid)
    for i in 3:
        cover.sync()
    assert_str(grid.digest()).is_equal(before)


func test_the_ground_is_not_buried_under_it() -> void:
    # 너무 빽빽하면 지면이 안 보인다. 꾸밈이 주인이 되면 안 된다.
    assert_int(GroundCover.DENSITY_PERCENT).is_less_equal(25)


func test_every_kind_takes_its_colour_from_the_palette() -> void:
    for entry: Array in GroundCover.KINDS:
        assert_bool(Palette.COVER_COLOURS.has(entry[1])).is_true()
