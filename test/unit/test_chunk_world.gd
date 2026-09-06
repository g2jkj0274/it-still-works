extends GdUnitTestSuite

## 청크 월드 검증: 상수, 좌표 변환, 초기 상태, 로드 반경, 중심 이동, 월드 좌표 접근,
## P7 왕복(스냅샷·persist), 경로 무관 해시, 인정된 한계, restore_snapshot, 정렬, 해시 필드,
## 불변식, 소스 가드, Node 아님.

const SEED := 20250901

## 실수로 값이 안 바뀌는 set 을 막기 위해 테스트가 놓는 값. stone(2) 최대 내구도 20 이지만 GROUND
## 는 air 비율이 높아 골든 시드 (0,0) 에서는 바뀐다 — 각 테스트가 set 의 반환값 true 를 단언한다.
const SET_ID := 2
const SET_D := 20


func _generator(seed := SEED) -> ChunkGenerator:
    var registry := BlockRegistry.load_default()
    var terrain := TerrainTable.load_default(registry)
    assert_object(registry).is_not_null()
    assert_object(terrain).is_not_null()
    return ChunkGenerator.new(seed, registry, terrain)


func _world(seed := SEED) -> ChunkWorld:
    return ChunkWorld.new(_generator(seed))


## 로드된 청크 키 집합. [Vector2i → true].
func _loaded_keys(world: ChunkWorld) -> Dictionary:
    var keys: Dictionary = {}
    for entry: Array in world.loaded_sorted():
        keys[entry[0]] = true
    return keys


func _snapshot_keys(world: ChunkWorld) -> Dictionary:
    var keys: Dictionary = {}
    for entry: Array in world.snapshots_sorted():
        keys[entry[0]] = true
    return keys


## 불변식: 로드 키에 스냅샷 없음, 스냅샷 키 안 로드.
func _assert_invariant(world: ChunkWorld) -> void:
    var snapshots := _snapshot_keys(world)
    for key: Vector2i in _loaded_keys(world).keys():
        assert_bool(snapshots.has(key)).override_failure_message(
            "로드된 청크 (%d,%d) 에 스냅샷이 남아 있다" % [key.x, key.y]
        ).is_false()
    for key: Vector2i in snapshots.keys():
        assert_bool(world.is_loaded(key.x, key.y)).override_failure_message(
            "스냅샷 청크 (%d,%d) 가 로드돼 있다" % [key.x, key.y]
        ).is_false()


# --- 상수 ---

func test_constants_agree_with_chunk() -> void:
    assert_int(1 << ChunkWorld.CHUNK_SHIFT).is_equal(Chunk.CHUNK_SIZE)
    assert_int(ChunkWorld.CHUNK_MASK).is_equal(Chunk.CHUNK_SIZE - 1)
    assert_int(ChunkWorld.LOAD_RADIUS).is_equal(2)


# --- 좌표 변환 ---

func test_chunk_of_and_local_of() -> void:
    var cases: Array = [
        [0, 0, 0], [15, 0, 15], [16, 1, 0],
        [-1, -1, 15], [-16, -1, 0], [-17, -2, 15],
    ]
    for c: Array in cases:
        assert_int(ChunkWorld.chunk_of(c[0])).override_failure_message(
            "chunk_of(%d) != %d" % [c[0], c[1]]
        ).is_equal(c[1])
        assert_int(ChunkWorld.local_of(c[0])).override_failure_message(
            "local_of(%d) != %d" % [c[0], c[2]]
        ).is_equal(c[2])


# --- 초기 상태 ---

