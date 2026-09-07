extends GdUnitTestSuite

## 고정 틱 루프와 명령 소비 검증. 생성 경로(create/create_default), 플레이어 발 칸 → 로드 중심
## 동기화(첫 틱 로드, 경계 넘기, 첫 틱 거부), P7 투명성, set_center·Simulation.new·옛 로드 중심 이름 소스 가드.
##
## 걷기가 확실히 성공해야 하는 테스트는 인메모리 평평한 세계(지하 dirt, 지상 air, 흩뿌림 0)를 쓴다.

const SPAWN := Vector2i(8, 8)
const FLAT_AIR := 0
const FLAT_DIRT := 1


func _registry() -> BlockRegistry:
    var registry := BlockRegistry.load_default()
    assert_object(registry).is_not_null()
    return registry


func _terrain(registry: BlockRegistry) -> TerrainTable:
    var terrain := TerrainTable.load_default(registry)
    assert_object(terrain).is_not_null()
    return terrain


func _flat_row(id: int, name: String, durability: int, on: Array = []) -> Dictionary:
    var row: Dictionary = {"id": id, "name": name, "durability": durability}
    for attr in BlockRegistry.ATTRIBUTES:
        row[attr] = on.has(attr)
    return row


## 평평한 세계의 시뮬레이션. 어느 방향으로도 걸을 수 있다.
func _flat_sim(seed_value: int) -> Simulation:
    var rows: Array = [_flat_row(FLAT_AIR, "air", 0), _flat_row(FLAT_DIRT, "dirt", 8, ["solid"])]
    var registry := BlockRegistry.from_text(JSON.stringify(rows, "", false))
    assert_object(registry).is_not_null()
    var table: Dictionary = {
        "under_zones": [FLAT_DIRT],
        "ground_zones": [FLAT_AIR],
        "ground_scatter": [{"id": FLAT_DIRT, "per_256": 0}],
    }
    var terrain := TerrainTable.from_text(JSON.stringify(table, "", false), registry)
    assert_object(terrain).is_not_null()
    var sim := Simulation.create(seed_value, registry, terrain)
    assert_object(sim).is_not_null()
    return sim


## [param count] 개의 이동 명령을 [param first_tick] 부터 4틱 간격으로 접수한다(칸당 4틱).
func _submit_walk(sim: Simulation, dx: int, dy: int, first_tick: int, count: int) -> void:
    for i in count:
        sim.submit_at(MovePlayerCommand.create(dx, dy), first_tick + 4 * i)


func test_starts_at_tick_zero() -> void:
    assert_int(Simulation.create_default(1).current_tick()).is_equal(0)


func test_step_advances_one_tick() -> void:
    var sim := Simulation.create_default(1)
    sim.step()
    assert_int(sim.current_tick()).is_equal(1)


func test_advance_runs_requested_ticks() -> void:
    var sim := Simulation.create_default(1)
    sim.advance(7)
    assert_int(sim.current_tick()).is_equal(7)


func test_advance_with_non_positive_count_does_nothing() -> void:
    var sim := Simulation.create_default(1)
    sim.advance(0)
    sim.advance(-3)
    assert_int(sim.current_tick()).is_equal(0)


func test_submitted_command_applies_on_next_step() -> void:
    var sim := Simulation.create_default(1)
    sim.submit(SetValueCommand.create(&"wood", 5))
    assert_int(sim.state.get_value(&"wood")).is_equal(0)
    sim.step()
    assert_int(sim.state.get_value(&"wood")).is_equal(5)


func test_command_applies_exactly_once() -> void:
    var sim := Simulation.create_default(1)
    sim.submit(AddValueCommand.create(&"wood", 1))
    sim.advance(10)
    assert_int(sim.state.get_value(&"wood")).is_equal(1)


