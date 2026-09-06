extends GdUnitTestSuite

## 아이소메트릭 고정 카메라 검증.


func _camera() -> IsometricCamera:
    var camera: IsometricCamera = auto_free(IsometricCamera.new())
    add_child(camera)
    return camera


func test_projection_is_orthogonal() -> void:
    assert_int(_camera().projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)


func test_angles_are_fixed_isometric() -> void:
    var camera := _camera()
    assert_float(camera.rotation_degrees.x).is_equal_approx(IsometricCamera.PITCH_DEGREES, 0.001)
    assert_float(camera.rotation_degrees.y).is_equal_approx(IsometricCamera.YAW_DEGREES, 0.001)
    assert_float(camera.rotation_degrees.z).is_equal_approx(0.0, 0.001)


func test_focus_keeps_the_target_straight_ahead() -> void:
    var camera := _camera()
    var target := Vector3(10, 2, 30)
    camera.focus_on(target)
    var forward := -camera.transform.basis.z
    var to_target := (target - camera.position).normalized()
    assert_float(forward.dot(to_target)).is_equal_approx(1.0, 0.001)


func test_focus_keeps_a_fixed_distance() -> void:
    var camera := _camera()
    camera.focus_on(Vector3(10, 2, 30))
    assert_float(camera.position.distance_to(Vector3(10, 2, 30))).is_equal_approx(IsometricCamera.DISTANCE, 0.001)


func test_angles_never_change_while_following() -> void:
    var camera := _camera()
    var before := camera.rotation_degrees
    camera.focus_on(Vector3(1, 2, 3))
    camera.follow(Vector3(40, 5, 40), 0.5)
    assert_bool(camera.rotation_degrees.is_equal_approx(before)).is_true()


func test_follow_moves_part_way() -> void:
    var camera := _camera()
    camera.focus_on(Vector3.ZERO)
    camera.follow(Vector3(10, 0, 0), 0.5)
    assert_float(camera.focus_point().x).is_equal_approx(5.0, 0.001)
