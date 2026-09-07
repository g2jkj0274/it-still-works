extends GdUnitTestSuite

## 메인 씬 통합 검증.
##
## M0: 루트 노드 하나가 시뮬레이션을 소유하고 고정 틱으로 굴린다.
## M1-5b: 루트는 Node2D, 자식 WorldView·Camera2D.
## M1-6a-2: _ready 는 명령을 제출하지 않는다 — 첫 틱이 플레이어 발 칸 (8,8) 의 청크 (0,0) 을 로드한다.
## 층 전환은 view 상태다. handle_action 을 직접 불러 검증한다.
## M1-6b-2b: 카메라는 WorldView.focus_position(플레이어 발 위치)을 따르고, 틱이 돌면 활성 층이
## 플레이어 층을 따라간다(follow_player_layer).
## M1-6b-2c: 이동은 키 누름 유지 = 틱마다 눌린 방향 하나. 헤드리스에서 Input.action_press /
## action_release 가 Input.is_action_pressed 에 즉시 반영된다(flush 불필요, 확인됨) — 테스트는 그걸로
## 키를 누른다. 걷는 중엔 제출하지 않으므로 명령 로그는 4틱당 1개. 벽 쪽을 눌러도 제출은 된다(view 는
## 판정을 모른다). 틱은 driver 를 reset 한 뒤 정확히 n 틱치 시간을 넣어 돌린다(_run_ticks).
## 지형 의존(시드 20250901): 스폰 (8,8) 에서 화면 4방향 중 move_left (-1,1) 만 허용, 그 도착 칸 (7,9)
## 에서 move_down (1,1) 이 두 걸음 연속 허용. 지형 표가 바뀌면 사전 조건 단언이 먼저 알린다.
## view→sim 소스 가드는 test_world_view 가 res://view 전체를 순회한다 — 여기는 main 전용 가드만 남는다.

const MAIN_SCENE := "res://view/main.tscn"
const MAIN_SOURCE := "res://view/main.gd"


## 자동 진행을 끄고 테스트가 틱을 직접 돌린다.
func _main() -> GameMain:
    var main: GameMain = auto_free((load(MAIN_SCENE) as PackedScene).instantiate())
    add_child(main)
    main.set_physics_process(false)
    return main


## 한 틱 분량이 흘렀다고 치고 _physics_process 를 손으로 한 번 부른다. 진행한 틱 수를 돌려준다.
func _tick_once(main: GameMain) -> int:
    var before := main.simulation.current_tick()
    main._last_usec = Time.get_ticks_usec() - Simulation.TICK_INTERVAL_USEC
    main._physics_process(0.0)
    return main.simulation.current_tick() - before


## 정확히 n 틱을 한 번의 _physics_process 로 돌린다. 이월 잔여를 지우고 n 틱치 시간을 넣는다.
## n 이 driver 상한(기본 5)을 넘으면 테스트가 driver 를 바꿔 둔다.
func _run_ticks(main: GameMain, n: int) -> void:
    var before := main.simulation.current_tick()
    main.driver.reset()
    main._last_usec = Time.get_ticks_usec() - Simulation.TICK_INTERVAL_USEC * n
    main._physics_process(0.0)
    assert_int(main.simulation.current_tick() - before).override_failure_message(
        "%d 틱을 요청했는데 다르게 돌았다" % n).is_equal(n)


func _press(action: StringName) -> void:
    Input.action_press(action)


func _release_all() -> void:
    for action: StringName in GameMain.MOVE_ACTIONS:
        Input.action_release(action)


## 눌린 키는 테스트 사이로 새지 않는다.
func after_test() -> void:
    _release_all()


## 발 칸 feet 에서 dir 로 한 걸음이 허용되는가. sim 이 쓰는 같은 판정(resolve_walk)으로 — 읽기만.
func _can_walk(sim: Simulation, feet: Vector2i, dir: Vector2i) -> bool:
    return MovementRules.resolve_walk(sim.state.chunks, sim.registry, feet, sim.state.player.layer, dir) != feet


## 화면 4방향 중 지금 발 칸에서 거부되는 첫 이동 액션.
func _blocked_move_action(sim: Simulation) -> StringName:
    var feet := sim.state.player.cell()
    for action: StringName in GameMain.MOVE_ACTIONS:
        if not _can_walk(sim, feet, GameMain.MOVE_DIRECTIONS[action]):
            return action
    assert_bool(false).override_failure_message("발 칸 %s 에서 거부되는 화면 방향이 없다" % feet).is_true()
    return &""


