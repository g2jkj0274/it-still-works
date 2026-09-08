extends GdUnitTestSuite

## 채집 판정 검증: target_of(8방향), can_harvest(air 거부·dirt 허용·solid 인데 못 부수는 hard 거부·
## solid 아닌데 부술 수 있는 soft 허용·지하), 언로드 칸 false(get_id_at 의 0 함정), 청크 경계,
## is_empty_at, remaining_after_hit, 상태 불변, 소스 가드, Node 아님.
##
## 세계는 인메모리 표로 만든다(test_move_player_command 와 같은 평평한 세계: 지하 dirt, 지상 air,
## 흩뿌림 0). 레지스트리에 hard(solid, 내구도 0)·soft(속성 없음, 내구도 5)를 더해 판정 근거가
## solid 가 아니라 내구도임을 증명한다. Simulation.create 뒤 advance(1) 로 스폰 청크 25개를 로드한다.

const SEED := 20250901
const AIR := 0
const DIRT := 1
const DIRT_D := 8
const HARD := 2
const SOFT := 3
const SOFT_D := 5

const GROUND := Chunk.LAYER_GROUND
const UNDER := Chunk.LAYER_UNDER
const SPAWN := Vector2i(8, 8)

## 스폰 (8,8) 은 청크 (0,0). 로드 범위 청크 -2..2 → 월드 -32..47. 그 밖.
const UNLOADED_X := 200


func _row(id: int, name: String, durability: int, on: Array = []) -> Dictionary:
    var row: Dictionary = {"id": id, "name": name, "durability": durability}
    for attr in BlockRegistry.ATTRIBUTES:
        row[attr] = on.has(attr)
    return row


func _registry() -> BlockRegistry:
    var rows: Array = [
        _row(AIR, "air", 0),
        _row(DIRT, "dirt", DIRT_D, ["solid"]),
        _row(HARD, "hard", 0, ["solid"]),
        _row(SOFT, "soft", SOFT_D),
    ]
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


## 로드 0 인 시뮬레이션(틱 0 직후).
func _unloaded_sim() -> Simulation:
    var registry := _registry()
    var sim := Simulation.create(SEED, registry, _terrain(registry))
    assert_object(sim).is_not_null()
    assert_int(sim.state.chunks.loaded_count()).is_equal(0)
    return sim


## 평평한 세계. 틱 0 을 돌려 스폰 청크 25개를 로드해 둔다.
func _loaded_sim() -> Simulation:
    var sim := _unloaded_sim()
    sim.advance(1)
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)
    assert_bool(sim.state.player.cell() == SPAWN).is_true()
    return sim


func _put(sim: Simulation, x: int, y: int, id: int, durability: int, layer: int = GROUND) -> void:
    assert_bool(sim.state.chunks.set_id_at(x, y, layer, id, durability)).is_true()


# --- target_of ---

func test_target_of_is_facing_neighbour_in_all_eight_directions() -> void:
    var feet := Vector2i(-3, 9)
    for dir: Vector2i in MovementRules.DIRECTIONS:
        var target := HarvestRules.target_of(feet, dir)
        assert_bool(target != feet).override_failure_message(
            "(%d,%d) 방향 목표가 발 칸과 같다" % [dir.x, dir.y]
        ).is_true()
        assert_that(target).is_equal(feet + dir)


# --- can_harvest ---

func test_can_harvest_air_is_false() -> void:
    var sim := _loaded_sim()
    assert_bool(HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, 9, 8, GROUND)).is_false()


func test_can_harvest_dirt_is_true() -> void:
    var sim := _loaded_sim()
    _put(sim, 9, 8, DIRT, DIRT_D)
    assert_bool(HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, 9, 8, GROUND)).is_true()


func test_can_harvest_solid_but_unbreakable_is_false() -> void:
    # 거부 근거는 solid 가 아니라 내구도다.
    var sim := _loaded_sim()
    _put(sim, 9, 8, HARD, 0)
    assert_bool(sim.state.registry.has_at(HARD, BlockRegistry.ATTR_SOLID)).is_true()
    assert_bool(sim.state.registry.is_breakable(HARD)).is_false()
    assert_bool(HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, 9, 8, GROUND)).is_false()


func test_can_harvest_non_solid_but_breakable_is_true() -> void:
    # 허용 근거도 solid 가 아니다.
    var sim := _loaded_sim()
    _put(sim, 9, 8, SOFT, SOFT_D)
    assert_bool(sim.state.registry.has_at(SOFT, BlockRegistry.ATTR_SOLID)).is_false()
    assert_bool(sim.state.registry.is_breakable(SOFT)).is_true()
    assert_bool(HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, 9, 8, GROUND)).is_true()


func test_can_harvest_under_layer_dirt_is_true() -> void:
    var sim := _loaded_sim()
    assert_int(sim.state.chunks.get_id_at(9, 8, UNDER)).is_equal(DIRT)
    assert_bool(HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, 9, 8, UNDER)).is_true()


# --- 언로드 ---

func test_unloaded_world_refuses_both_judgements() -> void:
    # get_id_at 은 언로드 칸에 0 을 돌려준다. 로드 검사가 먼저 없으면 is_empty_at 이 true 가 된다.
    var sim := _unloaded_sim()
    assert_int(sim.state.chunks.get_id_at(9, 8, GROUND)).is_equal(AIR)
    assert_bool(HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, 9, 8, GROUND)).is_false()
    assert_bool(HarvestRules.is_empty_at(sim.state.chunks, 9, 8, GROUND)).is_false()
    assert_bool(HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, 9, 8, UNDER)).is_false()
    assert_bool(HarvestRules.is_empty_at(sim.state.chunks, 9, 8, UNDER)).is_false()


