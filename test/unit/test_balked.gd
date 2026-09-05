extends GdUnitTestSuite

## 막혔을 때 알리는지 검증.
##
## **아무 일도 안 일어나는 것이 가장 나쁜 답이다.** 손이 차 있으면 부수기가
## 통째로 막히는데, 화면에서는 키가 안 먹는 것과 구별되지 않았다. 누르고 또
## 눌러도 세상이 그대로면 게임이 고장 난 것으로 읽힌다.
##
## 무엇이 막았는지는 말하지 않는다(스펙 §1). **눌린 것이 닿았고 세상은
## 그대로다**만 알린다. 규칙을 표현 레이어에 옮겨 적지 않고, 명령을 낸 다음
## 세상이 그대로인지만 본다.


func _sim() -> Simulation:
    return Simulation.new(7)


func _controller(sim: Simulation) -> InputController:
    var controller: InputController = auto_free(InputController.new())
    add_child(controller)
    controller.bind(sim)
    return controller


## 막혔다는 소식을 세어 준다.
func _counter(controller: InputController) -> Array[int]:
    var count: Array[int] = [0]
    controller.balked.connect(func() -> void: count[0] += 1)
    return count


func test_making_without_the_materials_says_so() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var count := _counter(controller)

    assert_bool(RecipeBook.has_materials(sim.state.inventory, 0)).is_false()
    controller.submit_craft()
    assert_int(count[0]).is_equal(1)


func test_making_with_the_materials_says_nothing() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var count := _counter(controller)

    sim.state.inventory.add(BlockType.WOOD, 64)
    controller.submit_craft()
    assert_int(count[0]).is_equal(0)


func test_breaking_what_cannot_be_broken_says_so() -> void:
    # 겨냥한 자리가 비어 있다. 눌러도 세상이 그대로다.
    var sim := _sim()
    var controller := _controller(sim)
    var count := _counter(controller)

    assert_int(sim.state.grid.get_block(controller.break_cell())).is_equal(
        BlockType.EMPTY)
    controller.submit_break()
    sim.advance(2)
    controller.poll(sim.current_tick())
    assert_int(count[0]).is_equal(1)


func test_a_break_that_changes_the_world_says_nothing() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var aimed := controller.break_cell()
    # 바위 층 위에 놓아야 부술 수 있다.
    aimed.z = maxi(aimed.z, 1)
    sim.state.grid.set_block(aimed, BlockType.WOOD)

    var count := _counter(controller)
    sim.submit(BreakBlockCommand.create(aimed))
    controller.submit_break()
    sim.advance(2)
    controller.poll(sim.current_tick())

    assert_int(sim.state.grid.get_block(aimed)).is_equal(BlockType.EMPTY)
    assert_int(count[0]).is_equal(0)


func test_nothing_is_said_before_the_tick_has_passed() -> void:
    # 낸 명령이 아직 돌지 않았다. 성급하게 울면 늘 우는 것과 같다.
    var sim := _sim()
    var controller := _controller(sim)
    var count := _counter(controller)

    controller.submit_break()
    controller.poll(sim.current_tick())
    assert_int(count[0]).is_equal(0)


func test_it_only_says_it_once() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var count := _counter(controller)

    controller.submit_break()
    sim.advance(2)
    for i in 5:
        controller.poll(sim.current_tick())
    assert_int(count[0]).is_less_equal(1)


## --- 흔들림 ---

func test_the_row_is_still_until_it_is_shaken() -> void:
    var hotbar: Hotbar = auto_free(Hotbar.new())
    add_child(hotbar)
    assert_bool(hotbar.is_shaking()).is_false()
    assert_float(hotbar.shake_offset()).is_equal_approx(0.0, 0.001)


func test_shaking_moves_the_row() -> void:
    var hotbar: Hotbar = auto_free(Hotbar.new())
    add_child(hotbar)
    hotbar.shake()
    assert_bool(hotbar.is_shaking()).is_true()
    assert_float(absf(hotbar.shake_offset())).is_less_equal(Hotbar.SHAKE_WIDTH)


func test_the_shaken_row_still_fits_on_the_screen() -> void:
    # 흔들리다가 칸이 화면 밖으로 나가면 무엇을 눌러야 하는지 알 수 없다.
    var sim := _sim()
    var hotbar: Hotbar = auto_free(Hotbar.new())
    add_child(hotbar)
    hotbar.bind(sim.state.inventory, _controller(sim))
    hotbar.shake()
    hotbar.sync()
    assert_bool(hotbar.all_slots_visible()).is_true()