func _last_log_entry(main: GameMain) -> Dictionary:
    var log := main.simulation.command_log()
    assert_int(log.size()).is_greater(0)
    return log[log.size() - 1]


## 플레이어 발 칸에서 실제로 걸을 수 있는 첫 방향. sim 이 쓰는 같은 판정(resolve_walk)으로 고른다 — 읽기만.
func _walkable_dir(sim: Simulation) -> Vector2i:
    var feet := sim.state.player.cell()
    for dir: Vector2i in MovementRules.DIRECTIONS:
        if MovementRules.resolve_walk(sim.state.chunks, sim.registry, feet, sim.state.player.layer, dir) != feet:
            return dir
    assert_bool(false).override_failure_message("발 칸 %s 에서 걸을 방향이 없다" % feet).is_true()
    return Vector2i.ZERO


# --- M0 골격 ---

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


# --- M1-5b 씬 구조 ---

func test_root_is_node2d_with_world_view_and_camera() -> void:
    var main := _main()
    assert_bool(main is Node2D).is_true()
    var as_variant: Variant = main
    assert_bool(as_variant is Node3D).is_false()
    assert_bool(ClassDB.is_parent_class(main.get_class(), "Node2D")).is_true()
    var world_view := main.get_node("WorldView")
    assert_object(world_view).is_not_null()
    assert_bool(world_view is WorldView).is_true()
    assert_object(main.world_view).is_same(world_view)
    assert_object((world_view as WorldView).simulation).is_same(main.simulation)
    var camera := main.get_node("Camera2D")
    assert_object(camera).is_not_null()
    assert_bool(camera is Camera2D).is_true()
    assert_object(main.camera).is_same(camera)
    assert_bool((camera as Camera2D).enabled).is_true()


# --- 첫 틱 ---

func test_ready_submits_nothing_and_loads_nothing_yet() -> void:
    var main := _main()
    assert_int(main.simulation.command_count()).is_equal(0)
    assert_int(main.simulation.state.chunks.loaded_count()).is_equal(0)
    assert_bool(main.simulation.state.chunks.has_center()).is_false()
    assert_bool(main.simulation.state.player.cell() == Vector2i(8, 8)).is_true()


func test_first_tick_loads_25_chunks_around_player_chunk() -> void:
    var main := _main()
    assert_int(_tick_once(main)).is_greater_equal(1)
    var chunks := main.simulation.state.chunks
    assert_int(chunks.loaded_count()).is_equal(25)
    assert_bool(chunks.has_center()).is_true()
    assert_bool(chunks.center() == Vector2i(0, 0)).is_true()
    assert_int(main.simulation.command_count()).is_equal(0)


# --- 층 전환 (view 상태) ---

func test_layer_actions_move_and_clamp_active_layer() -> void:
    var main := _main()
    assert_int(main.world_view.active_layer).is_equal(Chunk.LAYER_GROUND)
    main.handle_action(&"layer_up")
    assert_int(main.world_view.active_layer).is_equal(2)
    main.handle_action(&"layer_up")
    assert_int(main.world_view.active_layer).is_equal(2)
    main.handle_action(&"layer_down")
    main.handle_action(&"layer_down")
    main.handle_action(&"layer_down")
    assert_int(main.world_view.active_layer).is_equal(0)
    main.handle_action(&"layer_down")
    assert_int(main.world_view.active_layer).is_equal(0)
    # 층 전환은 명령을 만들지 않고 상태 해시도 바꾸지 않는다.
    assert_int(main.simulation.command_count()).is_equal(0)


func test_layer_actions_do_not_touch_sim_state() -> void:
    var main := _main()
    _tick_once(main)
    var before := main.simulation.state_hash()
    var count := main.simulation.command_count()
    main.handle_action(&"layer_up")
    main.handle_action(&"layer_down")
    main.handle_action(&"layer_down")
    assert_str(main.simulation.state_hash()).is_equal(before)
    assert_int(main.simulation.command_count()).is_equal(count)


# --- 이동 = 눌린 방향을 틱마다 명령으로 ---

## 키 → 방향, 화면 기준(iso_projection: +x 우하, +y 좌하).
const EXPECTED_DIRECTIONS := {
    &"move_up": Vector2i(-1, -1),
    &"move_down": Vector2i(1, 1),
    &"move_left": Vector2i(-1, 1),
    &"move_right": Vector2i(1, -1),
}


