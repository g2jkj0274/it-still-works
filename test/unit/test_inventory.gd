extends GdUnitTestSuite

## 인벤토리 검증.
##
## **칸으로 나뉘어 있고 칸마다 쌓이는 한계가 있다.** 예전에는 종류마다 세는
## 수 하나였고 한계가 없었다. 그러면 무엇을 가져갈지 고르는 일이 없고,
## 자원지를 오가는 일에 값이 붙지 않는다.


func _held(pairs: Array) -> Inventory:
    var inventory := Inventory.new()
    for pair: Array in pairs:
        inventory.add(pair[0], pair[1])
    return inventory


func test_a_new_inventory_is_empty() -> void:
    var inventory := Inventory.new()
    assert_int(inventory.total()).is_equal(0)
    for slot in inventory.slot_count():
        assert_bool(inventory.is_empty_slot(slot)).is_true()


func test_the_hotbar_is_the_front_of_the_inventory() -> void:
    assert_int(Inventory.HOTBAR_SLOTS).is_less(Inventory.SLOT_COUNT)


func test_what_goes_in_can_be_counted() -> void:
    var inventory := _held([[BlockType.WOOD, 5]])
    assert_int(inventory.count_of(BlockType.WOOD)).is_equal(5)
    assert_int(inventory.total()).is_equal(5)


func test_a_stack_fills_up_and_spills_into_the_next_slot() -> void:
    var inventory := Inventory.new()
    assert_int(inventory.add(BlockType.WOOD, Inventory.STACK_LIMIT + 3)).is_equal(0)

    assert_int(inventory.amount_at(0)).is_equal(Inventory.STACK_LIMIT)
    assert_int(inventory.amount_at(1)).is_equal(3)
    assert_int(inventory.count_of(BlockType.WOOD)).is_equal(Inventory.STACK_LIMIT + 3)


func test_a_half_stack_is_topped_up_before_a_new_slot_is_opened() -> void:
    var inventory := _held([[BlockType.WOOD, 10]])
    inventory.add(BlockType.ORE, 1)
    inventory.add(BlockType.WOOD, 5)

    assert_int(inventory.amount_at(0)).is_equal(15)
    assert_int(inventory.amount_at(1)).is_equal(1)
    assert_bool(inventory.is_empty_slot(2)).is_true()


func test_a_full_inventory_turns_things_away() -> void:
    # 손이 차면 더 들지 못한다. 그것이 왕복에 값을 붙인다.
    var inventory := Inventory.new()
    var room := Inventory.SLOT_COUNT * Inventory.STACK_LIMIT
    assert_int(inventory.add(BlockType.WOOD, room)).is_equal(0)
    assert_bool(inventory.has_room_for(BlockType.WOOD)).is_false()
    assert_int(inventory.add(BlockType.WOOD, 7)).is_equal(7)
    assert_int(inventory.total()).is_equal(room)


func test_a_full_inventory_still_has_room_for_what_is_already_stacking() -> void:
    var inventory := Inventory.new()
    inventory.add(BlockType.WOOD, Inventory.SLOT_COUNT * Inventory.STACK_LIMIT - 1)
    assert_bool(inventory.has_room_for(BlockType.WOOD)).is_true()
    assert_bool(inventory.has_room_for(BlockType.ORE)).is_false()


func test_taking_more_than_is_held_takes_nothing() -> void:
    var inventory := _held([[BlockType.WOOD, 3]])
    assert_bool(inventory.take(BlockType.WOOD, 4)).is_false()
    assert_int(inventory.count_of(BlockType.WOOD)).is_equal(3)


func test_taking_reaches_across_slots() -> void:
    var inventory := Inventory.new()
    inventory.add(BlockType.WOOD, Inventory.STACK_LIMIT + 5)
    assert_bool(inventory.take(BlockType.WOOD, Inventory.STACK_LIMIT + 2)).is_true()
    assert_int(inventory.count_of(BlockType.WOOD)).is_equal(3)


func test_an_emptied_slot_becomes_free_again() -> void:
    var inventory := _held([[BlockType.WOOD, 2]])
    inventory.take(BlockType.WOOD, 2)
    assert_bool(inventory.is_empty_slot(0)).is_true()
    assert_int(inventory.kind_at(0)).is_equal(BlockType.EMPTY)


func test_nothing_that_is_not_a_thing_goes_in() -> void:
    var inventory := Inventory.new()
    assert_int(inventory.add(BlockType.EMPTY, 3)).is_equal(3)
    assert_int(inventory.add(BlockType.WOOD, -1)).is_equal(0)
    assert_int(inventory.total()).is_equal(0)


