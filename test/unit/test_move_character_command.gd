extends GdUnitTestSuite

## 이동 명령 검증. 이동은 오직 이 명령을 통해서만 일어난다.


func _state() -> WorldState:
    var state := WorldState.new(SimRng.new(1))
    for y in 8:
        for x in 8:
            state.grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
    state.character.position = Vector3i(4, 4, 1)
    return state


func test_move_shifts_the_character_one_cell() -> void:
    var state := _state()
    MoveCharacterCommand.create(Vector3i(1, 0, 0)).apply(state)
    assert_bool(state.character.position == Vector3i(5, 4, 1)).is_true()


func test_move_updates_facing() -> void:
    var state := _state()
    MoveCharacterCommand.create(Vector3i(-1, 0, 0)).apply(state)
    assert_bool(state.character.facing == Vector3i(-1, 0, 0)).is_true()


func test_blocked_move_still_turns_the_character() -> void:
    # 갈 수 없어도 방향은 바뀐다. 제자리에서 돌아설 수 있어야 한다.
    var state := _state()
    state.grid.set_block(Vector3i(5, 4, 1), BlockType.STONE)
    state.grid.set_block(Vector3i(5, 4, 2), BlockType.STONE)
    MoveCharacterCommand.create(Vector3i(1, 0, 0)).apply(state)
    assert_bool(state.character.position == Vector3i(4, 4, 1)).is_true()
    assert_bool(state.character.facing == Vector3i(1, 0, 0)).is_true()


func test_invalid_direction_changes_nothing() -> void:
    var state := _state()
    var facing := state.character.facing
    MoveCharacterCommand.create(Vector3i(1, 1, 0)).apply(state)
    assert_bool(state.character.position == Vector3i(4, 4, 1)).is_true()
    assert_bool(state.character.facing == facing).is_true()


func test_move_does_not_consume_randomness() -> void:
    var state := _state()
    var before := state.rng.get_state()
    MoveCharacterCommand.create(Vector3i(1, 0, 0)).apply(state)
    assert_int(state.rng.get_state()).is_equal(before)


func test_move_command_round_trip() -> void:
    var original := MoveCharacterCommand.create(Vector3i(0, -1, 0))
    original.tick = 4
    var parsed: Variant = JSON.parse_string(JSON.stringify(original.to_dict()))
    var restored := SimCommandCodec.from_dict(parsed) as MoveCharacterCommand
    assert_object(restored).is_not_null()
    assert_int(restored.tick).is_equal(4)
    assert_bool(restored.direction == Vector3i(0, -1, 0)).is_true()