func test_move_actions_and_directions_are_the_four_screen_diagonals() -> void:
    assert_array(GameMain.ACTIONS).contains_exactly([&"layer_up", &"layer_down"])
    assert_array(GameMain.MOVE_ACTIONS).contains_exactly([&"move_up", &"move_down", &"move_left", &"move_right"])
    assert_int(GameMain.MOVE_DIRECTIONS.size()).is_equal(4)
    for action: StringName in GameMain.MOVE_ACTIONS:
        assert_bool(GameMain.MOVE_DIRECTIONS.has(action)).override_failure_message(str(action)).is_true()
        var dir: Vector2i = GameMain.MOVE_DIRECTIONS[action]
        assert_bool(dir == EXPECTED_DIRECTIONS[action]).override_failure_message(str(action)).is_true()
        assert_bool(MovementRules.is_direction(dir)).override_failure_message(str(action)).is_true()
        assert_bool(dir.x != 0 and dir.y != 0).override_failure_message("%s 는 대각선이어야 한다" % action).is_true()


func test_unhandled_input_ignores_move_keys_but_still_switches_layers() -> void:
    var main := _main()
    _run_ticks(main, 1)
    for action: StringName in GameMain.MOVE_ACTIONS:
        var event := InputEventAction.new()
        event.action = action
        event.pressed = true
        main._unhandled_input(event)
    assert_int(main.simulation.command_count()).is_equal(0)
    var layer_event := InputEventAction.new()
    layer_event.action = &"layer_up"
    layer_event.pressed = true
    main._unhandled_input(layer_event)
    assert_int(main.world_view.active_layer).is_equal(Chunk.LAYER_UPPER)
    assert_int(main.simulation.command_count()).is_equal(0)


func test_held_direction_is_zero_without_keys_and_physics_steps_submit_nothing() -> void:
    var main := _main()
    assert_bool(main.held_direction() == Vector2i.ZERO).is_true()
    _run_ticks(main, 1)
    _run_ticks(main, 5)
    assert_int(main.simulation.command_count()).is_equal(0)
    assert_int(main.simulation.current_tick()).is_equal(6)


func test_each_held_direction_submits_its_command_on_the_tick() -> void:
    var main := _main()
    _run_ticks(main, 1)
    for action: StringName in EXPECTED_DIRECTIONS:
        var count := main.simulation.command_count()
        _press(action)
        var tick_before := main.simulation.current_tick()
        _run_ticks(main, 1)
        _release_all()
        assert_int(main.simulation.command_count()).override_failure_message(str(action)).is_equal(count + 1)
        var entry := _last_log_entry(main)
        var expected: Vector2i = EXPECTED_DIRECTIONS[action]
        assert_str(str(entry["type"])).is_equal(String(MovePlayerCommand.TYPE))
        assert_int(int(entry["dx"])).override_failure_message("%s dx" % action).is_equal(expected.x)
        assert_int(int(entry["dy"])).override_failure_message("%s dy" % action).is_equal(expected.y)
        assert_bool(int(entry["dx"]) != 0 or int(entry["dy"]) != 0).is_true()
        assert_int(int(entry["tick"])).is_equal(tick_before)
        assert_bool(main.simulation.state.player.facing == expected).is_true()
        # 걷기가 허용됐으면 도착할 때까지 돌린다(키는 뗐으니 명령은 더 없다).
        var guard := 0
        while main.simulation.state.player.is_moving() and guard < 4:
            _run_ticks(main, 1)
            guard += 1
        assert_bool(main.simulation.state.player.is_moving()).is_false()
        assert_int(main.simulation.command_count()).is_equal(count + 1)


func test_submit_held_move_does_not_touch_state_until_tick() -> void:
    var main := _main()
    _run_ticks(main, 1)
    var before := main.simulation.state_hash()
    _press(&"move_right")
    main._submit_held_move()
    assert_int(main.simulation.command_count()).is_equal(1)
    # 제출만으로는 상태가 바뀌지 않는다.
    assert_str(main.simulation.state_hash()).is_equal(before)
    assert_bool(main.simulation.state.player.facing == Vector2i(0, 1)).is_true()
    _release_all()
    # 틱이 돌면 명령이 적용된다. 걷기 성공 여부는 지형에 달렸지만 facing 은 반드시 돈다.
    _run_ticks(main, 1)
    assert_bool(main.simulation.state.player.facing == Vector2i(1, -1)).is_true()
    assert_int(main.simulation.state.chunks.loaded_count()).is_equal(25)


