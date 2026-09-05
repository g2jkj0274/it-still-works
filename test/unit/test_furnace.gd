extends GdUnitTestSuite

## 화로 검증. **이 게임이 마인크래프트와 갈리는 자리다.**
##
## 저쪽 화로는 연료만 있으면 혼자 돈다. 여기서는 작동기가 때려야 한 번 돈다.
## 그래서 트리를 올라가려면 회로를 지어야 하고, 회로를 지으려면 트리를
## 올라가야 한다 — 생존과 자동화가 서로를 필요로 하게 묶이는 지점이다(§3.6).

const HERE := Vector3i(10, 10, 2)


func _sim() -> Simulation:
    var sim := Simulation.new(11)
    for y in range(6, 16):
        for x in range(6, 16):
            sim.state.grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
            sim.state.grid.set_block(Vector3i(x, y, 1), BlockType.GROUND)
    sim.state.character.place_at(HERE)
    return sim


## 감지기(사람) → 작동기 → 화로. 스펙 §5 의 자동 제련소다.
func _smelter(sim: Simulation) -> Vector3i:
    var furnace := HERE + Vector3i(2, 0, 0)
    var hand := HERE + Vector3i(1, 0, 0)
    var eye := HERE + Vector3i(0, 1, 0)

    sim.state.grid.set_block(furnace, BlockType.FURNACE)
    _put(sim, hand, BlockType.ACTUATOR, PackedInt32Array())
    _put(sim, eye, BlockType.DETECTOR, PackedInt32Array([DetectorPart.TARGET_PLAYER]))
    sim.state.circuit.link(eye, hand)
    return furnace


## 판을 세우는 일이라 명령을 거치지 않는다. 재료도 들지 않는다.
func _put(sim: Simulation, cell: Vector3i, kind: int, settings: PackedInt32Array) -> void:
    var part := CircuitPartFactory.create(kind, cell, settings)
    sim.state.grid.set_block(cell, kind)
    sim.state.circuit.add_part(part)


func test_a_hand_cannot_smelt() -> void:
    # **굽는 일은 손으로 못 한다.** 이 한 줄이 트리의 허리를 회로에 건다.
    var sim := _sim()
    sim.state.inventory.add(BlockType.ORE, 4)
    sim.state.inventory.add(BlockType.EMBER, 4)

    sim.submit(CraftCommand.create(BlockType.INGOT))
    sim.advance(4)
    assert_int(sim.state.inventory.count_of(BlockType.INGOT)).override_failure_message(
        "손으로 구워졌다. 화로가 회로를 요구하지 않으면 트리가 회로를 지나지 않는다"
        ).is_equal(0)


func test_the_circuit_smelts() -> void:
    var sim := _sim()
    sim.state.inventory.add(BlockType.ORE, 4)
    sim.state.inventory.add(BlockType.EMBER, 4)
    _smelter(sim)

    sim.advance(12)
    assert_int(sim.state.inventory.count_of(BlockType.INGOT)).is_greater(0)
    assert_int(sim.state.inventory.count_of(BlockType.ORE)).is_less(4)


func test_the_furnace_lights_while_the_signal_lasts() -> void:
    # 회로가 한 일이 화면에 보여야 한다. 숫자만 바뀌면 아무 일도 없는 것과 같다.
    var sim := _sim()
    sim.state.inventory.add(BlockType.ORE, 4)
    sim.state.inventory.add(BlockType.EMBER, 4)
    var furnace := _smelter(sim)

    sim.advance(12)
    assert_int(sim.state.grid.get_block(furnace)).is_equal(BlockType.FURNACE_LIT)


func test_it_smelts_once_per_firing_not_once_per_tick() -> void:
    # 켜져 있는 내내 구우면 되풀이의 간격이 뜻을 잃고 손에 든 것이 순식간에
    # 사라진다. 불이 막 붙은 그 틱에만 굽는다.
    var sim := _sim()
    sim.state.inventory.add(BlockType.ORE, 8)
    sim.state.inventory.add(BlockType.EMBER, 8)
    _smelter(sim)

    sim.advance(60)
    assert_int(sim.state.inventory.count_of(BlockType.INGOT)).override_failure_message(
        "한 번 불붙는 동안 여러 번 구웠다").is_equal(1)


