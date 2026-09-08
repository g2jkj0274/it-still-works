extends GdUnitTestSuite

## 인벤토리 검증: 새 인벤(칸 9·total 0·해시 필드 정확), 칸 수 인자, add(쌓다 만 칸 우선·빈 칸·
## 남은 수·조용히 버리지 않음), has_room_for, take(전부-아니면-무·뒤 칸부터·정규형 비움),
## count_of·범위 밖 조회, 거부(id·개수), 해시 결정론, 소스 가드, Node 아님.

const A := 1
const B := 2
const LIMIT := Inventory.STACK_LIMIT


func _hash(inventory: Inventory) -> String:
    return SimHash.hash_fields(inventory.to_hash_fields())


func _slot_field(inventory: Inventory, slot: int) -> String:
    return str(inventory.to_hash_fields()[slot + 1][1])


# --- 새 인벤토리 ---

func test_new_inventory_is_empty_with_nine_slots() -> void:
    var inventory := Inventory.new()
    assert_int(inventory.slot_count()).is_equal(9)
    assert_int(Inventory.SLOT_COUNT).is_equal(9)
    assert_int(Inventory.STACK_LIMIT).is_equal(64)
    assert_int(Inventory.MAX_KIND).is_equal(255)
    assert_int(inventory.total()).is_equal(0)
    for slot in 9:
        assert_bool(inventory.is_empty_slot(slot)).is_true()


func test_new_inventory_hash_fields_order_and_format() -> void:
    var fields := Inventory.new().to_hash_fields()
    assert_int(fields.size()).is_equal(10)
    assert_array(fields[0]).is_equal(["inventory.slots", 9])
    for slot in 9:
        assert_array(fields[slot + 1]).override_failure_message(
            "칸 %d 의 해시 필드가 다르다" % slot
        ).is_equal(["inventory.%d" % slot, "0:0"])


# --- 칸 수 인자 ---

func test_init_clamps_slot_count_to_at_least_one() -> void:
    assert_int(Inventory.new(0).slot_count()).is_equal(1)
    assert_int(Inventory.new(-5).slot_count()).is_equal(1)
    assert_int(Inventory.new(3).slot_count()).is_equal(3)
    assert_array(Inventory.new(3).to_hash_fields()[0]).is_equal(["inventory.slots", 3])


# --- add ---

func test_add_one_goes_to_first_slot() -> void:
    var inventory := Inventory.new()
    assert_int(inventory.add(A, 1)).is_equal(0)
    assert_int(inventory.kind_at(0)).is_equal(A)
    assert_int(inventory.amount_at(0)).is_equal(1)
    assert_int(inventory.total()).is_equal(1)
    assert_str(_slot_field(inventory, 0)).is_equal("1:1")


func test_add_exactly_stack_limit_fills_one_slot() -> void:
    var inventory := Inventory.new()
    assert_int(inventory.add(A, LIMIT)).is_equal(0)
    assert_int(inventory.amount_at(0)).is_equal(LIMIT)
    assert_bool(inventory.is_empty_slot(1)).is_true()


func test_add_over_stack_limit_spills_into_next_slot() -> void:
    var inventory := Inventory.new()
    assert_int(inventory.add(A, LIMIT + 1)).is_equal(0)
    assert_int(inventory.amount_at(0)).is_equal(LIMIT)
    assert_int(inventory.kind_at(1)).is_equal(A)
    assert_int(inventory.amount_at(1)).is_equal(1)
    assert_bool(inventory.is_empty_slot(2)).is_true()


func test_add_to_full_inventory_returns_remainder_and_keeps_hash() -> void:
    var inventory := Inventory.new()
    assert_int(inventory.add(A, LIMIT * 9)).is_equal(0)
    assert_int(inventory.total()).is_equal(LIMIT * 9)
    var before := _hash(inventory)
    assert_int(inventory.add(A, 1)).is_equal(1)
    assert_int(inventory.add(B, 5)).is_equal(5)
    assert_str(_hash(inventory)).is_equal(before)


func test_add_fills_partial_stack_before_empty_slot() -> void:
    var inventory := Inventory.new()
    assert_int(inventory.add(A, 10)).is_equal(0)
    assert_int(inventory.add(B, 5)).is_equal(0)
    assert_int(inventory.add(A, 60)).is_equal(0)
    assert_int(inventory.amount_at(0)).is_equal(LIMIT)
    assert_int(inventory.kind_at(1)).is_equal(B)
    assert_int(inventory.amount_at(1)).is_equal(5)
    assert_int(inventory.kind_at(2)).is_equal(A)
    assert_int(inventory.amount_at(2)).is_equal(6)


func test_add_different_kinds_use_different_slots() -> void:
    var inventory := Inventory.new()
    inventory.add(A, 3)
    inventory.add(B, 4)
    assert_int(inventory.kind_at(0)).is_equal(A)
    assert_int(inventory.kind_at(1)).is_equal(B)
    assert_int(inventory.count_of(A)).is_equal(3)
    assert_int(inventory.count_of(B)).is_equal(4)


# --- has_room_for ---

func test_has_room_for() -> void:
    var inventory := Inventory.new()
    assert_bool(inventory.has_room_for(A)).is_true()
    inventory.add(A, LIMIT * 9)
    assert_bool(inventory.has_room_for(A)).is_false()
    assert_bool(inventory.has_room_for(B)).is_false()
    assert_bool(inventory.take(A, 1)).is_true()
    assert_int(inventory.amount_at(8)).is_equal(LIMIT - 1)
    assert_bool(inventory.has_room_for(A)).is_true()
    # 쌓다 만 칸은 그 종류에게만 자리다.
    assert_bool(inventory.has_room_for(B)).is_false()