func test_future_command_does_not_apply_early() -> void:
    var sim := Simulation.create_default(1)
    sim.submit_at(SetValueCommand.create(&"wood", 9), 3)
    sim.advance(3)
    assert_int(sim.state.get_value(&"wood")).is_equal(0)
    sim.step()
    assert_int(sim.state.get_value(&"wood")).is_equal(9)


func test_same_tick_commands_apply_in_submission_order() -> void:
    var sim := Simulation.create_default(1)
    sim.submit(SetValueCommand.create(&"wood", 1))
    sim.submit(SetValueCommand.create(&"wood", 2))
    sim.step()
    assert_int(sim.state.get_value(&"wood")).is_equal(2)


func test_queue_is_drained_after_step() -> void:
    var sim := Simulation.create_default(1)
    sim.submit(SetValueCommand.create(&"wood", 1))
    sim.step()
    assert_bool(sim.queue.is_empty()).is_true()


func test_state_hash_changes_as_ticks_pass() -> void:
    var sim := Simulation.create_default(1)
    var before := sim.state_hash()
    sim.step()
    assert_str(sim.state_hash()).is_not_equal(before)


func test_steps_without_commands_touch_only_tick_and_spawn_load() -> void:
    # 명령이 없으면 틱과 첫 틱의 스폰 청크 로드 말고는 아무것도 바뀌지 않는다.
    # 난수원도 돌지 않고 값도 생기지 않고 플레이어도 제자리다.
    var sim := Simulation.create_default(1)
    var rng_before := sim.state.rng.get_state()
    sim.advance(50)
    assert_int(sim.state.rng.get_state()).is_equal(rng_before)
    assert_int(sim.state.value_count()).is_equal(0)
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)
    assert_bool(sim.state.chunks.center() == Vector2i(0, 0)).is_true()
    assert_bool(sim.state.player.cell() == SPAWN).is_true()
    assert_bool(sim.state.player.is_moving()).is_false()
    assert_int(sim.current_tick()).is_equal(50)


# --- 생성 경로 ---

func test_create_with_null_registry_yields_null() -> void:
    var registry := _registry()
    var terrain := _terrain(registry)
    assert_object(Simulation.create(0, null, terrain)).is_null()


func test_create_with_null_terrain_yields_null() -> void:
    assert_object(Simulation.create(0, _registry(), null)).is_null()


func test_create_with_empty_registry_and_null_terrain_yields_null() -> void:
    # 빈 레지스트리 자체는 유효하지만 그로부터 지형 표를 만들 수 없다. 짝이 안 맞으면 null.
    var empty := BlockRegistry.from_text("[]")
    assert_object(empty).is_not_null()
    assert_object(Simulation.create(0, empty, null)).is_null()


func test_create_with_both_tables_succeeds() -> void:
    var registry := _registry()
    var terrain := _terrain(registry)
    var sim := Simulation.create(3, registry, terrain)
    assert_object(sim).is_not_null()
    assert_object(sim.registry).is_same(registry)
    assert_object(sim.terrain).is_same(terrain)
    assert_int(sim.state.rng.get_seed()).is_equal(3)


func test_create_default_has_chunks_tables_and_spawned_player_without_center() -> void:
    var sim := Simulation.create_default(1)
    assert_object(sim).is_not_null()
    assert_object(sim.state.chunks).is_not_null()
    assert_object(sim.registry).is_not_null()
    assert_object(sim.state.registry).is_same(sim.registry)
    assert_object(sim.terrain).is_not_null()
    assert_bool(sim.state.chunks.has_center()).is_false()
    assert_int(sim.state.chunks.loaded_count()).is_equal(0)
    # 스폰: (8,8) 지상층, 멈춤, 시드 무관.
    assert_object(sim.state.player).is_not_null()
    assert_bool(sim.state.player.cell() == SPAWN).is_true()
    assert_bool(sim.state.player.cell() == Simulation.SPAWN_CELL).is_true()
    assert_int(sim.state.player.layer).is_equal(Chunk.LAYER_GROUND)
    assert_bool(sim.state.player.is_moving()).is_false()
    assert_bool(Simulation.create_default(99).state.player.cell() == SPAWN).is_true()


