extends GdUnitTestSuite

## 청크 검증: 인덱스 공식, 빈 청크, 왕복, 정규형, 거부, dirty 계약, 바이트 레이아웃, digest, Node 아님.


## 왕복·레이아웃 테스트가 공유하는 셀 세팅. [x, y, layer, id, durability].
func _sample_cells() -> Array:
    return [
        [0, 0, Chunk.LAYER_UNDER, 2, 20],
        [15, 0, Chunk.LAYER_UNDER, 1, 8],
        [0, 15, Chunk.LAYER_GROUND, 3, 6],
        [7, 9, Chunk.LAYER_GROUND, 4, 1],
        [15, 15, Chunk.LAYER_UPPER, 5, 255],
        [3, 3, Chunk.LAYER_UPPER, 255, 0],
    ]


func _filled() -> Chunk:
    var chunk := Chunk.empty()
    for cell: Array in _sample_cells():
        chunk.set_id(cell[0], cell[1], cell[2], cell[3], cell[4])
    return chunk


func _all_zero(bytes: PackedByteArray) -> bool:
    for b in bytes:
        if b != 0:
            return false
    return true


# --- 상수 ---

func test_constants_agree() -> void:
    assert_int(Chunk.CHUNK_SIZE).is_equal(16)
    assert_int(Chunk.LAYERS).is_equal(3)
    assert_int(Chunk.LAYER_UNDER).is_equal(0)
    assert_int(Chunk.LAYER_GROUND).is_equal(1)
    assert_int(Chunk.LAYER_UPPER).is_equal(2)
    assert_int(Chunk.CELL_COUNT).is_equal(Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE * Chunk.LAYERS)
    assert_int(Chunk.CELL_COUNT).is_equal(768)
    assert_int(Chunk.BYTE_COUNT).is_equal(Chunk.CELL_COUNT * 2)
    assert_int(Chunk.BYTE_COUNT).is_equal(1536)


# --- 인덱스 공식 ---

func test_index_formula() -> void:
    assert_int(Chunk.index_of(0, 0, 0)).is_equal(0)
    assert_int(Chunk.index_of(15, 0, 0)).is_equal(15)
    assert_int(Chunk.index_of(0, 1, 0)).is_equal(16)
    assert_int(Chunk.index_of(0, 0, 1)).is_equal(256)
    assert_int(Chunk.index_of(15, 15, 2)).is_equal(767)


func test_index_covers_every_cell_once() -> void:
    var seen := PackedByteArray()
    seen.resize(Chunk.CELL_COUNT)
    for layer in Chunk.LAYERS:
        for y in Chunk.CHUNK_SIZE:
            for x in Chunk.CHUNK_SIZE:
                var index := Chunk.index_of(x, y, layer)
                assert_bool(Chunk.in_bounds(x, y, layer)).is_true()
                assert_int(index).is_between(0, Chunk.CELL_COUNT - 1)
                assert_int(seen[index]).is_equal(0)
                seen[index] = 1


func test_out_of_bounds_index_is_minus_one() -> void:
    var cases: Array = [
        [-1, 0, 0], [16, 0, 0],
        [0, -1, 0], [0, 16, 0],
        [0, 0, -1], [0, 0, 3],
        [16, 16, 3], [-1, -1, -1], [1000, 0, 0],
    ]
    for c: Array in cases:
        assert_int(Chunk.index_of(c[0], c[1], c[2])).override_failure_message(
            "index_of(%d, %d, %d) 가 -1 이 아니다" % c
        ).is_equal(-1)
        assert_bool(Chunk.in_bounds(c[0], c[1], c[2])).override_failure_message(
            "in_bounds(%d, %d, %d) 가 true 다" % c
        ).is_false()


# --- empty ---

func test_empty_is_all_zero_and_clean() -> void:
    var chunk := Chunk.empty()
    assert_object(chunk).is_not_null()
    assert_bool(chunk.is_dirty()).is_false()
    for layer in Chunk.LAYERS:
        for y in Chunk.CHUNK_SIZE:
            for x in Chunk.CHUNK_SIZE:
                assert_int(chunk.get_id(x, y, layer)).is_equal(0)
                assert_int(chunk.get_durability(x, y, layer)).is_equal(0)
    var bytes := chunk.to_bytes()
    assert_int(bytes.size()).is_equal(Chunk.BYTE_COUNT)
    assert_bool(_all_zero(bytes)).is_true()


