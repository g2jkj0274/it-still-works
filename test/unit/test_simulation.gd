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


func test_simulation_runs_without_scene_tree() -> void:
    # 시뮬레이션은 노드 트리를 모른다. 헤드리스로 단독 생성·실행된다.
    var sim := Simulation.new(1)
    assert_str(sim.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(sim.get_class(), "Node")).is_false()
    sim.advance(5)
    assert_int(sim.current_tick()).is_equal(5)
