extends GdUnitTestSuite

## 입력 → 명령 변환 검증.
##
## 입력 레이어는 월드 상태를 직접 고치지 않는다. 명령을 만들어 큐에 넣을 뿐이다.


func _controller(sim: Simulation) -> InputController:
    var controller: InputController = auto_free(InputController.new())
    add_child(controller)
    controller.bind(sim)
    return controller


func _sim() -> Simulation:
    var sim := Simulation.new(1)
    IslandBuilder.populate(sim.state)
    for type in InputController.PLACEABLE:
        sim.state.inventory.add(type, 4)
    return sim


func test_move_actions_map_to_the_four_directions() -> void:
    var directions: Array = []
    for entry: Array in InputController.MOVE_ACTIONS:
        var dir: Vector3i = entry[1]
        assert_bool(MovementRules.is_direction(dir)).is_true()
        assert_bool(directions.has(dir)).is_false()
        directions.append(dir)
    assert_int(directions.size()).is_equal(4)


func test_unknown_action_maps_to_no_direction() -> void:
    assert_bool(InputController.direction_for_action(&"nope") == Vector3i.ZERO).is_true()


func test_submitting_a_move_only_queues_a_command() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var before := sim.state_hash()

    controller.submit_move(Vector3i(0, -1, 0))
    assert_int(sim.queue.size()).is_equal(1)
    assert_str(sim.state_hash()).is_equal(before)

    sim.advance(10)
    assert_bool(sim.state.character.cell() == IslandBuilder.SPAWN + Vector3i(0, -1, 0)).is_true()


func test_place_targets_the_cell_in_front() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    controller.select_block(BlockType.STONE)
    var target := sim.state.character.facing_cell()

    controller.submit_place()
    sim.advance(2)
    assert_int(sim.state.grid.get_block(target)).is_equal(BlockType.STONE)


func test_break_targets_the_cell_in_front() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var target := sim.state.character.facing_cell()
    sim.state.grid.set_block(target, BlockType.WOOD)

    controller.submit_break()
    sim.advance(2)
    assert_bool(sim.state.grid.is_solid(target)).is_false()


func test_selection_is_limited_to_placeable_blocks() -> void:
    var controller := _controller(_sim())
    for type in InputController.PLACEABLE:
        controller.select_block(type)
        assert_int(controller.selected_block()).is_equal(type)

    var last := controller.selected_block()
    for bad in [BlockType.EMPTY, BlockType.COUNT, -1]:
        controller.select_block(bad)
        assert_int(controller.selected_block()).is_equal(last)


func test_actions_are_installed_into_the_input_map() -> void:
    InputController.install_actions()
    for entry: Array in InputController.MOVE_ACTIONS:
        assert_bool(InputMap.has_action(entry[0])).is_true()
    assert_bool(InputMap.has_action(InputController.ACTION_PLACE)).is_true()
    assert_bool(InputMap.has_action(InputController.ACTION_BREAK)).is_true()


func test_installing_twice_does_not_duplicate_events() -> void:
    InputController.install_actions()
    var action: StringName = InputController.MOVE_ACTIONS[0][0]
    var count := InputMap.action_get_events(action).size()
    InputController.install_actions()
    assert_int(InputMap.action_get_events(action).size()).is_equal(count)


func _target_on(cell: Vector3i, normal: Vector3i) -> BlockTarget:
    var target := BlockTarget.new()
    target.hit = true
    target.cell = cell
    target.normal = normal
    return target


func test_without_a_target_the_cell_in_front_is_used() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    controller.clear_target()
    assert_bool(controller.has_target()).is_false()
    assert_bool(controller.break_cell() == sim.state.character.facing_cell()).is_true()
    assert_bool(controller.place_cell() == sim.state.character.facing_cell()).is_true()


func test_breaking_uses_the_targeted_cell() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var aimed := IslandBuilder.SPAWN + Vector3i(2, 0, -1)
    controller.set_target(_target_on(aimed, VoxelGrid.UP))
    assert_bool(controller.break_cell() == aimed).is_true()


func test_placing_uses_the_face_of_the_targeted_cell() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var aimed := IslandBuilder.SPAWN + Vector3i(2, 0, -1)
    controller.set_target(_target_on(aimed, VoxelGrid.UP))
    assert_bool(controller.place_cell() == aimed + VoxelGrid.UP).is_true()


func test_a_missed_target_falls_back_to_the_cell_in_front() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    controller.set_target(BlockTarget.new())
    assert_bool(controller.has_target()).is_false()
    assert_bool(controller.break_cell() == sim.state.character.facing_cell()).is_true()


func test_targeted_break_reaches_a_block_that_is_not_in_front() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var aimed := IslandBuilder.SPAWN + Vector3i(3, 3, -1)
    assert_bool(sim.state.grid.is_solid(aimed)).is_true()

    controller.set_target(_target_on(aimed, VoxelGrid.UP))
    controller.submit_break()
    sim.advance(2)
    assert_bool(sim.state.grid.is_solid(aimed)).is_false()
