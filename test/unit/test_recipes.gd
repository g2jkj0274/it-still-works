extends GdUnitTestSuite

## 제작법 검증. 스펙 §6 은 열 개 이내로 못박는다.
##
## 재료의 뜻은 스펙 §3.6 을 따른다. 광석은 부품 제작에 쓰인다. 그것이 지켜져야
## 떨어진 자원지를 오가는 일이 자동 운반 장치를 만들 이유가 된다.


func _stocked(pairs: Array) -> Inventory:
    var inventory := Inventory.new()
    for pair: Array in pairs:
        inventory.add(pair[0], pair[1])
    return inventory


func _full_purse() -> Inventory:
    return _stocked([
        [BlockType.WOOD, 99], [BlockType.PLANK, 99], [BlockType.ORE, 99],
        [BlockType.ROCK, 99], [BlockType.EMBER, 99], [BlockType.GROUND, 99],
    ])


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


func test_making_something_uses_up_the_materials() -> void:
    var inventory := _stocked([[BlockType.PLANK, 4]])
    assert_bool(RecipeBook.make(inventory, RecipeBook.index_for(BlockType.DOOR_CLOSED))).is_true()
    assert_int(inventory.count_of(BlockType.DOOR_CLOSED)).is_equal(1)
    assert_int(inventory.count_of(BlockType.PLANK)).is_equal(0)


func test_missing_one_material_costs_nothing() -> void:
    # 반쯤 쓰고 실패하면 재료만 사라진다. 되돌릴 길이 없으므로 먼저 다 본다.
    var index := RecipeBook.index_for(BlockType.DETECTOR)
    var inventory := _stocked([[BlockType.PLANK, 9]])
    assert_bool(RecipeBook.has_materials(inventory, index)).is_false()
    assert_bool(RecipeBook.make(inventory, index)).is_false()
    assert_int(inventory.count_of(BlockType.PLANK)).is_equal(9)
    assert_int(inventory.count_of(BlockType.DETECTOR)).is_equal(0)


func test_an_unknown_recipe_makes_nothing() -> void:
    var inventory := _full_purse()
    var before := inventory.total()
    assert_bool(RecipeBook.make(inventory, -1)).is_false()
    assert_bool(RecipeBook.make(inventory, RecipeBook.count())).is_false()
    assert_int(inventory.total()).is_equal(before)


func test_crafting_goes_through_a_command() -> void:
    var sim := Simulation.new(5)
    sim.state.inventory.add(BlockType.PLANK, 4)

    sim.submit(CraftCommand.create(BlockType.DOOR_CLOSED))
    # 아직은 그대로다. 명령이 소비되어야 바뀐다.
    assert_int(sim.state.inventory.count_of(BlockType.DOOR_CLOSED)).is_equal(0)

    sim.step()
    assert_int(sim.state.inventory.count_of(BlockType.DOOR_CLOSED)).is_equal(1)


func test_crafting_what_cannot_be_made_does_nothing() -> void:
    var sim := Simulation.new(5)
    sim.state.inventory.add(BlockType.PLANK, 9)
    var before := sim.state.inventory.total()

    sim.submit(CraftCommand.create(BlockType.ORE))
    sim.step()
    assert_int(sim.state.inventory.total()).is_equal(before)


func test_a_craft_command_survives_being_written_and_read_back() -> void:
    var command := CraftCommand.create(BlockType.REPEATER)
    var wire: Variant = JSON.parse_string(JSON.stringify(command.to_dict()))
    var restored := SimCommandCodec.from_dict(wire) as CraftCommand
    assert_int(restored.output).is_equal(BlockType.REPEATER)


func test_the_hint_line_spells_out_the_materials() -> void:
    var line := PartWords.recipe_line(BlockType.DETECTOR)
    assert_str(line).contains(PartWords.name_of(BlockType.ORE))
    assert_str(line).contains(PartWords.name_of(BlockType.PLANK))
    # 프로그래밍 용어가 화면에 나오면 안 된다.
    assert_str(line.to_lower()).not_contains("recipe")
    assert_str(line.to_lower()).not_contains("craft")


func test_things_that_are_gathered_show_no_recipe() -> void:
    assert_str(PartWords.recipe_line(BlockType.ORE)).is_empty()


func test_a_first_night_can_be_reached_by_hand() -> void:
    # 빈손에서 나무만 모아도 문은 세울 수 있어야 한다. 첫 밤을 손으로 버틴다.
    #
    # 이제 나무가 곧바로 문이 되지 않는다. **한 번 켜야 한다** — 나무 하나가
    # 판자 넷이 되므로 나무 한 그루(세 칸)면 문이 서고도 남는다. 오히려
    # 가벼워졌다: 예전에는 나무 4가 들었다.
    var inventory := Inventory.new()
    inventory.add(BlockType.WOOD, 1)
    assert_bool(RecipeBook.make(inventory, RecipeBook.index_for(BlockType.PLANK))).is_true()
    assert_int(inventory.count_of(BlockType.PLANK)).is_equal(4)
    assert_bool(RecipeBook.has_materials(
        inventory, RecipeBook.index_for(BlockType.DOOR_CLOSED))).is_true()


func test_the_first_pickaxe_costs_one_tree_and_nothing_else() -> void:
    # 나무 곡괭이가 없으면 돌을 캘 수 없고, 돌이 없으면 트리가 시작되지 않는다.
    # 그 문턱이 나무 하나 안에 들어와야 첫날이 성립한다.
    var inventory := Inventory.new()
    inventory.add(BlockType.WOOD, 1)
    assert_bool(RecipeBook.make(inventory, RecipeBook.index_for(BlockType.PLANK))).is_true()
    assert_bool(RecipeBook.make(inventory, RecipeBook.index_for(BlockType.WOOD_PICK))).is_true()
    assert_int(inventory.count_of(BlockType.WOOD_PICK)).is_equal(1)


func test_the_first_light_needs_no_ore() -> void:
    # 관솔불은 판자와 불씨돌만 든다. 등과 달리 광석이 들지 않으므로
    # 나무 곡괭이만으로 첫 굴을 밝힐 수 있다(스펙 §3.6).
    var torch := RecipeBook.inputs_of(RecipeBook.index_for(BlockType.TORCH))
    for entry: Array in torch:
        assert_int(int(entry[0])).is_not_equal(BlockType.ORE)


func test_the_whole_night_system_is_affordable_in_one_trip() -> void:
    # 스펙 §5 의 마지막 장치는 부품 다섯 종을 다 쓴다. 한 번의 채집으로
    # 닿지 못할 만큼 비싸면 회로를 시험해 볼 수가 없다.
    var inventory := _stocked([[BlockType.PLANK, 12], [BlockType.ORE, 12]])
    for block_type in [
        BlockType.DETECTOR, BlockType.ACTUATOR, BlockType.REPEATER,
        BlockType.BOX, BlockType.BRANCH,
    ]:
        assert_bool(RecipeBook.make(inventory, RecipeBook.index_for(block_type))
            ).override_failure_message(
                "나무 12 · 광석 12 로 %s 까지 가지 못한다" % BlockType.name_of(block_type)
            ).is_true()
