extends GdUnitTestSuite

## 월드 상태 저장소와 상태 해시 검증. 네 인자 생성(rng·chunks·registry·player), 해시 필드 순서
## (values → player.* 4개 → chunks), 플레이어 필드 각각이 해시를 바꿈, registry 는 해시 밖.
##
## 픽스처는 인메모리로 네 개를 만든다. Simulation 을 거치지 않으므로 플레이어는 원점에 선다.


func _registry() -> BlockRegistry:
    var registry := BlockRegistry.load_default()
    assert_object(registry).is_not_null()
    return registry


func _chunks(seed_value: int, registry: BlockRegistry) -> ChunkWorld:
    var terrain := TerrainTable.load_default(registry)
    assert_object(terrain).is_not_null()
    return ChunkWorld.new(ChunkGenerator.new(seed_value, registry, terrain))


func _make(seed_value: int = 1) -> WorldState:
    var registry := _registry()
    return WorldState.new(SimRng.new(seed_value), _chunks(seed_value, registry), registry, PlayerState.new())


func test_new_state_starts_at_tick_zero() -> void:
    assert_int(_make().tick).is_equal(0)


func test_new_state_has_chunks_without_center() -> void:
    var state := _make()
    assert_object(state.chunks).is_not_null()
    assert_bool(state.chunks.has_center()).is_false()
    assert_int(state.chunks.loaded_count()).is_equal(0)


func test_new_state_holds_registry_and_player() -> void:
    var registry := _registry()
    var player := PlayerState.new()
    player.place_at(Vector2i(3, -4), Chunk.LAYER_UPPER)
    var state := WorldState.new(SimRng.new(1), _chunks(1, registry), registry, player)
    assert_object(state.registry).is_same(registry)
    assert_object(state.player).is_same(player)
    assert_bool(state.player.cell() == Vector2i(3, -4)).is_true()
    assert_int(state.player.layer).is_equal(Chunk.LAYER_UPPER)


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


func test_hash_fields_are_ordered_and_named() -> void:
    # 해시 입력은 순서 있는 [이름, 값] 목록이다. 고정 필드가 앞에, 값이 사전순으로 뒤에 온다.
    var state := _make(42)
    state.set_value(&"wood", 3)
    state.set_value(&"ore", 5)
    var fields := state.to_hash_fields()

    var names: Array = []
    for field: Array in fields:
        names.append(str(field[0]))
    assert_array(names).contains_exactly([
        "tick", "rng.seed", "rng.state", "values.count", "value.ore", "value.wood",
        "player.sub", "player.target", "player.layer", "player.facing",
        "chunks.has_center", "chunks.center", "chunks.loaded", "chunks.snapshots",
    ])
    assert_int(int(fields[3][1])).is_equal(2)
    assert_int(int(fields[4][1])).is_equal(5)
    assert_int(int(fields[5][1])).is_equal(3)
    assert_str(str(fields[6][1])).is_equal("0,0")
    assert_str(str(fields[7][1])).is_equal("0,0")
    assert_int(int(fields[8][1])).is_equal(Chunk.LAYER_GROUND)
    assert_str(str(fields[9][1])).is_equal("0,1")
    assert_int(int(fields[10][1])).is_equal(0)
    assert_int(int(fields[12][1])).is_equal(0)


func test_registry_is_not_a_hash_field() -> void:
    # 표는 코드와 같은 층이다(DECISIONS 2026-09-06). 해시에 넣지 않는다.
    var state := _make(42)
    for field: Array in state.to_hash_fields():
        assert_bool(str(field[0]).contains("registry")).override_failure_message(
            "해시 필드에 registry 가 있다: %s" % str(field[0])
        ).is_false()


func test_player_sub_change_changes_hash() -> void:
    var state := _make(42)
    var before := state.compute_hash()
    state.player.sub += Vector2i(250, 0)
    assert_str(state.compute_hash()).is_not_equal(before)


func test_player_target_change_changes_hash() -> void:
    var state := _make(42)
    var before := state.compute_hash()
    state.player.walk_to(Vector2i(1, 0))
    assert_str(state.compute_hash()).is_not_equal(before)


func test_player_layer_change_changes_hash() -> void:
    var state := _make(42)
    var before := state.compute_hash()
    state.player.layer = Chunk.LAYER_UNDER
    assert_str(state.compute_hash()).is_not_equal(before)


func test_player_facing_change_changes_hash() -> void:
    var state := _make(42)
    var before := state.compute_hash()
    state.player.facing = Vector2i(-1, 0)
    assert_str(state.compute_hash()).is_not_equal(before)


func test_player_hash_fields_match_player_state() -> void:
    var state := _make(42)
    state.player.place_at(Vector2i(-2, 5), Chunk.LAYER_UPPER)
    var fields := state.to_hash_fields()
    var player_fields := state.player.to_hash_fields()
    var offset := 4  # tick, rng.seed, rng.state, values.count (값 없음)
    for i in player_fields.size():
        assert_str(str(fields[offset + i][0])).is_equal(str(player_fields[i][0]))
        assert_str(str(fields[offset + i][1])).is_equal(str(player_fields[i][1]))


func test_chunk_center_change_changes_hash() -> void:
    # 단위 테스트에서 set_center 직접 호출은 허용된다(가드는 sim/commands·view 만 본다).
    var state := _make(42)
    var before := state.compute_hash()
    state.chunks.set_center(0, 0)
    assert_int(state.chunks.loaded_count()).is_equal(25)
    assert_str(state.compute_hash()).is_not_equal(before)
    var names: Array = []
    for field: Array in state.to_hash_fields():
        names.append(str(field[0]))
    assert_bool(names.has("chunk.0,0")).is_true()
    assert_bool(names.has("chunk.-2,-2")).is_true()


func test_chunk_hash_fields_follow_player_fields() -> void:
    var state := _make(42)
    var fields := state.to_hash_fields()
    var chunk_fields := state.chunks.to_hash_fields()
    var offset := fields.size() - chunk_fields.size()
    assert_str(str(fields[offset - 1][0])).is_equal("player.facing")
    for i in chunk_fields.size():
        assert_str(str(fields[offset + i][0])).is_equal(str(chunk_fields[i][0]))
        assert_str(str(fields[offset + i][1])).is_equal(str(chunk_fields[i][1]))


func test_state_is_not_a_node() -> void:
    var state := _make()
    assert_str(state.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(state.get_class(), "Node")).is_false()