func test_without_materials_nothing_happens() -> void:
    var sim := _sim()
    var furnace := _smelter(sim)

    sim.advance(12)
    assert_int(sim.state.inventory.total()).is_equal(0)
    # 불은 붙는다. 무엇이 모자란지는 말하지 않는다(§1).
    assert_int(sim.state.grid.get_block(furnace)).is_equal(BlockType.FURNACE_LIT)


func test_what_it_smelts_follows_the_order_in_the_book() -> void:
    # 차례가 고정이므로 언제 돌려도 같은 것이 나온다. 결정론의 뿌리다.
    var bag := Inventory.new()
    bag.add(BlockType.ORE, 1)
    bag.add(BlockType.ROCK, 1)
    bag.add(BlockType.EMBER, 4)
    var first := RecipeBook.first_makeable(bag, RecipeBook.FURNACE)
    assert_int(RecipeBook.output_of(first)).is_equal(BlockType.INGOT)


func test_every_furnace_recipe_needs_the_ember() -> void:
    # 불씨돌이 없으면 굽지 못한다. 그것이 땅속에 내려갈 까닭이다.
    for index in RecipeBook.count():
        if RecipeBook.station_of(index) != RecipeBook.FURNACE:
            continue
        var needs_ember := false
        for entry: Array in RecipeBook.inputs_of(index):
            if int(entry[0]) == BlockType.EMBER:
                needs_ember = true
        assert_bool(needs_ember).override_failure_message(
            "%s 를 불씨돌 없이 굽는다" % BlockType.name_of(RecipeBook.output_of(index))
            ).is_true()


func test_the_bench_must_be_within_reach() -> void:
    var sim := _sim()
    sim.state.inventory.add(BlockType.PLANK, 8)
    sim.state.inventory.add(BlockType.INGOT, 8)

    sim.submit(CraftCommand.create(BlockType.IRON_PICK))
    sim.advance(4)
    assert_int(sim.state.inventory.count_of(BlockType.IRON_PICK)).override_failure_message(
        "작업대 없이 쇠 곡괭이가 만들어졌다").is_equal(0)

    sim.state.grid.set_block(HERE + Vector3i(2, 0, 0), BlockType.BENCH)
    sim.submit(CraftCommand.create(BlockType.IRON_PICK))
    sim.advance(4)
    assert_int(sim.state.inventory.count_of(BlockType.IRON_PICK)).is_equal(1)


func test_an_iron_pick_opens_nothing_new_yet() -> void:
    # 깊은광과 빛돌은 아직 섬에 없다. 쇠 곡괭이가 여는 것은 빠르기뿐이고,
    # 그 사실을 여기서 못박아 둔다 — 다음 단이 들어오면 이 테스트가 바뀐다.
    assert_int(ToolRules.tier_of(BlockType.IRON_PICK)).is_greater(
        ToolRules.tier_of(BlockType.STONE_PICK))
    for type in BlockType.COUNT:
        if ToolRules.needed_for(type) > ToolRules.STONE:
            fail("돌 곡괭이보다 깊은 것이 이미 있다: %s" % BlockType.name_of(type))


func test_a_strong_door_is_not_gnawed() -> void:
    var sim := _sim()
    var door := HERE + Vector3i(1, 0, 0)
    sim.state.grid.set_block(door, BlockType.IRON_DOOR_CLOSED)
    assert_bool(BlockType.is_strong_door(sim.state.grid.get_block(door))).is_true()
    assert_bool(BlockType.is_door(sim.state.grid.get_block(door))).is_true()


func test_cooked_crop_feeds_twice_as_much() -> void:
    var sim := _sim()
    sim.state.vitals.fullness = 0
    sim.state.inventory.add(BlockType.COOKED_CROP, 1)
    sim.submit(EatCommand.create())
    sim.advance(2)
    assert_int(sim.state.vitals.fullness).is_equal(EatCommand.FULLNESS_PER_COOKED)
