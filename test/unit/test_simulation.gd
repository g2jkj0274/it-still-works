extends GdUnitTestSuite

## 고정 틱 루프와 명령 소비 검증.


func test_starts_at_tick_zero() -> void:
    assert_int(Simulation.new(1).current_tick()).is_equal(0)


func test_step_advances_one_tick() -> void:
    var sim := Simulation.new(1)
    sim.step()
    assert_int(sim.current_tick()).is_equal(1)


func test_advance_runs_requested_ticks() -> void:
    var sim := Simulation.new(1)
    sim.advance(7)
    assert_int(sim.current_tick()).is_equal(7)


func test_advance_with_non_positive_count_does_nothing() -> void:
    var sim := Simulation.new(1)
    sim.advance(0)
    sim.advance(-3)
    assert_int(sim.current_tick()).is_equal(0)


func test_submitted_command_applies_on_next_step() -> void:
    var sim := Simulation.new(1)
    sim.submit(SetValueCommand.create(&"wood", 5))
    assert_int(sim.state.get_value(&"wood")).is_equal(0)
    sim.step()
    assert_int(sim.state.get_value(&"wood")).is_equal(5)


func test_command_applies_exactly_once() -> void:
    var sim := Simulation.new(1)
    sim.submit(AddValueCommand.create(&"wood", 1))
    sim.advance(10)
    assert_int(sim.state.get_value(&"wood")).is_equal(1)


func test_future_command_does_not_apply_early() -> void:
    var sim := Simulation.new(1)
    sim.submit_at(SetValueCommand.create(&"wood", 9), 3)
    sim.advance(3)
    assert_int(sim.state.get_value(&"wood")).is_equal(0)
    sim.step()
    assert_int(sim.state.get_value(&"wood")).is_equal(9)


func test_same_tick_commands_apply_in_submission_order() -> void:
    var sim := Simulation.new(1)
    sim.submit(SetValueCommand.create(&"wood", 1))
    sim.submit(SetValueCommand.create(&"wood", 2))
    sim.step()
    assert_int(sim.state.get_value(&"wood")).is_equal(2)


func test_queue_is_drained_after_step() -> void:
    var sim := Simulation.new(1)
    sim.submit(SetValueCommand.create(&"wood", 1))
    sim.step()
    assert_bool(sim.queue.is_empty()).is_true()


func test_state_hash_changes_as_ticks_pass() -> void:
    var sim := Simulation.new(1)
    var before := sim.state_hash()
    sim.step()
    assert_str(sim.state_hash()).is_not_equal(before)


func test_empty_world_step_touches_only_the_tick() -> void:
    # M0 빈 세계: 명령이 없으면 틱 말고는 아무것도 바뀌지 않는다.
    # 난수원도 돌지 않고 값도 생기지 않는다.
    var sim := Simulation.new(1)
    var rng_before := sim.state.rng.get_state()
    sim.advance(50)
    assert_int(sim.state.rng.get_state()).is_equal(rng_before)
    assert_int(sim.state.value_count()).is_equal(0)
    assert_int(sim.current_tick()).is_equal(50)


func test_command_log_records_submissions_in_order() -> void:
    # 저장 형식의 뿌리. 접수한 차례 그대로, 큐가 새긴 틱까지 적혀야 한다.
    var sim := Simulation.new(1)
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
    var sim := Simulation.new(1)
    assert_object(sim.submit(null)).is_null()
    assert_int(sim.command_count()).is_equal(0)


func test_command_log_is_a_copy() -> void:
    var sim := Simulation.new(1)
    sim.submit(SetValueCommand.create(&"wood", 1))
    var log := sim.command_log()
    log.clear()
    assert_int(sim.command_count()).is_equal(1)


func test_replaying_the_command_log_reproduces_the_hash() -> void:
    var original := Simulation.new(7)
    original.submit_at(SetValueCommand.create(&"wood", 3), 1)
    original.submit_at(RollValueCommand.create(&"die", 1, 6), 4)
    original.advance(10)

    var replay := Simulation.new(7)
    for data: Dictionary in original.command_log():
        var command := SimCommandCodec.from_dict(data)
        replay.submit_at(command, int(data["tick"]))
    replay.advance(10)

    assert_str(replay.state_hash()).is_equal(original.state_hash())


func test_simulation_runs_without_scene_tree() -> void:
    # 시뮬레이션은 노드 트리를 모른다. 헤드리스로 단독 생성·실행된다.
    var sim := Simulation.new(1)
    assert_str(sim.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(sim.get_class(), "Node")).is_false()
    sim.advance(5)
    assert_int(sim.current_tick()).is_equal(5)


func test_tick_interval_matches_tick_rate() -> void:
    # TickDriver 의 기본 간격이 이 상수를 본다. 20tps = 50,000µs.
    assert_int(Simulation.TICK_RATE).is_equal(20)
    assert_int(Simulation.TICK_INTERVAL_USEC).is_equal(50_000)
    assert_int(TickDriver.new().interval_usec()).is_equal(Simulation.TICK_INTERVAL_USEC)
