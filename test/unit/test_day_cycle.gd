extends GdUnitTestSuite

## 낮과 밤 검증.
##
## 틱만으로 정해진다. 따로 들고 있는 상태가 없으므로 어긋날 여지가 없다.


func test_a_cycle_is_ten_minutes() -> void:
    assert_int(DayCycle.CYCLE_TICKS).is_equal(10 * 60 * Simulation.TICK_RATE)


func test_day_is_seven_minutes_and_night_is_three() -> void:
    assert_int(DayCycle.DAY_TICKS).is_equal(7 * 60 * Simulation.TICK_RATE)
    assert_int(DayCycle.NIGHT_TICKS).is_equal(3 * 60 * Simulation.TICK_RATE)
    assert_int(DayCycle.DAY_TICKS + DayCycle.NIGHT_TICKS).is_equal(DayCycle.CYCLE_TICKS)


func test_the_world_starts_in_daylight() -> void:
    assert_bool(DayCycle.is_night(0)).is_false()


func test_night_comes_after_the_day() -> void:
    assert_bool(DayCycle.is_night(DayCycle.DAY_TICKS - 1)).is_false()
    assert_bool(DayCycle.is_night(DayCycle.DAY_TICKS)).is_true()
    assert_bool(DayCycle.is_night(DayCycle.CYCLE_TICKS - 1)).is_true()


func test_the_cycle_comes_round_again() -> void:
    assert_bool(DayCycle.is_night(DayCycle.CYCLE_TICKS)).is_false()
    assert_bool(DayCycle.is_night(DayCycle.CYCLE_TICKS + DayCycle.DAY_TICKS)).is_true()


func test_days_are_counted_from_the_first() -> void:
    assert_int(DayCycle.day_number(0)).is_equal(1)
    assert_int(DayCycle.day_number(DayCycle.CYCLE_TICKS - 1)).is_equal(1)
    assert_int(DayCycle.day_number(DayCycle.CYCLE_TICKS)).is_equal(2)


func test_phase_tick_stays_inside_one_cycle() -> void:
    for tick in [0, 1, DayCycle.DAY_TICKS, DayCycle.CYCLE_TICKS, DayCycle.CYCLE_TICKS * 3 + 7]:
        assert_int(DayCycle.phase_tick(tick)).is_between(0, DayCycle.CYCLE_TICKS - 1)


func test_nightfall_and_daybreak_are_found() -> void:
    assert_bool(DayCycle.is_nightfall(DayCycle.DAY_TICKS)).is_true()
    assert_bool(DayCycle.is_nightfall(DayCycle.DAY_TICKS + 1)).is_false()
    assert_bool(DayCycle.is_daybreak(DayCycle.CYCLE_TICKS)).is_true()
    assert_bool(DayCycle.is_daybreak(0)).is_false()
