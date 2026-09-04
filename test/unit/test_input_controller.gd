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


func test_move_actions_cover_the_four_screen_directions() -> void:
    var screens: Array = []
    for entry: Array in InputController.MOVE_ACTIONS:
        var screen: Vector2i = entry[1]
        assert_bool(ScreenDirections.SCREEN_ORDER.has(screen)).is_true()
        assert_bool(screens.has(screen)).is_false()
        screens.append(screen)
    assert_int(screens.size()).is_equal(4)


func test_unknown_action_maps_to_no_screen_direction() -> void:
    assert_bool(InputController.screen_for_action(&"nope") == Vector2i.ZERO).is_true()


func test_without_a_camera_the_keys_still_move() -> void:
    # 헤드리스에서도 이동은 되어야 한다. 카메라가 없으면 고정 배치로 물러난다.
    var controller := _controller(_sim())
    var directions: Array = []
    for entry: Array in InputController.MOVE_ACTIONS:
        var grid := controller.grid_for_screen(entry[1])
        assert_bool(MovementRules.is_direction(grid)).is_true()
        assert_bool(directions.has(grid)).is_false()
        directions.append(grid)
    assert_int(directions.size()).is_equal(4)


func test_opposite_keys_give_opposite_directions() -> void:
    var controller := _controller(_sim())
    var up := controller.grid_for_screen(ScreenDirections.UP)
    var down := controller.grid_for_screen(ScreenDirections.DOWN)
    var left := controller.grid_for_screen(ScreenDirections.LEFT)
    var right := controller.grid_for_screen(ScreenDirections.RIGHT)
    assert_bool(up == -down).is_true()
    assert_bool(left == -right).is_true()


func test_the_help_starts_hidden_and_toggles() -> void:
    var controller := _controller(_sim())
    assert_bool(controller.help_shown()).is_false()
    controller.toggle_help()
    assert_bool(controller.help_shown()).is_true()
    controller.toggle_help()
    assert_bool(controller.help_shown()).is_false()


func test_only_parts_with_choices_report_a_setting() -> void:
    var controller := _controller(_sim())
    controller.select_block(BlockType.WOOD)
    assert_bool(controller.has_part_setting()).is_false()

    for part_type in InputController.PARTS_WITH_SETTINGS:
        controller.select_block(part_type)
        assert_bool(controller.has_part_setting()).is_true()
        assert_str(controller.part_setting_name()).is_not_empty()
        assert_str(controller.part_setting_name()).is_not_equal("?")


func test_the_setting_name_follows_the_choice() -> void:
    var controller := _controller(_sim())
    controller.select_block(BlockType.BOX)
    var first := controller.part_setting_name()
    controller.cycle_part_setting()
    assert_str(controller.part_setting_name()).is_not_equal(first)


func test_submitting_a_move_only_queues_a_command() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var before := sim.state_hash()

    controller.submit_move(Vector3i(0, -1, 0))
    assert_int(sim.queue.size()).is_equal(1)
    assert_str(sim.state_hash()).is_equal(before)

    sim.advance(10)
    assert_bool(sim.state.character.cell() == IslandBuilder.spawn_cell() + Vector3i(0, -1, 0)).is_true()


func test_place_targets_the_cell_in_front() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    controller.select_block(BlockType.ORE)
    var target := sim.state.character.facing_cell()

    controller.submit_place()
    sim.advance(2)
    assert_int(sim.state.grid.get_block(target)).is_equal(BlockType.ORE)


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
    var aimed := IslandBuilder.spawn_cell() + Vector3i(2, 0, -1)
    controller.set_target(_target_on(aimed, VoxelGrid.UP))
    assert_bool(controller.break_cell() == aimed).is_true()


func test_placing_uses_the_face_of_the_targeted_cell() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var aimed := IslandBuilder.spawn_cell() + Vector3i(2, 0, -1)
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
    # 지표가 기복을 타므로 그 기둥의 높이를 따라 겨냥한다.
    var column := IslandBuilder.SPAWN_COLUMN + Vector2i(3, 3)
    var aimed := Vector3i(column.x, column.y, IslandBuilder.surface_z(column))
    assert_bool(sim.state.grid.is_solid(aimed)).is_true()

    controller.set_target(_target_on(aimed, VoxelGrid.UP))
    controller.submit_break()
    sim.advance(2)
    assert_bool(sim.state.grid.is_solid(aimed)).is_false()


