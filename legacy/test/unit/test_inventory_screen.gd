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


func test_clicking_a_recipe_asks_to_lay_it_out() -> void:
    # 만들기 책은 만들어 주지 않는다. **무늬대로 격자에 놓아 준다.**
    # 한 번 놓아 보면 모양이 눈에 남는다.
    var screen := _screen(Inventory.new())
    screen.open()

    var asked: Array = []
    screen.fill_requested.connect(func(index: int) -> void: asked.append(index))

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


## --- 그림과 이름 ---
##
## 열한 픽셀 글자로 "되풀이 12" 라고 적힌 칸 서른여섯 개는 읽어야만 알 수
## 있는 표였다. 그림과 개수만 두고, 이름은 마우스를 얹은 칸 하나만 뜬다.

func test_a_slot_draws_what_is_in_it() -> void:
    var hand := Inventory.new()
    hand.put_slot(4, BlockType.ORE, 3)
    var screen := _screen(hand)
    screen.open()
    screen.sync()
    assert_int(screen.slot_icon(InventoryScreen.WHERE_HAND, 4)).is_equal(BlockType.ORE)


func test_an_empty_slot_draws_nothing() -> void:
    var screen := _screen(Inventory.new())
    screen.open()
    screen.sync()
    assert_int(screen.slot_icon(InventoryScreen.WHERE_HAND, 4)).is_equal(
        BlockType.EMPTY)


func test_every_recipe_row_draws_what_it_makes() -> void:
    var screen := _screen(Inventory.new())
    screen.open()
    screen.sync()
    for i in RecipeBook.count():
        assert_int(screen.recipe_icon(i)).is_equal(RecipeBook.output_of(i))


func test_nothing_is_named_until_the_mouse_is_on_it() -> void:
    var hand := Inventory.new()
    hand.put_slot(0, BlockType.WOOD, 2)
    var screen := _screen(hand)
    screen.open()
    screen.sync()
    assert_str(screen.hovered_name()).is_empty()


func test_the_slot_under_the_mouse_is_named() -> void:
    var hand := Inventory.new()
    hand.put_slot(0, BlockType.WOOD, 2)
    var screen := _screen(hand)
    screen.open()
    screen.sync()

    screen.hover_at(_centre_of(screen, InventoryScreen.WHERE_HAND, 0))
    assert_str(screen.hovered_name()).is_equal(PartWords.name_of(BlockType.WOOD))


func test_an_empty_slot_under_the_mouse_is_not_named() -> void:
    var screen := _screen(Inventory.new())
    screen.open()
    screen.sync()
    screen.hover_at(_centre_of(screen, InventoryScreen.WHERE_HAND, 0))
    assert_str(screen.hovered_name()).is_empty()


func test_moving_off_a_slot_clears_the_name() -> void:
    var hand := Inventory.new()
    hand.put_slot(0, BlockType.WOOD, 2)
    var screen := _screen(hand)
    screen.open()
    screen.sync()

    screen.hover_at(_centre_of(screen, InventoryScreen.WHERE_HAND, 0))
    screen.hover_at(Vector2(-50.0, -50.0))
    assert_str(screen.hovered_name()).is_empty()


func test_a_closed_screen_names_nothing() -> void:
    var hand := Inventory.new()
    hand.put_slot(0, BlockType.WOOD, 2)
    var screen := _screen(hand)
    screen.sync()
    screen.hover_at(Vector2(10.0, 10.0))
    assert_str(screen.hovered_name()).is_empty()


## --- 제작 격자 ---
##
## **재료를 격자에 놓아 만든다.** 스물넉 줄에서 하나 찾던 것을 마인크래프트와
## 같은 짜임으로 바꿨다.

func _with_craft(hand: Inventory, craft: Inventory) -> InventoryScreen:
    var screen: InventoryScreen = auto_free(InventoryScreen.new())
    add_child(screen)
    screen.bind(hand, craft)
    return screen