func test_create_default_and_create_agree() -> void:
    var registry := _registry()
    var explicit := Simulation.create(5, registry, _terrain(registry))
    var implicit := Simulation.create_default(5)
    explicit.submit_at(MovePlayerCommand.create(1, 0), 1)
    implicit.submit_at(MovePlayerCommand.create(1, 0), 1)
    explicit.advance(3)
    implicit.advance(3)
    assert_str(implicit.state_hash()).is_equal(explicit.state_hash())


# --- 플레이어 발 칸 → 로드 중심 동기화 ---

func test_first_tick_loads_25_chunks_around_player_chunk() -> void:
    var sim := Simulation.create_default(1)
    assert_int(sim.state.chunks.loaded_count()).is_equal(0)
    assert_bool(sim.state.chunks.has_center()).is_false()
    sim.step()
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)
    assert_bool(sim.state.chunks.has_center()).is_true()
    assert_bool(sim.state.chunks.center() == Vector2i(0, 0)).is_true()


func test_walking_across_chunk_boundary_moves_center_and_unloads_far_side() -> void:
    # (8,8) → (16,8): 여덟 걸음, 틱 1,5,…,29 접수. 마지막 걸음은 틱 29 에 시작해 틱 32 에 도착한다.
    var sim := _flat_sim(1)
    _submit_walk(sim, 1, 0, 1, 8)
    sim.advance(32)
    assert_bool(sim.state.player.cell() == Vector2i(15, 8)).is_true()
    assert_bool(sim.state.chunks.center() == Vector2i(0, 0)).is_true()
    sim.step()
    assert_bool(sim.state.player.cell() == Vector2i(16, 8)).is_true()
    assert_bool(sim.state.player.is_moving()).is_false()
    assert_bool(sim.state.chunks.center() == Vector2i(1, 0)).is_true()
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)
    assert_bool(sim.state.chunks.is_loaded(3, 0)).is_true()
    assert_bool(sim.state.chunks.is_loaded(-2, 0)).is_false()


func test_center_follows_negative_chunks_too() -> void:
    # (8,8) → (-1,-1): 대각선 아홉 걸음, 틱 1,5,…,33 → 틱 36 도착. 청크 (-1,-1).
    var sim := _flat_sim(1)
    _submit_walk(sim, -1, -1, 1, 9)
    sim.advance(37)
    assert_bool(sim.state.player.cell() == Vector2i(-1, -1)).is_true()
    assert_bool(sim.state.chunks.center() == Vector2i(-1, -1)).is_true()
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)
    assert_bool(sim.state.chunks.is_loaded(-3, -3)).is_true()
    assert_bool(sim.state.chunks.is_loaded(2, 2)).is_false()


func test_move_on_tick_zero_is_refused_but_facing_turns() -> void:
    # 틱 0 에는 로드 집합이 비어 is_passable 이 전부 false — 걷기는 거부되고 facing 만 바뀐다.
    # 버그가 아니다(SIM_ORDER 1-M1b). 틱 1 부터는 걷는다.
    var sim := _flat_sim(1)
    sim.submit_at(MovePlayerCommand.create(1, 0), 0)
    sim.step()
    assert_bool(sim.state.player.cell() == SPAWN).is_true()
    assert_bool(sim.state.player.is_moving()).is_false()
    assert_bool(sim.state.player.facing == Vector2i(1, 0)).is_true()
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)
    sim.submit_at(MovePlayerCommand.create(1, 0), 1)
    sim.step()
    assert_bool(sim.state.player.is_moving()).is_true()
    assert_bool(sim.state.player.target_cell() == Vector2i(9, 8)).is_true()
    assert_bool(sim.state.player.sub == PlayerState.sub_of(SPAWN) + Vector2i(PlayerState.WALK_SPEED, 0)).is_true()