func test_choosing_a_part_places_a_part_not_a_block() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    controller.select_block(BlockType.DETECTOR)
    var cell := sim.state.character.facing_cell()

    controller.submit_place()
    sim.advance(2)
    assert_int(sim.state.grid.get_block(cell)).is_equal(BlockType.DETECTOR)
    assert_bool(sim.state.circuit.has_part(cell)).is_true()


func test_the_detector_watches_what_was_chosen() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    assert_int(controller.detector_target()).is_equal(DetectorPart.TARGET_PLAYER)

    controller.cycle_part_setting()
    var chosen := controller.detector_target()
    assert_int(chosen).is_not_equal(DetectorPart.TARGET_PLAYER)

    controller.select_block(BlockType.DETECTOR)
    var cell := sim.state.character.facing_cell()
    controller.submit_place()
    sim.advance(2)
    assert_int((sim.state.circuit.part_at(cell) as DetectorPart).target).is_equal(chosen)


func test_target_choice_wraps_around() -> void:
    var controller := _controller(_sim())
    for i in DetectorPart.TARGET_COUNT:
        controller.cycle_part_setting()
    assert_int(controller.detector_target()).is_equal(DetectorPart.TARGET_PLAYER)


func test_wiring_needs_two_presses() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var first := Vector3i(32, 31, 2)
    var second := Vector3i(33, 31, 2)
    sim.state.circuit.add_part(DetectorPart.create(first, DetectorPart.TARGET_PLAYER))
    sim.state.circuit.add_part(ActuatorPart.create(second))

    controller.set_target(_target_on(first, VoxelGrid.UP))
    controller.submit_link()
    assert_bool(controller.has_link_source()).is_true()
    assert_int(sim.state.circuit.link_count()).is_equal(0)

    controller.set_target(_target_on(second, VoxelGrid.UP))
    controller.submit_link()
    sim.advance(2)
    assert_bool(controller.has_link_source()).is_false()
    assert_bool(sim.state.circuit.is_linked(first, second)).is_true()


func test_pointing_at_nothing_cancels_the_wiring() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var part := Vector3i(32, 31, 2)
    sim.state.circuit.add_part(DetectorPart.create(part, DetectorPart.TARGET_PLAYER))

    controller.set_target(_target_on(part, VoxelGrid.UP))
    controller.submit_link()
    assert_bool(controller.has_link_source()).is_true()

    controller.set_target(_target_on(Vector3i(20, 20, 1), VoxelGrid.UP))
    controller.submit_link()
    assert_bool(controller.has_link_source()).is_false()
    assert_int(sim.state.circuit.link_count()).is_equal(0)


func _branch_at(sim: Simulation, cell: Vector3i) -> BranchPart:
    var part := BranchPart.create(cell)
    part.configure(PackedInt32Array([BranchPart.MODE_TRUTH, 0]))
    sim.state.circuit.add_part(part)
    return part


func test_the_exit_starts_on_the_true_side() -> void:
    var controller := _controller(_sim())
    assert_int(controller.link_port()).is_equal(BranchPart.PORT_TRUE)
    assert_str(controller.link_port_name()).is_equal("참")


func test_the_exit_switches_and_comes_back() -> void:
    var controller := _controller(_sim())
    controller.cycle_link_port()
    assert_int(controller.link_port()).is_equal(BranchPart.PORT_FALSE)
    assert_str(controller.link_port_name()).is_equal("거짓")
    controller.cycle_link_port()
    assert_int(controller.link_port()).is_equal(BranchPart.PORT_TRUE)


func test_the_setting_key_switches_the_exit_while_wiring_from_a_branch() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var branch := Vector3i(32, 31, 2)
    _branch_at(sim, branch)

    controller.set_target(_target_on(branch, VoxelGrid.UP))
    controller.submit_link()
    assert_bool(controller.wiring_from_branch()).is_true()

    controller.cycle_part_setting()
    assert_int(controller.link_port()).is_equal(BranchPart.PORT_FALSE)


