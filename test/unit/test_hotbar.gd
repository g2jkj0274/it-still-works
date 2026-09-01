extends GdUnitTestSuite

## 재료 핫바 검증.
##
## 화면에 프로그래밍 용어를 내보내지 않는다. 재료 이름과 개수만 보인다.


func _hotbar(inventory: Inventory, controller: InputController) -> Hotbar:
    var hotbar: Hotbar = auto_free(Hotbar.new())
    add_child(hotbar)
    hotbar.bind(inventory, controller)
    hotbar.sync()
    return hotbar


func _controller() -> InputController:
    var controller: InputController = auto_free(InputController.new())
    add_child(controller)
    return controller


func test_one_slot_per_placeable_material() -> void:
    var hotbar := _hotbar(Inventory.new(), _controller())
    assert_int(hotbar.slot_count()).is_equal(InputController.PLACEABLE.size())


func test_slot_shows_the_material_name_and_count() -> void:
    var inventory := Inventory.new()
    inventory.add(BlockType.STONE, 7)
    var hotbar := _hotbar(inventory, _controller())

    var slot := InputController.PLACEABLE.find(BlockType.STONE)
    assert_str(hotbar.slot_text(slot)).contains(Hotbar.name_of(BlockType.STONE))
    assert_str(hotbar.slot_text(slot)).contains("7")


func test_counts_follow_the_inventory() -> void:
    var inventory := Inventory.new()
    var controller := _controller()
    var hotbar := _hotbar(inventory, controller)
    var slot := InputController.PLACEABLE.find(BlockType.WOOD)
    assert_str(hotbar.slot_text(slot)).contains("0")

    inventory.add(BlockType.WOOD, 3)
    hotbar.sync()
    assert_str(hotbar.slot_text(slot)).contains("3")


func test_the_chosen_slot_is_marked() -> void:
    var controller := _controller()
    var hotbar := _hotbar(Inventory.new(), controller)

    controller.select_block(BlockType.STONE)
    hotbar.sync()
    assert_int(hotbar.selected_slot()).is_equal(InputController.PLACEABLE.find(BlockType.STONE))

    controller.select_block(BlockType.WOOD)
    hotbar.sync()
    assert_int(hotbar.selected_slot()).is_equal(InputController.PLACEABLE.find(BlockType.WOOD))


func test_every_material_has_a_plain_name() -> void:
    for type in InputController.PLACEABLE:
        var label := Hotbar.name_of(type)
        assert_str(label).is_not_empty()
        # 프로그래밍 용어가 화면에 나오면 안 된다.
        assert_str(label).not_contains("block")
        assert_str(label).not_contains("type")


func test_hotbar_never_writes_to_the_inventory() -> void:
    var inventory := Inventory.new()
    inventory.add(BlockType.WOOD, 2)
    var hotbar := _hotbar(inventory, _controller())
    for i in 5:
        hotbar.sync()
    assert_int(inventory.count_of(BlockType.WOOD)).is_equal(2)


func _wide_hotbar() -> Hotbar:
    var controller: InputController = auto_free(InputController.new())
    add_child(controller)
    return _hotbar(Inventory.new(), controller)


func test_every_slot_lands_inside_the_screen() -> void:
    var hotbar := _wide_hotbar()
    assert_bool(hotbar.all_slots_visible()).is_true()


func test_the_slots_are_centred() -> void:
    var hotbar := _wide_hotbar()
    var first := hotbar.slot_rect(0)
    var last := hotbar.slot_rect(hotbar.slot_count() - 1)
    var screen := Vector2(hotbar.get_viewport().get_visible_rect().size)
    # 왼쪽 여백과 오른쪽 여백이 같아야 가운데다.
    assert_float(absf(first.position.x - (screen.x - last.end.x))).is_less(1.0)


func test_slots_do_not_overlap() -> void:
    var hotbar := _wide_hotbar()
    for slot in hotbar.slot_count() - 1:
        assert_float(hotbar.slot_rect(slot).end.x).is_less_equal(
            hotbar.slot_rect(slot + 1).position.x + 0.001)


func test_the_row_sits_above_the_bottom_edge() -> void:
    var hotbar := _wide_hotbar()
    var screen := Vector2(hotbar.get_viewport().get_visible_rect().size)
    assert_float(hotbar.slot_rect(0).end.y).is_less(screen.y)


func test_the_row_is_laid_out_again_on_every_sync() -> void:
    # 처음 한 번만 재면 창이 자리를 잡기 전이라 어긋난다.
    var hotbar := _wide_hotbar()
    var before := hotbar.slot_rect(0)
    hotbar.sync()
    assert_bool(hotbar.slot_rect(0).is_equal_approx(before)).is_true()
    assert_bool(hotbar.all_slots_visible()).is_true()
