extends GdUnitTestSuite

## 캐릭터의 서브유닛 위치와 부피 검증.
##
## 시뮬레이션은 칸보다 잘게 움직인다. 한 칸을 1000 서브유닛으로 나눠
## 정수만으로 부드러운 이동을 만든다.


func test_character_is_two_cells_tall() -> void:
    assert_int(CharacterState.HEIGHT).is_equal(2)


func test_one_cell_is_a_thousand_subunits() -> void:
    assert_int(CharacterState.SUBUNITS).is_equal(1000)


func test_walk_and_fall_speeds_divide_a_cell_evenly() -> void:
    # 나누어떨어져야 칸 경계에 정확히 내려앉는다. 남으면 위치가 조금씩 밀린다.
    assert_int(CharacterState.SUBUNITS % CharacterState.WALK_SPEED).is_equal(0)
    assert_int(CharacterState.SUBUNITS % CharacterState.FALL_SPEED).is_equal(0)


func test_cell_and_subunit_conversion_round_trips() -> void:
    for cell in [Vector3i.ZERO, Vector3i(3, 4, 5), Vector3i(63, 63, 15)]:
        assert_bool(CharacterState.cell_of(CharacterState.sub_of(cell)) == cell).is_true()


func test_partial_progress_stays_in_the_departing_cell() -> void:
    var sub := CharacterState.sub_of(Vector3i(4, 4, 2)) + Vector3i(999, 0, 0)
    assert_bool(CharacterState.cell_of(sub) == Vector3i(4, 4, 2)).is_true()


func test_place_at_snaps_to_the_cell_and_stops_moving() -> void:
    var character := CharacterState.new()
    character.place_at(Vector3i(4, 5, 6))
    assert_bool(character.cell() == Vector3i(4, 5, 6)).is_true()
    assert_bool(character.sub_position == CharacterState.sub_of(Vector3i(4, 5, 6))).is_true()
    assert_bool(character.is_moving()).is_false()


func test_defaults_to_origin_facing_a_horizontal_direction() -> void:
    var character := CharacterState.new()
    assert_bool(character.cell() == Vector3i.ZERO).is_true()
    assert_int(character.facing.z).is_equal(0)
    assert_int(absi(character.facing.x) + absi(character.facing.y)).is_equal(1)


func test_walking_towards_a_target_takes_several_ticks() -> void:
    var character := CharacterState.new()
    character.place_at(Vector3i(0, 0, 0))
    character.walk_to(Vector3i(1, 0, 0))
    assert_bool(character.is_moving()).is_true()

    var ticks := 0
    while character.is_moving() and ticks < 100:
        character.advance()
        ticks += 1

    assert_int(ticks).is_equal(CharacterState.SUBUNITS / CharacterState.WALK_SPEED)
    assert_bool(character.cell() == Vector3i(1, 0, 0)).is_true()
    assert_bool(character.sub_position == CharacterState.sub_of(Vector3i(1, 0, 0))).is_true()


func test_falling_is_faster_than_walking() -> void:
    assert_int(CharacterState.FALL_SPEED).is_greater(CharacterState.WALK_SPEED)


func test_falling_lands_exactly_on_the_cell() -> void:
    var character := CharacterState.new()
    character.place_at(Vector3i(0, 0, 5))
    character.walk_to(Vector3i(0, 0, 1))
    for i in 100:
        character.advance()
    assert_bool(character.sub_position == CharacterState.sub_of(Vector3i(0, 0, 1))).is_true()


func test_advance_without_a_target_does_nothing() -> void:
    var character := CharacterState.new()
    character.place_at(Vector3i(2, 2, 2))
    character.advance()
    assert_bool(character.cell() == Vector3i(2, 2, 2)).is_true()


func test_occupied_cells_stack_upward() -> void:
    var character := CharacterState.new()
    character.place_at(Vector3i(4, 5, 6))
    var cells := character.occupied_cells()
    assert_bool(cells.has(Vector3i(4, 5, 6))).is_true()
    assert_bool(cells.has(Vector3i(4, 5, 7))).is_true()


func test_a_walking_character_occupies_both_cells() -> void:
    # 걷는 도중에는 두 칸에 걸쳐 있다. 그 자리에 블록이 놓이면 몸에 겹친다.
    var character := CharacterState.new()
    character.place_at(Vector3i(4, 5, 6))
    character.walk_to(Vector3i(5, 5, 6))
    assert_bool(character.occupies(Vector3i(4, 5, 6))).is_true()
    assert_bool(character.occupies(Vector3i(5, 5, 6))).is_true()
    assert_bool(character.occupies(Vector3i(5, 5, 7))).is_true()
    assert_bool(character.occupies(Vector3i(6, 5, 6))).is_false()


func test_head_sits_above_the_feet() -> void:
    var character := CharacterState.new()
    character.place_at(Vector3i(4, 5, 6))
    assert_bool(character.head_position() == Vector3i(4, 5, 7)).is_true()


func test_facing_cell_is_directly_in_front_of_the_feet() -> void:
    var character := CharacterState.new()
    character.place_at(Vector3i(4, 5, 6))
    character.facing = Vector3i(1, 0, 0)
    assert_bool(character.facing_cell() == Vector3i(5, 5, 6)).is_true()
