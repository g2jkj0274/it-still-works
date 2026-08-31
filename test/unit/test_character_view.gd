extends GdUnitTestSuite

## 캐릭터 렌더링 검증.


func _at(cell: Vector3i, facing: Vector3i = Vector3i(0, 1, 0)) -> CharacterState:
    var character := CharacterState.new()
    character.place_at(cell)
    character.facing = facing
    return character


func _view(character: CharacterState) -> CharacterView:
    var view: CharacterView = auto_free(CharacterView.new())
    add_child(view)
    view.bind(character)
    view.snap()
    return view


func test_snap_lands_on_the_body_centre() -> void:
    var character := _at(Vector3i(4, 5, 2))
    var view := _view(character)
    var expected := SimViewCoords.cell_to_world(Vector3i(4, 5, 2))
    assert_float(view.position.x).is_equal_approx(expected.x, 0.001)
    assert_float(view.position.z).is_equal_approx(expected.z, 0.001)
    # 몸이 두 칸이므로 중심은 발 칸보다 반 칸 위다.
    assert_float(view.position.y).is_equal_approx(expected.y + 0.5, 0.001)


func test_subunit_progress_shows_between_cells() -> void:
    # 시뮬레이션이 칸 사이에 있으면 화면에서도 칸 사이에 있어야 한다.
    var character := _at(Vector3i(0, 0, 1))
    character.walk_to(Vector3i(1, 0, 1))
    character.advance()
    var view := _view(character)
    var start := SimViewCoords.cell_to_world(Vector3i(0, 0, 1))
    assert_float(view.position.x).is_greater(start.x)
    assert_float(view.position.x).is_less(start.x + 1.0)


func test_sync_moves_towards_the_new_cell() -> void:
    var character := _at(Vector3i(0, 0, 1))
    var view := _view(character)
    var start := view.position
    character.place_at(Vector3i(5, 0, 1))
    view.sync(0.5)
    assert_float(view.position.x).is_greater(start.x)
    assert_float(view.position.x).is_less(view.target_position().x + 0.001)


func test_view_never_writes_to_the_character() -> void:
    var character := _at(Vector3i(4, 5, 2), Vector3i(1, 0, 0))
    var view := _view(character)
    view.sync(0.5)
    assert_bool(character.cell() == Vector3i(4, 5, 2)).is_true()
    assert_bool(character.facing == Vector3i(1, 0, 0)).is_true()
