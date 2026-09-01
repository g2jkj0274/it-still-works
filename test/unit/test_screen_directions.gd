extends GdUnitTestSuite

## 화면 방향 → 격자 방향 변환 검증.
##
## 아이소메트릭에서는 네 격자 방향이 모두 비스듬히 놓인다. 어떤 방향도 화면의
## 정확한 위아래를 가리키지 못한다. 그래서 여기서 지키는 것은 "정확히 위"가
## 아니라 **누른 쪽으로는 간다**이다. W 를 누르면 적어도 위로는 가야 한다.


func _camera(yaw: float = IsometricCamera.YAW_DEGREES) -> IsometricCamera:
    var camera: IsometricCamera = auto_free(IsometricCamera.new())
    add_child(camera)
    var steps := int(round((yaw - IsometricCamera.YAW_DEGREES) / IsometricCamera.YAW_STEP))
    camera.turn_by(steps)
    return camera


func test_the_four_keys_give_four_different_directions() -> void:
    var camera := _camera()
    var seen: Array = []
    for screen in ScreenDirections.SCREEN_ORDER:
        var grid := ScreenDirections.grid_for(camera, screen)
        assert_bool(MovementRules.is_direction(grid)).is_true()
        assert_bool(seen.has(grid)).is_false()
        seen.append(grid)


func test_opposite_keys_give_opposite_directions() -> void:
    var camera := _camera()
    assert_bool(ScreenDirections.grid_for(camera, ScreenDirections.UP)
        == -ScreenDirections.grid_for(camera, ScreenDirections.DOWN)).is_true()
    assert_bool(ScreenDirections.grid_for(camera, ScreenDirections.LEFT)
        == -ScreenDirections.grid_for(camera, ScreenDirections.RIGHT)).is_true()


func test_each_key_moves_at_least_the_way_it_points() -> void:
    var camera := _camera()
    for screen in ScreenDirections.SCREEN_ORDER:
        var grid := ScreenDirections.grid_for(camera, screen)
        var delta := ScreenDirections.screen_delta_of(camera, grid)
        if screen.x != 0:
            assert_float(delta.x * screen.x).is_greater(0.0)
        if screen.y != 0:
            assert_float(delta.y * screen.y).is_greater(0.0)


func test_the_mapping_follows_the_camera_when_it_turns() -> void:
    var camera := _camera()
    var before := ScreenDirections.grid_for(camera, ScreenDirections.UP)
    camera.turn_by(2)
    assert_bool(ScreenDirections.grid_for(camera, ScreenDirections.UP) == before).is_false()


func test_turning_all_the_way_round_comes_back() -> void:
    var camera := _camera()
    var before := ScreenDirections.grid_for(camera, ScreenDirections.UP)
    for i in 8:
        camera.turn_by(1)
    assert_bool(ScreenDirections.grid_for(camera, ScreenDirections.UP) == before).is_true()


func test_an_axis_aligned_view_points_the_keys_straight() -> void:
    # 요를 0도로 돌리면 격자 축이 화면과 나란해진다. 그때는 W 가 정확히 위다.
    var camera := _camera(0.0)
    var up := ScreenDirections.grid_for(camera, ScreenDirections.UP)
    var delta := ScreenDirections.screen_delta_of(camera, up)
    assert_float(absf(delta.x)).is_less(0.01)
    assert_float(delta.y).is_greater(0.0)


func test_a_key_that_is_not_a_direction_gives_nothing() -> void:
    assert_bool(ScreenDirections.grid_for(_camera(), Vector2i(1, 1)) == Vector3i.ZERO).is_true()


func test_no_camera_gives_nothing() -> void:
    assert_bool(ScreenDirections.grid_for(null, ScreenDirections.UP) == Vector3i.ZERO).is_true()
