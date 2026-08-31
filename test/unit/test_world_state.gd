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