func test_cell_outside_load_radius_refuses_both_judgements() -> void:
    var sim := _loaded_sim()
    assert_bool(sim.state.chunks.is_loaded(ChunkWorld.chunk_of(UNLOADED_X), 0)).is_false()
    assert_int(sim.state.chunks.get_id_at(UNLOADED_X, 8, GROUND)).is_equal(AIR)
    assert_bool(HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, UNLOADED_X, 8, GROUND)).is_false()
    assert_bool(HarvestRules.is_empty_at(sim.state.chunks, UNLOADED_X, 8, GROUND)).is_false()
    assert_bool(HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, UNLOADED_X, 8, UNDER)).is_false()
    assert_bool(HarvestRules.is_empty_at(sim.state.chunks, UNLOADED_X, 8, UNDER)).is_false()


# --- 청크 경계 ---

func test_target_across_chunk_boundary_when_loaded() -> void:
    var feet := Vector2i(15, 8)
    var target := HarvestRules.target_of(feet, Vector2i(1, 0))
    assert_that(target).is_equal(Vector2i(16, 8))
    assert_int(ChunkWorld.chunk_of(target.x)).is_equal(1)
    assert_int(ChunkWorld.chunk_of(target.y)).is_equal(0)
    var sim := _loaded_sim()
    assert_bool(HarvestRules.is_empty_at(sim.state.chunks, target.x, target.y, GROUND)).is_true()
    assert_bool(HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, target.x, target.y, GROUND)).is_false()
    _put(sim, target.x, target.y, DIRT, DIRT_D)
    assert_bool(HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, target.x, target.y, GROUND)).is_true()
    assert_bool(HarvestRules.is_empty_at(sim.state.chunks, target.x, target.y, GROUND)).is_false()


func test_target_across_chunk_boundary_when_unloaded() -> void:
    var sim := _unloaded_sim()
    var target := HarvestRules.target_of(Vector2i(15, 8), Vector2i(1, 0))
    assert_bool(HarvestRules.is_empty_at(sim.state.chunks, target.x, target.y, GROUND)).is_false()
    assert_bool(HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, target.x, target.y, GROUND)).is_false()


# --- is_empty_at ---

func test_is_empty_at() -> void:
    var sim := _loaded_sim()
    assert_bool(HarvestRules.is_empty_at(sim.state.chunks, 9, 8, GROUND)).is_true()
    _put(sim, 9, 8, DIRT, DIRT_D)
    assert_bool(HarvestRules.is_empty_at(sim.state.chunks, 9, 8, GROUND)).is_false()
    assert_bool(HarvestRules.is_empty_at(sim.state.chunks, 9, 8, UNDER)).is_false()
    # 부술 수 없는 블록도 빈 칸은 아니다.
    _put(sim, 10, 8, HARD, 0)
    assert_bool(HarvestRules.is_empty_at(sim.state.chunks, 10, 8, GROUND)).is_false()


# --- remaining_after_hit ---

func test_remaining_after_hit() -> void:
    assert_int(HarvestRules.HIT_POWER).is_equal(1)
    assert_int(HarvestRules.remaining_after_hit(8)).is_equal(7)
    assert_int(HarvestRules.remaining_after_hit(1)).is_equal(0)
    assert_int(HarvestRules.remaining_after_hit(0)).is_equal(0)


# --- 상태 불변 ---

func test_rules_do_not_mutate_state() -> void:
    var sim := _loaded_sim()
    _put(sim, 9, 8, DIRT, DIRT_D)
    _put(sim, 7, 8, HARD, 0)
    _put(sim, 8, 9, SOFT, SOFT_D)
    var before := sim.state_hash()
    var rng_before := sim.state.rng.get_state()
    for dir: Vector2i in MovementRules.DIRECTIONS:
        var target := HarvestRules.target_of(SPAWN, dir)
        for layer: int in [UNDER, GROUND, Chunk.LAYER_UPPER]:
            HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, target.x, target.y, layer)
            HarvestRules.is_empty_at(sim.state.chunks, target.x, target.y, layer)
    HarvestRules.can_harvest(sim.state.chunks, sim.state.registry, UNLOADED_X, 8, GROUND)
    HarvestRules.is_empty_at(sim.state.chunks, UNLOADED_X, 8, GROUND)
    HarvestRules.remaining_after_hit(DIRT_D)
    assert_str(sim.state_hash()).is_equal(before)
    assert_int(sim.state.rng.get_state()).is_equal(rng_before)
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)
    assert_int(sim.state.chunks.snapshot_count()).is_equal(0)


# --- 소스 가드 ---

func test_source_has_no_forbidden_tokens() -> void:
    var source := FileAccess.get_file_as_string("res://sim/harvest_rules.gd")
    assert_str(source).is_not_empty()
    for token: String in ["float", "randi", "randf", "FileAccess", "JSON", "Dictionary", "name_of(", "_process", "delta", "Node", "BlockType", "variant", "ATTR_SOLID", "\"solid\"", "set_id", "set_durability", "inventory"]:
        assert_bool(source.contains(token)).override_failure_message(
            "harvest_rules.gd 에 금지 토큰 '%s' 가 있다" % token
        ).is_false()


func test_source_compares_to_zero_exactly_once() -> void:
    # id 0 = 블록 없음 비교는 is_empty_at 한 곳에만 있다.
    var source := FileAccess.get_file_as_string("res://sim/harvest_rules.gd")
    assert_int(source.count("== 0")).is_equal(1)
    assert_bool(source.contains("is_breakable(")).is_true()


# --- Node 아님 ---

func test_rules_is_not_a_node() -> void:
    var rules: Variant = HarvestRules.new()
    assert_str(rules.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(rules.get_class(), "Node")).is_false()
    assert_bool(rules is Node).is_false()
    assert_bool(rules is RefCounted).is_true()
