extends GdUnitTestSuite

## 묶기를 손으로 하는 길 검증.
##
## 입력은 월드를 직접 고치지 않는다. 여기서도 명령을 만들 뿐이고, 그것이
## 시뮬레이션을 지나야 세상이 바뀐다.

const FLOOR_Z := 1
const A := Vector3i(4, 4, 2)
const B := Vector3i(5, 4, 2)
const C := Vector3i(6, 4, 2)


func _sim() -> Simulation:
    var sim := Simulation.new(31)
    for x in range(3, 9):
        sim.state.grid.set_block(Vector3i(x, 4, FLOOR_Z), BlockType.GROUND)
    sim.state.inventory.add(BlockType.BOX, 4)
    sim.state.inventory.add(BlockType.DETECTOR, 4)
    sim.state.inventory.add(BlockType.ACTUATOR, 4)
    return sim


func _controller(sim: Simulation) -> InputController:
    var controller: InputController = auto_free(InputController.new())
    add_child(controller)
    controller.bind(sim)
    return controller


## 겨냥한 곳이 없으면 앞 칸을 쓴다. 테스트에서는 겨냥을 직접 만들어 준다.
func _aim(controller: InputController, cell: Vector3i) -> void:
    var target := BlockTarget.new()
    target.hit = true
    target.cell = cell
    # 새 블록은 맞은 면 바깥에 놓인다. 여기서는 늘 윗면을 맞혔다고 본다.
    target.normal = VoxelGrid.UP
    controller.set_target(target)


func _place_three_boxes(sim: Simulation) -> void:
    for cell in [A, B, C]:
        sim.submit(PlacePartCommand.create(
            cell, BlockType.BOX, PackedInt32Array([BoxPart.SHAPE_SQUARE])))
    sim.step()


func test_only_a_cell_with_a_part_can_be_chosen() -> void:
    var sim := _sim()
    _place_three_boxes(sim)
    var controller := _controller(sim)

    _aim(controller, A)
    controller.toggle_chosen()
    assert_int(controller.chosen_cells().size()).is_equal(1)

    _aim(controller, Vector3i(20, 20, 5))
    controller.toggle_chosen()
    assert_int(controller.chosen_cells().size()).is_equal(1)


func test_choosing_the_same_cell_again_lets_it_go() -> void:
    var sim := _sim()
    _place_three_boxes(sim)
    var controller := _controller(sim)

    _aim(controller, A)
    controller.toggle_chosen()
    controller.toggle_chosen()
    assert_bool(controller.is_choosing()).is_false()


func test_a_chosen_cell_can_be_made_an_entry_or_an_exit() -> void:
    var sim := _sim()
    _place_three_boxes(sim)
    var controller := _controller(sim)

    _aim(controller, A)
    controller.toggle_chosen()
    assert_int(controller.role_of(A)).is_equal(InputController.ROLE_PLAIN)

    controller.cycle_role()
    assert_int(controller.role_of(A)).is_equal(InputController.ROLE_ENTRY)
    assert_array(controller.bundle_entries()).contains([A])

    controller.cycle_role()
    assert_int(controller.role_of(A)).is_equal(InputController.ROLE_EXIT)
    assert_array(controller.bundle_exits()).contains([A])

    controller.cycle_role()
    assert_int(controller.role_of(A)).is_equal(InputController.ROLE_PLAIN)


func test_a_cell_that_was_not_chosen_has_no_role() -> void:
    var sim := _sim()
    _place_three_boxes(sim)
    var controller := _controller(sim)

    _aim(controller, B)
    controller.cycle_role()
    assert_int(controller.role_of(B)).is_equal(InputController.ROLE_PLAIN)
    assert_bool(controller.is_choosing()).is_false()


func test_letting_a_cell_go_takes_its_role_with_it() -> void:
    var sim := _sim()
    _place_three_boxes(sim)
    var controller := _controller(sim)

    _aim(controller, A)
    controller.toggle_chosen()
    controller.cycle_role()
    controller.toggle_chosen()
    controller.toggle_chosen()
    assert_int(controller.role_of(A)).is_equal(InputController.ROLE_PLAIN)


func test_the_order_of_choosing_is_the_order_values_go_in() -> void:
    var sim := _sim()
    _place_three_boxes(sim)
    var controller := _controller(sim)

    # 나중 것을 먼저 고르면 그것이 첫째 자리가 된다.
    for cell in [C, A]:
        _aim(controller, cell)
        controller.toggle_chosen()
        controller.cycle_role()

    assert_array(controller.bundle_entries()).is_equal([C, A])


func test_bundling_goes_through_the_command_queue() -> void:
    var sim := _sim()
    _place_three_boxes(sim)
    var controller := _controller(sim)

    for cell in [A, B]:
        _aim(controller, cell)
        controller.toggle_chosen()

    controller.submit_bundle()
    # 아직은 세상이 그대로다. 명령이 소비되어야 바뀐다.
    assert_int(sim.state.circuit.part_count()).is_equal(3)
    assert_bool(controller.is_choosing()).is_false()

    sim.step()
    assert_int(sim.state.circuit.part_count()).is_equal(1)
    assert_int(sim.state.inventory.count_of_bundle(0)).is_equal(1)


