extends GdUnitTestSuite

## 제작법 검증.
##
## **재료를 격자에 놓아 만든다.** 목록에서 골라 누르던 것을 마인크래프트와
## 같은 짜임으로 바꿨다. 놓는 자리가 곧 기억이라 제작법이 늘어도 나빠지지 않는다.
##
## 재료의 뜻은 스펙 §3.6 을 따른다. 광석은 부품 제작에 쓰인다. 그것이 지켜져야
## 떨어진 자원지를 오가는 일이 자동 운반 장치를 만들 이유가 된다.


## 그 법대로 격자에 재료를 한 벌 놓는다.
func _laid_out(index: int, times: int = 1) -> Inventory:
    var grid := Inventory.new(RecipeBook.GRID_SLOTS)
    if RecipeBook.form_of(index) == RecipeBook.SHAPELESS:
        var at := 0
        for kind: int in RecipeBook.pattern_of(index):
            grid.put_slot(at, kind, times)
            at += 1
        return grid

    var rows: Array = RecipeBook.pattern_of(index)
    for r in rows.size():
        var row: Array = rows[r]
        for c in row.size():
            var kind := int(row[c])
            if kind != BlockType.EMPTY:
                grid.put_slot(r * RecipeBook.GRID_SIZE + c, kind, times)
    return grid


## 그 법을 만들 수 있는 넓이. 작업대가 있어야 하는 것은 세 칸이다.
func _reach_for(index: int) -> int:
    return RecipeBook.GRID_SIZE if RecipeBook.station_of(index) == RecipeBook.BENCH \
        else RecipeBook.HAND_SIZE


func _make(index: int, into: Inventory = null) -> bool:
    var inventory := into if into != null else Inventory.new()
    return RecipeBook.take_once(_laid_out(index), inventory, _reach_for(index))


## --- 책 전체가 지켜야 하는 것 ---

func test_the_book_stays_within_the_spec_limit() -> void:
    assert_int(RecipeBook.count()).is_less_equal(RecipeBook.MAX_RECIPES)
    assert_int(RecipeBook.count()).is_greater(0)


func test_every_placeable_part_can_be_made() -> void:
    # 만들 길이 없는 부품이 있으면 빈손으로 시작할 수 없다.
    for block_type in [
        BlockType.DOOR_CLOSED, BlockType.FIELD, BlockType.DETECTOR,
        BlockType.ACTUATOR, BlockType.REPEATER, BlockType.BOX, BlockType.BRANCH,
    ]:
        assert_bool(RecipeBook.can_be_made(block_type)).is_true()


func test_gathered_materials_are_not_made() -> void:
    # 흙·돌·나무·작물은 손으로 얻는 것이다. 만들어 내면 자원지가 뜻을 잃는다.
    for block_type in [
        BlockType.GROUND, BlockType.ORE, BlockType.WOOD, BlockType.CROP,
    ]:
        assert_bool(RecipeBook.can_be_made(block_type)).is_false()


func test_every_circuit_part_costs_ore() -> void:
    # 스펙 §3.6: 광석의 용도는 부품 제작이다. 자원지가 멀리 있는 이유가 여기 있다.
    for index in RecipeBook.count():
        var output := RecipeBook.output_of(index)
        if not BlockType.is_part(output):
            continue
        var ore := 0
        for entry: Array in RecipeBook.inputs_of(index):
            if int(entry[0]) == BlockType.ORE:
                ore = int(entry[1])
        assert_int(ore).override_failure_message(
            "%s 를 광석 없이 만들 수 있다" % BlockType.name_of(output)).is_greater(0)


func test_every_recipe_costs_something() -> void:
    for index in RecipeBook.count():
        var inputs := RecipeBook.inputs_of(index)
        assert_array(inputs).is_not_empty()
        for entry: Array in inputs:
            assert_int(int(entry[1])).is_greater(0)


