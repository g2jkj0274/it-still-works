extends GdUnitTestSuite

## 되풀이 검증.
##
## 받은 신호를 정한 간격으로 되풀이해 내보낸다.
## 횟수를 정하면 그만큼만, 조건을 정하면 조건이 참인 동안, 아무것도 정하지
## 않으면 끝없이. 끝없는 되풀이는 정상 동작이지만 장치가 과열되어 정지한다.

const AT := Vector3i(4, 4, 1)


func _state() -> WorldState:
    return WorldState.new(SimRng.new(1))


func _repeater(mode: int, limit: int = 3, interval: int = 2) -> RepeaterPart:
    var part := RepeaterPart.create(AT)
    part.configure(PackedInt32Array([mode, limit, interval]))
    return part


## 신호를 계속 넣으면서 몇 번 나오는지 센다.
func _pulses(part: RepeaterPart, ticks: int, signal_on: bool = true) -> int:
    var state := _state()
    # 신호가 없다는 것은 거짓이 아니라 아무것도 닿지 않는 것이다.
    var incoming: Array = [SignalValue.of_bool(true)] if signal_on else []
    var count := 0
    for i in ticks:
        part.compute(state, incoming)
        part.commit()
        if part.output.is_present() and part.output.as_bool():
            count += 1
    return count


func test_modes_are_distinct_and_contiguous() -> void:
    var modes := [RepeaterPart.MODE_COUNT, RepeaterPart.MODE_WHILE, RepeaterPart.MODE_FOREVER]
    assert_int(modes.size()).is_equal(RepeaterPart.MODE_COUNT_TOTAL)
    modes.sort()
    for i in modes.size():
        assert_int(modes[i]).is_equal(i)


func test_a_repeater_with_no_input_stays_quiet() -> void:
    assert_int(_pulses(_repeater(RepeaterPart.MODE_FOREVER), 20, false)).is_equal(0)


func test_counted_repeats_stop_after_the_given_number() -> void:
    assert_int(_pulses(_repeater(RepeaterPart.MODE_COUNT, 3, 2), 40)).is_equal(3)


func test_a_different_count_gives_a_different_number_of_pulses() -> void:
    assert_int(_pulses(_repeater(RepeaterPart.MODE_COUNT, 5, 2), 40)).is_equal(5)


func test_the_interval_spaces_the_pulses_out() -> void:
    var tight := _pulses(_repeater(RepeaterPart.MODE_FOREVER, 0, 1), 12)
    var loose := _pulses(_repeater(RepeaterPart.MODE_FOREVER, 0, 4), 12)
    assert_int(tight).is_greater(loose)


func test_conditional_repeats_run_while_the_condition_holds() -> void:
    var part := _repeater(RepeaterPart.MODE_WHILE, 0, 2)
    var state := _state()
    var on: Array = [SignalValue.of_bool(true)]
    var off: Array = []

    var during := 0
    for i in 10:
        part.compute(state, on)
        part.commit()
        if part.output.as_bool():
            during += 1
    assert_int(during).is_greater(0)

    var after := 0
    for i in 20:
        part.compute(state, off)
        part.commit()
        if part.output.as_bool():
            after += 1
    assert_int(after).is_equal(0)


func test_endless_repeats_overheat_and_stop() -> void:
    # 끝없는 되풀이는 잘못이 아니다. 다만 대가가 있다.
    var part := _repeater(RepeaterPart.MODE_FOREVER, 0, 1)
    var pulses := _pulses(part, 1000)
    assert_bool(part.is_burnt()).is_true()
    assert_int(pulses).is_equal(RepeaterPart.OVERHEAT_LIMIT)


func test_a_burnt_repeater_never_wakes_up() -> void:
    var part := _repeater(RepeaterPart.MODE_FOREVER, 0, 1)
    _pulses(part, 1000)
    assert_int(_pulses(part, 100)).is_equal(0)


func test_a_burnt_repeater_gives_nothing_back() -> void:
    # 소모된 자원은 돌아오지 않는다.
    var part := _repeater(RepeaterPart.MODE_FOREVER, 0, 1)
    assert_bool(part.yields_material()).is_true()
    _pulses(part, 1000)
    assert_bool(part.yields_material()).is_false()


func test_a_bounded_loop_never_burns() -> void:
    # 정해진 만큼만 도는 되풀이는 식을 틈이 있어 타지 않는다.
    var part := _repeater(RepeaterPart.MODE_COUNT, 4, 2)
    var state := _state()
    var on: Array = [SignalValue.of_bool(true)]
    var off: Array = []
    for round_index in 30:
        for i in 20:
            part.compute(state, on)
            part.commit()
        for i in 40:
            part.compute(state, off)
            part.commit()
    assert_bool(part.is_burnt()).is_false()


func test_the_repeated_signal_keeps_its_value() -> void:
    # 켜짐/꺼짐이 아니라 값을 되풀이한다.
    var part := _repeater(RepeaterPart.MODE_FOREVER, 0, 1)
    var state := _state()
    var incoming: Array = [SignalValue.of_int(7)]
    var seen := 0
    for i in 6:
        part.compute(state, incoming)
        part.commit()
        if part.output.is_present():
            assert_int(part.output.as_int()).is_equal(7)
            seen += 1
    assert_int(seen).is_greater(0)


func test_settings_survive_a_round_trip() -> void:
    var part := _repeater(RepeaterPart.MODE_WHILE, 5, 3)
    var copy := RepeaterPart.create(AT)
    copy.configure(part.parameters())
    assert_int(copy.mode).is_equal(RepeaterPart.MODE_WHILE)
    assert_int(copy.limit).is_equal(5)
    assert_int(copy.interval).is_equal(3)


func test_the_interval_never_drops_below_one_tick() -> void:
    var part := RepeaterPart.create(AT)
    part.configure(PackedInt32Array([RepeaterPart.MODE_FOREVER, 0, 0]))
    assert_int(part.interval).is_greater_equal(RepeaterPart.MIN_INTERVAL)
