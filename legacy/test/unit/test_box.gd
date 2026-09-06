extends GdUnitTestSuite

## 상자 검증.
##
## 값 하나를 담는다. 신호로 넣고 신호로 꺼낸다.
## 모양이 있고, 안 맞는 값은 들어가되 깎인다. 깎인 값은 되돌려도 복구되지 않는다.

const AT := Vector3i(4, 4, 1)


func _state() -> WorldState:
    return WorldState.new(SimRng.new(1))


func _box(shape: int) -> BoxPart:
    var part := BoxPart.create(AT)
    part.configure(PackedInt32Array([shape]))
    return part


## 신호 하나를 넣고 담긴 값을 돌려준다.
func _store(shape: int, value: SignalValue) -> SignalValue:
    var part := _box(shape)
    part.compute(_state(), [value])
    part.commit()
    return part.output


func test_shapes_are_distinct_and_contiguous() -> void:
    var shapes := [BoxPart.SHAPE_SQUARE, BoxPart.SHAPE_ROUND, BoxPart.SHAPE_SMALL]
    assert_int(shapes.size()).is_equal(BoxPart.SHAPE_COUNT)
    shapes.sort()
    for i in shapes.size():
        assert_int(shapes[i]).is_equal(i)


func test_an_empty_box_holds_nothing() -> void:
    assert_bool(_box(BoxPart.SHAPE_SQUARE).output.is_present()).is_false()


func test_a_matching_value_is_kept_whole() -> void:
    assert_int(_store(BoxPart.SHAPE_SQUARE, SignalValue.of_int(7)).as_int()).is_equal(7)
    assert_int(_store(BoxPart.SHAPE_ROUND, SignalValue.of_real(3, 700)).raw).is_equal(3700)
    assert_bool(_store(BoxPart.SHAPE_SMALL, SignalValue.of_bool(true)).as_bool()).is_true()


func test_the_box_keeps_its_own_shape() -> void:
    assert_int(_store(BoxPart.SHAPE_SQUARE, SignalValue.of_real(3, 700)).kind).is_equal(SignalValue.KIND_INT)
    assert_int(_store(BoxPart.SHAPE_ROUND, SignalValue.of_int(3)).kind).is_equal(SignalValue.KIND_REAL)
    assert_int(_store(BoxPart.SHAPE_SMALL, SignalValue.of_int(3)).kind).is_equal(SignalValue.KIND_BOOL)


func test_a_real_put_in_a_square_box_is_shaved() -> void:
    assert_int(_store(BoxPart.SHAPE_SQUARE, SignalValue.of_real(3, 700)).as_int()).is_equal(3)


func test_the_shaving_is_never_undone() -> void:
    var shaved := _store(BoxPart.SHAPE_SQUARE, SignalValue.of_real(3, 700))
    var back := _store(BoxPart.SHAPE_ROUND, shaved)
    assert_int(back.raw).is_equal(3000)
    assert_int(back.raw).is_not_equal(3700)


func test_a_number_put_in_a_small_box_loses_its_size() -> void:
    assert_bool(_store(BoxPart.SHAPE_SMALL, SignalValue.of_int(5)).as_bool()).is_true()
    assert_int(_store(BoxPart.SHAPE_SMALL, SignalValue.of_int(5)).as_int()).is_equal(1)
    assert_bool(_store(BoxPart.SHAPE_SMALL, SignalValue.of_int(0)).as_bool()).is_false()


func test_a_whole_number_fits_a_round_box_without_loss() -> void:
    assert_int(_store(BoxPart.SHAPE_ROUND, SignalValue.of_int(5)).as_int()).is_equal(5)
    assert_int(_store(BoxPart.SHAPE_ROUND, SignalValue.of_int(5)).raw).is_equal(5000)


func test_a_new_value_replaces_the_old_one() -> void:
    var part := _box(BoxPart.SHAPE_SQUARE)
    var state := _state()
    part.compute(state, [SignalValue.of_int(1)])
    part.commit()
    part.compute(state, [SignalValue.of_int(9)])
    part.commit()
    assert_int(part.output.as_int()).is_equal(9)


func test_no_signal_leaves_the_box_alone() -> void:
    var part := _box(BoxPart.SHAPE_SQUARE)
    var state := _state()
    part.compute(state, [SignalValue.of_int(4)])
    part.commit()
    part.compute(state, [])
    part.commit()
    assert_int(part.output.as_int()).is_equal(4)


func test_an_absent_signal_does_not_erase_the_box() -> void:
    var part := _box(BoxPart.SHAPE_SQUARE)
    var state := _state()
    part.compute(state, [SignalValue.of_int(4)])
    part.commit()
    part.compute(state, [SignalValue.none()])
    part.commit()
    assert_int(part.output.as_int()).is_equal(4)


func test_a_false_value_is_still_a_value() -> void:
    var part := _box(BoxPart.SHAPE_SMALL)
    var state := _state()
    part.compute(state, [SignalValue.of_bool(true)])
    part.commit()
    part.compute(state, [SignalValue.of_bool(false)])
    part.commit()
    assert_bool(part.output.is_present()).is_true()
    assert_bool(part.output.as_bool()).is_false()


func test_the_first_wire_wins_when_several_arrive() -> void:
    var part := _box(BoxPart.SHAPE_SQUARE)
    part.compute(_state(), [SignalValue.of_int(1), SignalValue.of_int(2)])
    part.commit()
    assert_int(part.output.as_int()).is_equal(1)


func test_settings_survive_a_round_trip() -> void:
    var part := _box(BoxPart.SHAPE_ROUND)
    var copy := BoxPart.create(AT)
    copy.configure(part.parameters())
    assert_int(copy.shape).is_equal(BoxPart.SHAPE_ROUND)


func test_negative_reals_shave_towards_zero() -> void:
    assert_int(_store(BoxPart.SHAPE_SQUARE, SignalValue.of_real(-3, 700)).as_int()).is_equal(-3)
