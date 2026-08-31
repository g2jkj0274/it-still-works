extends GdUnitTestSuite

## 시뮬레이션 격자 좌표 → Godot 월드 좌표 변환 검증.
##
## 격자는 z 가 높이고 Godot 은 y 가 높다. 이 변환이 유일한 접점이다.


func test_cell_maps_height_axis_to_godot_up() -> void:
    var world := SimViewCoords.cell_to_world(Vector3i(0, 0, 3))
    assert_float(world.y).is_equal_approx(3.5, 0.001)
    assert_float(world.x).is_equal_approx(0.5, 0.001)
    assert_float(world.z).is_equal_approx(0.5, 0.001)


func test_cell_is_centred_in_its_box() -> void:
    var world := SimViewCoords.cell_to_world(Vector3i(2, 5, 1))
    assert_float(world.x).is_equal_approx(2.5, 0.001)
    assert_float(world.z).is_equal_approx(5.5, 0.001)


func test_neighbouring_cells_are_one_unit_apart() -> void:
    var origin := SimViewCoords.cell_to_world(Vector3i(4, 4, 4))
    for offset in VoxelGrid.NEIGHBOURS:
        var neighbour := SimViewCoords.cell_to_world(Vector3i(4, 4, 4) + offset)
        assert_float(origin.distance_to(neighbour)).is_equal_approx(SimViewCoords.CELL_SIZE, 0.001)


func test_mapping_is_injective_over_the_grid_axes() -> void:
    var seen: Dictionary = {}
    for cell in [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, 0)]:
        var key := str(SimViewCoords.cell_to_world(cell))
        assert_bool(seen.has(key)).is_false()
        seen[key] = true
