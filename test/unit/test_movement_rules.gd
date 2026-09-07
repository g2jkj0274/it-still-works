extends GdUnitTestSuite

## 이동 판정 검증: 방향 표, passable/supported/walkable, resolve_walk(직진·벽·구멍·대각선 모서리·
## 스폰 규칙·언로드), 상태 불변, 소스 가드, Node 아님.
##
## 세계는 인메모리 표로 만든다: air(0)·dirt(1, solid). 지형 표는 지하 전부 dirt, 지상 전부 air,
## 흩뿌림 밀도 0 — 생성기 해시와 무관하게 평평한 세계가 나와서 벽·구멍을 set_id_at 으로만 놓는다.
## ChunkWorld 단위 테스트에서 set_center 직접 호출은 SIM_ORDER 예외로 허용된다.

const SEED := 20250901
const AIR := 0
const DIRT := 1
const DIRT_D := 8

const GROUND := Chunk.LAYER_GROUND
const UNDER := Chunk.LAYER_UNDER
const UPPER := Chunk.LAYER_UPPER

## set_center(0,0) 로드 범위: 청크 -2..2 → 월드 -32..47. 그 바로 밖.
const UNLOADED_X := 48


func _row(id: int, name: String, durability: int, on: Array = []) -> Dictionary:
    var row: Dictionary = {"id": id, "name": name, "durability": durability}
    for attr in BlockRegistry.ATTRIBUTES:
        row[attr] = on.has(attr)
    return row


func _registry() -> BlockRegistry:
    var rows: Array = [_row(AIR, "air", 0), _row(DIRT, "dirt", DIRT_D, ["solid"])]
    var registry := BlockRegistry.from_text(JSON.stringify(rows, "", false))
    assert_object(registry).is_not_null()
    return registry


func _terrain(registry: BlockRegistry) -> TerrainTable:
    var table: Dictionary = {
        "under_zones": [DIRT],
        "ground_zones": [AIR],
        "ground_scatter": [{"id": DIRT, "per_256": 0}],
    }
    var terrain := TerrainTable.from_text(JSON.stringify(table, "", false), registry)
    assert_object(terrain).is_not_null()
    return terrain


## 평평한 세계. 지하 전부 dirt, 지상·2층 전부 air. 중심 (0,0) 로드.
func _world(registry: BlockRegistry) -> ChunkWorld:
    var world := ChunkWorld.new(ChunkGenerator.new(SEED, registry, _terrain(registry)))
    world.set_center(0, 0)
    return world


func _wall(world: ChunkWorld, x: int, y: int, layer: int = GROUND) -> void:
    assert_bool(world.set_id_at(x, y, layer, DIRT, DIRT_D)).is_true()


## 바닥 없는 구멍: 아래 층을 air 로.
func _hole(world: ChunkWorld, x: int, y: int) -> void:
    assert_bool(world.set_id_at(x, y, UNDER, AIR, 0)).is_true()


# --- 방향 표 ---

func test_directions_are_eight_in_fixed_order() -> void:
    var expected: Array[Vector2i] = [
        Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0),
        Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1),
    ]
    assert_int(MovementRules.DIRECTIONS.size()).is_equal(8)
    for i in expected.size():
        assert_that(MovementRules.DIRECTIONS[i]).override_failure_message(
            "DIRECTIONS[%d] 순서가 다르다" % i
        ).is_equal(expected[i])
        assert_bool(MovementRules.is_direction(expected[i])).is_true()


func test_non_directions_are_rejected() -> void:
    for d: Vector2i in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(1, 2), Vector2i(-2, -2)]:
        assert_bool(MovementRules.is_direction(d)).override_failure_message(
            "(%d,%d) 는 방향이 아니어야 한다" % [d.x, d.y]
        ).is_false()


func test_is_diagonal() -> void:
    assert_bool(MovementRules.is_diagonal(Vector2i(1, 1))).is_true()
    assert_bool(MovementRules.is_diagonal(Vector2i(-1, 1))).is_true()
    assert_bool(MovementRules.is_diagonal(Vector2i(1, 0))).is_false()
    assert_bool(MovementRules.is_diagonal(Vector2i(0, -1))).is_false()
    assert_bool(MovementRules.is_diagonal(Vector2i(0, 0))).is_false()


# --- flat world 전제 ---

