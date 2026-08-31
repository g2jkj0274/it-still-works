extends GdUnitTestSuite

## 캐릭터 렌더링 검증.


func _view(character: CharacterState) -> CharacterView:
    var view: CharacterView = auto_free(CharacterView.new())
    add_child(view)
    view.bind(character)
    view.snap()
    return view


func test_snap_lands_on_the_body_centre() -> void:
    var character := CharacterState.new(Vector3i(4, 5, 2))
    var view := _view(character)
    var expected := SimViewCoords.cell_to_world(Vector3i(4, 5, 2))
    assert_float(view.position.x).is_equal_approx(expected.x, 0.001)
    assert_float(view.position.z).is_equal_approx(expected.z, 0.001)
    # 몸이 두 칸이므로 중심은 발 칸보다 반 칸 위다.
    assert_float(view.position.y).is_equal_approx(expected.y + 0.5, 0.001)


func test_sync_moves_towards_the_new_cell() -> void:
    var character := CharacterState.new(Vector3i(0, 0, 1))
    var view := _view(character)
    var start := view.position
    character.position = Vector3i(5, 0, 1)
    view.sync(0.5)
    assert_float(view.position.x).is_greater(start.x)
    assert_float(view.position.x).is_less(view.target_position().x + 0.001)


func test_view_never_writes_to_the_character() -> void:
    var character := CharacterState.new(Vector3i(4, 5, 2), Vector3i(1, 0, 0))
    var view := _view(character)
    view.sync(0.5)
    assert_bool(character.position == Vector3i(4, 5, 2)).is_true()
    assert_bool(character.facing == Vector3i(1, 0, 0)).is_true()
