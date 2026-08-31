extends GdUnitTestSuite

## 메인 씬 통합 검증.
##
## 헤드리스에서는 Godot 이 InputEvent 를 전달하지 않으므로 키 입력 자체는
## 재현하지 못한다. 대신 poll() 이 부르는 것과 같은 함수를 직접 불러
## 입력 → 명령 → 시뮬레이션 → 화면 경로 전체를 확인한다.

const MAIN_SCENE := "res://view/main.tscn"


## 자동 진행을 끄고 테스트가 틱을 직접 돌린다.
func _main() -> GameMain:
    var main: GameMain = auto_free((load(MAIN_SCENE) as PackedScene).instantiate())
    add_child(main)
    main.set_physics_process(false)
    return main


func _advance(main: GameMain, ticks: int) -> void:
    main.simulation.advance(ticks)
    main.sync_views()


func test_main_scene_is_the_project_entry_point() -> void:
    assert_str(str(ProjectSettings.get_setting("application/run/main_scene"))).is_equal(MAIN_SCENE)


func test_simulation_is_never_advanced_from_process() -> void:
    # 고정 틱 루프에서만 진행한다. _process 에서 갱신하지 않는다.
    var main := _main()
    assert_bool(main.has_method("_process")).is_false()
    assert_bool(main.has_method("_physics_process")).is_true()


func test_scene_builds_the_island_and_spawns_the_character() -> void:
    var main := _main()
    assert_object(main.simulation).is_not_null()
    assert_bool(main.simulation.state.character.cell() == IslandBuilder.SPAWN).is_true()
    assert_bool(main.simulation.state.grid.is_solid(Vector3i(32, 32, 0))).is_true()


func test_world_view_draws_the_island() -> void:
    var main := _main()
    assert_int(main.world_view().instance_count(BlockType.GROUND)).is_greater(1000)
    assert_int(main.world_view().instance_count(BlockType.WOOD)).is_greater(0)
    assert_int(main.world_view().instance_count(BlockType.STONE)).is_greater(0)


func test_camera_is_isometric_and_starts_on_the_character() -> void:
    var main := _main()
    assert_int(main.camera().projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
    assert_float(main.camera().focus_point().distance_to(main.character_view().target_position())).is_less(0.001)


func test_walking_moves_the_character_and_the_view_follows() -> void:
    var main := _main()
    var start := main.simulation.state.character.cell()
    var start_screen := main.character_view().position

    main.input_controller().submit_move(Vector3i(0, -1, 0))
    _advance(main, 10)

    assert_bool(main.simulation.state.character.cell() == start + Vector3i(0, -1, 0)).is_true()
    assert_bool(main.character_view().position.is_equal_approx(start_screen)).is_false()


func test_walking_repeatedly_covers_ground() -> void:
    var main := _main()
    var start := main.simulation.state.character.cell()
    for i in 5:
        main.input_controller().submit_move(Vector3i(1, 0, 0))
        _advance(main, 10)
    assert_int(main.simulation.state.character.cell().x).is_equal(start.x + 5)


func test_placing_a_block_changes_the_world_and_the_drawing() -> void:
    var main := _main()
    main.input_controller().select_block(BlockType.STONE)
    var target := main.simulation.state.character.facing_cell()
    var drawn := main.world_view().instance_count(BlockType.STONE)

    main.input_controller().submit_place()
    _advance(main, 2)

    assert_int(main.simulation.state.grid.get_block(target)).is_equal(BlockType.STONE)
    assert_int(main.world_view().instance_count(BlockType.STONE)).is_equal(drawn + 1)


func test_breaking_a_block_changes_the_world_and_the_drawing() -> void:
    var main := _main()
    main.input_controller().select_block(BlockType.WOOD)
    var target := main.simulation.state.character.facing_cell()

    main.input_controller().submit_place()
    _advance(main, 2)
    assert_bool(main.simulation.state.grid.is_solid(target)).is_true()

    main.input_controller().submit_break()
    _advance(main, 2)
    assert_bool(main.simulation.state.grid.is_solid(target)).is_false()


func test_syncing_views_never_changes_the_simulation() -> void:
    var main := _main()
    var before := main.simulation.state_hash()
    for i in 10:
        main.sync_views()
    assert_str(main.simulation.state_hash()).is_equal(before)


func test_input_only_queues_commands() -> void:
    var main := _main()
    var before := main.simulation.state_hash()
    main.input_controller().submit_move(Vector3i(1, 0, 0))
    main.input_controller().submit_place()
    assert_int(main.simulation.queue.size()).is_equal(2)
    assert_str(main.simulation.state_hash()).is_equal(before)


func test_aiming_at_the_screen_centre_finds_a_block() -> void:
    var main := _main()
    var centre := Vector2(main.get_viewport().get_visible_rect().size) * 0.5
    var target: BlockTarget = main.pick_target(centre)
    assert_object(target).is_not_null()
    assert_bool(target.hit).is_true()
    assert_bool(main.simulation.state.grid.is_solid(target.cell)).is_true()


func test_aiming_shows_the_highlight_on_the_targeted_cell() -> void:
    var main := _main()
    var centre := Vector2(main.get_viewport().get_visible_rect().size) * 0.5
    var target: BlockTarget = main.pick_target(centre)

    main.input_controller().set_target(target)
    main.block_highlight().show_cell(target.cell)
    assert_bool(main.block_highlight().is_showing()).is_true()
    assert_bool(main.block_highlight().targeted_cell() == target.cell).is_true()


func test_the_highlight_starts_hidden() -> void:
    assert_bool(_main().block_highlight().is_showing()).is_false()


func test_out_of_reach_targets_are_refused() -> void:
    var main := _main()
    var far := BlockTarget.new()
    far.hit = true
    far.cell = Vector3i(2, 2, 1)
    assert_bool(far.is_usable(main.simulation.state.character.cell())).is_false()
