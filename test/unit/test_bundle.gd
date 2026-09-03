extends GdUnitTestSuite

## 묶음 검증. 스펙 §4.3.
##
## 이 게임의 정체성이라고 스펙이 못박은 기능이다. 없으면 그냥 레드스톤이다.
##
## 확인하는 것: 압축과 재배치, 값이 드나드는 자리, 안쪽 감춤, 놓인 것마다
## 따로 도는 상태, 묶음 속 묶음, 자기 자신을 품지 못함.

const ORIGIN := Vector3i(10, 10, 3)


func _state() -> WorldState:
    return WorldState.new(SimRng.new(7))


func _detector(at: Vector3i, target: int = DetectorPart.TARGET_PLAYER) -> DetectorPart:
    return DetectorPart.create(at, target)


func _box(at: Vector3i, shape: int = BoxPart.SHAPE_SQUARE) -> BoxPart:
    var part := BoxPart.create(at)
    part.configure(PackedInt32Array([shape]))
    return part


## 상자 하나짜리 회로. 왼쪽으로 들어가 오른쪽으로 나온다.
func _one_box_circuit() -> Circuit:
    var circuit := Circuit.new()
    circuit.add_part(_box(ORIGIN))
    return circuit


func _cells(values: Array) -> Array[Vector3i]:
    var cells: Array[Vector3i] = []
    for value: Vector3i in values:
        cells.append(value)
    return cells


func _capture(circuit: Circuit, cells: Array, inputs: Array = [], outputs: Array = []) -> BundleBlueprint:
    return BundleBlueprint.capture(circuit, _cells(cells), _cells(inputs), _cells(outputs))


func _bundle(library: BundleLibrary, id: int, at: Vector3i = Vector3i(1, 1, 1)) -> BundlePart:
    return CircuitPartFactory.create(
        BlockType.BUNDLE, at, PackedInt32Array([id]), library) as BundlePart


func test_a_captured_circuit_keeps_its_parts_and_wires() -> void:
    var circuit := Circuit.new()
    circuit.add_part(_detector(ORIGIN))
    circuit.add_part(ActuatorPart.create(ORIGIN + Vector3i(1, 0, 0)))
    circuit.link(ORIGIN, ORIGIN + Vector3i(1, 0, 0))

    var blueprint := _capture(circuit, [ORIGIN, ORIGIN + Vector3i(1, 0, 0)])
    assert_int(blueprint.part_count()).is_equal(2)
    assert_int(blueprint.link_count()).is_equal(1)


func test_wires_leaving_the_selection_are_left_behind() -> void:
    # 고르지 않은 부품으로 나가는 배선은 함께 갈 수 없다. 그 부품이 남기 때문이다.
    var circuit := Circuit.new()
    var outside := ORIGIN + Vector3i(0, 2, 0)
    circuit.add_part(_detector(ORIGIN))
    circuit.add_part(ActuatorPart.create(outside))
    circuit.link(ORIGIN, outside)

    var blueprint := _capture(circuit, [ORIGIN])
    assert_int(blueprint.part_count()).is_equal(1)
    assert_int(blueprint.link_count()).is_equal(0)


func test_the_same_shape_captured_anywhere_is_the_same_blueprint() -> void:
    # 자리는 상대 좌표로 담긴다. 어디서 묶어도 같은 것이 나와야 한다.
    var near := Circuit.new()
    near.add_part(_box(Vector3i(1, 1, 1)))
    near.add_part(_box(Vector3i(2, 1, 1)))

    var far := Circuit.new()
    far.add_part(_box(Vector3i(40, 20, 6)))
    far.add_part(_box(Vector3i(41, 20, 6)))

    var here := _capture(near, [Vector3i(1, 1, 1), Vector3i(2, 1, 1)])
    var there := _capture(far, [Vector3i(40, 20, 6), Vector3i(41, 20, 6)])
    assert_array(here.parts()).is_equal(there.parts())


func test_an_empty_selection_cannot_be_bundled() -> void:
    assert_object(_capture(Circuit.new(), [])).is_null()


func test_a_cell_without_a_part_cannot_be_bundled() -> void:
    assert_object(_capture(_one_box_circuit(), [ORIGIN, ORIGIN + Vector3i(5, 0, 0)])).is_null()


func test_a_burnt_part_cannot_be_bundled() -> void:
    # 타 버린 부품은 부숴도 재료가 돌아오지 않는다. 묶어서 되살릴 수 있으면
    # 그 손해가 손해가 아니게 된다.
    var circuit := Circuit.new()
    var repeater := RepeaterPart.create(ORIGIN)
    repeater.configure(PackedInt32Array([RepeaterPart.MODE_FOREVER, 0, 1]))
    circuit.add_part(repeater)

    var state := _state()
    for i in 200:
        # 끝없이 도는 되풀이는 신호를 한 번 받으면 스스로 돈다.
        repeater.compute(state, [SignalValue.of_bool(true)])
        repeater.commit()
        if repeater.is_burnt():
            break

    assert_bool(repeater.is_burnt()).is_true()
    assert_object(_capture(circuit, [ORIGIN])).is_null()


