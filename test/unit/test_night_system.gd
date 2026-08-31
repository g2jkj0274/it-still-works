extends GdUnitTestSuite

## 스펙 5절의 마지막 장치 검증.
##
## 감지기 · 갈림길 · 되풀이 · 상자 · 작동기를 모두 써야 완성된다.
## 부품이 서로 필요해지는 구조인지 확인하는 기준점이다.
##
##   감지기 → 갈림길 → (참 쪽) 되풀이 → 상자 → 작동기 → 문
##
## 되풀이는 신호를 띄엄띄엄 내보내므로 사이가 빈다. 상자가 그 사이를 메운다.
## 상자를 빼면 문이 깜빡이고, 갈림길을 빼면 조건이 사라진다. 부품이 서로 필요하다.

const DETECTOR := Vector3i(8, 8, 1)
const BRANCH := Vector3i(8, 7, 1)
const REPEATER := Vector3i(8, 6, 1)
const BOX := Vector3i(8, 5, 1)
const ACTUATOR := Vector3i(8, 4, 1)
const DOOR := Vector3i(8, 3, 1)

const NEAR := Vector3i(8, 10, 1)
const FAR := Vector3i(2, 2, 1)


func _sim() -> Simulation:
    var sim := Simulation.new(1)
    for y in 16:
        for x in 16:
            sim.state.grid.set_block(Vector3i(x, y, 0), BlockType.GROUND)
    sim.state.grid.set_block(DOOR, BlockType.DOOR_CLOSED)

    _put(sim, DetectorPart.create(DETECTOR, DetectorPart.TARGET_PLAYER))
    _put(sim, _branch())
    _put(sim, _repeater())
    _put(sim, _box())
    _put(sim, ActuatorPart.create(ACTUATOR))

    var circuit := sim.state.circuit
    circuit.link(DETECTOR, BRANCH)
    circuit.link(BRANCH, REPEATER, BranchPart.PORT_TRUE)
    circuit.link(REPEATER, BOX)
    circuit.link(BOX, ACTUATOR)

    sim.state.character.place_at(FAR)
    return sim


func _put(sim: Simulation, part: CircuitPart) -> void:
    sim.state.grid.set_block(part.position, part.kind())
    sim.state.circuit.add_part(part)


func _branch() -> BranchPart:
    var part := BranchPart.create(BRANCH)
    part.configure(PackedInt32Array([BranchPart.MODE_TRUTH, 0]))
    return part


func _repeater() -> RepeaterPart:
    var part := RepeaterPart.create(REPEATER)
    part.configure(PackedInt32Array([RepeaterPart.MODE_WHILE, 0, 3]))
    return part


func _box() -> BoxPart:
    var part := BoxPart.create(BOX)
    part.configure(PackedInt32Array([BoxPart.SHAPE_SMALL]))
    return part


func _door(sim: Simulation) -> int:
    return sim.state.grid.get_block(DOOR)


func test_the_device_uses_all_five_parts() -> void:
    var kinds: Array = []
    for part in _sim().state.circuit.parts():
        if not kinds.has(part.kind()):
            kinds.append(part.kind())
    assert_array(kinds).contains_exactly_in_any_order([
        BlockType.DETECTOR, BlockType.BRANCH, BlockType.REPEATER,
        BlockType.BOX, BlockType.ACTUATOR,
    ])


func test_the_door_stays_shut_while_nobody_is_near() -> void:
    var sim := _sim()
    sim.advance(20)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_CLOSED)


func test_the_door_opens_when_someone_comes() -> void:
    var sim := _sim()
    sim.state.character.place_at(NEAR)
    sim.advance(20)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_OPEN)


func test_the_box_holds_the_door_steady_between_pulses() -> void:
    # 되풀이만 있으면 신호 사이가 비어 문이 깜빡인다. 상자가 그 사이를 메운다.
    var sim := _sim()
    sim.state.character.place_at(NEAR)
    sim.advance(20)

    for i in 12:
        sim.step()
        assert_int(_door(sim)).is_equal(BlockType.DOOR_OPEN)


func test_without_the_box_the_door_flickers() -> void:
    var sim := _sim()
    sim.state.circuit.remove_part(BOX)
    sim.state.circuit.link(REPEATER, ACTUATOR)
    sim.state.character.place_at(NEAR)
    sim.advance(20)

    var shut_at_least_once := false
    for i in 12:
        sim.step()
        if _door(sim) == BlockType.DOOR_CLOSED:
            shut_at_least_once = true
    assert_bool(shut_at_least_once).is_true()


func test_the_box_remembers_after_the_signal_stops() -> void:
    # 상자는 값을 기억한다. 사람이 떠나도 담긴 값은 남는다.
    # 되돌리려면 다른 신호로 덮어써야 한다. 이것이 상자의 뜻이다.
    var sim := _sim()
    sim.state.character.place_at(NEAR)
    sim.advance(20)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_OPEN)

    sim.state.character.place_at(FAR)
    sim.advance(20)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_OPEN)


func test_taking_the_branch_out_breaks_the_chain() -> void:
    var sim := _sim()
    sim.submit(BreakBlockCommand.create(BRANCH))
    sim.state.character.place_at(NEAR)
    sim.advance(25)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_CLOSED)


func test_taking_the_repeater_out_breaks_the_chain() -> void:
    var sim := _sim()
    sim.submit(BreakBlockCommand.create(REPEATER))
    sim.state.character.place_at(NEAR)
    sim.advance(25)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_CLOSED)


func test_taking_the_actuator_out_breaks_the_chain() -> void:
    var sim := _sim()
    sim.submit(BreakBlockCommand.create(ACTUATOR))
    sim.state.character.place_at(NEAR)
    sim.advance(25)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_CLOSED)


func test_a_branch_that_never_passes_keeps_the_door_shut() -> void:
    # 갈림길이 거짓 쪽으로만 보내면 참 쪽에 이어진 것은 실행되지 않는다.
    var sim := _sim()
    var branch := sim.state.circuit.part_at(BRANCH) as BranchPart
    branch.configure(PackedInt32Array([BranchPart.MODE_GREATER_EQUAL, 99]))
    sim.state.character.place_at(NEAR)
    sim.advance(25)
    assert_int(_door(sim)).is_equal(BlockType.DOOR_CLOSED)
