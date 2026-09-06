extends GdUnitTestSuite

## 청크 생성기 검증: 결정론(시드·좌표·순서), 격자 규칙, 층 규칙, 내구도, dirty, 소스 가드,
## cell_hash 성질, 골든 지형 해시, Node 아님.


## 골든 지형 해시: seed 20250901, 청크 (0,0) 의 digest.
## 지형 규칙·표(data/terrain.json)·blocks.json 내구도가 바뀌면 바뀐다 — 의도된 신호.
## 바뀌면 DECISIONS 에 이유를 적고 갱신한다.
const GOLDEN_SEED := 20250901
const GOLDEN_TERRAIN_HASH := "c4ae1a1b63bb00c84028c0ee13fd2c0430b0d199955a0a7a5ec6301170a61149"

## 지상층 air 비율의 허용 범위(퍼밀). 표 기준 기대값 ≈ 440 (지대 절반 air × (1 − 30/256)).
const AIR_PERMILLE_MIN := 300
const AIR_PERMILLE_MAX := 600


func _registry() -> BlockRegistry:
    return BlockRegistry.load_default()


func _make(seed: int) -> ChunkGenerator:
    var registry := _registry()
    var terrain := TerrainTable.load_default(registry)
    assert_object(registry).is_not_null()
    assert_object(terrain).is_not_null()
    return ChunkGenerator.new(seed, registry, terrain)


func _make_with_table(seed: int, table: Dictionary) -> ChunkGenerator:
    var registry := _registry()
    var terrain := TerrainTable.from_text(JSON.stringify(table), registry)
    assert_object(terrain).is_not_null()
    return ChunkGenerator.new(seed, registry, terrain)


## 층 하나의 id 집합을 셀 수와 함께 돌려준다. [id → 셀 수].
func _layer_histogram(chunk: Chunk, layer: int) -> Dictionary:
    var histogram: Dictionary = {}
    for y in Chunk.CHUNK_SIZE:
        for x in Chunk.CHUNK_SIZE:
            var id := chunk.get_id(x, y, layer)
            histogram[id] = histogram.get(id, 0) + 1
    return histogram


# --- 결정론 ---

func test_same_seed_and_coords_same_digest() -> void:
    var a := _make(7).generate(3, -2)
    var b := _make(7).generate(3, -2)
    assert_str(a.digest()).is_equal(b.digest())
    assert_array(a.to_bytes()).is_equal(b.to_bytes())
    var gen := _make(7)
    assert_str(gen.generate(3, -2).digest()).is_equal(gen.generate(3, -2).digest())


func test_different_seed_different_digest() -> void:
    assert_str(_make(7).generate(0, 0).digest()).is_not_equal(_make(8).generate(0, 0).digest())


func test_different_chunk_coords_different_digest() -> void:
    var gen := _make(7)
    var origin := gen.generate(0, 0).digest()
    assert_str(gen.generate(1, 0).digest()).is_not_equal(origin)
    assert_str(gen.generate(0, 1).digest()).is_not_equal(origin)
    assert_str(gen.generate(-1, 0).digest()).is_not_equal(origin)


func test_generation_order_does_not_matter() -> void:
    var a := _make(11)
    var a00 := a.generate(0, 0).digest()
    var a10 := a.generate(1, 0).digest()
    var b := _make(11)
    var b10 := b.generate(1, 0).digest()
    var b00 := b.generate(0, 0).digest()
    assert_str(a00).is_equal(b00)
    assert_str(a10).is_equal(b10)


func test_seed_zero_origin_is_not_degenerate() -> void:
    var chunk := _make(0).generate(0, 0)
    var histogram := _layer_histogram(chunk, Chunk.LAYER_UNDER)
    assert_int(histogram.size()).is_equal(2)
    assert_bool(histogram.has(2)).is_true()
    assert_bool(histogram.has(1)).is_true()
    assert_str(chunk.digest()).is_not_equal(_make(1).generate(0, 0).digest())


# --- 음수 청크 ---

