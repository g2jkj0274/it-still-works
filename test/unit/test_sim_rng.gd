extends GdUnitTestSuite

## 시드 고정 RNG 의 재현성 검증.
## 결정론 시뮬레이션은 이 클래스의 재현성 위에 서 있다.


func test_same_seed_produces_same_sequence() -> void:
    var a := SimRng.new(1234)
    var b := SimRng.new(1234)
    for i in 32:
        assert_int(a.next_int()).is_equal(b.next_int())


func test_different_seed_diverges() -> void:
    var a := SimRng.new(1)
    var b := SimRng.new(2)
    var identical := 0
    for i in 32:
        if a.next_int() == b.next_int():
            identical += 1
    assert_int(identical).is_less(32)


func test_reset_restores_initial_sequence() -> void:
    var rng := SimRng.new(99)
    var first: Array[int] = []
    for i in 8:
        first.append(rng.next_int())
    rng.reset()
    for i in 8:
        assert_int(rng.next_int()).is_equal(first[i])


func test_state_snapshot_and_restore() -> void:
    var rng := SimRng.new(7)
    rng.next_int()
    var snapshot := rng.get_state()
    var expected := rng.next_int()
    rng.set_state(snapshot)
    assert_int(rng.next_int()).is_equal(expected)


func test_range_stays_within_bounds() -> void:
    var rng := SimRng.new(5)
    for i in 128:
        assert_int(rng.next_range(3, 9)).is_between(3, 9)


func test_seed_is_preserved_after_draws() -> void:
    var rng := SimRng.new(4242)
    rng.next_int()
    assert_int(rng.get_seed()).is_equal(4242)