func test_a_terminal_must_be_one_of_the_chosen_cells() -> void:
    var outside := ORIGIN + Vector3i(3, 0, 0)
    assert_object(_capture(_one_box_circuit(), [ORIGIN], [outside])).is_null()
    assert_object(_capture(_one_box_circuit(), [ORIGIN], [], [outside])).is_null()


func test_the_library_numbers_bundles_in_the_order_they_are_made() -> void:
    var library := BundleLibrary.new()
    assert_int(library.define(_capture(_one_box_circuit(), [ORIGIN]))).is_equal(0)
    assert_int(library.define(_capture(_one_box_circuit(), [ORIGIN]))).is_equal(1)
    assert_int(library.count()).is_equal(2)


func test_a_value_goes_in_the_entry_and_comes_out_the_exit() -> void:
    var library := BundleLibrary.new()
    var id := library.define(_capture(_one_box_circuit(), [ORIGIN], [ORIGIN], [ORIGIN]))

    var outer := Circuit.new()
    var source := _box(Vector3i(0, 0, 0))
    outer.add_part(source)
    outer.add_part(_bundle(library, id, Vector3i(1, 0, 0)))
    outer.link(Vector3i(0, 0, 0), Vector3i(1, 0, 0))

    var state := _state()
    # 상자는 담긴 값을 늘 내보낸다. 먼저 넣어 둔다.
    source.compute(state, [SignalValue.of_int(5)])
    source.commit()

    outer.tick(state)
    var bundle := outer.part_at(Vector3i(1, 0, 0))
    assert_int(bundle.output.as_int()).is_equal(5)


func test_a_bundle_with_no_exit_sends_nothing_out() -> void:
    var library := BundleLibrary.new()
    var id := library.define(_capture(_one_box_circuit(), [ORIGIN], [ORIGIN]))
    var bundle := _bundle(library, id)

    bundle.compute(_state(), [SignalValue.of_int(9)])
    bundle.commit()
    assert_bool(bundle.output.is_present()).is_false()


func test_each_wire_reaches_its_own_entry_in_order() -> void:
    var circuit := Circuit.new()
    var left := ORIGIN
    var right := ORIGIN + Vector3i(1, 0, 0)
    circuit.add_part(_box(left))
    circuit.add_part(_box(right))

    var library := BundleLibrary.new()
    var id := library.define(_capture(circuit, [left, right], [left, right], [right]))
    var bundle := _bundle(library, id)

    # 둘째 배선이 둘째 자리로 가야 한다. 나가는 자리는 그 둘째 상자다.
    bundle.compute(_state(), [SignalValue.of_int(1), SignalValue.of_int(2)])
    bundle.commit()
    assert_int(bundle.output.as_int()).is_equal(2)


func test_a_bundle_can_have_more_than_one_exit() -> void:
    var circuit := Circuit.new()
    var left := ORIGIN
    var right := ORIGIN + Vector3i(1, 0, 0)
    circuit.add_part(_box(left))
    circuit.add_part(_box(right))

    var library := BundleLibrary.new()
    var id := library.define(_capture(circuit, [left, right], [left, right], [left, right]))
    var bundle := _bundle(library, id)

    assert_int(bundle.output_count()).is_equal(2)
    bundle.compute(_state(), [SignalValue.of_int(3), SignalValue.of_int(8)])
    bundle.commit()
    assert_int(bundle.output_at(0).as_int()).is_equal(3)
    assert_int(bundle.output_at(1).as_int()).is_equal(8)


func test_the_inside_of_a_bundle_is_not_in_the_world() -> void:
    # 안은 밖에서 보이지 않는다. 월드의 회로에는 묶음 한 칸만 있다.
    var library := BundleLibrary.new()
    var circuit := Circuit.new()
    circuit.add_part(_box(ORIGIN))
    circuit.add_part(_box(ORIGIN + Vector3i(1, 0, 0)))
    var id := library.define(_capture(circuit, [ORIGIN, ORIGIN + Vector3i(1, 0, 0)]))

    var outer := Circuit.new()
    outer.add_part(_bundle(library, id, ORIGIN))
    assert_int(outer.part_count()).is_equal(1)
    assert_object(outer.part_at(ORIGIN + Vector3i(1, 0, 0))).is_null()


