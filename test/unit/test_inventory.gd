extends GdUnitTestSuite

## 손에 든 재료 검증.


func test_starts_empty() -> void:
    var inventory := Inventory.new()
    for type in BlockType.COUNT:
        assert_int(inventory.count_of(type)).is_equal(0)
    assert_int(inventory.total()).is_equal(0)


func test_adding_increases_the_count() -> void:
    var inventory := Inventory.new()
    inventory.add(BlockType.WOOD, 3)
    assert_int(inventory.count_of(BlockType.WOOD)).is_equal(3)
    assert_int(inventory.count_of(BlockType.ORE)).is_equal(0)


func test_empty_is_never_stocked() -> void:
    # 빈 칸은 재료가 아니다. 부순 자리가 재료로 잡히면 개수가 엉킨다.
    var inventory := Inventory.new()
    inventory.add(BlockType.EMPTY, 5)
    assert_int(inventory.count_of(BlockType.EMPTY)).is_equal(0)


func test_unknown_type_is_ignored() -> void:
    var inventory := Inventory.new()
    inventory.add(BlockType.COUNT, 5)
    inventory.add(-1, 5)
    assert_int(inventory.total()).is_equal(0)


func test_negative_amounts_are_ignored() -> void:
    var inventory := Inventory.new()
    inventory.add(BlockType.WOOD, -3)
    assert_int(inventory.count_of(BlockType.WOOD)).is_equal(0)


func test_taking_removes_the_count() -> void:
    var inventory := Inventory.new()
    inventory.add(BlockType.ORE, 2)
    assert_bool(inventory.take(BlockType.ORE, 1)).is_true()
    assert_int(inventory.count_of(BlockType.ORE)).is_equal(1)


func test_taking_more_than_held_takes_nothing() -> void:
    var inventory := Inventory.new()
    inventory.add(BlockType.ORE, 2)
    assert_bool(inventory.take(BlockType.ORE, 3)).is_false()
    assert_int(inventory.count_of(BlockType.ORE)).is_equal(2)


func test_taking_from_empty_stock_fails() -> void:
    assert_bool(Inventory.new().take(BlockType.WOOD, 1)).is_false()


func test_total_sums_every_kind() -> void:
    var inventory := Inventory.new()
    inventory.add(BlockType.WOOD, 2)
    inventory.add(BlockType.ORE, 3)
    assert_int(inventory.total()).is_equal(5)


func test_hash_fields_are_ordered_by_type() -> void:
    var inventory := Inventory.new()
    inventory.add(BlockType.WOOD, 1)
    var fields := inventory.to_hash_fields()
    assert_int(fields.size()).is_equal(BlockType.COUNT)
    for i in fields.size():
        assert_str(str(fields[i][0])).is_equal("stock." + BlockType.name_of(i))