func test_no_recipe_makes_what_it_eats() -> void:
    # 자기 자신을 재료로 삼으면 무한히 불릴 수 있다.
    for index in RecipeBook.count():
        for entry: Array in RecipeBook.inputs_of(index):
            assert_bool(int(entry[0]) == RecipeBook.output_of(index)).is_false()


func test_each_thing_has_at_most_one_way_to_be_made() -> void:
    # 같은 것을 만드는 법이 둘이면 어느 쪽이 쓰이는지가 순회 순서에 달린다.
    var seen: Array[int] = []
    for index in RecipeBook.count():
        var output := RecipeBook.output_of(index)
        assert_bool(seen.has(output)).is_false()
        seen.append(output)


## --- 무늬 ---

func test_no_two_recipes_share_a_pattern() -> void:
    # 무늬가 같으면 앞의 것만 만들어진다. 뒤의 것은 영영 못 만든다.
    var seen: Array[String] = []
    for index in RecipeBook.count():
        var mark := "%d:%s" % [RecipeBook.form_of(index), RecipeBook.pattern_of(index)]
        assert_bool(seen.has(mark)).override_failure_message(
            "%s 의 무늬가 앞의 것과 겹친다" % BlockType.name_of(
                RecipeBook.output_of(index))).is_false()
        seen.append(mark)


func test_every_pattern_fits_the_grid() -> void:
    for index in RecipeBook.count():
        var size := RecipeBook.size_of(index)
        assert_int(size.x).is_between(1, RecipeBook.GRID_SIZE)
        assert_int(size.y).is_between(1, RecipeBook.GRID_SIZE)


func test_a_small_pattern_is_made_by_hand_and_a_big_one_needs_the_bench() -> void:
    # 규칙은 하나다. 두 칸 안에 들면 손, 넘으면 작업대.
    for index in RecipeBook.count():
        var size := RecipeBook.size_of(index)
        var wants_bench := size.x > RecipeBook.HAND_SIZE or size.y > RecipeBook.HAND_SIZE
        var station := RecipeBook.station_of(index)
        assert_bool(station == RecipeBook.BENCH).is_equal(wants_bench)


func test_what_is_laid_out_is_what_the_book_asked_for() -> void:
    # 무늬에서 센 재료 목록과 실제로 놓이는 칸이 어긋나면 안 된다.
    for index in RecipeBook.count():
        var grid := _laid_out(index)
        for entry: Array in RecipeBook.inputs_of(index):
            assert_int(grid.count_of(int(entry[0]))).override_failure_message(
                "%s 무늬가 적힌 재료와 다르다" % BlockType.name_of(
                    RecipeBook.output_of(index))).is_equal(int(entry[1]))


func test_every_recipe_can_actually_be_made_from_its_own_pattern() -> void:
    for index in RecipeBook.count():
        var inventory := Inventory.new()
        assert_bool(_make(index, inventory)).override_failure_message(
            "%s 를 제 무늬대로 놓아도 만들어지지 않는다" % BlockType.name_of(
                RecipeBook.output_of(index))).is_true()
        assert_int(inventory.count_of(RecipeBook.output_of(index))).is_equal(
            RecipeBook.yield_of(index))


## --- 격자를 읽는 법 ---

func test_where_it_sits_in_the_grid_does_not_matter() -> void:
    # 왼쪽 위에 놓든 오른쪽 아래에 놓든 같은 모양이면 같은 것이다.
    var grid := Inventory.new(RecipeBook.GRID_SLOTS)
    var bench := RecipeBook.index_for(BlockType.BENCH)
    # 오른쪽 아래 이 대 이에 작업대를 놓는다.
    for slot in [4, 5, 7, 8]:
        grid.put_slot(slot, BlockType.PLANK, 1)

    assert_int(RecipeBook.match_grid(grid, RecipeBook.GRID_SIZE)).is_equal(bench)


