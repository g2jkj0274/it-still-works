extends GdUnitTestSuite

## 첫 동사 안내 검증.
##
## 튜토리얼이 아니다. 막지 않고, 시키지 않고, 순서를 강요하지 않는다.
## 무엇을 눌러야 아무 일이라도 일어나는지만 알려준다.


func _rig(sim: Simulation) -> Array:
    var notice: Notice = auto_free(Notice.new())
    add_child(notice)
    var steps: FirstSteps = auto_free(FirstSteps.new())
    add_child(steps)
    steps.bind(sim, notice)
    return [steps, notice]


func test_the_very_first_line_teaches_walking_and_the_mouse() -> void:
    # **마우스를 살려 놓고 게임은 키를 가리키고 있었다.** 안 알려준 기능은
    # 없는 기능이다. 그리고 걷는 법이 부수는 법보다 먼저 나와야 한다.
    var line := FirstSteps.line_at(0)
    assert_str(line).contains("WASD")
    assert_str(line).contains("좌클릭")
    assert_str(line).contains("우클릭")
    assert_str(line).contains("H")
    assert_int(line.find("WASD")).is_less(line.find("좌클릭"))


func test_it_says_at_most_three_things() -> void:
    # 더 늘어나면 튜토리얼이 된다.
    assert_int(FirstSteps.line_count()).is_less_equal(3)


func test_no_line_says_why_something_did_not_work() -> void:
    # 스펙 §1: 원인을 알려주지 않는다. 여기서 말하는 것은 키 이름뿐이다.
    for i in FirstSteps.line_count():
        var line := FirstSteps.line_at(i)
        assert_str(line).not_contains("왜")
        assert_str(line).not_contains("없어서")
        assert_str(line).not_contains("모자")


func test_the_first_line_shows_straight_away() -> void:
    var rig := _rig(IslandBuilder.start(3))
    var steps: FirstSteps = rig[0]
    var notice: Notice = rig[1]

    steps.check()
    assert_str(notice.text()).is_equal(FirstSteps.line_at(0))
    assert_int(steps.step()).is_equal(1)


func test_lines_do_not_pile_on_top_of_each_other() -> void:
    var rig := _rig(IslandBuilder.start(3))
    var steps: FirstSteps = rig[0]

    steps.check()
    steps.check()
    steps.check()
    # 앞 줄이 아직 떠 있으므로 하나만 나갔다.
    assert_int(steps.step()).is_equal(1)


func test_the_next_line_waits_for_something_in_hand() -> void:
    var sim := IslandBuilder.start(3)
    var rig := _rig(sim)
    var steps: FirstSteps = rig[0]
    var notice: Notice = rig[1]

    steps.check()
    notice.visible = false
    steps.check()
    assert_int(steps.step()).is_equal(1)

    sim.state.inventory.add(BlockType.WOOD, 1)
    steps.check()
    assert_int(steps.step()).is_equal(2)


func test_the_last_line_waits_for_a_circuit_part() -> void:
    var sim := IslandBuilder.start(3)
    sim.state.inventory.add(BlockType.WOOD, 1)
    var rig := _rig(sim)
    var steps: FirstSteps = rig[0]
    var notice: Notice = rig[1]

    for i in 2:
        steps.check()
        notice.visible = false
    assert_bool(steps.is_ready(2)).is_false()

    sim.state.inventory.add(BlockType.DETECTOR, 1)
    assert_bool(steps.is_ready(2)).is_true()
    steps.check()
    assert_bool(steps.is_done()).is_true()


func test_it_stops_after_the_last_line() -> void:
    var sim := IslandBuilder.start(3)
    sim.state.inventory.add(BlockType.WOOD, 1)
    sim.state.inventory.add(BlockType.DETECTOR, 1)
    var rig := _rig(sim)
    var steps: FirstSteps = rig[0]
    var notice: Notice = rig[1]

    for i in 10:
        steps.check()
        notice.visible = false
    assert_int(steps.step()).is_equal(FirstSteps.line_count())
