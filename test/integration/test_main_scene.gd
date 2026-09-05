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
    # 테스트가 쓰려고 쥐여 준다. 시작 지급이 아니다.
    #
    # **손에 잡히는 줄은 아홉 칸인데 놓을 수 있는 것은 열일곱이다.**
    # 앞에서부터 담으면 뒤엣것이 줄 밖으로 밀려 select_block 이 못 찾는다.
    # 그래서 이 스위트가 고르는 것부터 담는다.
    var wanted: Array[int] = [
        BlockType.GROUND, BlockType.ORE, BlockType.WOOD, BlockType.PLANK,
        BlockType.DOOR_CLOSED, BlockType.DETECTOR, BlockType.ACTUATOR,
        BlockType.REPEATER, BlockType.BOX,
    ]
    for type in InputController.PLACEABLE:
        if BlockType.is_uniquely_made(type) or wanted.has(type):
            continue
        wanted.append(type)
    for type in wanted:
        main.simulation.state.inventory.add(type, 8)
    return main


## 만들 것을 고른다.
##
## 만들기 고르기(C)는 제작법을 차례로 돈다. 손에 든 칸과는 상관이 없다 —
## 빈 칸을 잡고도 만들 수 있어야 하기 때문이다(InputController.recipe_output).
func _choose_recipe(main: GameMain, wanted: int) -> void:
    var controller := main.input_controller()
    for i in RecipeBook.count():
        if controller.recipe_output() == wanted:
            return
        controller.cycle_recipe()
    assert_int(controller.recipe_output()).override_failure_message(
        "%s 를 만들 법이 없다" % BlockType.name_of(wanted)).is_equal(wanted)


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
    assert_bool(main.simulation.state.character.cell() == IslandBuilder.spawn_cell()).is_true()
    assert_bool(main.simulation.state.grid.is_solid(Vector3i(32, 32, 0))).is_true()


func test_world_view_draws_the_island() -> void:
    var main := _main()
    assert_int(main.world_view().instance_count(BlockType.GROUND)).is_greater(1000)
    assert_int(main.world_view().instance_count(BlockType.WOOD)).is_greater(0)
    assert_int(main.world_view().instance_count(BlockType.ORE)).is_greater(0)


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
    main.input_controller().select_block(BlockType.ORE)
    var target := main.simulation.state.character.facing_cell()
    var drawn := main.world_view().instance_count(BlockType.ORE)

    main.input_controller().submit_place()
    _advance(main, 2)

    assert_int(main.simulation.state.grid.get_block(target)).is_equal(BlockType.ORE)
    assert_int(main.world_view().instance_count(BlockType.ORE)).is_equal(drawn + 1)


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


func test_the_player_starts_empty_handed() -> void:
    # 스펙 §3.1. 첫 블록은 손으로 부숴 얻는다. 제작법이 생겨 지급을 껐다.
    #
    # 위의 _main() 은 테스트가 쓰려고 손에 쥐여 주므로 여기서는 쓰지 않는다.
    # 그것으로 재면 헬퍼가 채운 것을 다시 세는 꼴이 된다.
    var state := WorldState.new(SimRng.new(1))
    IslandBuilder.populate(state)
    assert_int(state.inventory.total()).is_equal(0)


func test_everything_in_hand_can_be_gathered_or_made() -> void:
    # 손에 쥘 수 있는 것마다 얻을 길이 있어야 한다. 길이 없으면 빈손으로
    # 시작할 수 없다. 묶음만은 회로를 압축해 얻는다.
    var gathered: Array[int] = [
        BlockType.GROUND, BlockType.ORE, BlockType.WOOD,
        BlockType.SAND, BlockType.EMBER,
    ]
    for block_type in InputController.PLACEABLE:
        if block_type == BlockType.BUNDLE:
            continue
        assert_bool(gathered.has(block_type) or RecipeBook.can_be_made(block_type)
            ).override_failure_message(
                "%s 를 얻을 길이 없다" % BlockType.name_of(block_type)).is_true()