func test_flat_world_setup() -> void:
    var registry := _registry()
    var world := _world(registry)
    assert_int(world.loaded_count()).is_equal(25)
    for c: Vector2i in [Vector2i(0, 0), Vector2i(5, 5), Vector2i(-20, 30), Vector2i(47, -32)]:
        assert_int(world.get_id_at(c.x, c.y, UNDER)).is_equal(DIRT)
        assert_int(world.get_id_at(c.x, c.y, GROUND)).is_equal(AIR)
        assert_int(world.get_id_at(c.x, c.y, UPPER)).is_equal(AIR)


# --- passable ---

func test_passable_air_true_solid_false() -> void:
    var registry := _registry()
    var world := _world(registry)
    assert_bool(MovementRules.is_passable(world, registry, 5, 5, GROUND)).is_true()
    _wall(world, 5, 6)
    assert_bool(MovementRules.is_passable(world, registry, 5, 6, GROUND)).is_false()
    # 다른 층은 영향 없다.
    assert_bool(MovementRules.is_passable(world, registry, 5, 6, UPPER)).is_true()
    # 지하는 전부 dirt.
    assert_bool(MovementRules.is_passable(world, registry, 5, 5, UNDER)).is_false()


func test_passable_unloaded_is_false_even_though_get_id_reads_air() -> void:
    var registry := _registry()
    var world := _world(registry)
    assert_int(world.get_id_at(UNLOADED_X, 0, GROUND)).is_equal(AIR)
    assert_bool(MovementRules.is_passable(world, registry, UNLOADED_X, 0, GROUND)).is_false()
    assert_bool(MovementRules.is_passable(world, registry, -33, 0, GROUND)).is_false()
    assert_bool(MovementRules.is_passable(world, registry, 0, 48, GROUND)).is_false()


# --- supported ---

func test_supported_ground_needs_solid_below() -> void:
    var registry := _registry()
    var world := _world(registry)
    assert_bool(MovementRules.is_supported(world, registry, 5, 5, GROUND)).is_true()
    _hole(world, 7, 7)
    assert_bool(MovementRules.is_supported(world, registry, 7, 7, GROUND)).is_false()


func test_supported_upper_needs_solid_on_ground() -> void:
    var registry := _registry()
    var world := _world(registry)
    assert_bool(MovementRules.is_supported(world, registry, 5, 5, UPPER)).is_false()
    _wall(world, 5, 5, GROUND)
    assert_bool(MovementRules.is_supported(world, registry, 5, 5, UPPER)).is_true()


func test_supported_under_is_always_true() -> void:
    var registry := _registry()
    var world := _world(registry)
    assert_bool(MovementRules.is_supported(world, registry, 5, 5, UNDER)).is_true()
    _hole(world, 7, 7)
    assert_bool(MovementRules.is_supported(world, registry, 7, 7, UNDER)).is_true()
    # 암묵 기반암은 로드와도 무관하다. 걷기는 passable 이 언로드를 막는다.
    assert_bool(MovementRules.is_supported(world, registry, UNLOADED_X, 0, UNDER)).is_true()


func test_supported_unloaded_is_false_above_under() -> void:
    var registry := _registry()
    var world := _world(registry)
    assert_bool(MovementRules.is_supported(world, registry, UNLOADED_X, 0, GROUND)).is_false()
    assert_bool(MovementRules.is_supported(world, registry, UNLOADED_X, 0, UPPER)).is_false()


# --- walkable ---

func test_walkable_combines_passable_and_supported() -> void:
    var registry := _registry()
    var world := _world(registry)
    assert_bool(MovementRules.is_walkable(world, registry, 5, 5, GROUND)).is_true()
    _wall(world, 5, 6)
    assert_bool(MovementRules.is_walkable(world, registry, 5, 6, GROUND)).is_false()
    _hole(world, 7, 7)
    assert_bool(MovementRules.is_walkable(world, registry, 7, 7, GROUND)).is_false()
    assert_bool(MovementRules.is_walkable(world, registry, UNLOADED_X, 0, GROUND)).is_false()
    # 지하: 지나갈 수 없어서(전부 dirt) 걸을 수 없다.
    assert_bool(MovementRules.is_walkable(world, registry, 5, 5, UNDER)).is_false()
    world.set_id_at(5, 5, UNDER, AIR, 0)
    assert_bool(MovementRules.is_walkable(world, registry, 5, 5, UNDER)).is_true()


# --- resolve_walk: 직진 ---

func test_resolve_walk_straight_succeeds_on_flat_ground() -> void:
    var registry := _registry()
    var world := _world(registry)
    var feet := Vector2i(5, 5)
    for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
        assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, d)).is_equal(feet + d)