# --- 왕복 ---

func test_set_and_get_round_trip() -> void:
    var chunk := Chunk.empty()
    assert_bool(chunk.set_id(3, 4, Chunk.LAYER_GROUND, 2, 20)).is_true()
    assert_int(chunk.get_id(3, 4, Chunk.LAYER_GROUND)).is_equal(2)
    assert_int(chunk.get_durability(3, 4, Chunk.LAYER_GROUND)).is_equal(20)
    # 다른 층의 같은 x,y 는 건드리지 않았다.
    assert_int(chunk.get_id(3, 4, Chunk.LAYER_UNDER)).is_equal(0)
    assert_int(chunk.get_id(3, 4, Chunk.LAYER_UPPER)).is_equal(0)
    # 경계값.
    assert_bool(chunk.set_id(15, 15, Chunk.LAYER_UPPER, 255, 255)).is_true()
    assert_int(chunk.get_id(15, 15, Chunk.LAYER_UPPER)).is_equal(255)
    assert_int(chunk.get_durability(15, 15, Chunk.LAYER_UPPER)).is_equal(255)


func test_out_of_bounds_get_is_zero() -> void:
    var chunk := _filled()
    assert_int(chunk.get_id(-1, 0, 0)).is_equal(0)
    assert_int(chunk.get_id(16, 0, 0)).is_equal(0)
    assert_int(chunk.get_id(0, 0, 3)).is_equal(0)
    assert_int(chunk.get_durability(-1, 0, 0)).is_equal(0)
    assert_int(chunk.get_durability(0, 16, 0)).is_equal(0)
    assert_int(chunk.get_durability(0, 0, -1)).is_equal(0)


# --- 정규형 ---

func test_air_discards_durability() -> void:
    var chunk := Chunk.empty()
    chunk.set_id(1, 1, 0, 2, 20)
    assert_bool(chunk.set_id(1, 1, 0, 0, 7)).is_true()
    assert_int(chunk.get_id(1, 1, 0)).is_equal(0)
    assert_int(chunk.get_durability(1, 1, 0)).is_equal(0)
    assert_bool(_all_zero(chunk.to_bytes())).is_true()


func test_set_durability_on_air_is_rejected() -> void:
    var chunk := Chunk.empty()
    assert_bool(chunk.set_durability(1, 1, 0, 5)).is_false()
    assert_int(chunk.get_durability(1, 1, 0)).is_equal(0)
    assert_bool(chunk.is_dirty()).is_false()
    assert_bool(_all_zero(chunk.to_bytes())).is_true()


func test_set_durability_changes_only_durability() -> void:
    var chunk := Chunk.empty()
    chunk.set_id(2, 2, 1, 2, 20)
    chunk.clear_dirty()
    assert_bool(chunk.set_durability(2, 2, 1, 19)).is_true()
    assert_int(chunk.get_id(2, 2, 1)).is_equal(2)
    assert_int(chunk.get_durability(2, 2, 1)).is_equal(19)


# --- 거부 ---

func test_rejects_out_of_range_values_without_wraparound() -> void:
    var chunk := Chunk.empty()
    var before := chunk.to_bytes()
    assert_bool(chunk.set_id(0, 0, 0, 256, 1)).is_false()
    assert_bool(chunk.set_id(0, 0, 0, -1, 1)).is_false()
    assert_bool(chunk.set_id(0, 0, 0, 1, 256)).is_false()
    assert_bool(chunk.set_id(0, 0, 0, 1, -1)).is_false()
    assert_bool(chunk.set_id(0, 0, 0, 1000, 1000)).is_false()
    assert_bool(chunk.is_dirty()).is_false()
    # 256 이 0 으로 접혀 들어갔다면 id 는 0 이지만 durability 1 이 남아 바이트가 달라진다.
    assert_array(chunk.to_bytes()).is_equal(before)
    assert_bool(_all_zero(chunk.to_bytes())).is_true()