func test_initial_state() -> void:
    var world := _world()
    assert_bool(world.has_center()).is_false()
    assert_int(world.loaded_count()).is_equal(0)
    assert_int(world.snapshot_count()).is_equal(0)
    var fields := world.to_hash_fields()
    assert_array(fields[0]).is_equal(["chunks.has_center", 0])
    assert_array(fields[1]).is_equal(["chunks.center", "0,0"])
    assert_int(world.get_id_at(0, 0, Chunk.LAYER_GROUND)).is_equal(0)
    assert_int(world.get_durability_at(0, 0, Chunk.LAYER_GROUND)).is_equal(0)
    assert_bool(world.set_id_at(0, 0, Chunk.LAYER_GROUND, SET_ID, SET_D)).is_false()
    assert_bool(world.set_durability_at(0, 0, Chunk.LAYER_GROUND, 1)).is_false()
    assert_object(world.get_chunk(0, 0)).is_null()


# --- 로드 반경 ---

func test_set_center_loads_radius_square() -> void:
    var world := _world()
    world.set_center(0, 0)
    assert_bool(world.has_center()).is_true()
    assert_that(world.center()).is_equal(Vector2i(0, 0))
    assert_int(world.loaded_count()).is_equal(25)
    var keys := _loaded_keys(world)
    assert_int(keys.size()).is_equal(25)
    for cy in range(-2, 3):
        for cx in range(-2, 3):
            assert_bool(keys.has(Vector2i(cx, cy))).is_true()
            assert_bool(world.is_loaded(cx, cy)).is_true()
    assert_bool(world.is_loaded(3, 0)).is_false()
    assert_bool(world.is_loaded(0, -3)).is_false()


func test_set_center_is_idempotent() -> void:
    var world := _world()
    world.set_center(0, 0)
    var before := world.compute_hash()
    world.set_center(0, 0)
    assert_int(world.loaded_count()).is_equal(25)
    assert_int(world.snapshot_count()).is_equal(0)
    assert_str(world.compute_hash()).is_equal(before)


func test_move_center_one_column() -> void:
    var world := _world()
    world.set_center(0, 0)
    world.set_center(1, 0)
    assert_int(world.loaded_count()).is_equal(25)
    for cy in range(-2, 3):
        assert_bool(world.is_loaded(-2, cy)).is_false()
        assert_bool(world.is_loaded(3, cy)).is_true()
    assert_int(world.snapshot_count()).is_equal(0)
    _assert_invariant(world)


func test_move_center_diagonal_swaps_nine() -> void:
    var world := _world()
    world.set_center(0, 0)
    var before := _loaded_keys(world)
    world.set_center(1, 1)
    var after := _loaded_keys(world)
    assert_int(after.size()).is_equal(25)
    var gone := 0
    for key: Vector2i in before.keys():
        if not after.has(key):
            gone += 1
    var fresh := 0
    for key: Vector2i in after.keys():
        if not before.has(key):
            fresh += 1
    assert_int(gone).is_equal(9)
    assert_int(fresh).is_equal(9)
    assert_int(world.snapshot_count()).is_equal(0)


# --- 순수 생성 ---

func test_loaded_chunks_match_generator() -> void:
    var world := _world()
    var gen := _generator()
    world.set_center(0, 0)
    for cy in range(-2, 3):
        for cx in range(-2, 3):
            assert_str(world.get_chunk(cx, cy).digest()).is_equal(gen.generate(cx, cy).digest())
            assert_bool(world.get_chunk(cx, cy).is_dirty()).is_false()


# --- 월드 좌표 접근 ---