func test_resolve_walk_all_eight_directions_succeed_on_flat_ground() -> void:
    var registry := _registry()
    var world := _world(registry)
    var feet := Vector2i(-3, 9)
    for d: Vector2i in MovementRules.DIRECTIONS:
        assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, d)).is_equal(feet + d)


func test_resolve_walk_into_wall_stays() -> void:
    var registry := _registry()
    var world := _world(registry)
    _wall(world, 6, 5)
    var feet := Vector2i(5, 5)
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(1, 0))).is_equal(feet)
    # 벽은 그 층만 막는다. 2층에서 같은 걸음은 바닥이 없어 역시 거부되지만 이유가 다르다 —
    # 벽 위에 서면(2층 (6,5) 바닥이 벽) 갈 수 있다.
    assert_bool(MovementRules.is_walkable(world, registry, 6, 5, UPPER)).is_true()


func test_resolve_walk_into_void_stays() -> void:
    var registry := _registry()
    var world := _world(registry)
    _hole(world, 5, 4)
    var feet := Vector2i(5, 5)
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(0, -1))).is_equal(feet)
    # 다른 방향은 열려 있다.
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(0, 1))).is_equal(Vector2i(5, 6))


func test_resolve_walk_non_direction_stays() -> void:
    var registry := _registry()
    var world := _world(registry)
    var feet := Vector2i(5, 5)
    for d: Vector2i in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 1)]:
        assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, d)).is_equal(feet)


# --- resolve_walk: 대각선 ---

func test_resolve_walk_diagonal_with_open_sides_succeeds() -> void:
    var registry := _registry()
    var world := _world(registry)
    var feet := Vector2i(5, 5)
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(1, 1))).is_equal(Vector2i(6, 6))
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(-1, -1))).is_equal(Vector2i(4, 4))


func test_resolve_walk_diagonal_blocked_by_one_side() -> void:
    var registry := _registry()
    var world := _world(registry)
    var feet := Vector2i(5, 5)
    # (1,1) 의 양옆은 (6,5) 와 (5,6).
    _wall(world, 6, 5)
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(1, 1))).is_equal(feet)
    # 목적지 자체는 걸을 수 있다 — 막힌 것은 모서리다.
    assert_bool(MovementRules.is_walkable(world, registry, 6, 6, GROUND)).is_true()
    # 직진으로 (5,6) 은 여전히 열려 있다.
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(0, 1))).is_equal(Vector2i(5, 6))


func test_resolve_walk_diagonal_blocked_by_other_side() -> void:
    var registry := _registry()
    var world := _world(registry)
    var feet := Vector2i(5, 5)
    _wall(world, 5, 6)
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(1, 1))).is_equal(feet)
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(1, 0))).is_equal(Vector2i(6, 5))


func test_resolve_walk_diagonal_blocked_by_both_sides() -> void:
    var registry := _registry()
    var world := _world(registry)
    var feet := Vector2i(5, 5)
    _wall(world, 4, 5)
    _wall(world, 5, 4)
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(-1, -1))).is_equal(feet)


func test_resolve_walk_diagonal_passes_over_void_sides() -> void:
    # 양옆은 passable 만 본다. 옆이 바닥 없는 구멍이어도 스칠 수 있다 — 딛는 곳은 목적지뿐이다.
    var registry := _registry()
    var world := _world(registry)
    var feet := Vector2i(5, 5)
    _hole(world, 6, 5)
    _hole(world, 5, 6)
    assert_bool(MovementRules.is_walkable(world, registry, 6, 5, GROUND)).is_false()
    assert_bool(MovementRules.is_walkable(world, registry, 5, 6, GROUND)).is_false()
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(1, 1))).is_equal(Vector2i(6, 6))


func test_resolve_walk_diagonal_into_void_destination_stays() -> void:
    var registry := _registry()
    var world := _world(registry)
    var feet := Vector2i(5, 5)
    _hole(world, 6, 6)
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(1, 1))).is_equal(feet)


# --- resolve_walk: 스폰 규칙·언로드 ---

func test_resolve_walk_leaves_solid_origin_into_air() -> void:
    # 출발 칸은 검사하지 않는다. solid 안에 스폰돼도 air 이웃으로 나온다.
    var registry := _registry()
    var world := _world(registry)
    var feet := Vector2i(5, 5)
    _wall(world, 5, 5)
    assert_bool(MovementRules.is_passable(world, registry, 5, 5, GROUND)).is_false()
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(1, 0))).is_equal(Vector2i(6, 5))
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(-1, 1))).is_equal(Vector2i(4, 6))


