extends GdUnitTestSuite

## MovePlayerCommand 검증: 적용(한 칸 이동 시작, 4틱 뒤 도착), 벽 거부, facing 갱신(거부돼도),
## 이동 중 무시, create(0,0) no-op(해시 불변), 방향 아닌 값 무시, 직렬화 왕복·JSON, 코덱 등록,
## 청크·난수원·값 불변, Node 아님.
##
## 세계는 인메모리 표로 만든다(test_movement_rules 와 같은 평평한 세계: 지하 dirt, 지상 air, 흩뿌림 0).
## Simulation.create(...) 에 넘겨 첫 틱에 스폰 (8,8) 청크를 로드한 뒤 명령을 적용한다.
## 벽은 단위 테스트에서 `chunks.set_id_at` 으로 직접 놓는다(상태 직접 조작 — 단위 테스트에서만 허용).

const SEED := 20250901
const AIR := 0
const DIRT := 1
const DIRT_D := 8
const GROUND := Chunk.LAYER_GROUND
const SPAWN := Vector2i(8, 8)


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


## 평평한 세계의 시뮬레이션. 틱 0 을 돌려 스폰 청크 25개를 로드해 둔다.
func _loaded_sim() -> Simulation:
    var registry := _registry()
    var sim := Simulation.create(SEED, registry, _terrain(registry))
    assert_object(sim).is_not_null()
    sim.advance(1)
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)
    assert_bool(sim.state.player.cell() == SPAWN).is_true()
    return sim


func _wall(sim: Simulation, x: int, y: int) -> void:
    assert_bool(sim.state.chunks.set_id_at(x, y, GROUND, DIRT, DIRT_D)).is_true()


# --- 적용 ---

func test_apply_starts_one_cell_walk() -> void:
    var sim := _loaded_sim()
    MovePlayerCommand.create(1, 0).apply(sim.state)
    var player := sim.state.player
    assert_bool(player.is_moving()).is_true()
    assert_bool(player.cell() == SPAWN).is_true()
    assert_bool(player.target_cell() == Vector2i(9, 8)).is_true()
    assert_bool(player.facing == Vector2i(1, 0)).is_true()


func test_submitted_move_arrives_after_four_ticks() -> void:
    var sim := _loaded_sim()
    sim.submit(MovePlayerCommand.create(0, 1))
    sim.advance(3)
    assert_bool(sim.state.player.is_moving()).is_true()
    assert_bool(sim.state.player.cell() == SPAWN).is_true()
    sim.step()
    assert_bool(sim.state.player.is_moving()).is_false()
    assert_bool(sim.state.player.cell() == Vector2i(8, 9)).is_true()
    assert_bool(sim.state.player.sub == PlayerState.sub_of(Vector2i(8, 9))).is_true()


func test_diagonal_walk_arrives_after_four_ticks() -> void:
    var sim := _loaded_sim()
    sim.submit(MovePlayerCommand.create(-1, -1))
    sim.advance(4)
    assert_bool(sim.state.player.cell() == Vector2i(7, 7)).is_true()
    assert_bool(sim.state.player.is_moving()).is_false()


# --- 거부 ---

func test_wall_refuses_walk_but_turns_facing() -> void:
    var sim := _loaded_sim()
    _wall(sim, 9, 8)
    MovePlayerCommand.create(1, 0).apply(sim.state)
    var player := sim.state.player
    assert_bool(player.is_moving()).is_false()
    assert_bool(player.cell() == SPAWN).is_true()
    assert_bool(player.facing == Vector2i(1, 0)).is_true()


func test_unloaded_world_refuses_walk_but_turns_facing() -> void:
    # 틱 0 의 상황: 청크가 하나도 로드되지 않았다. 걷기는 전부 거부, facing 만 바뀐다(SIM_ORDER 1-M1b).
    var registry := _registry()
    var sim := Simulation.create(SEED, registry, _terrain(registry))
    assert_int(sim.state.chunks.loaded_count()).is_equal(0)
    MovePlayerCommand.create(0, -1).apply(sim.state)
    assert_bool(sim.state.player.is_moving()).is_false()
    assert_bool(sim.state.player.cell() == SPAWN).is_true()
    assert_bool(sim.state.player.facing == Vector2i(0, -1)).is_true()


func test_command_while_moving_is_ignored_but_turns_facing() -> void:
    var sim := _loaded_sim()
    MovePlayerCommand.create(1, 0).apply(sim.state)
    var target_before := sim.state.player.target
    MovePlayerCommand.create(0, 1).apply(sim.state)
    assert_bool(sim.state.player.target == target_before).is_true()
    assert_bool(sim.state.player.target_cell() == Vector2i(9, 8)).is_true()
    assert_bool(sim.state.player.facing == Vector2i(0, 1)).is_true()


func test_zero_direction_is_a_no_op() -> void:
    var sim := _loaded_sim()
    var before := sim.state_hash()
    MovePlayerCommand.create(0, 0).apply(sim.state)
    assert_str(sim.state_hash()).is_equal(before)
    assert_bool(sim.state.player.facing == Vector2i(0, 1)).is_true()


func test_non_direction_is_a_no_op() -> void:
    var sim := _loaded_sim()
    var before := sim.state_hash()
    MovePlayerCommand.create(2, 0).apply(sim.state)
    MovePlayerCommand.create(-1, 3).apply(sim.state)
    assert_str(sim.state_hash()).is_equal(before)


func test_apply_touches_only_player() -> void:
    var sim := _loaded_sim()
    var rng_before := sim.state.rng.get_state()
    var chunks_before := sim.state.chunks.compute_hash()
    MovePlayerCommand.create(1, 1).apply(sim.state)
    assert_int(sim.state.rng.get_state()).is_equal(rng_before)
    assert_int(sim.state.value_count()).is_equal(0)
    assert_str(sim.state.chunks.compute_hash()).is_equal(chunks_before)


# --- 직렬화 ---

func test_round_trip_through_codec() -> void:
    var original := MovePlayerCommand.create(-1, 1)
    original.tick = 7
    var data := original.to_dict()
    assert_str(str(data["type"])).is_equal("move_player")
    assert_int(int(data["dx"])).is_equal(-1)
    assert_int(int(data["dy"])).is_equal(1)
    var restored := SimCommandCodec.from_dict(data) as MovePlayerCommand
    assert_object(restored).is_not_null()
    assert_int(restored.tick).is_equal(7)
    assert_int(restored.dx).is_equal(-1)
    assert_int(restored.dy).is_equal(1)


func test_survives_json() -> void:
    var original := MovePlayerCommand.create(1, -1)
    original.tick = 11
    var parsed: Variant = JSON.parse_string(JSON.stringify(SimCommandCodec.to_dict(original)))
    var restored := SimCommandCodec.from_dict(parsed) as MovePlayerCommand
    assert_object(restored).is_not_null()
    assert_int(restored.tick).is_equal(11)
    assert_int(restored.dx).is_equal(1)
    assert_int(restored.dy).is_equal(-1)
    assert_int(typeof(restored.dx)).is_equal(TYPE_INT)
    assert_int(typeof(restored.dy)).is_equal(TYPE_INT)


func test_codec_registers_type() -> void:
    var command := SimCommandCodec.create_by_type(MovePlayerCommand.TYPE)
    assert_object(command).is_not_null()
    assert_bool(command is MovePlayerCommand).is_true()
    assert_str(String(command.get_type())).is_equal("move_player")


func test_command_is_not_a_node() -> void:
    var command := MovePlayerCommand.create(1, 0)
    assert_str(command.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(command.get_class(), "Node")).is_false()