func test_the_hand_opens_a_two_by_two_grid() -> void:
    var screen := _with_craft(Inventory.new(), Inventory.new(RecipeBook.GRID_SLOTS))
    screen.open()
    assert_int(screen.craft_reach()).is_equal(RecipeBook.HAND_SIZE)
    # 왼쪽 위 네 칸만 쓴다.
    for slot in [0, 1, 3, 4]:
        assert_bool(screen.craft_slot_in_use(slot)).is_true()
    for slot in [2, 5, 6, 7, 8]:
        assert_bool(screen.craft_slot_in_use(slot)).is_false()


func test_the_bench_opens_a_three_by_three_grid() -> void:
    var screen := _with_craft(Inventory.new(), Inventory.new(RecipeBook.GRID_SLOTS))
    screen.open(true)
    assert_int(screen.craft_reach()).is_equal(RecipeBook.GRID_SIZE)
    for slot in RecipeBook.GRID_SLOTS:
        assert_bool(screen.craft_slot_in_use(slot)).is_true()


func test_the_result_slot_shows_what_the_grid_makes() -> void:
    var craft := Inventory.new(RecipeBook.GRID_SLOTS)
    var screen := _with_craft(Inventory.new(), craft)
    screen.open()
    assert_int(screen.result_block()).is_equal(BlockType.EMPTY)

    for slot in [0, 1, 3, 4]:
        craft.put_slot(slot, BlockType.PLANK, 1)
    screen.sync()
    assert_int(screen.result_block()).is_equal(BlockType.BENCH)


func test_a_big_shape_shows_nothing_without_the_bench() -> void:
    # 작업대가 하는 일이 이것뿐이다. 손에서는 세 칸이 읽히지 않는다.
    var craft := Inventory.new(RecipeBook.GRID_SLOTS)
    for slot in [0, 1, 2]:
        craft.put_slot(slot, BlockType.PLANK, 1)

    var screen := _with_craft(Inventory.new(), craft)
    screen.open()
    assert_int(screen.result_block()).is_equal(BlockType.EMPTY)

    screen.open(true)
    assert_int(screen.result_block()).is_equal(BlockType.WOOD_PICK)


func test_clicking_the_result_asks_to_take_it() -> void:
    var craft := Inventory.new(RecipeBook.GRID_SLOTS)
    for slot in [0, 1, 3, 4]:
        craft.put_slot(slot, BlockType.PLANK, 1)
    var screen := _with_craft(Inventory.new(), craft)
    screen.open()

    var asked: Array = []
    screen.craft_requested.connect(func(all: bool) -> void: asked.append(all))

    var result: Panel = screen.get_node("Anchor/Result")
    screen.click_at(result.position + result.size * 0.5)
    assert_array(asked).is_equal([false])

    # 우클릭(시프트 자리)이면 만들 수 있는 만큼 다.
    screen.click_at(result.position + result.size * 0.5, true)
    assert_array(asked).is_equal([false, true])


func test_clicking_an_empty_result_asks_nothing() -> void:
    var screen := _with_craft(Inventory.new(), Inventory.new(RecipeBook.GRID_SLOTS))
    screen.open()

    var asked: Array = []
    screen.craft_requested.connect(func(all: bool) -> void: asked.append(all))

    var result: Panel = screen.get_node("Anchor/Result")
    screen.click_at(result.position + result.size * 0.5)
    assert_array(asked).is_empty()


func test_the_chest_screen_has_no_crafting_grid() -> void:
    # 궤짝이 위를 차지하면 격자를 둘 자리가 없다. 마인크래프트도 그렇다.
    var craft := Inventory.new(RecipeBook.GRID_SLOTS)
    var screen := _with_craft(Inventory.new(), craft)
    screen.open_chest(Vector3i.ZERO, Inventory.new(ChestField.CHEST_SLOTS))
    screen.sync()

    var result: Panel = screen.get_node("Anchor/Result")
    assert_bool(result.visible).is_false()
    for slot in RecipeBook.GRID_SLOTS:
        assert_bool((screen.get_node("Anchor/Craft_%d" % slot) as Panel).visible).is_false()