func test_negative_chunk_generates_with_max_durability() -> void:
    var registry := _registry()
    var chunk := _make(5).generate(-1, -1)
    assert_object(chunk).is_not_null()
    for layer in Chunk.LAYERS:
        for y in Chunk.CHUNK_SIZE:
            for x in Chunk.CHUNK_SIZE:
                var id := chunk.get_id(x, y, layer)
                assert_int(chunk.get_durability(x, y, layer)).is_equal(registry.max_durability(id))


# --- 격자 규칙 ---

func test_arithmetic_shift_floors_negative() -> void:
    # 상수식 `-1 >> 3` 은 GDScript 파서의 상수 접기가 거부하므로 런타임 값으로 확인한다.
    # 생성기가 의존하는 것은 런타임 동작이다.
    var shift := ChunkGenerator.ZONE_SHIFT
    var cases: Array = [[-1, -1], [-8, -1], [-9, -2], [-16, -2], [0, 0], [7, 0], [8, 1], [15, 1], [16, 2]]
    for c: Array in cases:
        var value: int = c[0]
        assert_int(value >> shift).override_failure_message(
            "%d >> %d 가 %d 가 아니다" % [value, shift, c[1]]
        ).is_equal(c[1])


func _expected_under(seed: int, wx: int, wy: int, terrain: TerrainTable) -> int:
    var h := ChunkGenerator.cell_hash(seed, wx >> 3, wy >> 3, ChunkGenerator.SALT_UNDER_ZONE)
    return terrain.under_zone(ChunkGenerator.pick(h, terrain.under_zone_count()))


func test_under_layer_follows_zone_grid() -> void:
    var seed := 31
    var registry := _registry()
    var terrain := TerrainTable.load_default(registry)
    var gen := ChunkGenerator.new(seed, registry, terrain)
    # 청크 경계 양쪽과 음수 청크 경계를 포함한 (cx, cy, x, y).
    var cases: Array = [
        [0, 0, 15, 0], [1, 0, 0, 0],
        [0, 0, 0, 15], [0, 1, 0, 0],
        [-1, -1, 15, 15], [-1, -1, 0, 0], [-1, -1, 7, 8], [-1, -1, 8, 7],
        [0, 0, 7, 7], [0, 0, 8, 8],
    ]
    for c: Array in cases:
        var chunk := gen.generate(c[0], c[1])
        var wx: int = c[0] * Chunk.CHUNK_SIZE + c[2]
        var wy: int = c[1] * Chunk.CHUNK_SIZE + c[3]
        assert_int(chunk.get_id(c[2], c[3], Chunk.LAYER_UNDER)).override_failure_message(
            "청크 (%d,%d) 셀 (%d,%d) 의 UNDER id 가 격자 규칙과 다르다" % c
        ).is_equal(_expected_under(seed, wx, wy, terrain))
    # 전 셀 검사도 한 청크에 대해 한다.
    var chunk := gen.generate(-1, -1)
    for y in Chunk.CHUNK_SIZE:
        for x in Chunk.CHUNK_SIZE:
            var wx := -Chunk.CHUNK_SIZE + x
            var wy := -Chunk.CHUNK_SIZE + y
            assert_int(chunk.get_id(x, y, Chunk.LAYER_UNDER)).is_equal(_expected_under(seed, wx, wy, terrain))


func test_under_zone_is_uniform_within_a_grid_cell() -> void:
    # 굵은 격자 8×8 안의 셀은 같은 지대 값을 갖는다. 청크 (0,0) 은 격자 4칸으로 딱 나뉜다.
    var chunk := _make(31).generate(0, 0)
    for zy in 2:
        for zx in 2:
            var first := chunk.get_id(zx * 8, zy * 8, Chunk.LAYER_UNDER)
            for y in 8:
                for x in 8:
                    assert_int(chunk.get_id(zx * 8 + x, zy * 8 + y, Chunk.LAYER_UNDER)).is_equal(first)


func test_generate_matches_id_at_helpers() -> void:
    var gen := _make(31)
    var chunk := gen.generate(2, -3)
    for y in Chunk.CHUNK_SIZE:
        for x in Chunk.CHUNK_SIZE:
            var wx := 2 * Chunk.CHUNK_SIZE + x
            var wy := -3 * Chunk.CHUNK_SIZE + y
            assert_int(chunk.get_id(x, y, Chunk.LAYER_UNDER)).is_equal(gen.under_id_at(wx, wy))
            assert_int(chunk.get_id(x, y, Chunk.LAYER_GROUND)).is_equal(gen.ground_id_at(wx, wy))


