extends GdUnitTestSuite

## 바다 검증.
##
## 표현일 뿐이지만 **보이는 것이 사실이어야 한다.** 빈 칸에 물이 비치면 화면이
## 없는 것을 있다고 말하는 셈이다.


func _sea() -> SeaView:
    var sea: SeaView = auto_free(SeaView.new())
    add_child(sea)
    return sea


func test_the_water_never_reaches_under_the_island() -> void:
    # 평평한 판으로 깔면 땅을 파서 물낯보다 아래로 내려가는 순간 구덩이에
    # 물이 차 보인다. 시뮬레이션에는 빈 칸인데 화면이 물이라고 말하는 것이다.
    # 지하를 파는 게임에서는 그 일이 늘 일어나므로 가운데를 뚫어 둔다.
    var inner := float(IslandBuilder.ISLAND_RADIUS) - SeaView.INNER_MARGIN
    assert_float(inner).is_greater(0.0)

    var box := _sea().mesh_bounds()
    # 고리 안쪽에는 아무것도 없다. 섬 한가운데를 덮지 않는다는 뜻이다.
    assert_float(box.size.x).is_greater(inner * 2.0)


func test_the_shore_is_just_above_the_water() -> void:
    # 물낯이 해안보다 높으면 뭍이 잠기고, 너무 낮으면 섬이 공중에 뜬다.
    var shore_top := float(IslandBuilder.SHORE_Z + 1) * SimViewCoords.CELL_SIZE
    assert_float(SeaView.water_level()).is_less(shore_top)
    assert_float(SeaView.water_level()).is_greater(shore_top - 1.0)


func test_the_coastline_is_level_all_the_way_round() -> void:
    # 해안선의 높이가 들쭉날쭉하면 물낯을 어디에 두어도 어떤 곳은 잠기고
    # 어떤 곳은 절벽이 된다.
    var coast := 0
    for y in VoxelGrid.SIZE_Y:
        for x in VoxelGrid.SIZE_X:
            var column := Vector2i(x, y)
            var top := IslandBuilder.surface_z(column)
            if top < 0:
                continue
            if not _touches_water(column):
                continue
            coast += 1
            assert_int(top).override_failure_message(
                "물가 %s 의 높이가 %d 다" % [column, top]).is_equal(IslandBuilder.SHORE_Z)

    assert_int(coast).is_greater(100)


## 그 기둥이 물에 닿아 있는가. 이웃 넷 중 하나라도 뭍이 아니면 물가다.
func _touches_water(column: Vector2i) -> bool:
    for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        if IslandBuilder.surface_z(column + offset) < 0:
            return true
    return false


func test_the_surface_is_placed_at_the_water_level() -> void:
    assert_float(_sea().surface_height()).is_equal_approx(SeaView.water_level(), 0.001)


func test_the_water_reaches_past_the_island() -> void:
    # 끝이 보이면 섬이 접시 위에 놓인 것처럼 보인다.
    assert_float(SeaView.EXTENT).is_greater(float(VoxelGrid.SIZE_X) * SimViewCoords.CELL_SIZE * 2.0)
