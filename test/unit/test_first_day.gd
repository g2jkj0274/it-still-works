extends GdUnitTestSuite

## 첫날 검증. 스펙 §6 의 완료 판정 기준이 겨누는 자리다.
##
## *"첫날 밤을 손으로 버티고, 둘째 날 회로를 만들고 싶어지는가."*
##
## 앞의 절반은 숫자로 잴 수 있다. **손으로 첫 밤에 닿을 수 있는가.**
## 뒤의 절반은 사람이 해 봐야 안다.
##
## 한동안 이것이 불가능했다. 배는 4분에 비고 5분 40초에 쓰러지는데 첫 밤은
## 7분에 왔고, 섬에 손으로 먹을 것이 하나도 없었다.

const SEED := 20250901

## 얼마마다 한 번씩 들여다볼 것인가.
const STEP := 20


func _crop_cells() -> Array[Vector3i]:
    var cells: Array[Vector3i] = []
    for column in IslandBuilder.WILD_CROPS:
        cells.append(Vector3i(column.x, column.y, IslandBuilder.surface_z(column) + 1))
    return cells


## 낮이 끝날 때까지 돌리고, 처음 다친 틱을 돌려준다. 멀쩡하면 -1.
func _run_the_first_day(sim: Simulation, eat: bool) -> int:
    var hurt_at := -1
    while sim.current_tick() < DayCycle.DAY_TICKS:
        if eat and sim.state.vitals.fullness <= Vitals.MAX_FULLNESS - EatCommand.FULLNESS_PER_CROP:
            sim.submit(EatCommand.create())
        sim.advance(STEP)
        if hurt_at < 0 and sim.state.vitals.health < Vitals.MAX_HEALTH:
            hurt_at = sim.current_tick()
    return hurt_at


func test_the_island_has_something_to_eat_at_the_start() -> void:
    var state := WorldState.new(SimRng.new(SEED))
    IslandBuilder.populate(state)

    var found := 0
    for cell in _crop_cells():
        if state.grid.get_block(cell) == BlockType.CROP:
            found += 1
    assert_int(found).is_equal(IslandBuilder.WILD_CROPS.size())
    assert_int(found).is_greater(0)


func test_the_food_is_close_enough_to_find() -> void:
    # 스무 칸 밖에 있으면 첫 화면에서 보이지 않아 없는 것과 같다.
    for column in IslandBuilder.WILD_CROPS:
        var offset := column - Vector2i(IslandBuilder.SPAWN_COLUMN.x, IslandBuilder.SPAWN_COLUMN.y)
        assert_int(offset.x * offset.x + offset.y * offset.y).is_less_equal(12 * 12)


func test_wild_crops_come_off_in_the_hand() -> void:
    # 밭에서 거두는 것은 작동기뿐이지만(스펙 §3.6) 땅에 난 것은 부숴서 얻는다.
    var sim := IslandBuilder.start(SEED)
    for cell in _crop_cells():
        sim.submit(BreakBlockCommand.create(cell))
    sim.advance(4)
    assert_int(sim.state.inventory.count_of(BlockType.CROP)).is_equal(
        IslandBuilder.WILD_CROPS.size())


func test_the_first_night_can_be_reached_by_hand() -> void:
    var sim := IslandBuilder.start(SEED)
    for cell in _crop_cells():
        sim.submit(BreakBlockCommand.create(cell))
    sim.advance(4)

    assert_int(_run_the_first_day(sim, true)).override_failure_message(
        "손으로 모은 작물만으로는 첫 밤에 닿기 전에 굶는다").is_equal(-1)
    assert_int(sim.state.vitals.health).is_equal(Vitals.MAX_HEALTH)
    assert_bool(DayCycle.is_night(sim.current_tick())).is_true()


func test_not_eating_still_costs_you() -> void:
    # 위 테스트가 무는지 보이려는 것이다. 먹지 않으면 낮이 끝나기 전에 다친다.
    # 굶주림 자체를 없앤 것이 아니라 먹을 것을 둔 것이다.
    var sim := IslandBuilder.start(SEED)
    assert_int(_run_the_first_day(sim, false)).is_greater(0)


func test_the_wild_crops_do_not_come_back() -> void:
    # 첫날은 이것으로 넘기고, 둘째 날부터는 밭과 작동기가 필요해진다.
    var sim := IslandBuilder.start(SEED)
    for cell in _crop_cells():
        sim.submit(BreakBlockCommand.create(cell))
    sim.advance(4)

    sim.advance(DayCycle.CYCLE_TICKS)
    for cell in _crop_cells():
        assert_int(sim.state.grid.get_block(cell)).is_equal(BlockType.EMPTY)


func test_a_second_day_needs_a_farm() -> void:
    # 야생 작물을 다 먹어도 둘째 날 낮을 넘기지 못한다. 그것이 밭을 지을 이유다.
    var whole_day := DayCycle.CYCLE_TICKS
    var from_wild := IslandBuilder.WILD_CROPS.size() * EatCommand.FULLNESS_PER_CROP
    var from_start := Vitals.MAX_FULLNESS
    var lasts := (from_start + from_wild) * Vitals.FULLNESS_DECAY_TICKS

    assert_int(lasts).is_greater(whole_day)
    assert_int(lasts).is_less(whole_day * 2)