func test_player_round_trip_across_boundary_is_hash_transparent() -> void:
    # P7 투명성: 변경 없는 청크는 왕복해도 흔적을 남기지 않는다. 최종 위치·방향이 같으면 해시가 같다.
    var a := _flat_sim(9)
    _submit_walk(a, 1, 0, 1, 8)     # (16,8), 청크 (1,0) 로드 — 틱 32 도착
    _submit_walk(a, -1, 0, 41, 8)   # 다시 (8,8), 틱 72 도착
    a.advance(80)

    var b := _flat_sim(9)
    _submit_walk(b, 1, 0, 1, 1)     # (9,8)
    _submit_walk(b, -1, 0, 41, 1)   # 다시 (8,8), 같은 facing (-1,0)
    b.advance(80)

    assert_bool(a.state.player.cell() == SPAWN).is_true()
    assert_bool(b.state.player.cell() == SPAWN).is_true()
    assert_str(a.state_hash()).is_equal(b.state_hash())
    assert_int(a.state.chunks.snapshot_count()).is_equal(0)


func test_move_command_is_recorded_in_log() -> void:
    var sim := Simulation.create_default(1)
    sim.submit_at(MovePlayerCommand.create(-1, 1), 2)
    var log := sim.command_log()
    assert_int(log.size()).is_equal(1)
    assert_str(str(log[0]["type"])).is_equal("move_player")
    assert_int(int(log[0]["tick"])).is_equal(2)
    assert_int(int(log[0]["dx"])).is_equal(-1)
    assert_int(int(log[0]["dy"])).is_equal(1)


func test_replaying_log_with_moves_reproduces_hash() -> void:
    var original := Simulation.create_default(7)
    original.submit_at(MovePlayerCommand.create(1, -1), 1)
    original.submit_at(MovePlayerCommand.create(1, 0), 5)
    original.submit_at(RollValueCommand.create(&"die", 1, 6), 6)
    original.submit_at(MovePlayerCommand.create(0, 1), 9)
    original.advance(20)

    var replay := Simulation.create_default(7)
    for data: Dictionary in original.command_log():
        replay.submit_at(SimCommandCodec.from_dict(data), int(data["tick"]))
    replay.advance(20)

    assert_str(replay.state_hash()).is_equal(original.state_hash())
    assert_bool(replay.state.player.sub == original.state.player.sub).is_true()
    assert_bool(replay.state.player.facing == Vector2i(0, 1)).is_true()


# --- 소스 가드 ---

func test_set_center_is_not_called_from_commands_or_view() -> void:
    var offenders := PackedStringArray()
    _collect_files_containing("res://sim/commands", "set_center(", offenders)
    _collect_files_containing("res://view", "set_center(", offenders)
    assert_array(offenders).is_empty()


func test_set_center_is_called_exactly_once_in_simulation() -> void:
    assert_int(_count_in_file("res://sim/simulation.gd", "set_center(")).is_equal(1)


func test_old_center_names_are_gone_from_sim_view_and_test() -> void:
    # 로드 중심은 상태가 아니다 — 플레이어 발 칸에서 유도된다(M1-6a-2). 옛 이름이 어디에도 남지 않는다.
    # 이 파일 자신이 걸리지 않도록 찾을 문자열은 이어 붙여 만든다.
    for needle: String in ["load_" + "center", "SetLoad" + "Center", "_pending" + "_center"]:
        var offenders := PackedStringArray()
        _collect_files_containing("res://sim", needle, offenders)
        _collect_files_containing("res://view", needle, offenders)
        _collect_files_containing("res://test", needle, offenders)
        assert_array(offenders).override_failure_message("'%s' 가 남아 있다" % needle).is_empty()