func test_rejects_out_of_range_durability_on_block() -> void:
    var chunk := Chunk.empty()
    chunk.set_id(0, 0, 0, 2, 20)
    chunk.clear_dirty()
    var before := chunk.to_bytes()
    assert_bool(chunk.set_durability(0, 0, 0, 256)).is_false()
    assert_bool(chunk.set_durability(0, 0, 0, -1)).is_false()
    assert_int(chunk.get_durability(0, 0, 0)).is_equal(20)
    assert_bool(chunk.is_dirty()).is_false()
    assert_array(chunk.to_bytes()).is_equal(before)


func test_rejects_out_of_bounds_set() -> void:
    var chunk := Chunk.empty()
    var before := chunk.to_bytes()
    assert_bool(chunk.set_id(-1, 0, 0, 1, 1)).is_false()
    assert_bool(chunk.set_id(16, 0, 0, 1, 1)).is_false()
    assert_bool(chunk.set_id(0, 16, 0, 1, 1)).is_false()
    assert_bool(chunk.set_id(0, 0, 3, 1, 1)).is_false()
    assert_bool(chunk.set_durability(-1, 0, 0, 1)).is_false()
    assert_bool(chunk.set_durability(0, 0, 3, 1)).is_false()
    assert_bool(chunk.is_dirty()).is_false()
    assert_array(chunk.to_bytes()).is_equal(before)


# --- dirty 계약 ---

func test_dirty_contract_for_set_id() -> void:
    var chunk := Chunk.empty()
    assert_bool(chunk.is_dirty()).is_false()
    assert_bool(chunk.set_id(1, 2, 0, 2, 20)).is_true()
    assert_bool(chunk.is_dirty()).is_true()
    chunk.clear_dirty()
    assert_bool(chunk.is_dirty()).is_false()
    # 같은 값 재대입은 변화가 아니다.
    assert_bool(chunk.set_id(1, 2, 0, 2, 20)).is_false()
    assert_bool(chunk.is_dirty()).is_false()
    # id 는 같고 durability 만 다르면 변화다.
    assert_bool(chunk.set_id(1, 2, 0, 2, 19)).is_true()
    assert_bool(chunk.is_dirty()).is_true()


func test_air_to_air_is_not_a_change() -> void:
    var chunk := Chunk.empty()
    assert_bool(chunk.set_id(5, 5, 1, 0, 7)).is_false()
    assert_bool(chunk.is_dirty()).is_false()
    assert_bool(_all_zero(chunk.to_bytes())).is_true()


func test_dirty_contract_for_set_durability() -> void:
    var chunk := Chunk.empty()
    chunk.set_id(1, 2, 0, 2, 20)
    chunk.clear_dirty()
    assert_bool(chunk.set_durability(1, 2, 0, 19)).is_true()
    assert_bool(chunk.is_dirty()).is_true()
    chunk.clear_dirty()
    assert_bool(chunk.set_durability(1, 2, 0, 19)).is_false()
    assert_bool(chunk.is_dirty()).is_false()


# --- 바이트 왕복 ---

func test_bytes_round_trip() -> void:
    var original := _filled()
    var bytes := original.to_bytes()
    var restored := Chunk.from_bytes(bytes)
    assert_object(restored).is_not_null()
    assert_bool(restored.is_dirty()).is_false()
    for layer in Chunk.LAYERS:
        for y in Chunk.CHUNK_SIZE:
            for x in Chunk.CHUNK_SIZE:
                assert_int(restored.get_id(x, y, layer)).is_equal(original.get_id(x, y, layer))
                assert_int(restored.get_durability(x, y, layer)).is_equal(original.get_durability(x, y, layer))
    assert_str(restored.digest()).is_equal(original.digest())
    assert_array(restored.to_bytes()).is_equal(bytes)


func test_from_bytes_copies_input() -> void:
    # 입력 배열을 나중에 고쳐도 청크는 흔들리지 않는다.
    var bytes := _filled().to_bytes()
    var chunk := Chunk.from_bytes(bytes)
    var digest := chunk.digest()
    bytes[0] = 9
    assert_str(chunk.digest()).is_equal(digest)


# --- 바이트 레이아웃 ---