func test_a_shape_that_is_mirrored_is_the_same_shape() -> void:
    # 도끼는 오른손잡이도 왼손잡이도 도끼다.
    var index := RecipeBook.index_for(BlockType.STONE_AXE)
    var grid := Inventory.new(RecipeBook.GRID_SLOTS)
    var rows: Array = RecipeBook.pattern_of(index)
    for r in rows.size():
        var row: Array = rows[r]
        for c in row.size():
            var kind := int(row[c])
            if kind == BlockType.EMPTY:
                continue
            # 좌우를 뒤집어 놓는다.
            var mirrored := row.size() - 1 - c
            grid.put_slot(r * RecipeBook.GRID_SIZE + mirrored, kind, 1)

    assert_int(RecipeBook.match_grid(grid, RecipeBook.GRID_SIZE)).is_equal(index)


func test_the_wrong_shape_makes_nothing() -> void:
    # 재료가 맞아도 모양이 틀리면 아무것도 아니다. 그것이 모양이 있다는 뜻이다.
    var grid := Inventory.new(RecipeBook.GRID_SLOTS)
    grid.put_slot(0, BlockType.PLANK, 1)
    grid.put_slot(1, BlockType.PLANK, 1)
    grid.put_slot(2, BlockType.PLANK, 1)
    grid.put_slot(3, BlockType.PLANK, 1)
    # 판자 넷이지만 문 모양(이 대 이)이 아니다.
    assert_int(RecipeBook.match_grid(grid, RecipeBook.GRID_SIZE)).is_equal(-1)


func test_an_empty_grid_makes_nothing() -> void:
    var grid := Inventory.new(RecipeBook.GRID_SLOTS)
    assert_int(RecipeBook.match_grid(grid, RecipeBook.GRID_SIZE)).is_equal(-1)


func test_a_big_shape_does_not_fit_in_the_hand() -> void:
    # 화로는 세 칸짜리다. 작업대 없이 만들어지면 작업대가 할 일이 없다.
    var index := RecipeBook.index_for(BlockType.FURNACE)
    var grid := _laid_out(index)
    assert_int(RecipeBook.match_grid(grid, RecipeBook.GRID_SIZE)).is_equal(index)
    assert_int(RecipeBook.match_grid(grid, RecipeBook.HAND_SIZE)).is_equal(-1)


func test_leftovers_outside_the_hand_are_not_read() -> void:
    # 작업대에서 놓아 둔 것을 들고 걸어 나오면 손에는 네 칸만 보인다.
    var grid := Inventory.new(RecipeBook.GRID_SLOTS)
    for slot in [0, 1, 3, 4]:
        grid.put_slot(slot, BlockType.PLANK, 1)
    grid.put_slot(8, BlockType.ORE, 1)

    assert_int(RecipeBook.match_grid(grid, RecipeBook.HAND_SIZE)).is_equal(
        RecipeBook.index_for(BlockType.BENCH))


## --- 가져가기 ---

func test_taking_it_spends_one_from_each_cell() -> void:
    var index := RecipeBook.index_for(BlockType.BENCH)
    var grid := _laid_out(index, 3)
    var inventory := Inventory.new()

    assert_bool(RecipeBook.take_once(grid, inventory, RecipeBook.HAND_SIZE)).is_true()
    assert_int(inventory.count_of(BlockType.BENCH)).is_equal(1)
    # 칸마다 하나씩만 준다. 셋 놓았으면 둘이 남는다.
    assert_int(grid.count_of(BlockType.PLANK)).is_equal(8)


func test_taking_them_all_makes_as_many_as_the_materials_allow() -> void:
    # 판자 스무 장을 스무 번 눌러 만들던 것이 한 번이 된다.
    var index := RecipeBook.index_for(BlockType.BENCH)
    var grid := _laid_out(index, 5)
    var inventory := Inventory.new()

    assert_int(RecipeBook.take_all(grid, inventory, RecipeBook.HAND_SIZE)).is_equal(5)
    assert_int(inventory.count_of(BlockType.BENCH)).is_equal(5)
    assert_int(grid.total()).is_equal(0)