## --- 옮기기 ---

func test_moving_into_an_empty_slot_swaps() -> void:
    var inventory := _held([[BlockType.WOOD, 4]])
    inventory.move(0, 5)
    assert_bool(inventory.is_empty_slot(0)).is_true()
    assert_int(inventory.amount_at(5)).is_equal(4)


func test_moving_onto_the_same_thing_piles_it_up() -> void:
    var inventory := Inventory.new()
    inventory.put_slot(0, BlockType.WOOD, 4)
    inventory.put_slot(5, BlockType.WOOD, 3)
    inventory.move(0, 5)

    assert_bool(inventory.is_empty_slot(0)).is_true()
    assert_int(inventory.amount_at(5)).is_equal(7)


func test_moving_onto_something_else_swaps_them() -> void:
    var inventory := Inventory.new()
    inventory.put_slot(0, BlockType.WOOD, 4)
    inventory.put_slot(5, BlockType.ORE, 3)
    inventory.move(0, 5)

    assert_int(inventory.kind_at(0)).is_equal(BlockType.ORE)
    assert_int(inventory.kind_at(5)).is_equal(BlockType.WOOD)


func test_piling_beyond_the_limit_leaves_the_rest_behind() -> void:
    var inventory := Inventory.new()
    inventory.put_slot(0, BlockType.WOOD, 10)
    inventory.put_slot(5, BlockType.WOOD, Inventory.STACK_LIMIT - 4)
    inventory.move(0, 5)

    assert_int(inventory.amount_at(5)).is_equal(Inventory.STACK_LIMIT)
    assert_int(inventory.amount_at(0)).is_equal(6)


func test_a_slot_can_be_picked_up_whole() -> void:
    var inventory := Inventory.new()
    inventory.put_slot(3, BlockType.ORE, 9)
    var held := inventory.take_slot(3)

    assert_int(int(held[0])).is_equal(BlockType.ORE)
    assert_int(int(held[1])).is_equal(9)
    assert_bool(inventory.is_empty_slot(3)).is_true()


func test_putting_down_what_will_not_fit_gives_the_rest_back() -> void:
    var inventory := Inventory.new()
    inventory.put_slot(0, BlockType.WOOD, Inventory.STACK_LIMIT - 2)
    var left := inventory.put_slot(0, BlockType.WOOD, 5)
    assert_int(int(left[1])).is_equal(3)
    assert_int(inventory.amount_at(0)).is_equal(Inventory.STACK_LIMIT)


func test_putting_down_onto_something_else_puts_nothing() -> void:
    var inventory := Inventory.new()
    inventory.put_slot(0, BlockType.WOOD, 4)
    var left := inventory.put_slot(0, BlockType.ORE, 2)
    assert_int(int(left[1])).is_equal(2)
    assert_int(inventory.kind_at(0)).is_equal(BlockType.WOOD)


## --- 되살아날 때 ---

func test_half_of_everything_is_dropped() -> void:
    var inventory := _held([[BlockType.WOOD, 7], [BlockType.ORE, 4]])
    inventory.drop_half()
    assert_int(inventory.count_of(BlockType.WOOD)).is_equal(3)
    assert_int(inventory.count_of(BlockType.ORE)).is_equal(2)


func test_dropping_half_of_one_leaves_the_slot_empty() -> void:
    var inventory := _held([[BlockType.WOOD, 1]])
    inventory.drop_half()
    assert_bool(inventory.is_empty_slot(0)).is_true()


## --- 상태 해시 ---

func test_hash_fields_are_one_per_slot_in_order() -> void:
    var inventory := _held([[BlockType.WOOD, 2]])
    var fields := inventory.to_hash_fields()
    assert_int(fields.size()).is_equal(inventory.slot_count() + 1)

    var names := PackedStringArray()
    for field: Array in fields:
        names.append(str(field[0]))
    assert_str(names[0]).is_equal("stock.slots")
    assert_str(names[1]).is_equal("stock.0")


func test_the_same_things_in_different_slots_hash_differently() -> void:
    # 어느 칸에 있는지도 상태다. 옮긴 것이 해시에 남지 않으면 저장이 어긋난다.
    var left := Inventory.new()
    left.put_slot(0, BlockType.WOOD, 3)
    var right := Inventory.new()
    right.put_slot(4, BlockType.WOOD, 3)

    assert_str(SimHash.hash_fields(left.to_hash_fields())).is_not_equal(
        SimHash.hash_fields(right.to_hash_fields()))