func test_held_key_logs_one_command_per_walk_not_per_tick() -> void:
    # 스폰에서 move_left 한 걸음이 허용된다(사전 조건). 틱 1: 명령·출발. 틱 2~4: 걷는 중이라 제출 없음.
    # 틱 5(도착 뒤): 다시 명령 하나.
    var main := _main()
    _run_ticks(main, 1)
    var dir: Vector2i = GameMain.MOVE_DIRECTIONS[&"move_left"]
    assert_bool(_can_walk(main.simulation, Vector2i(8, 8), dir)).override_failure_message(
        "사전 조건: 시드 20250901 스폰에서 move_left 가 허용돼야 한다").is_true()
    _press(&"move_left")
    var first_tick := main.simulation.current_tick()
    _run_ticks(main, 1)
    assert_int(main.simulation.command_count()).is_equal(1)
    assert_bool(main.simulation.state.player.is_moving()).is_true()
    var entry := _last_log_entry(main)
    assert_int(int(entry["dx"])).is_equal(dir.x)
    assert_int(int(entry["dy"])).is_equal(dir.y)
    assert_int(int(entry["tick"])).is_equal(first_tick)
    for _i in 3:
        _run_ticks(main, 1)
        assert_int(main.simulation.command_count()).is_equal(1)
    assert_bool(main.simulation.state.player.is_moving()).is_false()
    assert_bool(main.simulation.state.player.cell() == Vector2i(8, 8) + dir).is_true()
    _run_ticks(main, 1)
    assert_int(main.simulation.command_count()).is_equal(2)
    assert_int(int(_last_log_entry(main)["tick"])).is_equal(first_tick + 4)


func test_eight_ticks_in_one_physics_step_submit_at_n_and_n_plus_4() -> void:
    # 한 물리 스텝에 틱 8개가 몰려도 "제출 → step" 은 틱마다 돈다: 명령은 틱 N 과 N+4 에 하나씩.
    var main := _main()
    _run_ticks(main, 1)
    # (8,8) → move_left → (7,9). 거기서 move_down 이 두 걸음 연속 허용된다(사전 조건).
    _press(&"move_left")
    _run_ticks(main, 4)
    _release_all()
    var start := main.simulation.state.player.cell()
    assert_bool(start == Vector2i(7, 9)).override_failure_message("사전 조건: move_left 로 (7,9)").is_true()
    assert_bool(main.simulation.state.player.is_moving()).is_false()
    var down: Vector2i = GameMain.MOVE_DIRECTIONS[&"move_down"]
    assert_bool(_can_walk(main.simulation, start, down)).override_failure_message("사전 조건: (7,9) 에서 move_down").is_true()
    assert_bool(_can_walk(main.simulation, start + down, down)).override_failure_message("사전 조건: (8,10) 에서 move_down").is_true()
    var count := main.simulation.command_count()
    var n := main.simulation.current_tick()
    main.driver = TickDriver.new(Simulation.TICK_INTERVAL_USEC, 8)
    _press(&"move_down")
    _run_ticks(main, 8)
    assert_int(main.simulation.current_tick()).is_equal(n + 8)
    assert_int(main.simulation.command_count()).is_equal(count + 2)
    var log := main.simulation.command_log()
    assert_int(int(log[count]["tick"])).is_equal(n)
    assert_int(int(log[count + 1]["tick"])).is_equal(n + 4)
    assert_bool(main.simulation.state.player.cell() == start + down * 2).is_true()
    assert_bool(main.simulation.state.player.is_moving()).is_false()


func test_two_held_keys_use_only_the_first_in_move_actions_order() -> void:
    var main := _main()
    _run_ticks(main, 1)
    var up: Vector2i = GameMain.MOVE_DIRECTIONS[&"move_up"]
    # right 를 먼저 눌러도 up 이 앞선다.
    _press(&"move_right")
    _press(&"move_up")
    assert_bool(main.held_direction() == up).is_true()
    _release_all()
    _press(&"move_up")
    _press(&"move_right")
    assert_bool(main.held_direction() == up).is_true()
    # 넷 다 눌러도 하나.
    _press(&"move_down")
    _press(&"move_left")
    assert_bool(main.held_direction() == up).is_true()
    var tick := main.simulation.current_tick()
    _run_ticks(main, 1)
    assert_int(main.simulation.command_count()).is_equal(1)
    var entry := _last_log_entry(main)
    assert_int(int(entry["dx"])).is_equal(up.x)
    assert_int(int(entry["dy"])).is_equal(up.y)
    assert_int(int(entry["tick"])).is_equal(tick)
    assert_bool(main.simulation.state.player.facing == up).is_true()
    _release_all()
    # up 을 떼면 다음 순서(down)가 잡힌다.
    _press(&"move_right")
    _press(&"move_down")
    assert_bool(main.held_direction() == GameMain.MOVE_DIRECTIONS[&"move_down"]).is_true()