func test_a_full_hand_takes_nothing_and_spends_nothing() -> void:
    # 만든 것을 받을 자리가 없으면 재료도 그대로 있어야 한다.
    var index := RecipeBook.index_for(BlockType.BENCH)
    var grid := _laid_out(index)
    var inventory := Inventory.new()
    inventory.add(BlockType.WOOD, Inventory.SLOT_COUNT * Inventory.STACK_LIMIT)

    assert_bool(RecipeBook.take_once(grid, inventory, RecipeBook.HAND_SIZE)).is_false()
    assert_int(grid.count_of(BlockType.PLANK)).is_equal(4)


func test_taking_from_a_grid_that_matches_nothing_spends_nothing() -> void:
    var grid := Inventory.new(RecipeBook.GRID_SLOTS)
    grid.put_slot(0, BlockType.ORE, 1)
    var inventory := Inventory.new()

    assert_bool(RecipeBook.take_once(grid, inventory, RecipeBook.HAND_SIZE)).is_false()
    assert_int(grid.count_of(BlockType.ORE)).is_equal(1)
    assert_int(inventory.total()).is_equal(0)


## --- 명령을 거친다 ---

func test_crafting_goes_through_a_command() -> void:
    var sim := Simulation.new(5)
    var bench := RecipeBook.index_for(BlockType.BENCH)
    for slot in [0, 1, 3, 4]:
        sim.state.craft.put_slot(slot, BlockType.PLANK, 1)

    sim.submit(CraftCommand.create())
    # 아직은 그대로다. 명령이 소비되어야 바뀐다.
    assert_int(sim.state.inventory.count_of(BlockType.BENCH)).is_equal(0)

    sim.step()
    assert_int(sim.state.inventory.count_of(BlockType.BENCH)).is_equal(
        RecipeBook.yield_of(bench))


func test_crafting_what_does_not_match_does_nothing() -> void:
    var sim := Simulation.new(5)
    sim.state.craft.put_slot(0, BlockType.PLANK, 9)
    var before := sim.state.inventory.total()

    sim.submit(CraftCommand.create())
    sim.step()
    assert_int(sim.state.inventory.total()).is_equal(before)


func test_the_bench_opens_the_third_row() -> void:
    # 작업대 곁에 서야 세 칸짜리 무늬가 열린다. 그것이 작업대가 하는 일이다.
    var sim := Simulation.new(5)
    var index := RecipeBook.index_for(BlockType.FURNACE)
    var rows: Array = RecipeBook.pattern_of(index)
    for r in rows.size():
        var row: Array = rows[r]
        for c in row.size():
            if int(row[c]) != BlockType.EMPTY:
                sim.state.craft.put_slot(r * RecipeBook.GRID_SIZE + c, int(row[c]), 1)

    sim.submit(CraftCommand.create())
    sim.step()
    assert_int(sim.state.inventory.count_of(BlockType.FURNACE)).is_equal(0)

    # 작업대를 곁에 세운다.
    var beside := sim.state.character.cell() + Vector3i(1, 0, 0)
    sim.state.grid.set_block(beside, BlockType.BENCH)
    sim.submit(CraftCommand.create())
    sim.step()
    assert_int(sim.state.inventory.count_of(BlockType.FURNACE)).is_equal(1)


func test_a_craft_command_survives_being_written_and_read_back() -> void:
    var command := CraftCommand.every()
    var wire: Variant = JSON.parse_string(JSON.stringify(command.to_dict()))
    var restored := SimCommandCodec.from_dict(wire) as CraftCommand
    assert_bool(restored.all).is_true()