func test_ground_cell_follows_scatter_thresholds() -> void:
    var seed := 31
    var registry := _registry()
    var terrain := TerrainTable.load_default(registry)
    var gen := ChunkGenerator.new(seed, registry, terrain)
    var chunk := gen.generate(0, 0)
    for y in Chunk.CHUNK_SIZE:
        for x in Chunk.CHUNK_SIZE:
            var zone_hash := ChunkGenerator.cell_hash(seed, x >> 3, y >> 3, ChunkGenerator.SALT_GROUND_ZONE)
            var expected := terrain.ground_zone(ChunkGenerator.pick(zone_hash, terrain.ground_zone_count()))
            var roll := ChunkGenerator.cell_hash(seed, x, y, ChunkGenerator.SALT_SCATTER) & 255
            var acc := 0
            for i in terrain.scatter_count():
                if roll < acc + terrain.scatter_per_256(i):
                    expected = terrain.scatter_id(i)
                    break
                acc += terrain.scatter_per_256(i)
            assert_int(chunk.get_id(x, y, Chunk.LAYER_GROUND)).is_equal(expected)


func test_scatter_with_full_density_covers_every_ground_cell() -> void:
    var table := {
        "under_zones": [2],
        "ground_zones": [0],
        "ground_scatter": [{"id": 4, "per_256": 256}],
    }
    var chunk := _make_with_table(3, table).generate(0, 0)
    var histogram := _layer_histogram(chunk, Chunk.LAYER_GROUND)
    assert_int(histogram.size()).is_equal(1)
    assert_int(histogram.get(4, 0)).is_equal(256)
    assert_int(_layer_histogram(chunk, Chunk.LAYER_UNDER).get(2, 0)).is_equal(256)


func test_scatter_with_zero_density_leaves_zone_only() -> void:
    var table := {
        "under_zones": [1],
        "ground_zones": [3],
        "ground_scatter": [{"id": 4, "per_256": 0}],
    }
    var chunk := _make_with_table(3, table).generate(0, 0)
    assert_int(_layer_histogram(chunk, Chunk.LAYER_GROUND).get(3, 0)).is_equal(256)


# --- 층 규칙 ---

func test_layer_rules_over_many_chunks() -> void:
    var registry := _registry()
    var gen := _make(20250901)
    var ground_cells := 0
    var air_cells := 0
    for cy in range(-2, 2):
        for cx in range(-2, 2):
            var chunk := gen.generate(cx, cy)
            for y in Chunk.CHUNK_SIZE:
                for x in Chunk.CHUNK_SIZE:
                    var under := chunk.get_id(x, y, Chunk.LAYER_UNDER)
                    assert_bool(registry.has_at(under, BlockRegistry.ATTR_SOLID)).is_true()
                    assert_int(chunk.get_durability(x, y, Chunk.LAYER_UNDER)).is_equal(registry.max_durability(under))
                    assert_int(chunk.get_id(x, y, Chunk.LAYER_UPPER)).is_equal(0)
                    assert_int(chunk.get_durability(x, y, Chunk.LAYER_UPPER)).is_equal(0)
                    var ground := chunk.get_id(x, y, Chunk.LAYER_GROUND)
                    assert_int(chunk.get_durability(x, y, Chunk.LAYER_GROUND)).is_equal(registry.max_durability(ground))
                    ground_cells += 1
                    if ground == 0:
                        air_cells += 1
                    else:
                        assert_bool(registry.has_at(ground, BlockRegistry.ATTR_SOLID)).is_true()
    assert_int(ground_cells).is_equal(16 * Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE)
    var permille := air_cells * 1000 / ground_cells
    assert_int(permille).override_failure_message(
        "지상 air 비율 %d‰ 가 [%d, %d] 밖이다" % [permille, AIR_PERMILLE_MIN, AIR_PERMILLE_MAX]
    ).is_between(AIR_PERMILLE_MIN, AIR_PERMILLE_MAX)