func test_wall_direction_held_submits_every_tick_but_never_moves() -> void:
    # 거부돼도 제출은 된다 — view 는 판정을 모른다. 위치는 그대로, facing 은 돈다.
    var main := _main()
    _run_ticks(main, 1)
    var action := _blocked_move_action(main.simulation)
    var dir: Vector2i = GameMain.MOVE_DIRECTIONS[action]
    var first_tick := main.simulation.current_tick()
    _press(action)
    _run_ticks(main, 5)
    assert_int(main.simulation.command_count()).is_equal(5)
    var log := main.simulation.command_log()
    for i in 5:
        assert_int(int(log[i]["tick"])).is_equal(first_tick + i)
        assert_int(int(log[i]["dx"])).is_equal(dir.x)
        assert_int(int(log[i]["dy"])).is_equal(dir.y)
    assert_bool(main.simulation.state.player.cell() == Vector2i(8, 8)).is_true()
    assert_bool(main.simulation.state.player.is_moving()).is_false()
    assert_bool(main.simulation.state.player.facing == dir).is_true()


func test_move_before_first_tick_is_refused_but_turns_facing() -> void:
    # 틱 0 에는 로드 집합이 비어 걷기가 거부된다(SIM_ORDER 1-M1b). facing 만 바뀐다. 버그가 아니다.
    var main := _main()
    _press(&"move_left")
    _run_ticks(main, 1)
    assert_int(main.simulation.command_count()).is_equal(1)
    assert_int(int(_last_log_entry(main)["tick"])).is_equal(0)
    assert_bool(main.simulation.state.player.cell() == Vector2i(8, 8)).is_true()
    assert_bool(main.simulation.state.player.is_moving()).is_false()
    assert_bool(main.simulation.state.player.facing == Vector2i(-1, 1)).is_true()
    assert_bool(main.simulation.state.chunks.center() == Vector2i(0, 0)).is_true()


# --- 카메라: 플레이어 발 위치 추적 ---

func test_camera_follows_focus_position() -> void:
    var main := _main()
    var spawn_center := IsoProjection.cell_center(8, 8)
    # 첫 프레임: 스폰 발 칸 중심.
    assert_bool(main.world_view.focus_position().is_equal_approx(spawn_center)).is_true()
    assert_bool(main.camera.position.is_equal_approx(spawn_center)).is_true()
    _tick_once(main)
    assert_bool(main.camera.position.is_equal_approx(spawn_center)).is_true()
    # 걸을 수 있는 방향으로 명령을 제출한다. 제출만으로는 카메라가 움직이지 않는다 — 상태가 바뀌어야 따라간다.
    var dir := _walkable_dir(main.simulation)
    main.simulation.submit(MovePlayerCommand.create(dir.x, dir.y))
    assert_bool(main.camera.position.is_equal_approx(spawn_center)).is_true()
    # 물리 스텝이 틱을 돌리면 카메라가 발 위치와 함께 움직인다.
    assert_int(_tick_once(main)).is_greater_equal(1)
    assert_bool(main.camera.position.is_equal_approx(spawn_center)).override_failure_message(
        "걷기 시작했는데 카메라가 스폰에 남아 있다").is_false()
    assert_bool(main.camera.position.is_equal_approx(main.world_view.focus_position())).is_true()
    # 도착할 때까지 돌리면 다음 칸 중심. 물리 스텝 하나가 틱을 여러 개 돌릴 수 있으니 도착 여부로 멈춘다.
    var guard := 0
    while main.simulation.state.player.is_moving() and guard < 8:
        _tick_once(main)
        assert_bool(main.camera.position.is_equal_approx(main.world_view.focus_position())).is_true()
        guard += 1
    assert_bool(main.simulation.state.player.is_moving()).is_false()
    var dest := Vector2i(8, 8) + dir
    assert_bool(main.simulation.state.player.cell() == dest).is_true()
    assert_bool(main.camera.position.is_equal_approx(IsoProjection.cell_center(dest.x, dest.y))).is_true()


