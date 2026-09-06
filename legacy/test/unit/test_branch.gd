extends GdUnitTestSuite

## 갈림길 검증.
##
## 조건을 판정해 신호를 한쪽으로만 보낸다. 참이면 A 출구, 거짓이면 B 출구.
## 조건이 거짓이면 A 쪽으로는 아무것도 나가지 않는다.

const AT := Vector3i(4, 4, 1)


func _state() -> WorldState:
    return WorldState.new(SimRng.new(1))


func _branch(mode: int, threshold: int = 0) -> BranchPart:
    var part := BranchPart.create(AT)
    part.configure(PackedInt32Array([mode, threshold]))
    return part


## 신호를 넣고 [A 출구, B 출구] 를 돌려준다.
func _run(part: BranchPart, incoming: Array) -> Array:
    part.compute(_state(), incoming)
    part.commit()
    return [part.output_at(BranchPart.PORT_TRUE), part.output_at(BranchPart.PORT_FALSE)]


func test_a_branch_has_two_ways_out() -> void:
    assert_int(_branch(BranchPart.MODE_TRUTH).output_count()).is_equal(2)
    assert_int(BranchPart.PORT_TRUE).is_equal(0)
    assert_int(BranchPart.PORT_FALSE).is_equal(1)


func test_modes_are_distinct_and_contiguous() -> void:
    var modes := [
        BranchPart.MODE_TRUTH, BranchPart.MODE_GREATER_EQUAL, BranchPart.MODE_LESS,
        BranchPart.MODE_EQUAL, BranchPart.MODE_AND, BranchPart.MODE_OR,
    ]
    assert_int(modes.size()).is_equal(BranchPart.MODE_COUNT)
    modes.sort()
    for i in modes.size():
        assert_int(modes[i]).is_equal(i)


func test_a_true_signal_leaves_by_the_true_way() -> void:
    var ways := _run(_branch(BranchPart.MODE_TRUTH), [SignalValue.of_bool(true)])
    assert_bool(ways[0].is_present()).is_true()
    assert_bool(ways[1].is_present()).is_false()


func test_a_false_signal_leaves_by_the_false_way() -> void:
    var ways := _run(_branch(BranchPart.MODE_TRUTH), [SignalValue.of_bool(false)])
    assert_bool(ways[0].is_present()).is_false()
    assert_bool(ways[1].is_present()).is_true()


func test_nothing_in_means_nothing_out_either_way() -> void:
    var ways := _run(_branch(BranchPart.MODE_TRUTH), [])
    assert_bool(ways[0].is_present()).is_false()
    assert_bool(ways[1].is_present()).is_false()


func test_the_value_passes_through_unchanged() -> void:
    # 갈림길은 값을 바꾸지 않는다. 어느 쪽으로 보낼지만 정한다.
    var ways := _run(_branch(BranchPart.MODE_TRUTH), [SignalValue.of_int(7)])
    assert_int(ways[0].as_int()).is_equal(7)


func test_comparing_against_a_number() -> void:
    var at_least_ten := _branch(BranchPart.MODE_GREATER_EQUAL, 10)
    assert_bool(_run(at_least_ten, [SignalValue.of_int(10)])[0].is_present()).is_true()
    assert_bool(_run(at_least_ten, [SignalValue.of_int(9)])[0].is_present()).is_false()
    assert_bool(_run(at_least_ten, [SignalValue.of_int(9)])[1].is_present()).is_true()


func test_less_than_is_the_other_way_round() -> void:
    var under_five := _branch(BranchPart.MODE_LESS, 5)
    assert_bool(_run(under_five, [SignalValue.of_int(4)])[0].is_present()).is_true()
    assert_bool(_run(under_five, [SignalValue.of_int(5)])[0].is_present()).is_false()


func test_equality_compares_the_whole_value() -> void:
    var exactly_three := _branch(BranchPart.MODE_EQUAL, 3)
    assert_bool(_run(exactly_three, [SignalValue.of_int(3)])[0].is_present()).is_true()
    assert_bool(_run(exactly_three, [SignalValue.of_real(3, 500)])[0].is_present()).is_false()


func test_reals_compare_without_being_shaved() -> void:
    var at_least_three := _branch(BranchPart.MODE_GREATER_EQUAL, 3)
    assert_bool(_run(at_least_three, [SignalValue.of_real(2, 900)])[0].is_present()).is_false()
    assert_bool(_run(at_least_three, [SignalValue.of_real(3, 100)])[0].is_present()).is_true()


func test_two_inputs_can_be_made_to_mean_and() -> void:
    # AND 는 따로 만든 부품이 아니다. 배선으로 발명한다.
    var both := _branch(BranchPart.MODE_AND)
    assert_bool(_run(both, [SignalValue.of_bool(true), SignalValue.of_bool(true)])[0].is_present()).is_true()
    assert_bool(_run(both, [SignalValue.of_bool(true), SignalValue.of_bool(false)])[0].is_present()).is_false()
    assert_bool(_run(both, [SignalValue.of_bool(false), SignalValue.of_bool(false)])[0].is_present()).is_false()


func test_two_inputs_can_be_made_to_mean_or() -> void:
    var either := _branch(BranchPart.MODE_OR)
    assert_bool(_run(either, [SignalValue.of_bool(true), SignalValue.of_bool(false)])[0].is_present()).is_true()
    assert_bool(_run(either, [SignalValue.of_bool(false), SignalValue.of_bool(false)])[0].is_present()).is_false()


func test_and_with_a_single_input_is_just_that_input() -> void:
    var both := _branch(BranchPart.MODE_AND)
    assert_bool(_run(both, [SignalValue.of_bool(true)])[0].is_present()).is_true()
    assert_bool(_run(both, [SignalValue.of_bool(false)])[0].is_present()).is_false()


func test_settings_survive_a_round_trip() -> void:
    var part := _branch(BranchPart.MODE_GREATER_EQUAL, 12)
    var copy := BranchPart.create(AT)
    copy.configure(part.parameters())
    assert_int(copy.mode).is_equal(BranchPart.MODE_GREATER_EQUAL)
    assert_int(copy.threshold).is_equal(12)


func test_the_plain_output_is_the_true_way() -> void:
    # 출구 번호를 따로 대지 않은 배선은 참 쪽에 붙는다.
    var part := _branch(BranchPart.MODE_TRUTH)
    _run(part, [SignalValue.of_bool(true)])
    assert_bool(part.output.is_present()).is_true()