func test_world_coordinate_set_and_get() -> void:
    var world := _world()
    world.set_center(0, 0)
    var chunk := world.get_chunk(-1, 1)
    assert_object(chunk).is_not_null()
    var changed := world.set_id_at(-1, 17, Chunk.LAYER_GROUND, SET_ID, SET_D)
    assert_bool(changed).is_true()
    assert_int(world.get_id_at(-1, 17, Chunk.LAYER_GROUND)).is_equal(SET_ID)
    assert_int(world.get_durability_at(-1, 17, Chunk.LAYER_GROUND)).is_equal(SET_D)
    assert_int(chunk.get_id(15, 1, Chunk.LAYER_GROUND)).is_equal(SET_ID)
    assert_int(chunk.get_durability(15, 1, Chunk.LAYER_GROUND)).is_equal(SET_D)
    assert_bool(chunk.is_dirty()).is_true()
    # 경계를 넘는 인접 셀은 각각 다른 청크에 있다.
    for wy in range(0, 16):
        assert_int(world.get_id_at(15, wy, Chunk.LAYER_UNDER)).is_equal(
            world.get_chunk(0, 0).get_id(15, wy, Chunk.LAYER_UNDER))
        assert_int(world.get_id_at(16, wy, Chunk.LAYER_UNDER)).is_equal(
            world.get_chunk(1, 0).get_id(0, wy, Chunk.LAYER_UNDER))


func test_set_durability_at_routes_to_chunk() -> void:
    var world := _world()
    world.set_center(0, 0)
    # UNDER 는 전부 solid 라 내구도가 있다.
    var before := world.get_durability_at(-1, -1, Chunk.LAYER_UNDER)
    assert_int(before).is_greater(0)
    assert_bool(world.set_durability_at(-1, -1, Chunk.LAYER_UNDER, before - 1)).is_true()
    assert_int(world.get_durability_at(-1, -1, Chunk.LAYER_UNDER)).is_equal(before - 1)
    assert_int(world.get_chunk(-1, -1).get_durability(15, 15, Chunk.LAYER_UNDER)).is_equal(before - 1)
    assert_bool(world.set_durability_at(-1, -1, Chunk.LAYER_UNDER, before - 1)).is_false()


func test_unloaded_cell_reads_zero_and_rejects_writes() -> void:
    var world := _world()
    world.set_center(0, 0)
    assert_bool(world.is_loaded(ChunkWorld.chunk_of(100), 0)).is_false()
    assert_int(world.get_id_at(100, 0, Chunk.LAYER_UNDER)).is_equal(0)
    assert_int(world.get_durability_at(100, 0, Chunk.LAYER_UNDER)).is_equal(0)
    assert_bool(world.set_id_at(100, 0, Chunk.LAYER_UNDER, SET_ID, SET_D)).is_false()
    assert_bool(world.set_durability_at(100, 0, Chunk.LAYER_UNDER, 1)).is_false()
    assert_int(world.snapshot_count()).is_equal(0)


func test_unchanged_set_keeps_chunk_clean() -> void:
    var world := _world()
    world.set_center(0, 0)
    var id := world.get_id_at(5, 5, Chunk.LAYER_UNDER)
    var d := world.get_durability_at(5, 5, Chunk.LAYER_UNDER)
    assert_bool(world.set_id_at(5, 5, Chunk.LAYER_UNDER, id, d)).is_false()
    assert_bool(world.get_chunk(0, 0).is_dirty()).is_false()


# --- P7 왕복 ---

func test_p7_round_trip_preserves_edit_and_persist() -> void:
    var world := _world()
    world.set_center(0, 0)
    assert_bool(world.set_id_at(0, 0, Chunk.LAYER_GROUND, SET_ID, SET_D)).is_true()
    assert_bool(world.get_chunk(0, 0).is_dirty()).is_true()

    world.set_center(10, 10)
    assert_bool(world.is_loaded(0, 0)).is_false()
    assert_int(world.snapshot_count()).is_equal(1)
    assert_bool(_snapshot_keys(world).has(Vector2i(0, 0))).is_true()

    world.set_center(0, 0)
    assert_bool(world.is_loaded(0, 0)).is_true()
    assert_int(world.get_id_at(0, 0, Chunk.LAYER_GROUND)).is_equal(SET_ID)
    assert_int(world.get_durability_at(0, 0, Chunk.LAYER_GROUND)).is_equal(SET_D)
    assert_bool(world.get_chunk(0, 0).is_dirty()).is_false()
    assert_int(world.snapshot_count()).is_equal(0)
    _assert_invariant(world)

    # 변경 없이 다시 내보내도 persist 표지 덕에 스냅샷이 남는다.
    world.set_center(10, 10)
    assert_int(world.snapshot_count()).is_equal(1)
    world.set_center(0, 0)
    assert_int(world.get_id_at(0, 0, Chunk.LAYER_GROUND)).is_equal(SET_ID)
    assert_int(world.get_durability_at(0, 0, Chunk.LAYER_GROUND)).is_equal(SET_D)
    _assert_invariant(world)