func test_the_player_starts_with_no_bundle() -> void:
    # 묶음은 지급하지 못한다. 안에 무엇이 들었는지를 사람이 정하는 것이 묶음이다.
    # 쥐여 주려면 회로를 대신 지어 주는 셈이 된다.
    var main := _main()
    assert_int(main.simulation.state.inventory.count_of(BlockType.BUNDLE)).is_equal(0)
    assert_int(main.simulation.state.bundles.count()).is_equal(0)


func test_the_hotbar_shows_the_front_of_the_inventory() -> void:
    var main := _main()
    main.hotbar().sync()
    assert_int(main.hotbar().slot_count()).is_equal(Inventory.HOTBAR_SLOTS)

    # 칸에는 그림이 들고, 이름은 고른 것 하나만 줄 위에 뜬다.
    var inventory := main.simulation.state.inventory
    for slot in main.hotbar().slot_count():
        var kind := inventory.kind_at(slot)
        if kind == BlockType.EMPTY:
            continue
        assert_int(main.hotbar().slot_icon(slot)).is_equal(kind)
        assert_bool(main.hotbar().slot_icon_fits(slot)).is_true()
        var held := inventory.amount_at(slot)
        if held > 1:
            assert_str(main.hotbar().slot_text(slot)).contains(str(held))


func test_only_the_chosen_slot_is_marked() -> void:
    var main := _main()
    main.input_controller().select_block(BlockType.DETECTOR)
    main.hotbar().sync()

    # 고른 칸이 몇 번째인지는 무엇을 담아 두었는가에 달렸다. 그것을 여기서
    # 다시 셈하면 담는 차례를 바꿀 때마다 이 테스트가 깨진다.
    # **묻는 것은 고른 칸 하나만 표시되는가다.**
    var chosen := main.hotbar().selected_slot()
    assert_int(main.simulation.state.inventory.kind_at(chosen)).is_equal(BlockType.DETECTOR)
    for slot in main.hotbar().slot_count():
        assert_bool(main.hotbar().slot_is_marked(slot)).is_equal(slot == chosen)


func test_the_chosen_thing_explains_itself() -> void:
    var main := _main()
    main.input_controller().select_block(BlockType.DETECTOR)
    main.part_hint().sync()

    var line := main.part_hint().text()
    assert_str(line).contains("감지기")
    assert_str(line).contains("잇기")


func test_the_explanation_follows_the_choice() -> void:
    var main := _main()
    main.input_controller().select_block(BlockType.DETECTOR)
    main.part_hint().sync()
    var before := main.part_hint().text()

    main.input_controller().select_block(BlockType.ACTUATOR)
    main.part_hint().sync()
    assert_str(main.part_hint().text()).is_not_equal(before)
    assert_str(main.part_hint().text()).contains("작동기")


func test_the_help_starts_hidden_and_answers_the_key() -> void:
    var main := _main()
    assert_bool(main.help_overlay().is_shown()).is_false()

    main.input_controller().toggle_help()
    assert_bool(main.help_overlay().is_shown()).is_true()

    main.input_controller().toggle_help()
    assert_bool(main.help_overlay().is_shown()).is_false()


func test_the_help_names_every_thing_a_player_must_press() -> void:
    var help := _main().help_overlay().text()
    for key in ["W A S D", "E", "Q", "R", "T", "F", "H"]:
        assert_str(help).contains(key)


func test_the_camera_starts_close_enough_to_place_parts() -> void:
    var main := _main()
    assert_float(main.camera().view_size()).is_equal_approx(
        IsometricCamera.DEFAULT_VIEW_SIZE, 0.001)
    assert_float(main.camera().view_size()).is_less(20.0)


