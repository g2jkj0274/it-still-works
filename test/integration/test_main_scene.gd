extends GdUnitTestSuite

## 메인 씬 통합 검증.
##
## M0 빈 씬: 루트 노드 하나가 시뮬레이션을 소유하고 고정 틱으로 굴린다.
## 그리는 것은 아직 없다.

const MAIN_SCENE := "res://view/main.tscn"


## 자동 진행을 끄고 테스트가 틱을 직접 돌린다.
func _main() -> GameMain:
    var main: GameMain = auto_free((load(MAIN_SCENE) as PackedScene).instantiate())
    add_child(main)
    main.set_physics_process(false)
    return main


func test_main_scene_is_the_project_entry_point() -> void:
    assert_str(str(ProjectSettings.get_setting("application/run/main_scene"))).is_equal(MAIN_SCENE)


func test_main_scene_loads_and_owns_a_simulation() -> void:
    var main := _main()
    assert_object(main.simulation).is_not_null()
    assert_object(main.driver).is_not_null()
    assert_int(main.simulation.current_tick()).is_equal(0)


func test_simulation_is_never_advanced_from_process() -> void:
    # 고정 틱 루프에서만 진행한다. _process 에서 갱신하지 않는다.
    var main := _main()
    assert_bool(main.has_method("_process")).is_false()
    assert_bool(main.has_method("_physics_process")).is_true()


func test_physics_step_pumps_the_driver_with_integer_microseconds() -> void:
    # 한 틱 분량이 흘렀다고 치고 손으로 한 번 부른다. 실수 delta 는 쓰이지 않는다.
    var main := _main()
    main._last_usec = Time.get_ticks_usec() - Simulation.TICK_INTERVAL_USEC * 2
    main._physics_process(0.0)
    assert_int(main.simulation.current_tick()).is_greater_equal(2)
    assert_int(main.simulation.current_tick()).is_less_equal(TickDriver.DEFAULT_MAX_TICKS_PER_PUMP)