func test_the_grid_and_the_hand_do_not_overlap() -> void:
    var screen := _with_craft(Inventory.new(), Inventory.new(RecipeBook.GRID_SLOTS))
    screen.open()
    screen.sync()

    var result: Panel = screen.get_node("Anchor/Result")
    for slot in Inventory.SLOT_COUNT:
        var hand: Panel = screen.get_node("Anchor/Hand_%d" % slot)
        var hand_box := Rect2(hand.position, hand.size)
        assert_bool(hand_box.intersects(Rect2(result.position, result.size))
            ).override_failure_message("결과 칸이 가진 것 %d 번 칸을 덮는다" % slot).is_false()
        for i in [0, 1, 3, 4]:
            var cell: Panel = screen.get_node("Anchor/Craft_%d" % i)
            assert_bool(hand_box.intersects(Rect2(cell.position, cell.size))
                ).override_failure_message(
                    "제작 격자 %d 번이 가진 것 %d 번 칸을 덮는다" % [i, slot]).is_false()


func test_the_whole_grid_stays_on_the_screen() -> void:
    var screen := _with_craft(Inventory.new(), Inventory.new(RecipeBook.GRID_SLOTS))
    screen.open(true)
    screen.sync()

    var room := Rect2(Vector2.ZERO, Vector2(screen.get_viewport().get_visible_rect().size))
    for i in RecipeBook.GRID_SLOTS:
        var cell: Panel = screen.get_node("Anchor/Craft_%d" % i)
        assert_bool(room.encloses(Rect2(cell.position, cell.size))
            ).override_failure_message("제작 격자 %d 번이 화면 밖으로 나갔다" % i).is_true()
    var result: Panel = screen.get_node("Anchor/Result")
    assert_bool(room.encloses(Rect2(result.position, result.size))).is_true()


func test_what_can_be_made_is_told_from_what_cannot() -> void:
    # **지금 만들 수 있는 것과 없는 것이 똑같이 생겼었다.** 스물넉 줄을 훑어도
    # "뭘 만들 수 있지"를 알 수 없었다.
    var hand := Inventory.new()
    var screen := _with_craft(hand, Inventory.new(RecipeBook.GRID_SLOTS))
    screen.open()

    var planks := RecipeBook.index_for(BlockType.PLANK)
    assert_bool(screen.can_make(planks)).is_false()

    hand.add(BlockType.WOOD, 1)
    assert_bool(screen.can_make(planks)).is_true()


func test_a_bench_recipe_is_out_of_reach_in_the_hand() -> void:
    var hand := Inventory.new()
    hand.add(BlockType.PLANK, 64)
    var screen := _with_craft(hand, Inventory.new(RecipeBook.GRID_SLOTS))

    var pick := RecipeBook.index_for(BlockType.WOOD_PICK)
    screen.open()
    assert_bool(screen.can_make(pick)).is_false()
    screen.open(true)
    assert_bool(screen.can_make(pick)).is_true()


func test_the_rows_that_cannot_be_made_are_dimmed() -> void:
    var hand := Inventory.new()
    hand.add(BlockType.WOOD, 1)
    var screen := _with_craft(hand, Inventory.new(RecipeBook.GRID_SLOTS))
    screen.open()
    screen.sync()

    var planks := RecipeBook.index_for(BlockType.PLANK)
    var chest := RecipeBook.index_for(BlockType.CHEST)
    var ready: Panel = screen.get_node("Anchor/Recipe_%d" % planks)
    var far: Panel = screen.get_node("Anchor/Recipe_%d" % chest)
    assert_float(ready.modulate.a).is_greater(far.modulate.a)