func test_the_camera_pulls_in_and_pushes_out() -> void:
    var main := _main()
    var start := main.camera().view_size()

    main.camera().zoom_by(-2)
    assert_float(main.camera().view_size()).is_less(start)

    main.camera().zoom_by(4)
    assert_float(main.camera().view_size()).is_greater(start)


func test_zoom_stays_within_bounds() -> void:
    var main := _main()
    main.camera().zoom_by(-100)
    assert_float(main.camera().view_size()).is_equal_approx(IsometricCamera.MIN_VIEW_SIZE, 0.001)
    main.camera().zoom_by(100)
    assert_float(main.camera().view_size()).is_equal_approx(IsometricCamera.MAX_VIEW_SIZE, 0.001)


func test_walking_keys_follow_the_camera() -> void:
    var main := _main()
    var before := main.input_controller().grid_for_screen(ScreenDirections.UP)
    main.camera().turn_by(2)
    assert_bool(main.input_controller().grid_for_screen(ScreenDirections.UP) == before).is_false()


func test_pressing_up_moves_the_character_up_the_screen() -> void:
    var main := _main()
    var start := main.character_view().target_position()
    var before := main.camera().unproject_position(start)

    main.input_controller().submit_move_screen(ScreenDirections.UP)
    _advance(main, 10)

    var after := main.camera().unproject_position(main.character_view().target_position())
    # 화면 좌표는 아래가 양수다. 위로 갔다면 y 가 줄어든다.
    assert_float(after.y).is_less(before.y)


func test_a_player_can_build_an_automatic_door() -> void:
    # 완료 조건. 사람이 손에 든 것만으로 자동문을 세울 수 있어야 한다.
    var main := _main()
    var here := _level_around(main, 5)
    # 감지기는 사람이 가까이 있어야 본다. 세 칸 안에 들어오도록 붙여 짓는다.
    var door := here + Vector3i(2, 0, 0)
    var actuator := here + Vector3i(2, 1, 0)
    var detector := here + Vector3i(2, 2, 0)

    var controller := main.input_controller()
    controller.select_block(BlockType.DOOR_CLOSED)
    controller.set_target(_aim_at(door - VoxelGrid.UP))
    controller.submit_place()
    _advance(main, 2)

    controller.select_block(BlockType.ACTUATOR)
    controller.set_target(_aim_at(actuator - VoxelGrid.UP))
    controller.submit_place()
    _advance(main, 2)

    controller.select_block(BlockType.DETECTOR)
    controller.set_target(_aim_at(detector - VoxelGrid.UP))
    controller.submit_place()
    _advance(main, 2)

    controller.set_target(_aim_at(detector))
    controller.submit_link()
    controller.set_target(_aim_at(actuator))
    controller.submit_link()
    _advance(main, 4)

    assert_bool(main.simulation.state.circuit.is_linked(detector, actuator)).is_true()
    assert_int(main.simulation.state.grid.get_block(door)).is_equal(BlockType.DOOR_OPEN)


