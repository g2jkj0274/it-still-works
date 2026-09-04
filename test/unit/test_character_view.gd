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


func test_the_head_is_bigger_than_the_body() -> void:
    # 치비 비율. 머리가 커야 밝고 경쾌한 톤에 맞는다.
    var view := _view(_at(Vector3i(0, 0, 1)))
    assert_float(view.head_radius()).is_greater(view.body_radius())


func test_the_head_sits_on_top_of_the_body() -> void:
    var view := _view(_at(Vector3i(0, 0, 1)))
    assert_float(view.head_height()).is_greater(view.body_height())


func test_the_whole_body_fits_in_two_cells() -> void:
    # 몸통이 아니라 발끝에서 머리끝까지를 잰다.
    var view := _view(_at(Vector3i(0, 0, 1)))
    assert_float(view.highest_point() - view.lowest_point()).is_less_equal(
        CharacterState.HEIGHT * SimViewCoords.CELL_SIZE)


func test_the_body_turns_the_way_the_character_looks() -> void:
    # 겨냥한 곳이 없으면 바라보는 앞 칸에 놓인다. 어느 쪽을 보는지 보여야 한다.
    var north := _view(_at(Vector3i(4, 4, 2), Vector3i(0, -1, 0)))
    var east := _view(_at(Vector3i(4, 4, 2), Vector3i(1, 0, 0)))

    # 격자의 y 는 Godot 의 z 다. 축 바꿈은 표현 레이어의 몫이다.
    assert_float(north.facing_direction().z).is_less(-0.9)
    assert_float(east.facing_direction().x).is_greater(0.9)


func test_turning_on_the_spot_is_shown() -> void:
    var character := _at(Vector3i(4, 4, 2), Vector3i(0, 1, 0))
    var view := _view(character)
    var before := view.facing_direction()

    character.facing = Vector3i(-1, 0, 0)
    view.sync(1.0)
    assert_bool(view.facing_direction().is_equal_approx(before)).is_false()


func test_a_standing_still_character_keeps_its_last_facing() -> void:
    # 방향이 비면 마지막으로 보던 쪽을 그대로 둔다. 갑자기 홱 돌면 안 된다.
    var character := _at(Vector3i(4, 4, 2), Vector3i(1, 0, 0))
    var view := _view(character)
    var before := view.facing_direction()

    character.facing = Vector3i.ZERO
    view.sync(1.0)
    assert_bool(view.facing_direction().is_equal_approx(before)).is_true()
