extends GdUnitTestSuite

## 고정 틱 루프와 명령 소비 검증. 생성 경로(create/create_default), 로드 중심 동기화,
## P7 투명성, set_center·Simulation.new 소스 가드.


func _registry() -> BlockRegistry:
    var registry := BlockRegistry.load_default()
    assert_object(registry).is_not_null()
    return registry


func _terrain(registry: BlockRegistry) -> TerrainTable:
    var terrain := TerrainTable.load_default(registry)
    assert_object(terrain).is_not_null()
    return terrain


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


func test_empty_world_step_touches_only_the_tick() -> void:
    # 명령이 없으면 틱 말고는 아무것도 바뀌지 않는다.
    # 난수원도 돌지 않고 값도 생기지 않고 청크도 로드되지 않는다.
    var sim := Simulation.create_default(1)
    var rng_before := sim.state.rng.get_state()
    sim.advance(50)
    assert_int(sim.state.rng.get_state()).is_equal(rng_before)
    assert_int(sim.state.value_count()).is_equal(0)
    assert_int(sim.state.chunks.loaded_count()).is_equal(0)
    assert_bool(sim.state.chunks.has_center()).is_false()
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


func test_create_default_has_chunks_and_tables_without_center() -> void:
    var sim := Simulation.create_default(1)
    assert_object(sim).is_not_null()
    assert_object(sim.state.chunks).is_not_null()
    assert_object(sim.registry).is_not_null()
    assert_object(sim.terrain).is_not_null()
    assert_bool(sim.state.chunks.has_center()).is_false()
    assert_int(sim.state.chunks.loaded_count()).is_equal(0)
    assert_bool(sim.state.has_load_center).is_false()


func test_create_default_and_create_agree() -> void:
    var registry := _registry()
    var explicit := Simulation.create(5, registry, _terrain(registry))
    var implicit := Simulation.create_default(5)
    explicit.submit(SetLoadCenterCommand.create(0, 0))
    implicit.submit(SetLoadCenterCommand.create(0, 0))
    explicit.advance(3)
    implicit.advance(3)
    assert_str(implicit.state_hash()).is_equal(explicit.state_hash())


# --- 로드 중심 동기화 ---

func test_load_center_command_loads_chunks_on_step() -> void:
    var sim := Simulation.create_default(1)
    sim.submit(SetLoadCenterCommand.create(0, 0))
    assert_int(sim.state.chunks.loaded_count()).is_equal(0)
    assert_bool(sim.state.has_load_center).is_false()
    sim.step()
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)
    assert_bool(sim.state.chunks.center() == Vector2i(0, 0)).is_true()
    assert_bool(sim.state.chunks.has_center()).is_true()
    assert_bool(sim.state.has_load_center).is_true()
    assert_bool(sim.state.load_center == Vector2i(0, 0)).is_true()


func test_command_apply_sets_target_but_step_loads() -> void:
    # 순서: 명령은 load_center 만 바꾼다. set_center 는 step() 의 동기화 단계가 부른다.
    var sim := Simulation.create_default(1)
    SetLoadCenterCommand.create(2, -1).apply(sim.state)
    assert_bool(sim.state.has_load_center).is_true()
    assert_bool(sim.state.chunks.has_center()).is_false()
    assert_int(sim.state.chunks.loaded_count()).is_equal(0)
    sim.step()
    assert_bool(sim.state.chunks.has_center()).is_true()
    assert_bool(sim.state.chunks.center() == Vector2i(2, -1)).is_true()
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)


func test_moving_load_center_follows_on_next_step() -> void:
    var sim := Simulation.create_default(1)
    sim.submit_at(SetLoadCenterCommand.create(0, 0), 0)
    sim.submit_at(SetLoadCenterCommand.create(1, 0), 2)
    sim.advance(2)
    assert_bool(sim.state.chunks.center() == Vector2i(0, 0)).is_true()
    sim.step()
    assert_bool(sim.state.chunks.center() == Vector2i(1, 0)).is_true()
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)
    assert_bool(sim.state.chunks.is_loaded(3, 0)).is_true()
    assert_bool(sim.state.chunks.is_loaded(-2, 0)).is_false()


func test_load_center_path_is_hash_transparent() -> void:
    # P7 투명성: 변경 없는 청크는 왕복해도 흔적을 남기지 않는다. 최종 중심이 같으면 해시가 같다.
    var a := Simulation.create_default(9)
    a.submit_at(SetLoadCenterCommand.create(0, 0), 0)
    a.submit_at(SetLoadCenterCommand.create(1, 0), 3)
    a.submit_at(SetLoadCenterCommand.create(0, 0), 6)
    a.advance(10)

    var b := Simulation.create_default(9)
    b.submit_at(SetLoadCenterCommand.create(0, 0), 0)
    b.advance(10)

    assert_str(a.state_hash()).is_equal(b.state_hash())
    assert_int(a.state.chunks.snapshot_count()).is_equal(0)


func test_load_center_command_is_recorded_in_log() -> void:
    var sim := Simulation.create_default(1)
    sim.submit_at(SetLoadCenterCommand.create(4, -3), 2)
    var log := sim.command_log()
    assert_int(log.size()).is_equal(1)
    assert_str(str(log[0]["type"])).is_equal("set_load_center")
    assert_int(int(log[0]["tick"])).is_equal(2)
    assert_int(int(log[0]["cx"])).is_equal(4)
    assert_int(int(log[0]["cy"])).is_equal(-3)


func test_resubmitting_same_load_center_keeps_hash() -> void:
    var sim := Simulation.create_default(1)
    sim.submit(SetLoadCenterCommand.create(0, 0))
    sim.step()
    var before := sim.state_hash()
    sim.submit(SetLoadCenterCommand.create(0, 0))
    sim.step()
    # 틱은 올랐으니 틱 필드만 다르다. 틱을 되돌려 비교한다.
    sim.state.tick -= 1
    assert_str(sim.state_hash()).is_equal(before)
    assert_int(sim.state.chunks.loaded_count()).is_equal(25)


func test_replaying_log_with_load_center_reproduces_hash() -> void:
    var original := Simulation.create_default(7)
    original.submit_at(SetLoadCenterCommand.create(0, 0), 0)
    original.submit_at(SetLoadCenterCommand.create(-1, 2), 4)
    original.submit_at(RollValueCommand.create(&"die", 1, 6), 5)
    original.advance(10)

    var replay := Simulation.create_default(7)
    for data: Dictionary in original.command_log():
        replay.submit_at(SimCommandCodec.from_dict(data), int(data["tick"]))
    replay.advance(10)

    assert_str(replay.state_hash()).is_equal(original.state_hash())
    assert_bool(replay.state.chunks.center() == Vector2i(-1, 2)).is_true()


# --- 소스 가드 ---

func test_set_center_is_not_called_from_commands_or_view() -> void:
    var offenders := PackedStringArray()
    _collect_files_containing("res://sim/commands", "set_center(", offenders)
    _collect_files_containing("res://view", "set_center(", offenders)
    assert_array(offenders).is_empty()


func test_set_center_is_called_exactly_once_in_simulation() -> void:
    assert_int(_count_in_file("res://sim/simulation.gd", "set_center(")).is_equal(1)


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