func test_a_player_can_gather_and_make_a_door_by_hand() -> void:
    # 완료 조건. 빈손에서 시작해 부수고, 만들고, 놓는 데까지 **입력 레이어를
    # 거쳐** 닿아야 한다. 스펙 §3.1 의 "첫 블록은 손으로 부숴 얻는다".
    var main: GameMain = auto_free((load(MAIN_SCENE) as PackedScene).instantiate())
    add_child(main)
    main.set_physics_process(false)

    var state := main.simulation.state
    assert_int(state.inventory.total()).is_equal(0)

    # 곁에 나무를 세워 두고 손으로 부순다.
    var here := _level_around(main, 4)
    var trunk := here + Vector3i(1, 0, 0)
    var controller := main.input_controller()
    for i in 4:
        state.grid.set_block(trunk, BlockType.WOOD)
        controller.set_target(_aim_at(trunk))
        controller.submit_break()
        _advance(main, 2)
    assert_int(state.inventory.count_of(BlockType.WOOD)).is_equal(4)

    # 모은 나무를 판자로 켜고, 그 판자로 문을 만든다.
    #
    # 나무가 곧바로 문이 되지 않는다. **한 번 켜야 한다.** 나무 하나가 판자
    # 넷이 되므로 한 그루면 문이 서고도 남는다 — 예전보다 오히려 가볍다.
    _choose_recipe(main, BlockType.PLANK)
    controller.submit_craft()
    _advance(main, 2)
    assert_int(state.inventory.count_of(BlockType.PLANK)).is_equal(4)
    assert_int(state.inventory.count_of(BlockType.WOOD)).is_equal(3)

    _choose_recipe(main, BlockType.DOOR_CLOSED)
    controller.submit_craft()
    _advance(main, 2)
    assert_int(state.inventory.count_of(BlockType.DOOR_CLOSED)).is_equal(1)
    assert_int(state.inventory.count_of(BlockType.PLANK)).is_equal(0)

    # 만든 문을 손에 쥐고 놓는다.
    #
    # 쥐는 것이 따로 필요해졌다. 예전에는 나무가 몽땅 문이 되어 빈 칸에
    # 문이 들어와 저절로 잡혔는데, 이제 나무가 남으므로 문이 다른 칸으로 간다.
    var spot := here + Vector3i(2, 0, 0)
    controller.select_block(BlockType.DOOR_CLOSED)
    controller.set_target(_aim_at(spot - VoxelGrid.UP))
    controller.submit_place()
    _advance(main, 2)
    assert_int(state.grid.get_block(spot)).is_equal(BlockType.DOOR_CLOSED)


func test_making_without_the_materials_changes_nothing() -> void:
    var main: GameMain = auto_free((load(MAIN_SCENE) as PackedScene).instantiate())
    add_child(main)
    main.set_physics_process(false)

    var controller := main.input_controller()
    controller.select_block(BlockType.DETECTOR)
    controller.submit_craft()
    _advance(main, 2)
    assert_int(main.simulation.state.inventory.total()).is_equal(0)


func test_the_game_screen_can_write_and_read_back_a_game() -> void:
    SaveSlot.clear()

    var main: GameMain = auto_free((load(MAIN_SCENE) as PackedScene).instantiate())
    add_child(main)
    main.set_physics_process(false)

    var here: Vector3i = main.simulation.state.character.cell()
    main.simulation.submit(BreakBlockCommand.create(here + Vector3i(1, 0, -1)))
    _advance(main, 8)
    var saved := main.simulation.state_hash()

    assert_bool(main.save_game()).is_true()
    assert_str(main.notice().text()).is_not_empty()

    # 저장한 뒤로 더 진행한다. 불러오면 그 자리로 되돌아가야 한다.
    _advance(main, 60)
    assert_str(main.simulation.state_hash()).is_not_equal(saved)

    assert_bool(main.load_game()).is_true()
    assert_str(main.simulation.state_hash()).is_equal(saved)
    SaveSlot.clear()


func test_the_views_follow_the_game_that_was_loaded() -> void:
    # 붙이는 것을 하나라도 빠뜨리면 화면이 옛 판을 계속 읽는다.
    SaveSlot.clear()

    var main: GameMain = auto_free((load(MAIN_SCENE) as PackedScene).instantiate())
    add_child(main)
    main.set_physics_process(false)
    main.save_game()

    var before := main.simulation
    assert_bool(main.load_game()).is_true()
    assert_bool(main.simulation != before).is_true()

    var state := main.simulation.state
    main.sync_views()
    assert_bool(main.character_view().target_position().is_equal_approx(
        SimViewCoords.sub_to_world(state.character.sub_position) + Vector3.UP * 0.5)).is_true()

    # 인벤토리를 바꿔 핫바가 새 판을 읽고 있는지 본다.
    state.inventory.add(BlockType.WOOD, 5)
    main.hotbar().sync()

    var slot := -1
    for i in Inventory.HOTBAR_SLOTS:
        if state.inventory.kind_at(i) == BlockType.WOOD:
            slot = i
            break
    assert_int(slot).is_greater_equal(0)
    assert_str(main.hotbar().slot_text(slot)).contains("5")
    SaveSlot.clear()