func test_a_new_bundle_lands_in_the_hand_by_itself() -> void:
    var sim := _sim()
    _place_three_boxes(sim)
    var controller := _controller(sim)
    assert_int(controller.held_bundle()).is_equal(-1)

    _aim(controller, A)
    controller.toggle_chosen()
    controller.submit_bundle()
    sim.step()

    controller.cycle_held_bundle()
    assert_int(controller.held_bundle()).is_equal(0)


func test_holding_a_bundle_walks_through_the_ones_in_hand() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    sim.state.inventory.add_bundle(0, 1)
    sim.state.inventory.add_bundle(2, 1)

    controller.cycle_held_bundle()
    assert_int(controller.selected_block()).is_equal(BlockType.BUNDLE)
    assert_int(controller.held_bundle()).is_equal(0)

    controller.cycle_held_bundle()
    assert_int(controller.held_bundle()).is_equal(2)

    controller.cycle_held_bundle()
    assert_int(controller.held_bundle()).is_equal(0)


func test_an_empty_hand_places_no_bundle() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    _aim(controller, A)

    controller.cycle_held_bundle()
    controller.submit_place()
    sim.step()
    assert_int(sim.state.circuit.part_count()).is_equal(0)


func test_a_held_bundle_is_placed_with_its_own_number() -> void:
    var sim := _sim()
    _place_three_boxes(sim)
    var controller := _controller(sim)

    _aim(controller, A)
    controller.toggle_chosen()
    controller.submit_bundle()
    sim.step()
    controller.refresh_held_bundle()
    controller.cycle_held_bundle()

    _aim(controller, Vector3i(7, 4, FLOOR_Z))
    controller.submit_place()
    sim.step()

    var placed := Vector3i(7, 4, FLOOR_Z + 1)
    assert_int(sim.state.grid.get_block(placed)).is_equal(BlockType.BUNDLE)
    assert_int((sim.state.circuit.part_at(placed) as BundlePart).bundle_id).is_equal(0)


func test_a_bundle_that_is_gone_leaves_the_hand() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    sim.state.inventory.add_bundle(0, 1)
    controller.cycle_held_bundle()
    assert_int(controller.held_bundle()).is_equal(0)

    sim.state.inventory.take_bundle(0, 1)
    controller.refresh_held_bundle()
    assert_int(controller.held_bundle()).is_equal(-1)


func test_the_line_says_what_is_being_bundled() -> void:
    var sim := _sim()
    _place_three_boxes(sim)
    var controller := _controller(sim)

    _aim(controller, A)
    controller.toggle_chosen()
    controller.cycle_role()

    var line := PartHint.line_for(controller)
    assert_str(line).contains("묶는 중")
    # 프로그래밍 용어가 화면에 나오면 안 된다.
    assert_str(line.to_lower()).not_contains("function")
    assert_str(line).not_contains("함수")
    assert_str(line).not_contains("매개변수")


func test_the_marks_follow_what_was_chosen() -> void:
    var sim := _sim()
    _place_three_boxes(sim)
    var controller := _controller(sim)
    var marks: BundleMarks = auto_free(BundleMarks.new())
    add_child(marks)
    marks.bind(controller)

    marks.sync()
    assert_int(marks.marked_count()).is_equal(0)
    assert_bool(marks.visible).is_false()

    for cell in [A, B]:
        _aim(controller, cell)
        controller.toggle_chosen()
    marks.sync()

    assert_int(marks.marked_count()).is_equal(2)
    assert_bool(marks.visible).is_true()


func test_the_three_roles_are_told_apart_by_colour() -> void:
    var plain := BundleMarks.colour_of_role(InputController.ROLE_PLAIN)
    var entry := BundleMarks.colour_of_role(InputController.ROLE_ENTRY)
    var exit_colour := BundleMarks.colour_of_role(InputController.ROLE_EXIT)
    assert_bool(plain.is_equal_approx(entry)).is_false()
    assert_bool(entry.is_equal_approx(exit_colour)).is_false()
    assert_bool(plain.is_equal_approx(exit_colour)).is_false()


func test_the_hotbar_shows_which_bundle_is_in_hand() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    sim.state.inventory.add_bundle(1, 2)
    controller.cycle_held_bundle()

    var hotbar: Hotbar = auto_free(Hotbar.new())
    add_child(hotbar)
    hotbar.bind(sim.state.inventory, controller)
    hotbar.sync()

    var slot := controller.selected_slot()
    assert_int(controller.held_bundle()).is_equal(1)
    assert_str(hotbar.slot_text(slot)).contains(PartWords.name_of(BlockType.BUNDLE))
    assert_str(hotbar.slot_text(slot)).contains("2")