func test_what_is_left_in_the_grid_comes_back_to_hand() -> void:
    # 놓아 둔 채로 화면을 닫으면 물건이 사라진 것처럼 보인다.
    var sim := Simulation.new(5)
    sim.state.craft.put_slot(0, BlockType.ORE, 3)
    sim.state.craft.put_slot(4, BlockType.PLANK, 2)

    sim.submit(ClearCraftCommand.create())
    sim.step()

    assert_int(sim.state.craft.total()).is_equal(0)
    assert_int(sim.state.inventory.count_of(BlockType.ORE)).is_equal(3)
    assert_int(sim.state.inventory.count_of(BlockType.PLANK)).is_equal(2)


func test_what_will_not_fit_stays_in_the_grid() -> void:
    # 손이 차 있으면 남는다. 없애면 재료가 조용히 사라진다.
    var sim := Simulation.new(5)
    sim.state.inventory.add(BlockType.WOOD, Inventory.SLOT_COUNT * Inventory.STACK_LIMIT)
    sim.state.craft.put_slot(0, BlockType.ORE, 3)

    sim.submit(ClearCraftCommand.create())
    sim.step()
    assert_int(sim.state.craft.count_of(BlockType.ORE)).is_equal(3)


func test_the_grid_is_part_of_the_state() -> void:
    # 저장한 판을 되살리면 놓아 두었던 그대로 놓여 있어야 한다.
    var bare := WorldState.new(SimRng.new(1))
    var laid := WorldState.new(SimRng.new(1))
    laid.craft.put_slot(0, BlockType.PLANK, 1)

    assert_str(SimHash.hash_fields(bare.to_hash_fields())).is_not_equal(
        SimHash.hash_fields(laid.to_hash_fields()))


## --- 굽는 것 ---

func test_smelting_is_not_laid_out_in_the_grid() -> void:
    # 화로는 모양을 만드는 것이 아니라 재료를 받아 굽는다.
    for block_type in [
        BlockType.INGOT, BlockType.BRICK, BlockType.GLASS, BlockType.COOKED_CROP,
    ]:
        assert_int(RecipeBook.index_for(block_type)).is_equal(-1)
        assert_int(RecipeBook.smelt_index_for(block_type)).is_greater_equal(0)


func test_smelting_uses_up_the_materials() -> void:
    var inventory := Inventory.new()
    inventory.add(BlockType.ORE, 1)
    inventory.add(BlockType.EMBER, 1)

    assert_bool(RecipeBook.smelt(
        inventory, RecipeBook.smelt_index_for(BlockType.INGOT))).is_true()
    assert_int(inventory.count_of(BlockType.INGOT)).is_equal(1)
    assert_int(inventory.count_of(BlockType.ORE)).is_equal(0)


func test_missing_one_material_costs_nothing() -> void:
    # 반쯤 쓰고 실패하면 재료만 사라진다. 되돌릴 길이 없으므로 먼저 다 본다.
    var index := RecipeBook.smelt_index_for(BlockType.INGOT)
    var inventory := Inventory.new()
    inventory.add(BlockType.ORE, 9)

    assert_bool(RecipeBook.has_smelt_materials(inventory, index)).is_false()
    assert_bool(RecipeBook.smelt(inventory, index)).is_false()
    assert_int(inventory.count_of(BlockType.ORE)).is_equal(9)


## --- 화면에 적히는 말 ---

func test_the_hint_line_spells_out_the_materials() -> void:
    var line := PartWords.recipe_line(BlockType.DETECTOR)
    assert_str(line).contains(PartWords.name_of(BlockType.ORE))
    assert_str(line).contains(PartWords.name_of(BlockType.PLANK))
    # 프로그래밍 용어가 화면에 나오면 안 된다.
    assert_str(line.to_lower()).not_contains("recipe")
    assert_str(line.to_lower()).not_contains("craft")


func test_things_that_are_gathered_show_no_recipe() -> void:
    assert_str(PartWords.recipe_line(BlockType.ORE)).is_empty()


