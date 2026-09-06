extends GdUnitTestSuite

## 명령 객체의 적용 동작과 직렬화 왕복 검증.


func _state(seed_value: int = 1) -> WorldState:
    var registry := BlockRegistry.load_default()
    var terrain := TerrainTable.load_default(registry)
    assert_object(registry).is_not_null()
    assert_object(terrain).is_not_null()
    var chunks := ChunkWorld.new(ChunkGenerator.new(seed_value, registry, terrain))
    return WorldState.new(SimRng.new(seed_value), chunks)


func test_set_value_command_applies() -> void:
    var state := _state()
    SetValueCommand.create(&"wood", 5).apply(state)
    assert_int(state.get_value(&"wood")).is_equal(5)


func test_set_value_command_overwrites() -> void:
    var state := _state()
    state.set_value(&"wood", 2)
    SetValueCommand.create(&"wood", 5).apply(state)
    assert_int(state.get_value(&"wood")).is_equal(5)


func test_add_value_command_accumulates() -> void:
    var state := _state()
    state.set_value(&"wood", 2)
    AddValueCommand.create(&"wood", 3).apply(state)
    assert_int(state.get_value(&"wood")).is_equal(5)


func test_add_value_command_treats_missing_key_as_zero() -> void:
    var state := _state()
    AddValueCommand.create(&"wood", 3).apply(state)
    assert_int(state.get_value(&"wood")).is_equal(3)


func test_roll_value_command_draws_from_world_rng() -> void:
    var state := _state(7)
    var expected := SimRng.new(7).next_range(1, 6)
    RollValueCommand.create(&"die", 1, 6).apply(state)
    assert_int(state.get_value(&"die")).is_equal(expected)


func test_roll_value_command_advances_world_rng() -> void:
    var state := _state(7)
    var before := state.rng.get_state()
    RollValueCommand.create(&"die", 1, 6).apply(state)
    assert_int(state.rng.get_state()).is_not_equal(before)


func test_set_load_center_command_sets_target_only() -> void:
    # 명령은 로드 중심 목표만 적는다. 청크 로드(set_center)는 Simulation.step() 의 일이다.
    var state := _state()
    SetLoadCenterCommand.create(3, -2).apply(state)
    assert_bool(state.has_load_center).is_true()
    assert_bool(state.load_center == Vector2i(3, -2)).is_true()
    assert_bool(state.chunks.has_center()).is_false()
    assert_int(state.chunks.loaded_count()).is_equal(0)


func test_set_load_center_command_does_not_touch_rng_or_values() -> void:
    var state := _state(7)
    var before := state.rng.get_state()
    SetLoadCenterCommand.create(1, 1).apply(state)
    assert_int(state.rng.get_state()).is_equal(before)
    assert_int(state.value_count()).is_equal(0)


func test_type_names_are_distinct() -> void:
    var names := [
        String(SetValueCommand.create(&"k", 0).get_type()),
        String(AddValueCommand.create(&"k", 0).get_type()),
        String(RollValueCommand.create(&"k", 0, 1).get_type()),
        String(SetLoadCenterCommand.create(0, 0).get_type()),
    ]
    assert_array(names).has_size(4)
    assert_array(names).contains_exactly_in_any_order([
        "set_value", "add_value", "roll_value", "set_load_center",
    ])


func test_set_value_command_round_trip() -> void:
    var original := SetValueCommand.create(&"wood", 5)
    original.tick = 12
    var restored := SimCommandCodec.from_dict(original.to_dict()) as SetValueCommand
    assert_object(restored).is_not_null()
    assert_int(restored.tick).is_equal(12)
    assert_str(String(restored.key)).is_equal("wood")
    assert_int(restored.value).is_equal(5)


func test_add_value_command_round_trip() -> void:
    var original := AddValueCommand.create(&"ore", -4)
    original.tick = 3
    var restored := SimCommandCodec.from_dict(original.to_dict()) as AddValueCommand
    assert_object(restored).is_not_null()
    assert_str(String(restored.key)).is_equal("ore")
    assert_int(restored.delta).is_equal(-4)


func test_roll_value_command_round_trip() -> void:
    var original := RollValueCommand.create(&"die", 1, 6)
    var restored := SimCommandCodec.from_dict(original.to_dict()) as RollValueCommand
    assert_object(restored).is_not_null()
    assert_int(restored.min_value).is_equal(1)
    assert_int(restored.max_value).is_equal(6)


func test_set_load_center_command_round_trip() -> void:
    var original := SetLoadCenterCommand.create(-4, 9)
    original.tick = 5
    var data := original.to_dict()
    assert_str(str(data["type"])).is_equal("set_load_center")
    assert_int(int(data["cx"])).is_equal(-4)
    assert_int(int(data["cy"])).is_equal(9)
    var restored := SimCommandCodec.from_dict(data) as SetLoadCenterCommand
    assert_object(restored).is_not_null()
    assert_int(restored.tick).is_equal(5)
    assert_int(restored.cx).is_equal(-4)
    assert_int(restored.cy).is_equal(9)


func test_set_load_center_command_survives_json() -> void:
    var original := SetLoadCenterCommand.create(2, -7)
    original.tick = 11
    var parsed: Variant = JSON.parse_string(JSON.stringify(SimCommandCodec.to_dict(original)))
    var restored := SimCommandCodec.from_dict(parsed) as SetLoadCenterCommand
    assert_object(restored).is_not_null()
    assert_int(restored.tick).is_equal(11)
    assert_int(restored.cx).is_equal(2)
    assert_int(restored.cy).is_equal(-7)
    assert_int(typeof(restored.cx)).is_equal(TYPE_INT)
    assert_int(typeof(restored.cy)).is_equal(TYPE_INT)


func test_serialized_command_survives_json() -> void:
    # JSON 은 수를 실수로 되돌린다. 경계에서 정수로 되돌아오는지 확인한다.
    var original := RollValueCommand.create(&"die", 1, 6)
    original.tick = 3
    var parsed: Variant = JSON.parse_string(JSON.stringify(original.to_dict()))
    var restored := SimCommandCodec.from_dict(parsed) as RollValueCommand
    assert_object(restored).is_not_null()
    assert_int(restored.tick).is_equal(3)
    assert_int(restored.max_value).is_equal(6)
    assert_int(typeof(restored.max_value)).is_equal(TYPE_INT)


func test_unknown_type_yields_null() -> void:
    assert_object(SimCommandCodec.from_dict({"type": "nope", "tick": 0})).is_null()


func test_command_is_not_a_node() -> void:
    # 명령은 RefCounted 다. 씬 트리 없이 헤드리스로 생성·적용된다.
    var command := SetValueCommand.create(&"wood", 1)
    assert_str(command.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(command.get_class(), "Node")).is_false()
