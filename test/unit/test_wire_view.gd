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


func test_a_wire_climbs_over_the_parts_it_joins() -> void:
    # 부품은 자기 칸을 거의 채운다. 칸 한가운데끼리 곧게 이으면 배선이 통째로
    # 부품 안에 파묻혀 화면에서 사라진다. 회로 게임인데 회로가 안 보였다.
    var neighbour := Vector3i(5, 4, 1)
    var path := WireView.path_of([A, neighbour, 0])

    var cell_top := SimViewCoords.cell_to_world(A).y + SimViewCoords.CELL_SIZE * 0.5
    # 건너가는 토막은 두 부품 지붕보다 위에 있어야 한다.
    assert_float(path[1].y).is_greater(cell_top)
    assert_float(path[2].y).is_greater(cell_top)


func test_a_wire_is_drawn_in_three_pieces() -> void:
    var circuit := _circuit()
    circuit.link(A, B)
    var view := _view(circuit)
    assert_int(view.wire_count()).is_equal(1)
    assert_int(view.piece_count()).is_equal(WireView.PIECES)


func test_a_wire_is_thick_enough_to_see() -> void:
    # 한 칸이 화면에서 사십 픽셀 남짓이다. 0.08 은 세 픽셀이라 보이지 않았다.
    assert_float(WireView.THICKNESS).is_greater(0.1)


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


## --- 방향과 흐름 ---
##
## 스펙 §4.1: "배선은 방향이 있다. 출발에서 도착으로만 흐른다."
## 굵기가 일정한 막대로는 어느 쪽이 출발인지 알 수 없었다.

func test_a_wire_thins_towards_where_it_goes() -> void:
    assert_float(WireView.TAIL).is_less(1.0)
    assert_float(WireView.TAIL).is_greater(0.0)


func test_a_signal_travels_from_the_start_to_the_end() -> void:
    var link: Array = [A, B, 0]
    var start := WireView.point_along(link, 0.0)
    var middle := WireView.point_along(link, 0.5)
    var finish := WireView.point_along(link, 1.0)

    assert_bool(start.is_equal_approx(SimViewCoords.cell_to_world(A))).is_true()
    assert_bool(finish.is_equal_approx(SimViewCoords.cell_to_world(B))).is_true()
    # 가운데는 부품 지붕 위를 지난다.
    assert_float(middle.y).is_greater(start.y)


func test_the_signal_walks_the_whole_wire() -> void:
    var link: Array = [A, B, 0]
    var last := WireView.point_along(link, 0.0)
    var walked := 0.0
    for i in range(1, 21):
        var here := WireView.point_along(link, i / 20.0)
        walked += here.distance_to(last)
        last = here
    # 올라가고 건너가고 내려온 길이만큼은 지나야 한다.
    assert_float(walked).is_greater(SimViewCoords.cell_to_world(A).distance_to(
        SimViewCoords.cell_to_world(B)))


func test_a_flowing_wire_always_shows_its_signal() -> void:
    # 이미 돌고 있는 회로를 나중에 와서 본 사람에게도 흐름이 보여야 한다.
    # 켜지는 순간에 한 번만 태워 보내면 그 사람 화면에서는 아무 일도 없다.
    var circuit := _branch_circuit()
    var view := _view(circuit)
    var branch := circuit.part_at(A) as BranchPart
    branch.compute(WorldState.new(SimRng.new(1)), [SignalValue.of_bool(true)])
    branch.commit()

    view.sync()
    assert_int(view.spark_count()).is_equal(1)
    view.sync()
    assert_int(view.spark_count()).is_equal(1)


func test_a_still_wire_shows_no_signal() -> void:
    var circuit := _circuit()
    circuit.link(A, B)
    var view := _view(circuit)
    view.sync()
    assert_int(view.spark_count()).is_equal(0)
