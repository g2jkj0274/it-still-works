extends GdUnitTestSuite

## 부품 설정 표시 검증.
##
## 스펙 §4.2 는 상자에 **모양이 있다**고 명시한다 — 네모(정수) / 둥근(실수) /
## 작은(불리언). 이름만 있고 화면에는 하나의 모양뿐이었다.
##
## 이것은 오류를 말해 주는 UI 가 아니다. 눈에 안 보이던 사실을 보이게 할 뿐이다.

const AT := Vector3i(5, 5, 2)


func _box(shape: int, at: Vector3i = AT) -> BoxPart:
    var part := BoxPart.create(at)
    part.configure(PackedInt32Array([shape]))
    return part


func _repeater(mode: int, at: Vector3i = AT) -> RepeaterPart:
    var part := RepeaterPart.create(at)
    part.configure(PackedInt32Array([mode, 3, 10]))
    return part


func _view(circuit: Circuit) -> PartMarks:
    var view: PartMarks = auto_free(PartMarks.new())
    add_child(view)
    view.bind(circuit)
    view.rebuild()
    return view


func test_the_three_box_shapes_are_told_apart() -> void:
    var seen: Array[int] = []
    for shape in BoxPart.SHAPE_COUNT:
        var mark := PartMarks.mark_for(_box(shape))
        assert_int(mark).is_greater_equal(0)
        assert_bool(seen.has(mark)).is_false()
        seen.append(mark)


func test_a_square_box_shows_a_square() -> void:
    var circuit := Circuit.new()
    circuit.add_part(_box(BoxPart.SHAPE_SQUARE))
    var view := _view(circuit)
    assert_int(view.mark_count(PartMarks.MARK_SQUARE)).is_equal(1)
    assert_int(view.total_mark_count()).is_equal(1)


func test_changing_the_shape_changes_what_is_drawn() -> void:
    var circuit := Circuit.new()
    circuit.add_part(_box(BoxPart.SHAPE_ROUND))
    var view := _view(circuit)
    assert_int(view.mark_count(PartMarks.MARK_ROUND)).is_equal(1)
    assert_int(view.mark_count(PartMarks.MARK_SQUARE)).is_equal(0)


func test_only_the_endless_repeater_looks_different() -> void:
    # 끝없이 도는 것만 타 버린다. 그 대가가 예고되어야 한다.
    assert_int(PartMarks.mark_for(_repeater(RepeaterPart.MODE_FOREVER))).is_equal(
        PartMarks.MARK_ENDLESS)
    assert_int(PartMarks.mark_for(_repeater(RepeaterPart.MODE_COUNT))).is_less(0)
    assert_int(PartMarks.mark_for(_repeater(RepeaterPart.MODE_WHILE))).is_less(0)


func test_parts_with_nothing_to_show_get_no_mark() -> void:
    for part in [
        ActuatorPart.create(AT),
        DetectorPart.create(AT, DetectorPart.TARGET_PLAYER),
        BranchPart.create(AT),
    ]:
        assert_int(PartMarks.mark_for(part)).is_less(0)


func test_marks_follow_the_circuit() -> void:
    var circuit := Circuit.new()
    var view := _view(circuit)
    assert_int(view.total_mark_count()).is_equal(0)

    circuit.add_part(_box(BoxPart.SHAPE_SMALL))
    view.sync()
    assert_int(view.total_mark_count()).is_equal(1)

    circuit.remove_part(AT)
    view.sync()
    assert_int(view.total_mark_count()).is_equal(0)


func test_it_only_rebuilds_when_the_circuit_changes() -> void:
    var circuit := Circuit.new()
    circuit.add_part(_box(BoxPart.SHAPE_SQUARE))
    var view := _view(circuit)
    var builds := view.build_count()
    for i in 5:
        view.sync()
    assert_int(view.build_count()).is_equal(builds)


func test_the_view_never_writes_to_the_circuit() -> void:
    var circuit := Circuit.new()
    circuit.add_part(_box(BoxPart.SHAPE_ROUND))
    var view := _view(circuit)
    for i in 3:
        view.sync()
    assert_int(circuit.part_count()).is_equal(1)
    assert_int((circuit.part_at(AT) as BoxPart).shape).is_equal(BoxPart.SHAPE_ROUND)


func test_the_line_reads_out_what_a_placed_part_is_set_to() -> void:
    assert_str(PartWords.setting_of(_box(BoxPart.SHAPE_ROUND))).is_equal(
        PartWords.shape_name(BoxPart.SHAPE_ROUND))
    assert_str(PartWords.setting_of(
        DetectorPart.create(AT, DetectorPart.TARGET_TIME))).is_equal(
        PartWords.target_name(DetectorPart.TARGET_TIME))
    assert_str(PartWords.setting_of(_repeater(RepeaterPart.MODE_FOREVER))).is_equal("끝없이")


func test_the_line_never_says_why_something_failed() -> void:
    # 스펙 §1: 원인을 알려주지 않는다. 사실만 읽어 준다.
    var line := PartHint.aimed_line(_box(BoxPart.SHAPE_SQUARE))
    assert_str(line).not_contains("안 ")
    assert_str(line).not_contains("못 ")
    assert_str(line).contains(PartWords.name_of(BlockType.BOX))
