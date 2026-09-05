extends GdUnitTestSuite

## 부품 설명 한 줄 검증.
##
## 이 글은 화면 하단에 가로 한 줄로 놓여야 한다. 세로줄로 무너지면 게임 화면을
## 가린다. 줄바꿈을 켜면 라벨이 얼마든지 좁아질 수 있다고 답해서 폭이 0 에
## 가깝게 잡히고, 글자마다 줄이 바뀐다. 그 일을 다시 겪지 않도록 못박는다.


func _controller() -> InputController:
    var controller: InputController = auto_free(InputController.new())
    add_child(controller)
    controller.bind(_sim())
    return controller


func _sim() -> Simulation:
    var sim := Simulation.new(1)
    IslandBuilder.populate(sim.state)
    return sim


func _hint(controller: InputController) -> PartHint:
    var hint: PartHint = auto_free(PartHint.new())
    add_child(hint)
    hint.bind(controller)
    hint.sync()
    return hint


func test_the_line_is_laid_out_horizontally() -> void:
    var hint := _hint(_controller())
    assert_bool(hint.is_single_line()).is_true()


func test_the_box_is_wider_than_it_is_tall() -> void:
    # 세로줄이 되면 이 비율이 뒤집힌다.
    var hint := _hint(_controller())
    var rect := hint.panel_rect()
    assert_float(rect.size.x).is_greater(rect.size.y * 3.0)


func test_the_box_is_wide_enough_for_the_words() -> void:
    var hint := _hint(_controller())
    assert_float(hint.panel_rect().size.x).is_greater(float(hint.text().length()) * 2.0)


func test_every_choice_stays_on_one_line() -> void:
    var controller := _controller()
    var hint := _hint(controller)
    for block_type in InputController.PLACEABLE:
        controller.select_block(block_type)
        hint.sync()
        assert_bool(hint.is_single_line()).is_true()
        assert_bool(hint.fully_visible()).is_true()


func test_every_setting_stays_on_one_line() -> void:
    var controller := _controller()
    var hint := _hint(controller)
    for block_type in InputController.PARTS_WITH_SETTINGS:
        controller.select_block(block_type)
        for i in 8:
            controller.cycle_part_setting()
            hint.sync()
            assert_bool(hint.is_single_line()).is_true()


func test_the_line_sits_above_the_hotbar() -> void:
    var hint := _hint(_controller())
    var screen := Vector2(hint.get_viewport().get_visible_rect().size)
    var rect := hint.panel_rect()
    assert_float(rect.end.y).is_less_equal(screen.y - Hotbar.SLOT_HEIGHT)
    assert_float(rect.position.y).is_greater(screen.y * 0.5)


func test_the_line_is_centred() -> void:
    var hint := _hint(_controller())
    var screen := Vector2(hint.get_viewport().get_visible_rect().size)
    var rect := hint.panel_rect()
    assert_float(absf(rect.position.x - (screen.x - rect.end.x))).is_less(1.0)


func test_the_line_stays_inside_the_screen() -> void:
    var hint := _hint(_controller())
    assert_bool(hint.fully_visible()).is_true()


func test_a_long_line_is_still_one_line() -> void:
    var controller := _controller()
    var hint := _hint(controller)
    controller.select_block(BlockType.BRANCH)
    hint.sync()
    assert_bool(hint.is_single_line()).is_true()
    assert_bool(hint.fully_visible()).is_true()


func test_an_empty_hand_reads_what_is_aimed_at() -> void:
    # **처음 켠 사람은 손이 비어 있다.** 그때 뜨던 "빈 손 — 손에 잡힐 칸을
    # 1~9 로 고른다"는 아무것도 말해 주지 않았다. 돌을 쳐 보고 안 캐지면
    # 고장으로 읽는다 — "곡괭이"라는 말을 화면 어디서도 본 적이 없기 때문이다.
    var controller := _controller()
    var here := controller.simulation().state.character.cell()
    var stone := Vector3i(here.x, here.y, VoxelGrid.BEDROCK_Z + 2)
    controller.simulation().state.grid.set_block(stone, BlockType.ROCK)
    controller.set_target(_aim_at(stone))

    var line := PartHint.line_for(controller)
    assert_str(line).contains(PartWords.name_of(BlockType.ROCK))
    assert_str(line).contains("곡괭이")


func test_what_the_hand_holds_still_wins() -> void:
    # 손에 든 것이 있으면 그쪽을 읽는다. 놓기 전에 무엇을 놓는지 알아야 한다.
    var controller := _controller()
    var here := controller.simulation().state.character.cell()
    controller.simulation().state.inventory.add(BlockType.WOOD, 1)
    controller.select_block(BlockType.WOOD)
    controller.set_target(_aim_at(Vector3i(here.x, here.y, VoxelGrid.BEDROCK_Z + 2)))

    assert_str(PartHint.line_for(controller)).contains(PartWords.name_of(BlockType.WOOD))


func test_the_gathering_line_asks_the_rules() -> void:
    # 규칙을 옮겨 적지 않는다. 도구 등급이 늘면 이 글도 저절로 따라와야 한다.
    assert_str(PartWords.gathering_of(BlockType.WOOD)).contains("맨손")
    assert_str(PartWords.gathering_of(BlockType.ROCK)).contains("나무 곡괭이")
    assert_str(PartWords.gathering_of(BlockType.EMBER)).contains("나무 곡괭이")
    assert_str(PartWords.gathering_of(BlockType.ORE)).contains("돌 곡괭이")


func _aim_at(cell: Vector3i) -> BlockTarget:
    var target := BlockTarget.new()
    target.hit = true
    target.cell = cell
    target.normal = Vector3i(0, 0, 1)
    return target
