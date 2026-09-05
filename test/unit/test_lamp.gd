extends GdUnitTestSuite

## 등 검증.
##
## 스펙 §4.2 의 작동기 표와 §5 의 "자동 조명"에 등이 적혀 있는데 블록이
## 없었다. 회로가 세상을 바꾸는 자리가 문 하나뿐이었던 것이다.
##
## 땅속은 지표에서 멀어질수록 어둡다. 등은 그것을 밝히는 유일한 길이다.

const AT := Vector3i(10, 10, 5)


func _world() -> WorldState:
    var state := WorldState.new(SimRng.new(3))
    for y in range(8, 14):
        for x in range(8, 14):
            for z in range(0, 5):
                state.grid.set_block(Vector3i(x, y, z), BlockType.ROCK)
    return state


## 등 옆에 작동기를 붙이고 신호를 준다.
func _switch(state: WorldState, on: bool) -> void:
    var actuator := ActuatorPart.create(AT + Vector3i(1, 0, 0))
    state.circuit.add_part(actuator)
    actuator.compute(state, [SignalValue.of_bool(true)] if on else [])
    actuator.commit()
    actuator.act(state)


func test_a_lamp_is_a_block_you_can_hold() -> void:
    assert_bool(BlockType.is_lamp(BlockType.LAMP_DARK)).is_true()
    assert_bool(BlockType.is_lamp(BlockType.LAMP_LIT)).is_true()
    assert_bool(BlockType.is_lamp(BlockType.DOOR_CLOSED)).is_false()
    assert_bool(InputController.PLACEABLE.has(BlockType.LAMP_DARK)).is_true()


func test_a_lamp_can_be_made() -> void:
    # 여럿 필요하다. 땅속을 밝히려면 몇 칸마다 하나씩 놓는다.
    assert_bool(RecipeBook.can_be_made(BlockType.LAMP_DARK)).is_true()
    assert_int(RecipeBook.yield_of(RecipeBook.index_for(BlockType.LAMP_DARK))).is_greater(1)


func test_an_actuator_lights_a_lamp_beside_it() -> void:
    var state := _world()
    state.grid.set_block(AT, BlockType.LAMP_DARK)
    _switch(state, true)
    assert_int(state.grid.get_block(AT)).is_equal(BlockType.LAMP_LIT)


func test_the_lamp_goes_out_when_the_signal_stops() -> void:
    var state := _world()
    state.grid.set_block(AT, BlockType.LAMP_LIT)
    _switch(state, false)
    assert_int(state.grid.get_block(AT)).is_equal(BlockType.LAMP_DARK)


func test_breaking_a_lit_lamp_gives_back_a_lamp() -> void:
    var state := _world()
    state.grid.set_block(AT, BlockType.LAMP_LIT)
    BreakBlockCommand.create(AT).apply(state)
    assert_int(state.inventory.count_of(BlockType.LAMP_DARK)).is_equal(1)
    assert_int(state.inventory.count_of(BlockType.LAMP_LIT)).is_equal(0)


func test_the_night_watch_lights_the_lamp() -> void:
    # 스펙 §5 의 자동 조명: 감지기(시간=밤) → 작동기(등).
    var state := _world()
    state.grid.set_block(AT, BlockType.LAMP_DARK)

    var eye := DetectorPart.create(AT + Vector3i(0, 1, 0), DetectorPart.TARGET_TIME)
    var hand := ActuatorPart.create(AT + Vector3i(1, 0, 0))
    state.circuit.add_part(eye)
    state.circuit.add_part(hand)
    state.circuit.link(eye.position, hand.position)

    state.tick = DayCycle.DAY_TICKS / 2
    for i in 3:
        state.circuit.tick(state)
    assert_int(state.grid.get_block(AT)).is_equal(BlockType.LAMP_DARK)

    state.tick = DayCycle.DAY_TICKS + 10
    for i in 3:
        state.circuit.tick(state)
    assert_int(state.grid.get_block(AT)).is_equal(BlockType.LAMP_LIT)