func test_the_setting_key_still_changes_settings_when_not_wiring() -> void:
    var controller := _controller(_sim())
    controller.select_block(BlockType.BOX)
    var before := controller.box_shape()
    controller.cycle_part_setting()
    assert_int(controller.box_shape()).is_not_equal(before)
    assert_int(controller.link_port()).is_equal(BranchPart.PORT_TRUE)


func test_a_wire_leaves_by_the_chosen_exit() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var branch := Vector3i(32, 31, 2)
    var actuator := Vector3i(33, 31, 2)
    _branch_at(sim, branch)
    sim.state.circuit.add_part(ActuatorPart.create(actuator))

    controller.set_target(_target_on(branch, VoxelGrid.UP))
    controller.submit_link()
    controller.cycle_part_setting()
    controller.set_target(_target_on(actuator, VoxelGrid.UP))
    controller.submit_link()
    sim.advance(2)

    assert_bool(sim.state.circuit.is_linked(branch, actuator, BranchPart.PORT_FALSE)).is_true()
    assert_bool(sim.state.circuit.is_linked(branch, actuator, BranchPart.PORT_TRUE)).is_false()


func test_wiring_from_something_else_ignores_the_exit() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var detector := Vector3i(32, 31, 2)
    var actuator := Vector3i(33, 31, 2)
    sim.state.circuit.add_part(DetectorPart.create(detector, DetectorPart.TARGET_PLAYER))
    sim.state.circuit.add_part(ActuatorPart.create(actuator))

    controller.cycle_link_port()
    controller.set_target(_target_on(detector, VoxelGrid.UP))
    controller.submit_link()
    assert_bool(controller.wiring_from_branch()).is_false()

    controller.set_target(_target_on(actuator, VoxelGrid.UP))
    controller.submit_link()
    sim.advance(2)
    assert_bool(sim.state.circuit.is_linked(detector, actuator, 0)).is_true()


func test_two_keys_together_make_a_screen_corner() -> void:
    assert_bool(InputController.combine(ScreenDirections.UP + ScreenDirections.RIGHT)
        == ScreenDirections.UP_RIGHT).is_true()
    assert_bool(InputController.combine(ScreenDirections.DOWN + ScreenDirections.LEFT)
        == ScreenDirections.DOWN_LEFT).is_true()


func test_facing_keys_cancel_each_other() -> void:
    assert_bool(InputController.combine(ScreenDirections.UP + ScreenDirections.DOWN)
        == Vector2i.ZERO).is_true()
    assert_bool(InputController.combine(ScreenDirections.LEFT + ScreenDirections.RIGHT)
        == Vector2i.ZERO).is_true()


func test_three_keys_still_give_one_way() -> void:
    var mixed := ScreenDirections.UP + ScreenDirections.LEFT + ScreenDirections.RIGHT
    assert_bool(InputController.combine(mixed) == ScreenDirections.UP).is_true()


func test_every_screen_way_reaches_a_different_grid_way() -> void:
    var controller := _controller(_sim())
    var seen: Array = []
    for screen in ScreenDirections.SCREEN_ORDER:
        var grid := controller.grid_for_screen(screen)
        assert_bool(MovementRules.is_direction(grid)).is_true()
        assert_bool(seen.has(grid)).is_false()
        seen.append(grid)
    assert_int(seen.size()).is_equal(MovementRules.DIRECTIONS.size())


func test_combined_keys_walk_along_the_grid_axes() -> void:
    # 조합키가 축 방향에 물려 있어야 여덟 쪽이 모두 열린다.
    var controller := _controller(_sim())
    for screen in [ScreenDirections.UP_RIGHT, ScreenDirections.UP_LEFT,
            ScreenDirections.DOWN_RIGHT, ScreenDirections.DOWN_LEFT]:
        assert_bool(MovementRules.is_diagonal(controller.grid_for_screen(screen))).is_false()