# --- 경로 무관 해시 ---

func test_hash_is_path_independent_with_edit() -> void:
    var a := _world()
    a.set_center(0, 0)
    assert_bool(a.set_id_at(0, 0, Chunk.LAYER_GROUND, SET_ID, SET_D)).is_true()
    a.set_center(1, 0)
    a.set_center(0, 0)

    var b := _world()
    b.set_center(0, 0)
    assert_bool(b.set_id_at(0, 0, Chunk.LAYER_GROUND, SET_ID, SET_D)).is_true()

    assert_str(a.compute_hash()).is_equal(b.compute_hash())


func test_hash_is_path_independent_without_edit() -> void:
    var c := _world()
    c.set_center(0, 0)
    c.set_center(1, 0)
    c.set_center(0, 0)
    var d := _world()
    d.set_center(0, 0)
    assert_str(c.compute_hash()).is_equal(d.compute_hash())


func test_hash_differs_after_edit() -> void:
    var a := _world()
    a.set_center(0, 0)
    var before := a.compute_hash()
    assert_bool(a.set_id_at(0, 0, Chunk.LAYER_GROUND, SET_ID, SET_D)).is_true()
    assert_str(a.compute_hash()).is_not_equal(before)


## 인정된 한계(의도된 동작): 스냅샷에서 온 청크를 생성값으로 되돌려도 persist 표지 때문에
## 언로드 시 스냅샷이 남고, 언로드 상태의 해시는 순수 생성 세계와 다르다. Chunk 는 자기 출처를
## 모르고 ChunkWorld 는 생성값과 비교하지 않는다 — 비교하려면 언로드마다 재생성이 필요하다.
func test_limitation_reverted_snapshot_chunk_still_snapshots() -> void:
    var a := _world()
    a.set_center(0, 0)
    var orig_id := a.get_id_at(0, 0, Chunk.LAYER_GROUND)
    var orig_d := a.get_durability_at(0, 0, Chunk.LAYER_GROUND)
    assert_bool(a.set_id_at(0, 0, Chunk.LAYER_GROUND, SET_ID, SET_D)).is_true()
    a.set_center(10, 10)
    a.set_center(0, 0)
    assert_bool(a.set_id_at(0, 0, Chunk.LAYER_GROUND, orig_id, orig_d)).is_true()
    assert_str(a.get_chunk(0, 0).digest()).is_equal(_generator().generate(0, 0).digest())
    a.set_center(10, 10)
    assert_int(a.snapshot_count()).is_equal(1)

    var d := _world()
    d.set_center(10, 10)
    assert_int(d.snapshot_count()).is_equal(0)
    assert_str(a.compute_hash()).is_not_equal(d.compute_hash())


# --- restore_snapshot ---

func _edited_bytes(cx: int, cy: int) -> PackedByteArray:
    var chunk := _generator().generate(cx, cy)
    assert_bool(chunk.set_id(3, 4, Chunk.LAYER_UPPER, 4, 12)).is_true()
    return chunk.to_bytes()


