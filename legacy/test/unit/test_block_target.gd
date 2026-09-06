extends GdUnitTestSuite

## 시선이 가리키는 블록 찾기 검증.
##
## 광선은 격자 좌표계에서 쏜다. 칸 (i,j,k) 는 [i,i+1] x [j,j+1] x [k,k+1] 을 차지한다.

const FAR := 100.0


## z=0..1 에 8x8 지면.
func _ground() -> VoxelGrid:
    var grid := VoxelGrid.new()
    for y in 8:
        for x in 8:
            for z in 2:
                grid.set_block(Vector3i(x, y, z), BlockType.GROUND)
    return grid


func test_ray_from_above_hits_the_top_face() -> void:
    var target := BlockTarget.raycast(_ground(), Vector3(4.5, 4.5, 9.0), Vector3(0, 0, -1), FAR)
    assert_bool(target.hit).is_true()
    assert_bool(target.cell == Vector3i(4, 4, 1)).is_true()
    assert_bool(target.normal == Vector3i(0, 0, 1)).is_true()


func test_place_cell_sits_on_the_hit_face() -> void:
    var target := BlockTarget.raycast(_ground(), Vector3(4.5, 4.5, 9.0), Vector3(0, 0, -1), FAR)
    assert_bool(target.place_cell() == Vector3i(4, 4, 2)).is_true()


func test_ray_from_the_side_hits_the_side_face() -> void:
    var target := BlockTarget.raycast(_ground(), Vector3(-5.0, 4.5, 0.5), Vector3(1, 0, 0), FAR)
    assert_bool(target.hit).is_true()
    assert_bool(target.cell == Vector3i(0, 4, 0)).is_true()
    assert_bool(target.normal == Vector3i(-1, 0, 0)).is_true()


func test_ray_along_y_hits_the_near_face() -> void:
    var target := BlockTarget.raycast(_ground(), Vector3(4.5, -5.0, 0.5), Vector3(0, 1, 0), FAR)
    assert_bool(target.hit).is_true()
    assert_bool(target.cell == Vector3i(4, 0, 0)).is_true()
    assert_bool(target.normal == Vector3i(0, -1, 0)).is_true()


func test_ray_into_the_void_misses() -> void:
    var target := BlockTarget.raycast(_ground(), Vector3(4.5, 4.5, 9.0), Vector3(0, 0, 1), FAR)
    assert_bool(target.hit).is_false()


func test_ray_that_runs_out_of_distance_misses() -> void:
    var target := BlockTarget.raycast(_ground(), Vector3(4.5, 4.5, 9.0), Vector3(0, 0, -1), 2.0)
    assert_bool(target.hit).is_false()


func test_diagonal_ray_still_lands_on_a_face() -> void:
    var target := BlockTarget.raycast(_ground(), Vector3(4.2, 4.2, 9.0), Vector3(0.2, 0.1, -1).normalized(), FAR)
    assert_bool(target.hit).is_true()
    assert_bool(VoxelGrid.NEIGHBOURS.has(target.normal)).is_true()
    assert_bool(target.cell.z == 1).is_true()


func test_a_miss_reports_no_cell_to_use() -> void:
    var target := BlockTarget.raycast(_ground(), Vector3(4.5, 4.5, 9.0), Vector3(0, 0, 1), FAR)
    assert_bool(target.is_usable(Vector3i(4, 4, 2))).is_false()


func test_reach_limits_how_far_the_character_can_touch() -> void:
    var target := BlockTarget.raycast(_ground(), Vector3(0.5, 0.5, 9.0), Vector3(0, 0, -1), FAR)
    assert_bool(target.hit).is_true()
    assert_bool(target.is_usable(Vector3i(0, 0, 2))).is_true()
    assert_bool(target.is_usable(Vector3i(60, 60, 2))).is_false()


func test_zero_direction_misses_instead_of_looping() -> void:
    var target := BlockTarget.raycast(_ground(), Vector3(4.5, 4.5, 9.0), Vector3.ZERO, FAR)
    assert_bool(target.hit).is_false()


func test_ray_starting_outside_the_grid_still_enters_it() -> void:
    var target := BlockTarget.raycast(_ground(), Vector3(4.5, 4.5, 400.0), Vector3(0, 0, -1), 1000.0)
    assert_bool(target.hit).is_true()
    assert_bool(target.cell == Vector3i(4, 4, 1)).is_true()
