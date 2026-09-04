extends GdUnitTestSuite

## 바다 검증.
##
## 표현일 뿐이지만 **보이는 것이 사실이어야 한다.** 빈 칸에 물이 비치면 화면이
## 없는 것을 있다고 말하는 셈이다.


func _sea() -> SeaView:
    var sea: SeaView = auto_free(SeaView.new())
    add_child(sea)
    return sea


func test_the_water_sits_below_anything_that_can_be_dug_out() -> void:
    # 바닥층은 부술 수 없다. 그 윗면보다 물낯이 낮아야 파 놓은 구덩이에
    # 물이 비치지 않는다.
    var bedrock_top := float(VoxelGrid.BEDROCK_Z + 1) * SimViewCoords.CELL_SIZE
    assert_float(SeaView.water_level()).is_less(bedrock_top)


func test_the_shore_still_shows_a_drop() -> void:
    # 물낯이 지면과 같은 높이면 물가가 사라진다.
    var ground_top := float(IslandBuilder.GROUND_TOP_Z + 1) * SimViewCoords.CELL_SIZE
    assert_float(SeaView.water_level()).is_less(ground_top - 0.5)


func test_the_surface_is_placed_at_the_water_level() -> void:
    assert_float(_sea().surface_height()).is_equal_approx(SeaView.water_level(), 0.001)


func test_the_water_reaches_past_the_island() -> void:
    # 끝이 보이면 섬이 접시 위에 놓인 것처럼 보인다.
    assert_float(SeaView.EXTENT).is_greater(float(VoxelGrid.SIZE_X) * SimViewCoords.CELL_SIZE * 2.0)