func test_restore_snapshot_valid_then_load_and_persist() -> void:
    var world := _world()
    var bytes := _edited_bytes(0, 0)
    assert_bool(world.restore_snapshot(0, 0, bytes)).is_true()
    assert_int(world.snapshot_count()).is_equal(1)
    assert_int(world.loaded_count()).is_equal(0)

    world.set_center(0, 0)
    assert_int(world.snapshot_count()).is_equal(0)
    assert_int(world.get_id_at(3, 4, Chunk.LAYER_UPPER)).is_equal(4)
    assert_int(world.get_durability_at(3, 4, Chunk.LAYER_UPPER)).is_equal(12)
    assert_bool(world.get_chunk(0, 0).is_dirty()).is_false()
    _assert_invariant(world)

    # persist 가 켜져 있어 변경 없이 언로드해도 스냅샷이 다시 생긴다.
    world.set_center(10, 10)
    assert_int(world.snapshot_count()).is_equal(1)
    var entry: Array = world.snapshots_sorted()[0]
    assert_that(entry[0]).is_equal(Vector2i(0, 0))
    assert_array(entry[1]).is_equal(bytes)


func test_restore_snapshot_copies_bytes() -> void:
    var world := _world()
    var bytes := _edited_bytes(0, 0)
    assert_bool(world.restore_snapshot(0, 0, bytes)).is_true()
    var expected := bytes.duplicate()
    bytes[0] = 255
    var entry: Array = world.snapshots_sorted()[0]
    assert_array(entry[1]).is_equal(expected)


func test_restore_snapshot_rejects_loaded_key() -> void:
    var world := _world()
    world.set_center(0, 0)
    assert_bool(world.restore_snapshot(0, 0, _edited_bytes(0, 0))).is_false()
    assert_int(world.snapshot_count()).is_equal(0)
    assert_bool(world.restore_snapshot(5, 5, _edited_bytes(5, 5))).is_true()
    assert_int(world.snapshot_count()).is_equal(1)
    _assert_invariant(world)


func test_restore_snapshot_rejects_wrong_length() -> void:
    var world := _world()
    var short := PackedByteArray()
    short.resize(Chunk.BYTE_COUNT - 1)
    assert_bool(world.restore_snapshot(0, 0, short)).is_false()
    var long := PackedByteArray()
    long.resize(Chunk.BYTE_COUNT + 1)
    assert_bool(world.restore_snapshot(0, 0, long)).is_false()
    assert_bool(world.restore_snapshot(0, 0, PackedByteArray())).is_false()
    assert_int(world.snapshot_count()).is_equal(0)


func test_restore_snapshot_rejects_non_canonical() -> void:
    var world := _world()
    var bytes := PackedByteArray()
    bytes.resize(Chunk.BYTE_COUNT)
    # id 0 인 셀에 내구도 — 정규형 위반.
    bytes[Chunk.CELL_COUNT] = 1
    assert_bool(world.restore_snapshot(0, 0, bytes)).is_false()
    assert_int(world.snapshot_count()).is_equal(0)


# --- 정렬 ---

func test_sort_keys_is_y_then_x() -> void:
    var sorted := ChunkWorld._sort_keys([Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)])
    assert_array(sorted).is_equal([Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)])
    var mixed := ChunkWorld._sort_keys([Vector2i(0, 0), Vector2i(0, -1), Vector2i(-5, 0), Vector2i(3, -1)])
    assert_array(mixed).is_equal([Vector2i(0, -1), Vector2i(3, -1), Vector2i(-5, 0), Vector2i(0, 0)])


func test_snapshots_sorted_order() -> void:
    var world := _world()
    for key: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
        assert_bool(world.restore_snapshot(key.x, key.y, _edited_bytes(key.x, key.y))).is_true()
    var keys: Array = []
    for entry: Array in world.snapshots_sorted():
        keys.append(entry[0])
    assert_array(keys).is_equal([Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)])


func test_loaded_sorted_order() -> void:
    var world := _world()
    world.set_center(0, 0)
    var entries := world.loaded_sorted()
    assert_int(entries.size()).is_equal(25)
    var index := 0
    for cy in range(-2, 3):
        for cx in range(-2, 3):
            var entry: Array = entries[index]
            assert_that(entry[0]).is_equal(Vector2i(cx, cy))
            assert_object(entry[1]).is_same(world.get_chunk(cx, cy))
            index += 1