## --- 첫날이 성립하는가 ---

func test_a_first_night_can_be_reached_by_hand() -> void:
    # 빈손에서 나무만 모아도 문은 세울 수 있어야 한다. 첫 밤을 손으로 버틴다.
    #
    # 판자와 작업대는 손으로 만든다. 그 둘이 손에 있으면 나머지는 나무를
    # 더 베는 일뿐이다 — 회로도 화로도 끼어들지 않는다.
    var inventory := Inventory.new()
    var planks := Inventory.new(RecipeBook.GRID_SLOTS)
    planks.put_slot(0, BlockType.WOOD, 1)
    assert_bool(RecipeBook.take_once(planks, inventory, RecipeBook.HAND_SIZE)).is_true()
    assert_int(inventory.count_of(BlockType.PLANK)).is_equal(4)

    assert_int(RecipeBook.station_of(
        RecipeBook.index_for(BlockType.PLANK))).is_equal(RecipeBook.HAND)
    assert_int(RecipeBook.station_of(
        RecipeBook.index_for(BlockType.BENCH))).is_equal(RecipeBook.HAND)


func test_the_bench_is_reachable_on_the_first_day() -> void:
    # **작업대가 첫날에 서야 한다.** 쇳덩이를 물려 두었더니 화로가 먼저
    # 필요했고, 화로는 회로가 있어야 도는 것이라 첫 곡괭이조차 못 만들었다.
    var index := RecipeBook.index_for(BlockType.BENCH)
    assert_int(RecipeBook.station_of(index)).is_equal(RecipeBook.HAND)
    for entry: Array in RecipeBook.inputs_of(index):
        assert_int(int(entry[0])).is_equal(BlockType.PLANK)


func test_the_first_pickaxe_costs_two_trees() -> void:
    # 나무 곡괭이가 없으면 돌을 캘 수 없고, 돌이 없으면 트리가 시작되지 않는다.
    # 작업대 넷 + 곡괭이 셋이므로 나무 둘이면 닿는다. 마인크래프트와 같다.
    var bench := RecipeBook.inputs_of(RecipeBook.index_for(BlockType.BENCH))
    var pick := RecipeBook.inputs_of(RecipeBook.index_for(BlockType.WOOD_PICK))
    var planks := 0
    for entry: Array in bench + pick:
        if int(entry[0]) == BlockType.PLANK:
            planks += int(entry[1])
    # 나무 하나가 판자 넷이다.
    assert_int(planks).is_less_equal(8)


func test_the_first_light_needs_no_ore() -> void:
    # 관솔불은 판자와 불씨돌만 든다. 등과 달리 광석이 들지 않으므로
    # 나무 곡괭이만으로 첫 굴을 밝힐 수 있다(스펙 §3.6).
    for entry: Array in RecipeBook.inputs_of(RecipeBook.index_for(BlockType.TORCH)):
        assert_int(int(entry[0])).is_not_equal(BlockType.ORE)


func test_the_whole_night_system_is_affordable_in_one_trip() -> void:
    # 스펙 §5 의 마지막 장치는 부품 다섯 종을 다 쓴다. 한 번의 채집으로
    # 닿지 못할 만큼 비싸면 회로를 시험해 볼 수가 없다.
    var planks := 0
    var ore := 0
    for block_type in [
        BlockType.DETECTOR, BlockType.ACTUATOR, BlockType.REPEATER,
        BlockType.BOX, BlockType.BRANCH,
    ]:
        for entry: Array in RecipeBook.inputs_of(RecipeBook.index_for(block_type)):
            if int(entry[0]) == BlockType.PLANK:
                planks += int(entry[1])
            elif int(entry[0]) == BlockType.ORE:
                ore += int(entry[1])

    assert_int(planks).is_less_equal(12)
    assert_int(ore).is_less_equal(12)
