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