func test_two_placings_of_one_bundle_keep_their_own_boxes() -> void:
    # 스코프. 같은 묶음을 열 개 놓으면 상자도 열 개다.
    var library := BundleLibrary.new()
    var id := library.define(_capture(_one_box_circuit(), [ORIGIN], [ORIGIN], [ORIGIN]))

    var first := _bundle(library, id, Vector3i(0, 0, 0))
    var second := _bundle(library, id, Vector3i(2, 0, 0))
    var state := _state()

    first.compute(state, [SignalValue.of_int(4)])
    first.commit()
    second.compute(state, [])
    second.commit()

    assert_int(first.output.as_int()).is_equal(4)
    assert_bool(second.output.is_present()).is_false()


func test_a_bundle_holds_what_it_was_given_after_the_signal_stops() -> void:
    var library := BundleLibrary.new()
    var id := library.define(_capture(_one_box_circuit(), [ORIGIN], [ORIGIN], [ORIGIN]))
    var bundle := _bundle(library, id)
    var state := _state()

    bundle.compute(state, [SignalValue.of_int(6)])
    bundle.commit()
    bundle.compute(state, [])
    bundle.commit()
    assert_int(bundle.output.as_int()).is_equal(6)


func test_a_bundle_can_hold_another_bundle() -> void:
    var library := BundleLibrary.new()
    var inner_id := library.define(_capture(_one_box_circuit(), [ORIGIN], [ORIGIN], [ORIGIN]))

    var middle := Circuit.new()
    middle.add_part(_bundle(library, inner_id, ORIGIN))
    var outer_id := library.define(_capture(middle, [ORIGIN], [ORIGIN], [ORIGIN]))

    var bundle := _bundle(library, outer_id)
    bundle.compute(_state(), [SignalValue.of_int(11)])
    bundle.commit()
    assert_int(bundle.output.as_int()).is_equal(11)


func test_a_bundle_cannot_hold_itself() -> void:
    # 재귀는 만들지 않는다. 아직 없는 번호를 품은 설계도는 받지 않는다.
    var library := BundleLibrary.new()
    var blueprint := BundleBlueprint.from_dict({
        "parts": [[BlockType.BUNDLE, [0, 0, 0], [0]]],
        "links": [],
        "inputs": [],
        "outputs": [],
    })
    assert_int(library.define(blueprint)).is_equal(-1)
    assert_int(library.count()).is_equal(0)


func test_a_bundle_of_an_unknown_number_is_never_made() -> void:
    assert_object(_bundle(BundleLibrary.new(), 3)).is_null()


func test_a_bundle_shaves_the_value_the_way_its_box_does() -> void:
    # 형변환 손실은 묶어 넣어도 그대로다. 되돌려도 돌아오지 않는다.
    var library := BundleLibrary.new()
    var circuit := Circuit.new()
    circuit.add_part(_box(ORIGIN, BoxPart.SHAPE_SQUARE))
    var id := library.define(_capture(circuit, [ORIGIN], [ORIGIN], [ORIGIN]))

    var bundle := _bundle(library, id)
    bundle.compute(_state(), [SignalValue.of_real(3, 700)])
    bundle.commit()
    assert_int(bundle.output.as_int()).is_equal(3)
    assert_int(bundle.output.as_real_scaled()).is_equal(3000)


func test_a_bundle_with_a_burnt_part_inside_gives_nothing_back() -> void:
    var library := BundleLibrary.new()
    var circuit := Circuit.new()
    var repeater := RepeaterPart.create(ORIGIN)
    repeater.configure(PackedInt32Array([RepeaterPart.MODE_FOREVER, 0, 1]))
    circuit.add_part(repeater)
    var id := library.define(_capture(circuit, [ORIGIN], [ORIGIN], [ORIGIN]))

    var bundle := _bundle(library, id)
    assert_bool(bundle.yields_material()).is_true()

    var state := _state()
    for i in 200:
        bundle.compute(state, [SignalValue.of_bool(true)])
        bundle.commit()
    assert_bool(bundle.yields_material()).is_false()


func test_a_blueprint_survives_being_written_and_read_back() -> void:
    var circuit := Circuit.new()
    circuit.add_part(_detector(ORIGIN, DetectorPart.TARGET_TIME))
    circuit.add_part(_box(ORIGIN + Vector3i(1, 0, 0), BoxPart.SHAPE_ROUND))
    circuit.link(ORIGIN, ORIGIN + Vector3i(1, 0, 0))

    var before := _capture(
        circuit, [ORIGIN, ORIGIN + Vector3i(1, 0, 0)], [], [ORIGIN + Vector3i(1, 0, 0)])
    var wire: Variant = JSON.parse_string(JSON.stringify(before.to_dict()))
    var after := BundleBlueprint.from_dict(wire)

    assert_array(after.parts()).is_equal(before.parts())
    assert_array(after.links()).is_equal(before.links())
    assert_array(after.outputs()).is_equal(before.outputs())
