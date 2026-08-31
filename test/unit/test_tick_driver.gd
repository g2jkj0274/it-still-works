extends GdUnitTestSuite

## 실시간 경과 → 고정 틱 환산 검증.

const INTERVAL := Simulation.TICK_INTERVAL_USEC


func test_tick_rate_is_twenty_per_second() -> void:
    assert_int(Simulation.TICK_RATE).is_equal(20)
    assert_int(INTERVAL).is_equal(50_000)
    assert_int(Simulation.TICK_RATE * INTERVAL).is_equal(1_000_000)


func test_no_elapsed_time_yields_no_tick() -> void:
    assert_int(TickDriver.new().pump(0)).is_equal(0)


func test_one_interval_yields_one_tick() -> void:
    assert_int(TickDriver.new().pump(INTERVAL)).is_equal(1)


func test_partial_interval_accumulates() -> void:
    var driver := TickDriver.new()
    assert_int(driver.pump(INTERVAL - 1)).is_equal(0)
    assert_int(driver.pump(1)).is_equal(1)


func test_remainder_is_carried_forward() -> void:
    var driver := TickDriver.new()
    assert_int(driver.pump(INTERVAL + 10)).is_equal(1)
    assert_int(driver.remainder_usec()).is_equal(10)


func test_one_simulated_second_yields_twenty_ticks() -> void:
    var driver := TickDriver.new(INTERVAL, 100)
    assert_int(driver.pump(1_000_000)).is_equal(20)


func test_many_small_pumps_match_one_big_pump() -> void:
    # 프레임률이 달라져도 같은 실시간에는 같은 틱 수가 나와야 한다.
    var coarse := TickDriver.new(INTERVAL, 1000)
    var fine := TickDriver.new(INTERVAL, 1000)
    var coarse_ticks := coarse.pump(1_000_000)

    var fine_ticks := 0
    for i in 1000:
        fine_ticks += fine.pump(1_000)

    assert_int(fine_ticks).is_equal(coarse_ticks)


func test_backlog_is_clamped() -> void:
    var driver := TickDriver.new(INTERVAL, 5)
    assert_int(driver.pump(INTERVAL * 100)).is_equal(5)
    assert_int(driver.dropped_usec()).is_equal(INTERVAL * 95)


func test_negative_elapsed_is_ignored() -> void:
    var driver := TickDriver.new()
    assert_int(driver.pump(-INTERVAL * 3)).is_equal(0)
    assert_int(driver.remainder_usec()).is_equal(0)


func test_reset_clears_accumulator() -> void:
    var driver := TickDriver.new()
    driver.pump(INTERVAL - 1)
    driver.reset()
    assert_int(driver.remainder_usec()).is_equal(0)
    assert_int(driver.pump(1)).is_equal(0)