func test_resolve_walk_into_unloaded_cell_stays() -> void:
    var registry := _registry()
    var world := _world(registry)
    var feet := Vector2i(47, 0)
    assert_bool(MovementRules.is_walkable(world, registry, 47, 0, GROUND)).is_true()
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(1, 0))).is_equal(feet)
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(1, 1))).is_equal(feet)
    # 로드 안쪽으로는 간다.
    assert_that(MovementRules.resolve_walk(world, registry, feet, GROUND, Vector2i(-1, 0))).is_equal(Vector2i(46, 0))
    # 경계 위에서 대각선: 목적지가 로드 안이어도 양옆 하나가 언로드면 거부.
    var corner := Vector2i(47, 47)
    assert_that(MovementRules.resolve_walk(world, registry, corner, GROUND, Vector2i(-1, 1))).is_equal(corner)


func test_resolve_walk_crosses_chunk_boundary_inside_load_radius() -> void:
    # 청크 경계(15→16, -1→0)는 이동에 보이지 않는다(P7 3항).
    var registry := _registry()
    var world := _world(registry)
    assert_that(MovementRules.resolve_walk(world, registry, Vector2i(15, 15), GROUND, Vector2i(1, 1))).is_equal(Vector2i(16, 16))
    assert_that(MovementRules.resolve_walk(world, registry, Vector2i(0, 0), GROUND, Vector2i(-1, -1))).is_equal(Vector2i(-1, -1))
    assert_that(MovementRules.resolve_walk(world, registry, Vector2i(-16, 3), GROUND, Vector2i(-1, 0))).is_equal(Vector2i(-17, 3))


# --- 상태 불변 ---

func test_rules_do_not_mutate_world() -> void:
    var registry := _registry()
    var world := _world(registry)
    _wall(world, 6, 5)
    _hole(world, 4, 4)
    var before := world.compute_hash()
    var feet := Vector2i(5, 5)
    for d: Vector2i in MovementRules.DIRECTIONS:
        MovementRules.resolve_walk(world, registry, feet, GROUND, d)
        MovementRules.resolve_walk(world, registry, feet, UPPER, d)
        MovementRules.resolve_walk(world, registry, feet, UNDER, d)
    MovementRules.resolve_walk(world, registry, Vector2i(47, 47), GROUND, Vector2i(1, 1))
    MovementRules.is_walkable(world, registry, UNLOADED_X, UNLOADED_X, GROUND)
    MovementRules.is_supported(world, registry, UNLOADED_X, 0, UPPER)
    assert_str(world.compute_hash()).is_equal(before)
    assert_int(world.loaded_count()).is_equal(25)
    assert_int(world.snapshot_count()).is_equal(0)


func test_rules_are_deterministic_across_worlds() -> void:
    var registry := _registry()
    var a := _world(registry)
    var b := _world(registry)
    _wall(a, 6, 5)
    _wall(b, 6, 5)
    var feet := Vector2i(5, 5)
    for d: Vector2i in MovementRules.DIRECTIONS:
        assert_that(MovementRules.resolve_walk(a, registry, feet, GROUND, d)).is_equal(
            MovementRules.resolve_walk(b, registry, feet, GROUND, d))


# --- 소스 가드 ---

func test_source_has_no_forbidden_tokens() -> void:
    var source := FileAccess.get_file_as_string("res://sim/movement_rules.gd")
    assert_str(source).is_not_empty()
    for token: String in ["float", "randi", "randf", "FileAccess", "JSON", "Vector3i", "name_of(", "set_id", "set_center(", "_process", "delta", ">> 4", "& 15"]:
        assert_bool(source.contains(token)).override_failure_message(
            "movement_rules.gd 에 금지 토큰 '%s' 가 있다" % token
        ).is_false()


func test_source_reads_attributes_by_index_only() -> void:
    # P2: solid 는 ATTR_SOLID 인덱스로만 묻는다. 이름 문자열(&"solid")·블록 id 상수 비교는 없다.
    var source := FileAccess.get_file_as_string("res://sim/movement_rules.gd")
    assert_bool(source.contains("ATTR_SOLID")).is_true()
    assert_bool(source.contains("\"solid\"")).is_false()
    assert_bool(source.contains("== 0")).is_false()
    assert_bool(source.contains("== 1")).is_false()


# --- Node 아님 ---

func test_rules_is_not_a_node() -> void:
    var rules: Variant = MovementRules.new()
    assert_str(rules.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(rules.get_class(), "Node")).is_false()
    assert_bool(rules is Node).is_false()
    assert_bool(rules is RefCounted).is_true()
