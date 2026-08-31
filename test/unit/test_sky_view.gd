extends GdUnitTestSuite

## 낮과 밤의 밝기 검증.


func test_broad_daylight_is_not_dark() -> void:
    assert_float(SkyView.darkness_at(0)).is_equal_approx(0.0, 0.001)
    assert_float(SkyView.darkness_at(DayCycle.DAY_TICKS / 2)).is_equal_approx(0.0, 0.001)


func test_the_dead_of_night_is_fully_dark() -> void:
    assert_float(SkyView.darkness_at(DayCycle.DAY_TICKS + DayCycle.NIGHT_TICKS / 2)).is_equal_approx(1.0, 0.001)


func test_dusk_darkens_gradually() -> void:
    var half_way := DayCycle.DAY_TICKS - SkyView.TWILIGHT_TICKS / 2
    var dusk := SkyView.darkness_at(half_way)
    assert_float(dusk).is_greater(0.0)
    assert_float(dusk).is_less(1.0)


func test_dawn_brightens_gradually() -> void:
    var half_way := DayCycle.CYCLE_TICKS - SkyView.TWILIGHT_TICKS / 2
    var dawn := SkyView.darkness_at(half_way)
    assert_float(dawn).is_greater(0.0)
    assert_float(dawn).is_less(1.0)


func test_darkness_stays_within_bounds_all_cycle() -> void:
    for i in 200:
        var tick := i * (DayCycle.CYCLE_TICKS / 200)
        assert_float(SkyView.darkness_at(tick)).is_between(0.0, 1.0)


func test_the_next_cycle_looks_the_same() -> void:
    for tick in [0, 100, DayCycle.DAY_TICKS, DayCycle.CYCLE_TICKS - 10]:
        assert_float(SkyView.darkness_at(tick)).is_equal_approx(
            SkyView.darkness_at(tick + DayCycle.CYCLE_TICKS), 0.001)