func test_simulation_new_is_called_only_inside_simulation_create() -> void:
    # 테스트·view 는 create/create_default 만 쓴다. null 검사를 우회하는 생성 경로를 막는다.
    # 이 파일 자신이 걸리지 않도록 찾을 문자열은 이어 붙여 만든다.
    var needle := "Simulation" + ".new("
    assert_int(_count_in_file("res://sim/simulation.gd", needle)).is_equal(1)
    var offenders := PackedStringArray()
    _collect_files_containing("res://test", needle, offenders)
    _collect_files_containing("res://view", needle, offenders)
    assert_array(offenders).is_empty()


func _count_in_file(path: String, needle: String) -> int:
    assert_bool(FileAccess.file_exists(path)).is_true()
    return FileAccess.get_file_as_string(path).count(needle)


func _collect_files_containing(dir_path: String, needle: String, offenders: PackedStringArray) -> void:
    var dir := DirAccess.open(dir_path)
    assert_object(dir).is_not_null()
    if dir == null:
        return
    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        var path := dir_path.path_join(entry)
        if dir.current_is_dir():
            _collect_files_containing(path, needle, offenders)
        elif entry.get_extension() == "gd":
            if FileAccess.get_file_as_string(path).contains(needle):
                offenders.append(path)
        entry = dir.get_next()
    dir.list_dir_end()


func test_command_log_records_submissions_in_order() -> void:
    # 저장 형식의 뿌리. 접수한 차례 그대로, 큐가 새긴 틱까지 적혀야 한다.
    var sim := Simulation.create_default(1)
    sim.advance(2)
    sim.submit(SetValueCommand.create(&"wood", 1))
    sim.submit_at(AddValueCommand.create(&"ore", 2), 9)
    assert_int(sim.command_count()).is_equal(2)

    var log := sim.command_log()
    assert_str(str(log[0]["type"])).is_equal("set_value")
    assert_int(int(log[0]["tick"])).is_equal(2)
    assert_str(str(log[1]["type"])).is_equal("add_value")
    assert_int(int(log[1]["tick"])).is_equal(9)


func test_command_log_ignores_null_submission() -> void:
    var sim := Simulation.create_default(1)
    assert_object(sim.submit(null)).is_null()
    assert_int(sim.command_count()).is_equal(0)


func test_command_log_is_a_copy() -> void:
    var sim := Simulation.create_default(1)
    sim.submit(SetValueCommand.create(&"wood", 1))
    var log := sim.command_log()
    log.clear()
    assert_int(sim.command_count()).is_equal(1)


func test_replaying_the_command_log_reproduces_the_hash() -> void:
    var original := Simulation.create_default(7)
    original.submit_at(SetValueCommand.create(&"wood", 3), 1)
    original.submit_at(RollValueCommand.create(&"die", 1, 6), 4)
    original.advance(10)

    var replay := Simulation.create_default(7)
    for data: Dictionary in original.command_log():
        var command := SimCommandCodec.from_dict(data)
        replay.submit_at(command, int(data["tick"]))
    replay.advance(10)

    assert_str(replay.state_hash()).is_equal(original.state_hash())


func test_simulation_runs_without_scene_tree() -> void:
    # 시뮬레이션은 노드 트리를 모른다. 헤드리스로 단독 생성·실행된다.
    var sim := Simulation.create_default(1)
    assert_str(sim.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(sim.get_class(), "Node")).is_false()
    sim.advance(5)
    assert_int(sim.current_tick()).is_equal(5)


func test_tick_interval_matches_tick_rate() -> void:
    # TickDriver 의 기본 간격이 이 상수를 본다. 20tps = 50,000µs.
    assert_int(Simulation.TICK_RATE).is_equal(20)
    assert_int(Simulation.TICK_INTERVAL_USEC).is_equal(50_000)
    assert_int(TickDriver.new().interval_usec()).is_equal(Simulation.TICK_INTERVAL_USEC)
