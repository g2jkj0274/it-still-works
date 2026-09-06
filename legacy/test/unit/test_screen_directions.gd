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
    assert_bool(ScreenDirections.grid_for(_camera(), Vector2i(2, 0)) == Vector3i.ZERO).is_true()
    assert_bool(ScreenDirections.grid_for(_camera(), Vector2i.ZERO) == Vector3i.ZERO).is_true()


func test_no_camera_gives_nothing() -> void:
    assert_bool(ScreenDirections.grid_for(null, ScreenDirections.UP) == Vector3i.ZERO).is_true()


func test_all_eight_screen_ways_give_eight_different_grid_ways() -> void:
    var camera := _camera()
    var seen: Array = []
    for screen in ScreenDirections.SCREEN_ORDER:
        var grid := ScreenDirections.grid_for(camera, screen)
        assert_bool(MovementRules.is_direction(grid)).is_true()
        assert_bool(seen.has(grid)).is_false()
        seen.append(grid)
    assert_int(seen.size()).is_equal(MovementRules.DIRECTIONS.size())


func test_the_straight_keys_land_on_grid_corners() -> void:
    # 요 45도에서 화면 위아래좌우는 격자 대각선이다.
    var camera := _camera()
    for screen in [ScreenDirections.UP, ScreenDirections.DOWN,
            ScreenDirections.LEFT, ScreenDirections.RIGHT]:
        assert_bool(MovementRules.is_diagonal(ScreenDirections.grid_for(camera, screen))).is_true()


func test_the_combined_keys_land_on_grid_axes() -> void:
    # 화면 대각선은 격자 축이다. 그래서 조합키로 축 방향에 갈 수 있다.
    var camera := _camera()
    for screen in [ScreenDirections.UP_RIGHT, ScreenDirections.UP_LEFT,
            ScreenDirections.DOWN_RIGHT, ScreenDirections.DOWN_LEFT]:
        assert_bool(MovementRules.is_diagonal(ScreenDirections.grid_for(camera, screen))).is_false()


func test_every_way_moves_at_least_the_way_it_points() -> void:
    var camera := _camera()
    for screen in ScreenDirections.SCREEN_ORDER:
        var delta := ScreenDirections.screen_delta_of(camera, ScreenDirections.grid_for(camera, screen))
        if screen.x != 0:
            assert_float(delta.x * screen.x).is_greater(0.0)
        if screen.y != 0:
            assert_float(delta.y * screen.y).is_greater(0.0)


func test_a_grid_axis_and_a_grid_corner_cover_the_same_screen_distance() -> void:
    # 아이소메트릭 투영이 화면 세로를 눌러 주기 때문에, 월드에서 sqrt(2) 배 먼
    # 대각선이 화면에서는 축과 같은 길이가 된다. 이것이 속도를 같게 둔 근거다.
    var camera := _camera()
    var axis := ScreenDirections.grid_for(camera, ScreenDirections.UP_RIGHT)
    var corner := ScreenDirections.grid_for(camera, ScreenDirections.UP)

    var axis_length := ScreenDirections.screen_delta_of(camera, axis).length()
    var corner_length := ScreenDirections.screen_delta_of(camera, corner).length()
    assert_float(absf(corner_length - axis_length) / axis_length).is_less(0.01)


func test_six_of_the_eight_ways_look_equally_fast() -> void:
    # 화면 좌우 두 방향만은 세로 눌림을 받지 않아 빨라 보인다.
    # 나머지 여섯은 눈에 같은 빠르기여야 한다.
    var camera := _camera()
    var speeds: Array = []
    for screen in ScreenDirections.SCREEN_ORDER:
        if screen == ScreenDirections.LEFT or screen == ScreenDirections.RIGHT:
            continue
        var grid := ScreenDirections.grid_for(camera, screen)
        var ticks := CharacterState.DIAGONAL_WALK_TICKS if MovementRules.is_diagonal(grid)             else CharacterState.SUBUNITS / CharacterState.WALK_SPEED
        speeds.append(ScreenDirections.screen_delta_of(camera, grid).length() / ticks)

    assert_int(speeds.size()).is_equal(6)
    for speed: float in speeds:
        assert_float(absf(speed - speeds[0]) / speeds[0]).is_less(0.01)


func test_the_sideways_ways_are_the_ones_that_look_faster() -> void:
    var camera := _camera()
    var sideways := ScreenDirections.screen_delta_of(
        camera, ScreenDirections.grid_for(camera, ScreenDirections.RIGHT)).length()
    var upward := ScreenDirections.screen_delta_of(
        camera, ScreenDirections.grid_for(camera, ScreenDirections.UP)).length()
    assert_float(sideways).is_greater(upward)


func test_an_axis_aligned_view_swaps_which_keys_are_corners() -> void:
    # 요를 0도로 돌리면 화면 위아래좌우가 격자 축이 된다.
    var camera := _camera(0.0)
    assert_bool(MovementRules.is_diagonal(
        ScreenDirections.grid_for(camera, ScreenDirections.UP))).is_false()
    assert_bool(MovementRules.is_diagonal(
        ScreenDirections.grid_for(camera, ScreenDirections.UP_RIGHT))).is_true()
