extends GdUnitTestSuite

## 생존 지표 검증.
##
## 포만도는 시간에 따라 준다. 0이 되면 체력이 서서히 준다. 체력이 0이면 죽는다.


func _full() -> Vitals:
    return Vitals.new()


func test_starts_full() -> void:
    var vitals := _full()
    assert_int(vitals.health).is_equal(Vitals.MAX_HEALTH)
    assert_int(vitals.fullness).is_equal(Vitals.MAX_FULLNESS)
    assert_bool(vitals.is_dead()).is_false()


func test_fullness_drops_with_time() -> void:
    var vitals := _full()
    for i in Vitals.FULLNESS_DECAY_TICKS:
        vitals.tick()
    assert_int(vitals.fullness).is_equal(Vitals.MAX_FULLNESS - 1)


func test_fullness_does_not_drop_before_its_time() -> void:
    var vitals := _full()
    for i in Vitals.FULLNESS_DECAY_TICKS - 1:
        vitals.tick()
    assert_int(vitals.fullness).is_equal(Vitals.MAX_FULLNESS)


func test_health_holds_while_there_is_food() -> void:
    var vitals := _full()
    for i in Vitals.FULLNESS_DECAY_TICKS * 2:
        vitals.tick()
    assert_int(vitals.health).is_equal(Vitals.MAX_HEALTH)


func test_an_empty_belly_wears_health_down() -> void:
    var vitals := _full()
    vitals.fullness = 0
    for i in Vitals.STARVE_TICKS:
        vitals.tick()
    assert_int(vitals.health).is_equal(Vitals.MAX_HEALTH - 1)


func test_starving_is_slow_not_sudden() -> void:
    var vitals := _full()
    vitals.fullness = 0
    for i in Vitals.STARVE_TICKS - 1:
        vitals.tick()
    assert_int(vitals.health).is_equal(Vitals.MAX_HEALTH)


func test_eating_fills_the_belly_but_never_past_full() -> void:
    var vitals := _full()
    vitals.fullness = 5
    vitals.feed(3)
    assert_int(vitals.fullness).is_equal(8)
    vitals.feed(100)
    assert_int(vitals.fullness).is_equal(Vitals.MAX_FULLNESS)


func test_damage_lowers_health() -> void:
    var vitals := _full()
    vitals.damage(3)
    assert_int(vitals.health).is_equal(Vitals.MAX_HEALTH - 3)


func test_health_never_falls_below_nothing() -> void:
    var vitals := _full()
    vitals.damage(1000)
    assert_int(vitals.health).is_equal(0)
    assert_bool(vitals.is_dead()).is_true()


func test_negative_amounts_are_ignored() -> void:
    var vitals := _full()
    vitals.damage(-5)
    vitals.feed(-5)
    assert_int(vitals.health).is_equal(Vitals.MAX_HEALTH)
    assert_int(vitals.fullness).is_equal(Vitals.MAX_FULLNESS)


func test_reviving_starts_over() -> void:
    var vitals := _full()
    vitals.damage(1000)
    vitals.fullness = 0
    vitals.revive()
    assert_int(vitals.health).is_equal(Vitals.MAX_HEALTH)
    assert_int(vitals.fullness).is_greater(0)
    assert_bool(vitals.is_dead()).is_false()


func test_a_dead_body_stops_starving() -> void:
    var vitals := _full()
    vitals.fullness = 0
    vitals.damage(Vitals.MAX_HEALTH)
    for i in Vitals.STARVE_TICKS * 3:
        vitals.tick()
    assert_int(vitals.health).is_equal(0)