func test_ground_scatter_actually_appears() -> void:
    # 표의 세 흩뿌림 블록이 3×3 청크 안에 전부 등장한다.
    var gen := _make(20250901)
    var seen: Dictionary = {}
    for cy in range(-1, 2):
        for cx in range(-1, 2):
            var histogram := _layer_histogram(gen.generate(cx, cy), Chunk.LAYER_GROUND)
            for id: int in histogram.keys():
                seen[id] = true
    for id: int in [0, 3, 5, 2, 4]:
        assert_bool(seen.has(id)).override_failure_message("id %d 가 지상층에 없다" % id).is_true()


# --- dirty ---

func test_generated_chunk_is_clean() -> void:
    var chunk := _make(1).generate(0, 0)
    assert_bool(chunk.is_dirty()).is_false()
    assert_int(chunk.get_id(0, 0, Chunk.LAYER_UNDER)).is_not_equal(0)


# --- 소스 가드 ---

func test_generator_source_has_no_forbidden_tokens() -> void:
    var source := FileAccess.get_file_as_string("res://sim/chunk_generator.gd")
    assert_str(source).is_not_empty()
    for token: String in ["float", "randf", "randi", "sin(", "noise", "Noise", "FileAccess", "JSON", "RandomNumberGenerator", "SimRng"]:
        assert_bool(source.contains(token)).override_failure_message(
            "chunk_generator.gd 에 금지 토큰 '%s' 가 있다" % token
        ).is_false()


# --- cell_hash ---

func test_cell_hash_does_not_degenerate_at_zero() -> void:
    assert_int(ChunkGenerator.cell_hash(0, 0, 0, 0)).is_not_equal(0)


func test_cell_hash_distinguishes_salt_and_coords() -> void:
    var base := ChunkGenerator.cell_hash(3, 5, 7, ChunkGenerator.SALT_UNDER_ZONE)
    assert_int(ChunkGenerator.cell_hash(3, 5, 7, ChunkGenerator.SALT_GROUND_ZONE)).is_not_equal(base)
    assert_int(ChunkGenerator.cell_hash(3, 5, 7, ChunkGenerator.SALT_SCATTER)).is_not_equal(base)
    assert_int(ChunkGenerator.cell_hash(3, 6, 7, ChunkGenerator.SALT_UNDER_ZONE)).is_not_equal(base)
    assert_int(ChunkGenerator.cell_hash(3, 5, 8, ChunkGenerator.SALT_UNDER_ZONE)).is_not_equal(base)
    assert_int(ChunkGenerator.cell_hash(4, 5, 7, ChunkGenerator.SALT_UNDER_ZONE)).is_not_equal(base)
    assert_int(ChunkGenerator.cell_hash(3, 5, 7, ChunkGenerator.SALT_UNDER_ZONE)).is_equal(base)


func test_salts_are_distinct_large_odd() -> void:
    var salts: Array = [ChunkGenerator.SALT_UNDER_ZONE, ChunkGenerator.SALT_GROUND_ZONE, ChunkGenerator.SALT_SCATTER]
    for salt: int in salts:
        assert_int(salt & 1).is_equal(1)
        assert_int(salt).is_greater(1 << 32)
    assert_int(salts[0]).is_not_equal(salts[1])
    assert_int(salts[1]).is_not_equal(salts[2])
    assert_int(salts[0]).is_not_equal(salts[2])


func test_pick_is_in_range_for_negative_hash() -> void:
    for h: int in [-1, -9223372036854775807, 9223372036854775807, 0, 255, -256]:
        for n: int in [1, 2, 3, 7]:
            assert_int(ChunkGenerator.pick(h, n)).is_between(0, n - 1)
    assert_int(ChunkGenerator.pick(5, 0)).is_equal(0)


# --- 골든 지형 해시 ---

func test_golden_terrain_hash() -> void:
    assert_str(_make(GOLDEN_SEED).generate(0, 0).digest()).is_equal(GOLDEN_TERRAIN_HASH)


# --- Node 아님 ---

func test_generator_is_not_a_node() -> void:
    var gen: Variant = _make(1)
    assert_str(gen.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(gen.get_class(), "Node")).is_false()
    assert_bool(gen is Node).is_false()
    assert_bool(gen is RefCounted).is_true()
