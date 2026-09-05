extends GdUnitTestSuite

## 부품 설정 표시 검증.
##
## 스펙 §4.2 는 상자에 **모양이 있다**고 명시한다 — 네모(정수) / 둥근(실수) /
## 작은(불리언). 이름만 있고 화면에는 하나의 모양뿐이었다.
##
## **설정이 갈리는 부품은 모두 밖에서 갈려 보인다.** 부품은 다섯 종뿐이고
## 나머지는 전부 설정으로 갈린다. 상자만 표시를 달고 감지기·갈림길·되풀이는
## 똑같이 생겼을 때에는, 감지기 스무 개가 놓인 판을 하나씩 겨냥해 봐야만
## 읽을 수 있었다. 눈으로 판을 읽는 것이 이 장르의 즐거움이다.
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


func test_the_endless_repeater_is_marked() -> void:
    # 끝없이 도는 것만 타 버린다. 그 대가가 예고되어야 한다.
    assert_int(PartMarks.mark_for(_repeater(RepeaterPart.MODE_FOREVER))).is_equal(
        PartMarks.MARK_ENDLESS)


func test_the_three_ways_of_repeating_are_told_apart() -> void:
    var seen: Array[int] = []
    for mode in RepeaterPart.MODE_COUNT_TOTAL:
        var mark := PartMarks.mark_for(_repeater(mode))
        assert_int(mark).is_greater_equal(0)
        assert_bool(seen.has(mark)).is_false()
        seen.append(mark)


func test_what_a_detector_watches_is_told_apart() -> void:
    # 사람을 보는 것과 밤을 보는 것이 똑같이 생기면 판을 읽을 수 없다.
    var seen: Array[int] = []
    for target in DetectorPart.TARGET_COUNT:
        var mark := PartMarks.mark_for(DetectorPart.create(AT, target))
        assert_int(mark).is_greater_equal(0)
        assert_bool(seen.has(mark)).is_false()
        seen.append(mark)


func test_what_a_branch_judges_shows_on_it() -> void:
    var marks: Array[int] = []
    for mode in BranchPart.MODE_COUNT:
        var part := BranchPart.create(AT)
        part.configure(PackedInt32Array([mode, 0]))
        var mark := PartMarks.mark_for(part)
        assert_int(mark).is_greater_equal(0)
        marks.append(mark)

    # 견주는 셋은 한 갈래로 묶여도 좋다. 참·둘 다·하나라도는 갈려야 한다.
    assert_int(marks[BranchPart.MODE_TRUTH]).is_not_equal(marks[BranchPart.MODE_AND])
    assert_int(marks[BranchPart.MODE_AND]).is_not_equal(marks[BranchPart.MODE_OR])
    assert_int(marks[BranchPart.MODE_TRUTH]).is_not_equal(
        marks[BranchPart.MODE_GREATER_EQUAL])


func test_parts_with_nothing_to_show_get_no_mark() -> void:
    # 동작기는 설정이 없다. 무엇을 여닫는지는 놓인 자리가 말한다.
    assert_int(PartMarks.mark_for(ActuatorPart.create(AT))).is_less(0)
    assert_int(PartMarks.mark_for(null)).is_less(0)


func test_a_mark_follows_the_setting_not_just_the_part() -> void:
    # 설정만 바꾸어도 다시 그려져야 한다. 자리는 그대로다.
    var circuit := Circuit.new()
    circuit.add_part(DetectorPart.create(AT, DetectorPart.TARGET_PLAYER))
    var view := _view(circuit)
    assert_int(view.mark_count(PartMarks.MARK_EYE_PLAYER)).is_equal(1)

    circuit.remove_part(AT)
    circuit.add_part(DetectorPart.create(AT, DetectorPart.TARGET_TIME))
    view.sync()
    assert_int(view.mark_count(PartMarks.MARK_EYE_PLAYER)).is_equal(0)
    assert_int(view.mark_count(PartMarks.MARK_EYE_TIME)).is_equal(1)


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


## --- 묶음 ---
##
## 묶음은 밖에서 보면 전부 같은 상자다. 부품 셋을 접은 것과 열둘을 접은 것이
## 같아 보이면 어느 것이 큰 장치인지 알 수 없다. 숫자가 아니라 높이로 보인다.

func test_a_bigger_bundle_is_marked_differently() -> void:
    var small := PartMarks.bundle_mark_for(1)
    var big := PartMarks.bundle_mark_for(PartMarks.BUNDLE_STEP)
    var huge := PartMarks.bundle_mark_for(PartMarks.BUNDLE_STEP * 2)

    assert_int(small).is_not_equal(big)
    assert_int(big).is_not_equal(huge)
    assert_int(small).is_not_equal(huge)


func test_bundles_of_a_like_size_look_alike() -> void:
    assert_int(PartMarks.bundle_mark_for(1)).is_equal(PartMarks.bundle_mark_for(2))


func test_an_empty_bundle_still_gets_a_mark() -> void:
    assert_int(PartMarks.bundle_mark_for(0)).is_greater_equal(0)


## --- 색으로 갈래를 가른다 ---
##
## 한 색으로 통일했더니 열두 픽셀짜리 알갱이 열여덟 종이 되었다. 형태만으로
## 갈리기에는 화면에서 너무 작다. 금지된 것은 글자와 기호이지 색이 아니다.

func test_the_families_have_their_own_colours() -> void:
    var eye := PartMarks.colour_for(PartMarks.MARK_EYE_PLAYER)
    var judge := PartMarks.colour_for(PartMarks.MARK_TRUTH)
    var turn := PartMarks.colour_for(PartMarks.MARK_ENDLESS)
    var bundle := PartMarks.colour_for(PartMarks.MARK_BUNDLE)
    var shape := PartMarks.colour_for(PartMarks.MARK_SQUARE)

    var seen: Array[Color] = []
    for colour in [eye, judge, turn, bundle, shape]:
        for other: Color in seen:
            assert_bool(colour.is_equal_approx(other)).is_false()
        seen.append(colour)


func test_one_family_keeps_one_colour() -> void:
    # 갈래 안에서는 형태가 가른다. 색까지 흩으면 무엇이 무엇인지 알 수 없다.
    var first := PartMarks.colour_for(PartMarks.MARK_EYE_PLAYER)
    for kind in [PartMarks.MARK_EYE_THREAT, PartMarks.MARK_EYE_TIME,
            PartMarks.MARK_EYE_CROP, PartMarks.MARK_EYE_ITEM]:
        assert_bool(PartMarks.colour_for(kind).is_equal_approx(first)).is_true()


func test_every_mark_is_dark_enough_to_read_on_a_pastel_part() -> void:
    # 표시는 파스텔 몸통 위에 얹힌다. 밝으면 몸통에 녹는다.
    for kind in PartMarks.MARK_COUNT:
        var colour := PartMarks.colour_for(kind)
        assert_float(colour.get_luminance()).is_less(0.5)


func test_marks_within_a_family_are_told_apart_by_shape() -> void:
    var view: PartMarks = auto_free(PartMarks.new())
    add_child(view)
    var seen: Array[String] = []
    for kind in [PartMarks.MARK_EYE_PLAYER, PartMarks.MARK_EYE_THREAT,
            PartMarks.MARK_EYE_TIME, PartMarks.MARK_EYE_CROP,
            PartMarks.MARK_EYE_ITEM]:
        var mesh := view.mesh_for(kind)
        var shape := "%s|%s" % [mesh.get_class(), mesh.get_aabb().size]
        assert_bool(seen.has(shape)).is_false()
        seen.append(shape)