# --- 해시 필드 ---

func test_hash_fields_order_and_names() -> void:
    var world := _world()
    world.set_center(0, 0)
    assert_bool(world.restore_snapshot(7, 7, _edited_bytes(7, 7))).is_true()
    var fields := world.to_hash_fields()
    assert_int(fields.size()).is_equal(3 + 25 + 1 + 1)
    assert_array(fields[0]).is_equal(["chunks.has_center", 1])
    assert_array(fields[1]).is_equal(["chunks.center", "0,0"])
    assert_array(fields[2]).is_equal(["chunks.loaded", 25])
    assert_str(fields[3][0]).is_equal("chunk.-2,-2")
    assert_str(fields[3][1]).is_equal(world.get_chunk(-2, -2).digest())
    assert_str(fields[4][0]).is_equal("chunk.-1,-2")
    assert_str(fields[8][0]).is_equal("chunk.-2,-1")
    assert_str(fields[27][0]).is_equal("chunk.2,2")
    assert_array(fields[28]).is_equal(["chunks.snapshots", 1])
    assert_str(fields[29][0]).is_equal("snapshot.7,7")
    assert_str(fields[29][1]).is_equal(SimHash.hash_bytes(_edited_bytes(7, 7)))
    assert_str(world.compute_hash()).is_equal(SimHash.hash_fields(fields))


func test_center_field_uses_plain_ints() -> void:
    var world := _world()
    world.set_center(-3, 5)
    assert_array(world.to_hash_fields()[1]).is_equal(["chunks.center", "-3,5"])


func test_dirty_flag_does_not_affect_hash() -> void:
    var world := _world()
    world.set_center(0, 0)
    assert_bool(world.set_id_at(0, 0, Chunk.LAYER_GROUND, SET_ID, SET_D)).is_true()
    var dirty_hash := world.compute_hash()
    world.get_chunk(0, 0).clear_dirty()
    assert_str(world.compute_hash()).is_equal(dirty_hash)


# --- 불변식 ---

func test_invariant_after_many_moves() -> void:
    var world := _world()
    world.set_center(0, 0)
    assert_bool(world.set_id_at(0, 0, Chunk.LAYER_GROUND, SET_ID, SET_D)).is_true()
    assert_bool(world.set_id_at(-30, 20, Chunk.LAYER_GROUND, SET_ID, SET_D)).is_true()
    for c: Array in [[3, 0], [3, 3], [-2, 3], [-6, -6], [0, 0], [10, 10], [-1, 1], [0, 0]]:
        world.set_center(c[0], c[1])
        assert_int(world.loaded_count()).is_equal(25)
        _assert_invariant(world)
    assert_int(world.get_id_at(0, 0, Chunk.LAYER_GROUND)).is_equal(SET_ID)
    assert_int(world.get_id_at(-30, 20, Chunk.LAYER_GROUND)).is_equal(SET_ID)


# --- 소스 가드 ---

func test_source_has_no_forbidden_tokens() -> void:
    var source := FileAccess.get_file_as_string("res://sim/chunk_world.gd")
    assert_str(source).is_not_empty()
    for token: String in ["float", "randi", "randf", "FileAccess", "JSON", ">> 4", "& 15", "name_of("]:
        assert_bool(source.contains(token)).override_failure_message(
            "chunk_world.gd 에 금지 토큰 '%s' 가 있다" % token
        ).is_false()


# --- Node 아님 ---

func test_world_is_not_a_node() -> void:
    var world: Variant = _world()
    assert_str(world.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(world.get_class(), "Node")).is_false()
    assert_bool(world is Node).is_false()
    assert_bool(world is RefCounted).is_true()
