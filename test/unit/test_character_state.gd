extends GdUnitTestSuite

## 캐릭터가 격자에서 차지하는 부피 검증.


func test_character_is_two_cells_tall() -> void:
    assert_int(CharacterState.HEIGHT).is_equal(2)


func test_defaults_to_origin_facing_a_horizontal_direction() -> void:
    var character := CharacterState.new()
    assert_bool(character.position == Vector3i.ZERO).is_true()
    assert_int(character.facing.z).is_equal(0)
    assert_int(absi(character.facing.x) + absi(character.facing.y)).is_equal(1)


func test_occupied_cells_stack_upward() -> void:
    var character := CharacterState.new(Vector3i(4, 5, 6))
    var cells := character.occupied_cells()
    assert_int(cells.size()).is_equal(CharacterState.HEIGHT)
    assert_bool(cells[0] == Vector3i(4, 5, 6)).is_true()
    assert_bool(cells[1] == Vector3i(4, 5, 7)).is_true()


func test_head_sits_above_the_feet() -> void:
    var character := CharacterState.new(Vector3i(4, 5, 6))
    assert_bool(character.head_position() == Vector3i(4, 5, 7)).is_true()


func test_occupies_covers_the_whole_body() -> void:
    var character := CharacterState.new(Vector3i(4, 5, 6))
    assert_bool(character.occupies(Vector3i(4, 5, 6))).is_true()
    assert_bool(character.occupies(Vector3i(4, 5, 7))).is_true()
    assert_bool(character.occupies(Vector3i(4, 5, 5))).is_false()
    assert_bool(character.occupies(Vector3i(4, 5, 8))).is_false()
    assert_bool(character.occupies(Vector3i(5, 5, 6))).is_false()