# --- take ---

func test_take_more_than_held_is_all_or_nothing() -> void:
    var inventory := Inventory.new()
    inventory.add(A, 10)
    var before := _hash(inventory)
    assert_bool(inventory.take(A, 11)).is_false()
    assert_str(_hash(inventory)).is_equal(before)
    assert_int(inventory.count_of(A)).is_equal(10)


func test_take_removes_from_last_slot_first_and_clears_to_canonical() -> void:
    var inventory := Inventory.new()
    inventory.add(A, LIMIT + 5)
    assert_int(inventory.amount_at(0)).is_equal(LIMIT)
    assert_int(inventory.amount_at(1)).is_equal(5)
    assert_bool(inventory.take(A, 6)).is_true()
    assert_str(_slot_field(inventory, 1)).is_equal("0:0")
    assert_int(inventory.kind_at(1)).is_equal(0)
    assert_int(inventory.amount_at(1)).is_equal(0)
    assert_bool(inventory.is_empty_slot(1)).is_true()
    assert_int(inventory.amount_at(0)).is_equal(LIMIT - 1)
    assert_int(inventory.count_of(A)).is_equal(LIMIT - 1)


func test_take_to_zero_resets_kind() -> void:
    var inventory := Inventory.new()
    inventory.add(A, 3)
    assert_bool(inventory.take(A, 3)).is_true()
    assert_int(inventory.kind_at(0)).is_equal(0)
    assert_int(inventory.amount_at(0)).is_equal(0)
    assert_int(inventory.total()).is_equal(0)
    assert_str(_hash(inventory)).is_equal(_hash(Inventory.new()))


func test_take_skips_other_kinds() -> void:
    var inventory := Inventory.new()
    inventory.add(A, 5)
    inventory.add(B, 5)
    inventory.add(A, LIMIT)
    # 칸: [A 64][B 5][A 5]
    assert_bool(inventory.take(A, 7)).is_true()
    assert_str(_slot_field(inventory, 2)).is_equal("0:0")
    assert_int(inventory.amount_at(0)).is_equal(LIMIT - 2)
    assert_int(inventory.amount_at(1)).is_equal(5)
    assert_int(inventory.kind_at(1)).is_equal(B)


# --- 조회 ---

func test_count_of_sums_across_slots() -> void:
    var inventory := Inventory.new()
    inventory.add(A, LIMIT * 2 + 7)
    assert_int(inventory.count_of(A)).is_equal(LIMIT * 2 + 7)
    assert_int(inventory.count_of(B)).is_equal(0)
    assert_int(inventory.total()).is_equal(LIMIT * 2 + 7)


func test_out_of_range_slots_read_as_empty() -> void:
    var inventory := Inventory.new()
    inventory.add(A, 1)
    for slot: int in [-1, 9, 100]:
        assert_int(inventory.kind_at(slot)).is_equal(0)
        assert_int(inventory.amount_at(slot)).is_equal(0)
        assert_bool(inventory.is_empty_slot(slot)).is_true()


# --- 거부 ---

func test_rejects_invalid_ids_and_amounts_without_change() -> void:
    var inventory := Inventory.new()
    inventory.add(A, 2)
    var before := _hash(inventory)
    for id: int in [0, -1, 256]:
        assert_int(inventory.add(id, 5)).override_failure_message("add(%d) 가 5 를 돌려주지 않았다" % id).is_equal(5)
        assert_bool(inventory.take(id, 1)).is_false()
        assert_bool(inventory.has_room_for(id)).is_false()
    for amount: int in [0, -3]:
        assert_int(inventory.add(A, amount)).override_failure_message("add(A, %d) 가 0 을 돌려주지 않았다" % amount).is_equal(0)
        assert_bool(inventory.take(A, amount)).is_false()
    assert_str(_hash(inventory)).is_equal(before)
    assert_int(inventory.count_of(0)).is_equal(0)


func test_max_kind_is_accepted() -> void:
    var inventory := Inventory.new()
    assert_bool(inventory.has_room_for(Inventory.MAX_KIND)).is_true()
    assert_int(inventory.add(Inventory.MAX_KIND, 1)).is_equal(0)
    assert_int(inventory.kind_at(0)).is_equal(255)


# --- 해시 결정론 ---

func test_same_operations_give_same_hash() -> void:
    var a := Inventory.new()
    var b := Inventory.new()
    for inventory: Inventory in [a, b]:
        inventory.add(A, 70)
        inventory.add(B, 3)
        inventory.take(A, 10)
        inventory.add(A, 1)
    assert_str(_hash(a)).is_equal(_hash(b))
    assert_array(a.to_hash_fields()).is_equal(b.to_hash_fields())
    b.add(B, 1)
    assert_str(_hash(a)).is_not_equal(_hash(b))


# --- 소스 가드 ---

func test_source_has_no_forbidden_tokens() -> void:
    var source := FileAccess.get_file_as_string("res://sim/inventory.gd")
    assert_str(source).is_not_empty()
    for token: String in ["float", "randi", "randf", "FileAccess", "JSON", "Dictionary", "name_of(", "_process", "delta", "Node", "BlockType", "variant", "BlockRegistry", "ChunkWorld"]:
        assert_bool(source.contains(token)).override_failure_message(
            "inventory.gd 에 금지 토큰 '%s' 가 있다" % token
        ).is_false()


# --- Node 아님 ---

func test_inventory_is_not_a_node() -> void:
    var inventory: Variant = Inventory.new()
    assert_str(inventory.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(inventory.get_class(), "Node")).is_false()
    assert_bool(inventory is Node).is_false()
    assert_bool(inventory is RefCounted).is_true()
