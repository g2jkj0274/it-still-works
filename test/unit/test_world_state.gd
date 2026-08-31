extends GdUnitTestSuite

## 월드 상태 저장소와 상태 해시 검증.


func _make(seed_value: int = 1) -> WorldState:
    return WorldState.new(SimRng.new(seed_value))


func test_new_state_starts_at_tick_zero() -> void:
    assert_int(_make().tick).is_equal(0)


func test_missing_value_returns_fallback() -> void:
    var state := _make()
    assert_int(state.get_value(&"nope")).is_equal(0)
    assert_int(state.get_value(&"nope", 7)).is_equal(7)
    assert_bool(state.has_value(&"nope")).is_false()


func test_set_and_get_value() -> void:
    var state := _make()
    state.set_value(&"wood", 3)
    assert_int(state.get_value(&"wood")).is_equal(3)
    assert_bool(state.has_value(&"wood")).is_true()
    assert_int(state.value_count()).is_equal(1)


func test_set_overwrites_previous_value() -> void:
    var state := _make()
    state.set_value(&"wood", 3)
    state.set_value(&"wood", 9)
    assert_int(state.get_value(&"wood")).is_equal(9)
    assert_int(state.value_count()).is_equal(1)


func test_erase_value() -> void:
    var state := _make()
    state.set_value(&"wood", 3)
    state.erase_value(&"wood")
    assert_bool(state.has_value(&"wood")).is_false()
    assert_int(state.value_count()).is_equal(0)


func test_sorted_keys_ignore_insertion_order() -> void:
    var state := _make()
    state.set_value(&"ore", 1)
    state.set_value(&"crop", 2)
    state.set_value(&"wood", 3)
    assert_array(state.sorted_keys()).contains_exactly([&"crop", &"ore", &"wood"])


func test_identical_states_hash_equal() -> void:
    var a := _make(42)
    var b := _make(42)
    a.set_value(&"wood", 3)
    a.set_value(&"ore", 5)
    b.set_value(&"wood", 3)
    b.set_value(&"ore", 5)
    assert_str(a.compute_hash()).is_equal(b.compute_hash())


func test_insertion_order_does_not_change_hash() -> void:
    var a := _make(42)
    a.set_value(&"wood", 3)
    a.set_value(&"ore", 5)
    var b := _make(42)
    b.set_value(&"ore", 5)
    b.set_value(&"wood", 3)
    assert_str(a.compute_hash()).is_equal(b.compute_hash())


func test_value_change_changes_hash() -> void:
    var state := _make(42)
    state.set_value(&"wood", 3)
    var before := state.compute_hash()
    state.set_value(&"wood", 4)
    assert_str(state.compute_hash()).is_not_equal(before)


func test_tick_change_changes_hash() -> void:
    var state := _make(42)
    var before := state.compute_hash()
    state.tick = 1
    assert_str(state.compute_hash()).is_not_equal(before)


func test_rng_advance_changes_hash() -> void:
    var state := _make(42)
    var before := state.compute_hash()
    state.rng.next_int()
    assert_str(state.compute_hash()).is_not_equal(before)


func test_different_seed_changes_hash() -> void:
    assert_str(_make(1).compute_hash()).is_not_equal(_make(2).compute_hash())


func test_erased_key_is_not_confused_with_zero_value() -> void:
    var absent := _make(42)
    var present := _make(42)
    present.set_value(&"wood", 0)
    assert_str(absent.compute_hash()).is_not_equal(present.compute_hash())


func test_sorted_keys_are_lexicographic_not_intern_order() -> void:
    # StringName 끼리의 비교는 내부 포인터 순이다. 사전순 정렬을 보장하지 않는다.
    # 역순으로 넣어 삽입 순서와 사전순이 어긋나게 만든 뒤 결과를 확인한다.
    var state := _make()
    var names: Array = ["wood", "ore", "crop", "door", "lamp", "field", "box", "alarm"]
    for i in names.size():
        state.set_value(StringName(names[names.size() - 1 - i]), i)

    var expected: Array = names.duplicate()
    expected.sort()

    var actual: Array = []
    for key in state.sorted_keys():
        actual.append(String(key))

    assert_array(actual).contains_exactly(expected)


func test_state_owns_a_grid_and_a_character() -> void:
    var state := _make()
    assert_object(state.grid).is_not_null()
    assert_object(state.character).is_not_null()
    assert_int(state.grid.get_block(Vector3i(0, 0, 0))).is_equal(BlockType.EMPTY)


func test_block_change_changes_hash() -> void:
    var state := _make(42)
    var before := state.compute_hash()
    state.grid.set_block(Vector3i(3, 4, 5), BlockType.STONE)
    assert_str(state.compute_hash()).is_not_equal(before)


func test_character_move_changes_hash() -> void:
    var state := _make(42)
    var before := state.compute_hash()
    state.character.place_at(Vector3i(1, 0, 0))
    assert_str(state.compute_hash()).is_not_equal(before)


func test_character_facing_changes_hash() -> void:
    var state := _make(42)
    var before := state.compute_hash()
    state.character.facing = Vector3i(1, 0, 0)
    assert_str(state.compute_hash()).is_not_equal(before)


func test_states_with_same_world_hash_equal() -> void:
    var a := _make(42)
    var b := _make(42)
    for state: WorldState in [a, b]:
        state.grid.set_block(Vector3i(3, 4, 5), BlockType.STONE)
        state.character.place_at(Vector3i(9, 9, 1))
    assert_str(a.compute_hash()).is_equal(b.compute_hash())
