extends GdUnitTestSuite

## 낮밤 표시 검증.
##
## 낮밤은 이 게임의 리듬이자 시험 사이클이다(스펙 §3.2). 리듬은 예고될 때만
## 리듬이다. 언제 밤이 오는지 모르면 "낮에 만들고 밤에 시험받는다"는 구조가
## 사람에게 도달하지 않는다.


func _clock() -> DayClock:
    var clock: DayClock = auto_free(DayClock.new())
    add_child(clock)
    return clock


func test_the_day_number_starts_at_one() -> void:
    assert_str(DayClock.text_for(0)).contains("1일째")


func test_the_day_number_climbs_with_the_cycles() -> void:
    assert_str(DayClock.text_for(DayCycle.CYCLE_TICKS)).contains("2일째")
    assert_str(DayClock.text_for(DayCycle.CYCLE_TICKS * 4)).contains("5일째")


func test_day_and_night_are_told_apart() -> void:
    var noon := DayClock.text_for(DayCycle.DAY_TICKS / 2)
    var midnight := DayClock.text_for(DayCycle.DAY_TICKS + DayCycle.NIGHT_TICKS / 2)
    assert_str(noon).is_not_equal(midnight)
    assert_str(midnight).contains("밤")


func test_the_coming_night_is_announced() -> void:
    # 예고가 없으면 긴장도 없다. 갑자기 어두워지고 뭔가에 맞을 뿐이다.
    assert_bool(DayClock.is_dusk(DayCycle.DAY_TICKS / 2)).is_false()
    assert_bool(DayClock.is_dusk(DayCycle.DAY_TICKS - 10)).is_true()
    assert_str(DayClock.text_for(DayCycle.DAY_TICKS - 10)).is_not_equal(
        DayClock.text_for(DayCycle.DAY_TICKS / 2))


func test_the_warning_comes_before_the_night_not_during_it() -> void:
    assert_bool(DayClock.is_dusk(DayCycle.DAY_TICKS)).is_false()
    assert_bool(DayClock.is_dusk(DayCycle.DAY_TICKS + 10)).is_false()


func test_the_marker_walks_across_the_whole_cycle() -> void:
    var clock := _clock()
    clock.apply(0)
    var start := clock.marker_ratio()

    clock.apply(DayCycle.DAY_TICKS)
    var dusk := clock.marker_ratio()

    clock.apply(DayCycle.CYCLE_TICKS - 1)
    var end := clock.marker_ratio()

    assert_float(start).is_less(dusk)
    assert_float(dusk).is_less(end)
    assert_float(start).is_greater_equal(-0.001)
    assert_float(end).is_less_equal(1.001)


func test_the_screen_never_shows_programming_words() -> void:
    for tick in [0, DayCycle.DAY_TICKS - 10, DayCycle.DAY_TICKS + 10]:
        var line := DayClock.text_for(tick).to_lower()
        assert_str(line).not_contains("tick")
        assert_str(line).not_contains("틱")