## --- 빛 ---

func _lights(grid: VoxelGrid) -> LampLights:
    var lights: LampLights = auto_free(LampLights.new())
    add_child(lights)
    lights.bind(grid)
    lights.sync()
    return lights


func test_a_lit_lamp_gets_a_light() -> void:
    var state := _world()
    state.grid.set_block(AT, BlockType.LAMP_LIT)
    var lights := _lights(state.grid)
    assert_int(lights.lit_count()).is_equal(1)
    assert_int(lights.shining_count()).is_equal(1)


func test_a_dark_lamp_gets_none() -> void:
    var state := _world()
    state.grid.set_block(AT, BlockType.LAMP_DARK)
    assert_int(_lights(state.grid).shining_count()).is_equal(0)


func test_putting_out_a_lamp_puts_out_its_light() -> void:
    var state := _world()
    state.grid.set_block(AT, BlockType.LAMP_LIT)
    var lights := _lights(state.grid)
    assert_int(lights.shining_count()).is_equal(1)

    state.grid.set_block(AT, BlockType.LAMP_DARK)
    lights.sync()
    assert_int(lights.shining_count()).is_equal(0)


func test_many_lamps_do_not_light_them_all_at_once() -> void:
    # 등을 백 개 놓아도 화면이 버텨야 한다.
    var state := _world()
    var placed := 0
    for y in range(8, 14):
        for x in range(8, 14):
            state.grid.set_block(Vector3i(x, y, 5), BlockType.LAMP_LIT)
            placed += 1

    var lights := _lights(state.grid)
    assert_int(lights.lit_count()).is_equal(placed)
    assert_int(lights.shining_count()).is_equal(LampLights.MAX_LIGHTS)


func test_the_view_never_writes_to_the_grid() -> void:
    var state := _world()
    state.grid.set_block(AT, BlockType.LAMP_LIT)
    var before := state.grid.digest()
    var lights := _lights(state.grid)
    for i in 3:
        lights.sync()
    assert_str(state.grid.digest()).is_equal(before)


## --- 빛의 세기 ---
##
## **한낮에도 같은 세기로 때리면 바닥이 하얗게 날아간다.** 켜진 등이 아니라
## 잘못 그려진 흰 상자로 보였다. 등이 값을 하는 곳은 밤과 땅속이다.

func test_a_lamp_is_dimmer_by_day_than_by_night() -> void:
    var state := _world()
    var lights := _lights(state.grid)
    var high := Vector3i(AT.x, AT.y, VoxelGrid.SIZE_Z - 1)

    lights.set_darkness(0.0)
    var by_day := lights.strength_at(high)
    lights.set_darkness(1.0)
    var by_night := lights.strength_at(high)

    assert_float(by_day).is_less(by_night)
    assert_float(by_day).is_greater(0.0)


func test_a_buried_lamp_burns_full_even_at_noon() -> void:
    # 땅속은 하늘이 밝아도 캄캄하다. 파고 내려가는 보람이 여기 있다.
    var state := _world()
    state.grid.set_block(Vector3i(AT.x, AT.y, VoxelGrid.SIZE_Z - 1), BlockType.ROCK)
    var lights := _lights(state.grid)
    lights.set_darkness(0.0)

    var deep := Vector3i(AT.x, AT.y, VoxelGrid.BEDROCK_Z + 1)
    assert_float(lights.strength_at(deep)).is_equal_approx(LampLights.STRENGTH, 0.01)


func test_no_lamp_ever_burns_brighter_than_full() -> void:
    var state := _world()
    var lights := _lights(state.grid)
    lights.set_darkness(1.0)
    for z in [VoxelGrid.BEDROCK_Z + 1, VoxelGrid.SIZE_Z - 1]:
        assert_float(lights.strength_at(Vector3i(AT.x, AT.y, z))).is_less_equal(
            LampLights.STRENGTH + 0.001)