func test_loading_with_nothing_saved_leaves_the_game_alone() -> void:
    SaveSlot.clear()

    var main: GameMain = auto_free((load(MAIN_SCENE) as PackedScene).instantiate())
    add_child(main)
    main.set_physics_process(false)
    _advance(main, 10)
    var before := main.simulation.state_hash()

    assert_bool(main.load_game()).is_false()
    assert_str(main.simulation.state_hash()).is_equal(before)


## 지을 자리를 고르게 다진다. 지표가 기복을 타므로 이웃 칸의 높이가 저마다
## 다르다. 지형을 시험하는 테스트가 아니므로 무대만 평평하게 만들어 둔다.
func _level_around(main: GameMain, reach: int) -> Vector3i:
    var grid := main.simulation.state.grid
    var here: Vector3i = main.simulation.state.character.cell()
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            for z in range(VoxelGrid.BEDROCK_Z + 1, VoxelGrid.SIZE_Z):
                var kind := BlockType.GROUND if z < here.z else BlockType.EMPTY
                grid.set_block(Vector3i(here.x + dx, here.y + dy, z), kind)
    return here


func _aim_at(cell: Vector3i) -> BlockTarget:
    var target := BlockTarget.new()
    target.hit = true
    target.cell = cell
    target.normal = VoxelGrid.UP
    return target


func test_the_hotbar_fits_on_the_screen() -> void:
    var main := _main()
    main.hotbar().sync()
    assert_bool(main.hotbar().all_slots_visible()).is_true()


func test_the_explanation_fits_on_the_screen() -> void:
    var main := _main()
    main.input_controller().select_block(BlockType.BRANCH)
    main.part_hint().sync()
    assert_bool(main.part_hint().fully_visible()).is_true()


func test_pressing_up_moves_straight_up_the_screen() -> void:
    # 8방향이 되면서 화면 위가 실제로 위가 되었다.
    var main := _main()
    var start := main.character_view().target_position()
    var before := main.camera().unproject_position(start)

    main.input_controller().submit_move_screen(ScreenDirections.UP)
    _advance(main, 12)

    var after := main.camera().unproject_position(main.character_view().target_position())
    assert_float(after.y).is_less(before.y)
    # 옆으로는 거의 흐르지 않아야 한다.
    assert_float(absf(after.x - before.x)).is_less(1.0)


func test_pressing_right_moves_straight_across_the_screen() -> void:
    var main := _main()
    var before := main.camera().unproject_position(main.character_view().target_position())

    main.input_controller().submit_move_screen(ScreenDirections.RIGHT)
    _advance(main, 12)

    var after := main.camera().unproject_position(main.character_view().target_position())
    assert_float(after.x).is_greater(before.x)
    assert_float(absf(after.y - before.y)).is_less(1.0)


func test_the_camera_keeps_its_diamond_angle() -> void:
    assert_float(_main().camera().yaw_degrees()).is_equal_approx(45.0, 0.001)


func test_wiring_from_a_branch_shows_which_way_out() -> void:
    var main := _main()
    var branch: Vector3i = main.simulation.state.character.cell() + Vector3i(2, 0, 0)
    var part := BranchPart.create(branch)
    part.configure(PackedInt32Array([BranchPart.MODE_TRUTH, 0]))
    main.simulation.state.circuit.add_part(part)

    var controller := main.input_controller()
    controller.set_target(_aim_at(branch))
    controller.submit_link()
    main.part_hint().sync()

    assert_str(main.part_hint().text()).contains("참")
    controller.cycle_part_setting()
    main.part_hint().sync()
    assert_str(main.part_hint().text()).contains("거짓")
