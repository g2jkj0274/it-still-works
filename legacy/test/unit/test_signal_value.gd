extends GdUnitTestSuite

## 신호 값 검증.
##
## 신호는 값을 가진다. 켜짐/꺼짐이 아니다.
## 실수는 1000배 고정소수점으로 담는다. 시뮬레이션에 부동소수점을 들이지 않는다.


func test_no_signal_is_the_default() -> void:
    var value := SignalValue.none()
    assert_int(value.kind).is_equal(SignalValue.KIND_NONE)
    assert_bool(value.is_present()).is_false()


func test_boolean_signal_carries_truth() -> void:
    assert_bool(SignalValue.of_bool(true).as_bool()).is_true()
    assert_bool(SignalValue.of_bool(false).as_bool()).is_false()
    assert_bool(SignalValue.of_bool(false).is_present()).is_true()


func test_integer_signal_carries_a_number() -> void:
    var value := SignalValue.of_int(7)
    assert_int(value.kind).is_equal(SignalValue.KIND_INT)
    assert_int(value.as_int()).is_equal(7)


func test_real_signal_is_scaled_by_a_thousand() -> void:
    assert_int(SignalValue.REAL_SCALE).is_equal(1000)
    var value := SignalValue.of_real(3, 700)
    assert_int(value.raw).is_equal(3700)


func test_real_to_integer_loses_the_fraction() -> void:
    # 3.7 이 정수가 되면 3 이다. 되돌려도 3.7 은 돌아오지 않는다.
    var value := SignalValue.of_real(3, 700)
    assert_int(value.as_int()).is_equal(3)
    assert_int(SignalValue.of_int(value.as_int()).raw).is_equal(3)


func test_negative_real_truncates_towards_zero() -> void:
    var value := SignalValue.of_real(-3, 700)
    assert_int(value.raw).is_equal(-3700)
    assert_int(value.as_int()).is_equal(-3)


func test_integer_reads_as_true_when_not_zero() -> void:
    assert_bool(SignalValue.of_int(0).as_bool()).is_false()
    assert_bool(SignalValue.of_int(5).as_bool()).is_true()
    assert_bool(SignalValue.of_int(-1).as_bool()).is_true()


func test_absent_signal_reads_as_false_and_zero() -> void:
    assert_bool(SignalValue.none().as_bool()).is_false()
    assert_int(SignalValue.none().as_int()).is_equal(0)


func test_boolean_reads_as_one_or_zero() -> void:
    assert_int(SignalValue.of_bool(true).as_int()).is_equal(1)
    assert_int(SignalValue.of_bool(false).as_int()).is_equal(0)


func test_equal_signals_match() -> void:
    assert_bool(SignalValue.of_int(3).equals(SignalValue.of_int(3))).is_true()
    assert_bool(SignalValue.of_int(3).equals(SignalValue.of_int(4))).is_false()
    assert_bool(SignalValue.of_int(1).equals(SignalValue.of_bool(true))).is_false()
    assert_bool(SignalValue.none().equals(SignalValue.none())).is_true()


func test_signal_is_hashable_as_text() -> void:
    assert_str(SignalValue.of_int(3).to_key()).is_equal(SignalValue.of_int(3).to_key())
    assert_str(SignalValue.of_int(3).to_key()).is_not_equal(SignalValue.of_int(4).to_key())
    assert_str(SignalValue.of_bool(true).to_key()).is_not_equal(SignalValue.of_int(1).to_key())


func test_every_kind_has_a_name() -> void:
    for kind in [SignalValue.KIND_NONE, SignalValue.KIND_BOOL, SignalValue.KIND_INT, SignalValue.KIND_REAL]:
        assert_str(SignalValue.name_of(kind)).is_not_empty()
