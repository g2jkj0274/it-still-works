extends GdUnitTestSuite

## 손에 잡히는 줄 검증.
##
## **핫바는 인벤토리의 앞 아홉 칸이다.** 종류마다 칸이 고정되어 있던 것이
## 아니다. 무엇을 앞줄에 둘지 고르는 것이 곧 무엇을 들고 다닐지 고르는 일이다.
##
## **칸에는 그림이 든다.** 아홉 칸에 이름을 적어 두면 훑을 수 없고 매번
## 읽어야 한다. 고른 것의 이름은 [PartHint] 가 줄 바로 위에서 읽어 준다.
##
## 화면에 프로그래밍 용어를 내보내지 않는다. 재료 이름과 개수만 보인다.


func _sim() -> Simulation:
    return Simulation.new(11)


func _controller(sim: Simulation) -> InputController:
    var controller: InputController = auto_free(InputController.new())
    add_child(controller)
    controller.bind(sim)
    return controller


func _hotbar(sim: Simulation) -> Hotbar:
    var hotbar: Hotbar = auto_free(Hotbar.new())
    add_child(hotbar)
    hotbar.bind(sim.state.inventory, _controller(sim))
    hotbar.sync()
    return hotbar


func test_one_panel_per_hotbar_slot() -> void:
    assert_int(_hotbar(_sim()).slot_count()).is_equal(Inventory.HOTBAR_SLOTS)


func test_a_slot_shows_what_is_in_it() -> void:
    var sim := _sim()
    sim.state.inventory.add(BlockType.ORE, 7)
    var hotbar := _hotbar(sim)

    assert_int(hotbar.slot_icon(0)).is_equal(BlockType.ORE)
    assert_str(hotbar.slot_text(0)).contains("7")


func test_an_empty_slot_shows_nothing_at_all() -> void:
    var hotbar := _hotbar(_sim())
    assert_str(hotbar.slot_text(3)).is_empty()
    assert_int(hotbar.slot_icon(3)).is_equal(BlockType.EMPTY)


func test_a_single_thing_is_not_counted() -> void:
    # 하나뿐인 것에 "1" 이 붙으면 눈이 읽을 것만 늘어난다.
    var sim := _sim()
    sim.state.inventory.add(BlockType.WOOD, 1)
    var hotbar := _hotbar(sim)
    assert_str(hotbar.slot_text(0)).is_empty()
    assert_int(hotbar.slot_icon(0)).is_equal(BlockType.WOOD)


func test_the_name_of_what_is_held_is_read_out_above_the_row() -> void:
    # 줄 자체는 이름을 적지 않는다. 바로 위 한 줄이 이름과 쓰임을 함께 읽는다.
    var sim := _sim()
    sim.state.inventory.add(BlockType.ORE, 2)
    var controller := _controller(sim)
    controller.select_slot(0)
    assert_str(PartHint.line_for(controller)).contains(
        Hotbar.name_of(BlockType.ORE))


func test_the_name_follows_the_chosen_slot() -> void:
    var sim := _sim()
    sim.state.inventory.put_slot(0, BlockType.WOOD, 3)
    sim.state.inventory.put_slot(1, BlockType.ORE, 3)
    var controller := _controller(sim)

    controller.select_slot(1)
    assert_str(PartHint.line_for(controller)).contains(Hotbar.name_of(BlockType.ORE))


func test_every_icon_stays_inside_its_slot() -> void:
    var sim := _sim()
    for slot in Inventory.HOTBAR_SLOTS:
        sim.state.inventory.put_slot(slot, InputController.PLACEABLE[
            slot % InputController.PLACEABLE.size()], 1)
    var hotbar := _hotbar(sim)
    for slot in Inventory.HOTBAR_SLOTS:
        assert_bool(hotbar.slot_icon_fits(slot)).is_true()


func test_counts_follow_the_inventory() -> void:
    var sim := _sim()
    var hotbar := _hotbar(sim)

    sim.state.inventory.add(BlockType.WOOD, 3)
    hotbar.sync()
    assert_str(hotbar.slot_text(0)).contains("3")

    sim.state.inventory.add(BlockType.WOOD, 2)
    hotbar.sync()
    assert_str(hotbar.slot_text(0)).contains("5")


func test_the_chosen_slot_is_marked() -> void:
    var sim := _sim()
    var controller := _controller(sim)
    var hotbar: Hotbar = auto_free(Hotbar.new())
    add_child(hotbar)
    hotbar.bind(sim.state.inventory, controller)

    controller.select_slot(4)
    hotbar.sync()
    assert_int(hotbar.selected_slot()).is_equal(4)
    assert_bool(hotbar.slot_is_marked(4)).is_true()
    assert_bool(hotbar.slot_is_marked(0)).is_false()


func test_a_bundle_slot_says_which_bundle() -> void:
    var sim := _sim()
    sim.state.inventory.add_bundle(2, 1)
    var hotbar := _hotbar(sim)

    assert_int(hotbar.slot_icon(0)).is_equal(BlockType.BUNDLE)


func test_every_thing_that_can_be_held_has_a_plain_name() -> void:
    for type in InputController.PLACEABLE:
        var label := Hotbar.name_of(type)
        assert_str(label).is_not_empty()
        # 프로그래밍 용어가 화면에 나오면 안 된다.
        assert_str(label).not_contains("block")
        assert_str(label).not_contains("type")


func test_the_hotbar_never_writes_to_the_inventory() -> void:
    var sim := _sim()
    sim.state.inventory.add(BlockType.WOOD, 2)
    var hotbar := _hotbar(sim)
    for i in 5:
        hotbar.sync()
    assert_int(sim.state.inventory.count_of(BlockType.WOOD)).is_equal(2)


func test_every_slot_lands_inside_the_screen() -> void:
    assert_bool(_hotbar(_sim()).all_slots_visible()).is_true()


func test_the_slots_are_centred() -> void:
    var hotbar := _hotbar(_sim())
    var first := hotbar.slot_rect(0)
    var last := hotbar.slot_rect(hotbar.slot_count() - 1)
    var screen := Vector2(hotbar.get_viewport().get_visible_rect().size)
    assert_float(absf(first.position.x - (screen.x - last.end.x))).is_less(1.0)


func test_slots_do_not_overlap() -> void:
    var hotbar := _hotbar(_sim())
    for slot in hotbar.slot_count() - 1:
        assert_float(hotbar.slot_rect(slot).end.x).is_less_equal(
            hotbar.slot_rect(slot + 1).position.x + 0.001)


func test_the_row_sits_above_the_bottom_edge() -> void:
    var hotbar := _hotbar(_sim())
    var screen := Vector2(hotbar.get_viewport().get_visible_rect().size)
    assert_float(hotbar.slot_rect(0).end.y).is_less(screen.y)


func test_the_row_is_laid_out_again_on_every_sync() -> void:
    var hotbar := _hotbar(_sim())
    var before := hotbar.slot_rect(0)
    hotbar.sync()
    assert_bool(hotbar.slot_rect(0).is_equal_approx(before)).is_true()
    assert_bool(hotbar.all_slots_visible()).is_true()
