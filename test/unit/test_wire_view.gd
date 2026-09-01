extends GdUnitTestSuite

## 배선 렌더링 검증. 회로를 읽기만 한다.

const A := Vector3i(4, 4, 1)
const B := Vector3i(8, 4, 1)


func _circuit() -> Circuit:
    var circuit := Circuit.new()
    circuit.add_part(DetectorPart.create(A, DetectorPart.TARGET_PLAYER))
    circuit.add_part(ActuatorPart.create(B))
    return circuit


func _view(circuit: Circuit) -> WireView:
    var view: WireView = auto_free(WireView.new())
    add_child(view)
    view.bind(circuit)
    view.rebuild()
    return view


func test_no_wires_means_nothing_drawn() -> void:
    assert_int(_view(_circuit()).wire_count()).is_equal(0)


func test_each_wire_gets_one_piece() -> void:
    var circuit := _circuit()
    circuit.link(A, B)
    assert_int(_view(circuit).wire_count()).is_equal(1)


func test_wires_appear_and_disappear_with_the_circuit() -> void:
    var circuit := _circuit()
    var view := _view(circuit)

    circuit.link(A, B)
    view.sync()
    assert_int(view.wire_count()).is_equal(1)

    circuit.unlink(A, B)
    view.sync()
    assert_int(view.wire_count()).is_equal(0)


func test_sync_rebuilds_only_when_wiring_changes() -> void:
    var circuit := _circuit()
    circuit.link(A, B)
    var view := _view(circuit)
    var builds := view.build_count()
    view.sync()
    view.sync()
    assert_int(view.build_count()).is_equal(builds)


func test_view_never_writes_to_the_circuit() -> void:
    var circuit := _circuit()
    circuit.link(A, B)
    var view := _view(circuit)
    view.sync()
    view.rebuild()
    assert_int(circuit.link_count()).is_equal(1)
    assert_int(circuit.part_count()).is_equal(2)


func test_a_wire_with_no_signal_reads_as_idle() -> void:
    var circuit := _circuit()
    circuit.link(A, B)
    var view := _view(circuit)
    assert_int(view.live_count()).is_equal(0)


func test_a_wire_carrying_a_signal_reads_as_live() -> void:
    var circuit := _circuit()
    circuit.link(A, B)
    var view := _view(circuit)

    var source := circuit.part_at(A)
    source.output = SignalValue.of_bool(true)
    view.sync()
    assert_int(view.live_count()).is_equal(1)


func test_the_untaken_way_out_of_a_branch_reads_as_idle() -> void:
    # 갈림길이 참일 때 거짓 쪽 배선은 흐르지 않는 것이 보여야 한다.
    var circuit := Circuit.new()
    var branch := BranchPart.create(A)
    branch.configure(PackedInt32Array([BranchPart.MODE_TRUTH, 0]))
    circuit.add_part(branch)
    circuit.add_part(ActuatorPart.create(B))
    circuit.add_part(ActuatorPart.create(Vector3i(12, 4, 1)))
    circuit.link(A, B, BranchPart.PORT_TRUE)
    circuit.link(A, Vector3i(12, 4, 1), BranchPart.PORT_FALSE)

    var view := _view(circuit)
    branch.compute(WorldState.new(SimRng.new(1)), [SignalValue.of_bool(true)])
    branch.commit()
    view.sync()

    assert_int(view.wire_count()).is_equal(2)
    assert_int(view.live_count()).is_equal(1)


func _branch_circuit() -> Circuit:
    var circuit := Circuit.new()
    var branch := BranchPart.create(A)
    branch.configure(PackedInt32Array([BranchPart.MODE_TRUTH, 0]))
    circuit.add_part(branch)
    circuit.add_part(ActuatorPart.create(B))
    circuit.link(A, B, BranchPart.PORT_TRUE)
    circuit.link(A, B, BranchPart.PORT_FALSE)
    return circuit


func test_the_two_ways_out_are_drawn_in_different_colours() -> void:
    var circuit := _branch_circuit()
    var view := _view(circuit)
    var links := circuit.links()
    assert_int(links.size()).is_equal(2)
    assert_bool(view.colour_of(links[0]).is_equal_approx(view.colour_of(links[1]))).is_false()


func test_a_flowing_wire_is_brighter_than_a_still_one() -> void:
    var circuit := _branch_circuit()
    var view := _view(circuit)
    var branch := circuit.part_at(A) as BranchPart
    branch.compute(WorldState.new(SimRng.new(1)), [SignalValue.of_bool(true)])
    branch.commit()

    for link: Array in circuit.links():
        var expected_live := int(link[2]) == BranchPart.PORT_TRUE
        assert_bool(view.is_live(link)).is_equal(expected_live)
