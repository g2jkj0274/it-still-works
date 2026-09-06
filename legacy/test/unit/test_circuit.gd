extends GdUnitTestSuite

## 회로 부품 배치·배선·신호 전파 검증.
##
## 신호는 1틱에 한 부품씩 나아간다. 그래서 감지기가 본 것이 작동기에 닿기까지
## 한 틱이 걸린다.

const DETECTOR_AT := Vector3i(4, 4, 1)
const ACTUATOR_AT := Vector3i(6, 4, 1)


func _circuit() -> Circuit:
    return Circuit.new()


func _detector(at: Vector3i = DETECTOR_AT) -> DetectorPart:
    return DetectorPart.create(at, DetectorPart.TARGET_PLAYER)


func _actuator(at: Vector3i = ACTUATOR_AT) -> ActuatorPart:
    return ActuatorPart.create(at)


func test_new_circuit_is_empty() -> void:
    var circuit := _circuit()
    assert_int(circuit.part_count()).is_equal(0)
    assert_int(circuit.link_count()).is_equal(0)


func test_parts_can_be_added_and_found() -> void:
    var circuit := _circuit()
    assert_bool(circuit.add_part(_detector())).is_true()
    assert_int(circuit.part_count()).is_equal(1)
    assert_object(circuit.part_at(DETECTOR_AT)).is_not_null()
    assert_object(circuit.part_at(Vector3i(9, 9, 9))).is_null()


func test_two_parts_cannot_share_a_cell() -> void:
    var circuit := _circuit()
    circuit.add_part(_detector())
    assert_bool(circuit.add_part(_actuator(DETECTOR_AT))).is_false()
    assert_int(circuit.part_count()).is_equal(1)


func test_parts_are_kept_in_position_order() -> void:
    var circuit := _circuit()
    circuit.add_part(_actuator(Vector3i(9, 0, 0)))
    circuit.add_part(_detector(Vector3i(1, 0, 0)))
    circuit.add_part(_actuator(Vector3i(5, 0, 0)))

    var positions: Array = []
    for part in circuit.parts():
        positions.append(part.position.x)
    assert_array(positions).contains_exactly([1, 5, 9])


func test_removing_a_part_drops_its_wires() -> void:
    var circuit := _circuit()
    circuit.add_part(_detector())
    circuit.add_part(_actuator())
    circuit.link(DETECTOR_AT, ACTUATOR_AT)
    assert_int(circuit.link_count()).is_equal(1)

    assert_bool(circuit.remove_part(DETECTOR_AT)).is_true()
    assert_int(circuit.link_count()).is_equal(0)


func test_wires_need_parts_at_both_ends() -> void:
    var circuit := _circuit()
    circuit.add_part(_detector())
    assert_bool(circuit.link(DETECTOR_AT, ACTUATOR_AT)).is_false()


func test_a_part_cannot_wire_to_itself() -> void:
    var circuit := _circuit()
    circuit.add_part(_detector())
    assert_bool(circuit.link(DETECTOR_AT, DETECTOR_AT)).is_false()


func test_the_same_wire_is_not_laid_twice() -> void:
    var circuit := _circuit()
    circuit.add_part(_detector())
    circuit.add_part(_actuator())
    assert_bool(circuit.link(DETECTOR_AT, ACTUATOR_AT)).is_true()
    assert_bool(circuit.link(DETECTOR_AT, ACTUATOR_AT)).is_false()
    assert_int(circuit.link_count()).is_equal(1)


func test_wires_can_be_taken_out() -> void:
    var circuit := _circuit()
    circuit.add_part(_detector())
    circuit.add_part(_actuator())
    circuit.link(DETECTOR_AT, ACTUATOR_AT)
    assert_bool(circuit.unlink(DETECTOR_AT, ACTUATOR_AT)).is_true()
    assert_int(circuit.link_count()).is_equal(0)
    assert_bool(circuit.unlink(DETECTOR_AT, ACTUATOR_AT)).is_false()


func test_wires_are_kept_in_a_fixed_order() -> void:
    var far := Vector3i(8, 8, 1)
    var forward := _circuit()
    var backward := _circuit()
    for circuit in [forward, backward]:
        circuit.add_part(_detector())
        circuit.add_part(_actuator())
        circuit.add_part(_actuator(far))
    forward.link(DETECTOR_AT, ACTUATOR_AT)
    forward.link(DETECTOR_AT, far)
    backward.link(DETECTOR_AT, far)
    backward.link(DETECTOR_AT, ACTUATOR_AT)

    assert_str(SimHash.hash_fields(forward.to_hash_fields())).is_equal(
        SimHash.hash_fields(backward.to_hash_fields()))