# --- 활성 층: 플레이어 층 추적 ---

func test_active_layer_tracks_player_layer() -> void:
    var main := _main()
    # 씬 준비 직후 활성 층 == 플레이어 층.
    assert_int(main.world_view.active_layer).is_equal(main.simulation.state.player.layer)
    _tick_once(main)
    assert_int(main.world_view.active_layer).is_equal(main.simulation.state.player.layer)
    # Q/E 엿보기는 플레이어 층이 그대로면 틱이 돌아도 되돌리지 않는다.
    main.handle_action(&"layer_up")
    assert_int(main.world_view.active_layer).is_equal(Chunk.LAYER_UPPER)
    _tick_once(main)
    assert_int(main.world_view.active_layer).is_equal(Chunk.LAYER_UPPER)
    # 플레이어 층이 바뀌면 다음 틱에 따라간다. 층 변경: 테스트에서만 허용되는 상태 직접 조작
    # (M1 에는 층을 바꾸는 명령이 없다).
    main.simulation.state.player.layer = Chunk.LAYER_UNDER
    assert_int(main.world_view.active_layer).is_equal(Chunk.LAYER_UPPER)
    assert_int(_tick_once(main)).is_greater_equal(1)
    assert_int(main.world_view.active_layer).is_equal(Chunk.LAYER_UNDER)


# --- 소스 가드 (main 전용 — view→sim 쓰기 가드는 test_world_view 가 res://view 전체를 순회한다) ---

func test_main_source_does_not_write_tick_or_use_delta() -> void:
    assert_bool(FileAccess.file_exists(MAIN_SOURCE)).is_true()
    var source := FileAccess.get_file_as_string(MAIN_SOURCE)
    for token: String in ["state.tick =",
            "delta *", "* delta", "delta)", "delta /", "/ delta", "delta +", "+ delta", "delta -", "- delta"]:
        assert_bool(source.contains(token)).override_failure_message(
            "%s 에 '%s' 가 있다" % [MAIN_SOURCE, token]
        ).is_false()
    # _delta 는 파라미터 이름으로만 등장한다.
    assert_bool(source.contains("_delta: float")).is_true()
    assert_int(source.count("_delta")).is_equal(1)
    # 이동은 명령으로만. (0,0) 을 제출하는 경로는 없다.
    assert_bool(source.contains("MovePlayerCommand.create(")).is_true()
    assert_bool(source.contains("_submit_move(0, 0)")).is_false()
    # 틱마다 "제출 → step" 을 문자 그대로 돈다. 묶음 진행(advance)은 쓰지 않는다.
    assert_bool(source.contains("advance(")).is_false()
    assert_int(source.count("simulation.step()")).is_equal(1)
    assert_bool(source.contains("Input.is_action_pressed(")).is_true()
    # 카메라·층은 view 의 판단을 부른다.
    assert_bool(source.contains("world_view.focus_position()")).is_true()
    assert_int(source.count("world_view.follow_player_layer()")).is_equal(2)


# --- 다시 그리기는 프레임당 최대 1회 ---

func test_physics_step_only_flags_refresh_and_process_frame_consumes_it_once() -> void:
    # 물리 스텝은 플래그만 세운다. 스텝이 여러 번 돌아도 플래그는 하나다.
    var main := _main()
    assert_bool(main._needs_refresh).is_false()
    _tick_once(main)
    _tick_once(main)
    _tick_once(main)
    assert_bool(main._needs_refresh).is_true()
    # process_frame 핸들러가 연결돼 있고, 한 번 소비하면 내려간다.
    assert_bool(main.get_tree().process_frame.is_connected(main._on_process_frame)).is_true()
    main._on_process_frame()
    assert_bool(main._needs_refresh).is_false()
    # 틱이 없으면 플래그를 세우지 않는다.
    main._last_usec = Time.get_ticks_usec()
    main._physics_process(0.0)
    assert_bool(main._needs_refresh).is_false()


func test_main_source_refreshes_view_only_from_process_frame_handler() -> void:
    var source := FileAccess.get_file_as_string(MAIN_SOURCE)
    assert_int(source.count("world_view.refresh()")).is_equal(1)
    var handler_at := source.find("func _on_process_frame()")
    assert_int(handler_at).is_greater(0)
    assert_int(source.find("world_view.refresh()")).is_greater(handler_at)
