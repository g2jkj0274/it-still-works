extends GdUnitTestSuite

## 인벤토리 화면 검증.
##
## **옮기는 것도 명령을 거친다.** 화면이 인벤토리를 직접 고치면 저장한 판을
## 되살렸을 때 물건이 제자리로 돌아간다.


func _screen(hand: Inventory) -> InventoryScreen:
    var screen: InventoryScreen = auto_free(InventoryScreen.new())
    add_child(screen)
    screen.bind(hand)
    return screen


func _centre_of(screen: InventoryScreen, where: int, slot: int) -> Vector2:
    var panel: Panel = screen.get_node("Anchor/%s_%d" % [
        "Hand" if where == InventoryScreen.WHERE_HAND else "Chest", slot])
    return panel.position + panel.size * 0.5


func test_it_starts_closed() -> void:
    assert_bool(_screen(Inventory.new()).is_open()).is_false()


func test_opening_and_closing() -> void:
    var screen := _screen(Inventory.new())
    screen.open()
    assert_bool(screen.is_open()).is_true()
    screen.close()
    assert_bool(screen.is_open()).is_false()


func test_a_click_on_a_full_slot_picks_it_up() -> void:
    var hand := Inventory.new()
    hand.put_slot(0, BlockType.WOOD, 3)
    var screen := _screen(hand)
    screen.open()

    screen.click_at(_centre_of(screen, InventoryScreen.WHERE_HAND, 0))
    assert_array(screen.picked()).is_equal([InventoryScreen.WHERE_HAND, 0])


func test_a_click_on_an_empty_slot_picks_up_nothing() -> void:
    var screen := _screen(Inventory.new())
    screen.open()
    screen.click_at(_centre_of(screen, InventoryScreen.WHERE_HAND, 4))
    assert_array(screen.picked()).is_equal([-1, -1])


func test_the_second_click_asks_for_a_move() -> void:
    var hand := Inventory.new()
    hand.put_slot(0, BlockType.WOOD, 3)
    var screen := _screen(hand)
    screen.open()

    # GDScript 의 람다는 바깥 값을 복사해 간다. 다시 담으면 밖에서 안 보이므로
    # 배열 자체를 고친다.
    var asked: Array = []
    screen.move_requested.connect(
        func(fw: int, fs: int, tw: int, ts: int) -> void: asked.assign([fw, fs, tw, ts]))

    screen.click_at(_centre_of(screen, InventoryScreen.WHERE_HAND, 0))
    screen.click_at(_centre_of(screen, InventoryScreen.WHERE_HAND, 5))

    assert_array(asked).is_equal([
        InventoryScreen.WHERE_HAND, 0, InventoryScreen.WHERE_HAND, 5])
    assert_array(screen.picked()).is_equal([-1, -1])


func test_the_screen_never_moves_anything_itself() -> void:
    # 화면이 직접 고치면 명령 기록에 남지 않아 불러온 판에서 되돌아간다.
    var hand := Inventory.new()
    hand.put_slot(0, BlockType.WOOD, 3)
    var screen := _screen(hand)
    screen.open()

    screen.click_at(_centre_of(screen, InventoryScreen.WHERE_HAND, 0))
    screen.click_at(_centre_of(screen, InventoryScreen.WHERE_HAND, 5))
    assert_int(hand.amount_at(0)).is_equal(3)
    assert_bool(hand.is_empty_slot(5)).is_true()


func test_a_chest_shows_up_above_when_opened() -> void:
    var screen := _screen(Inventory.new())
    assert_bool(screen.showing_chest()).is_false()

    var chest := Inventory.new(ChestField.CHEST_SLOTS)
    chest.put_slot(0, BlockType.ORE, 4)
    screen.open_chest(Vector3i(2, 3, 4), chest)

    assert_bool(screen.showing_chest()).is_true()
    assert_bool(screen.chest_cell() == Vector3i(2, 3, 4)).is_true()


func test_things_can_be_moved_between_the_hand_and_the_chest() -> void:
    var hand := Inventory.new()
    hand.put_slot(0, BlockType.WOOD, 3)
    var screen := _screen(hand)
    var chest := Inventory.new(ChestField.CHEST_SLOTS)
    screen.open_chest(Vector3i(2, 3, 4), chest)

    # GDScript 의 람다는 바깥 값을 복사해 간다. 다시 담으면 밖에서 안 보이므로
    # 배열 자체를 고친다.
    var asked: Array = []
    screen.move_requested.connect(
        func(fw: int, fs: int, tw: int, ts: int) -> void: asked.assign([fw, fs, tw, ts]))

    screen.click_at(_centre_of(screen, InventoryScreen.WHERE_HAND, 0))
    screen.click_at(_centre_of(screen, InventoryScreen.WHERE_CHEST, 2))
    assert_array(asked).is_equal([
        InventoryScreen.WHERE_HAND, 0, InventoryScreen.WHERE_CHEST, 2])


func test_clicking_a_recipe_asks_to_make_it() -> void:
    var screen := _screen(Inventory.new())
    screen.open()

    var asked: Array = []
    screen.craft_requested.connect(func(index: int) -> void: asked.append(index))

    var row: Panel = screen.get_node("Anchor/Recipe_2")
    screen.click_at(row.position + row.size * 0.5)
    assert_array(asked).is_equal([2])


func test_a_closed_screen_ignores_clicks() -> void:
    var hand := Inventory.new()
    hand.put_slot(0, BlockType.WOOD, 3)
    var screen := _screen(hand)

    screen.click_at(Vector2(100, 100))
    assert_array(screen.picked()).is_equal([-1, -1])


func test_every_recipe_has_a_row() -> void:
    var screen := _screen(Inventory.new())
    screen.open()
    for i in RecipeBook.count():
        assert_object(screen.get_node_or_null("Anchor/Recipe_%d" % i)).is_not_null()