func test_bytes_layout_ids_then_durability() -> void:
    var chunk := _filled()
    var bytes := chunk.to_bytes()
    var ids := bytes.slice(0, Chunk.CELL_COUNT)
    var durability := bytes.slice(Chunk.CELL_COUNT, Chunk.BYTE_COUNT)
    assert_int(ids.size()).is_equal(Chunk.CELL_COUNT)
    assert_int(durability.size()).is_equal(Chunk.CELL_COUNT)
    for layer in Chunk.LAYERS:
        for y in Chunk.CHUNK_SIZE:
            for x in Chunk.CHUNK_SIZE:
                var index := Chunk.index_of(x, y, layer)
                assert_int(ids[index]).is_equal(chunk.get_id(x, y, layer))
                assert_int(durability[index]).is_equal(chunk.get_durability(x, y, layer))
    for cell: Array in _sample_cells():
        var index := Chunk.index_of(cell[0], cell[1], cell[2])
        assert_int(ids[index]).is_equal(cell[3])
        assert_int(durability[index]).is_equal(cell[4])


func test_swapped_halves_have_different_digest() -> void:
    # 모든 셀 id 가 0 이 아니게 채워 뒤바꾼 열도 정규형을 지키게 한다.
    var chunk := Chunk.empty()
    for layer in Chunk.LAYERS:
        for y in Chunk.CHUNK_SIZE:
            for x in Chunk.CHUNK_SIZE:
                chunk.set_id(x, y, layer, 1 + (x + y + layer) % 200, 1 + (x * 3 + y) % 250)
    var bytes := chunk.to_bytes()
    var swapped := PackedByteArray()
    swapped.append_array(bytes.slice(Chunk.CELL_COUNT, Chunk.BYTE_COUNT))
    swapped.append_array(bytes.slice(0, Chunk.CELL_COUNT))
    var other := Chunk.from_bytes(swapped)
    assert_object(other).is_not_null()
    assert_str(other.digest()).is_not_equal(chunk.digest())
    assert_str(SimHash.hash_bytes(swapped)).is_not_equal(SimHash.hash_bytes(bytes))


# --- from_bytes 거부 ---

func test_from_bytes_rejects_wrong_length() -> void:
    for size: int in [0, 1535, 1537, 768]:
        var bytes := PackedByteArray()
        bytes.resize(size)
        assert_object(Chunk.from_bytes(bytes)).override_failure_message(
            "길이 %d 를 받아들였다" % size
        ).is_null()


func test_from_bytes_rejects_air_with_durability() -> void:
    var bytes := PackedByteArray()
    bytes.resize(Chunk.BYTE_COUNT)
    bytes[Chunk.CELL_COUNT + Chunk.index_of(4, 4, 1)] = 5
    assert_object(Chunk.from_bytes(bytes)).is_null()
    # 같은 위치에 id 를 넣으면 정규형이 지켜져 받아들인다.
    bytes[Chunk.index_of(4, 4, 1)] = 1
    assert_object(Chunk.from_bytes(bytes)).is_not_null()


# --- digest ---

func test_digest_is_fixed_length_hex() -> void:
    var digest := Chunk.empty().digest()
    assert_str(digest).has_length(64)
    assert_bool(digest.is_valid_hex_number(false)).is_true()
    assert_str(digest).is_equal(SimHash.hash_bytes(Chunk.empty().to_bytes()))


func test_same_content_same_digest() -> void:
    assert_str(_filled().digest()).is_equal(_filled().digest())
    assert_str(Chunk.empty().digest()).is_equal(Chunk.empty().digest())


func test_one_cell_changes_digest() -> void:
    var a := _filled()
    var b := _filled()
    b.set_durability(0, 0, Chunk.LAYER_UNDER, 19)
    assert_str(b.digest()).is_not_equal(a.digest())
    var c := _filled()
    c.set_id(8, 8, Chunk.LAYER_UPPER, 1, 8)
    assert_str(c.digest()).is_not_equal(a.digest())


func test_digest_ignores_dirty() -> void:
    var chunk := _filled()
    assert_bool(chunk.is_dirty()).is_true()
    var while_dirty := chunk.digest()
    chunk.clear_dirty()
    assert_str(chunk.digest()).is_equal(while_dirty)


# --- Node 아님 ---

func test_chunk_is_not_a_node() -> void:
    # 정적 타입이 Chunk 면 `is Node` 가 파싱 단계에서 막히므로 Variant 로 풀어 런타임에 묻는다.
    var chunk: Variant = Chunk.new()
    assert_str(chunk.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(chunk.get_class(), "Node")).is_false()
    assert_bool(chunk is Node).is_false()
    assert_bool(chunk is RefCounted).is_true()
