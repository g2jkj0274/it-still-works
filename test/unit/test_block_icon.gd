extends GdUnitTestSuite

## 손에 든 것 그림 검증.
##
## **칸에 이름이 적혀 있었다.** 아홉 칸을 매번 읽어야 무엇을 들고 있는지 알 수
## 있었다. 마인크래프트는 눈으로 훑는다.
##
## 그림은 세상에 세우는 것과 **같은 상자 표**를 읽는다. 표를 두 벌 두면
## 언젠가 어긋나고, 어긋난 그림은 없느니만 못하다.

const BOX_SIZE := Vector2(48.0, 48.0)


func _icon(block_type: int) -> BlockIcon:
    var icon: BlockIcon = auto_free(BlockIcon.new())
    add_child(icon)
    icon.size = BOX_SIZE
    icon.show_block(block_type)
    return icon


func test_an_empty_icon_draws_nothing() -> void:
    var icon := _icon(BlockType.EMPTY)
    assert_bool(icon.is_empty()).is_true()
    assert_bool(icon.drawn_bounds().has_area()).is_false()


func test_a_block_draws_something() -> void:
    var icon := _icon(BlockType.WOOD)
    assert_bool(icon.is_empty()).is_false()
    assert_bool(icon.drawn_bounds().has_area()).is_true()


func test_every_thing_that_can_be_held_has_a_picture() -> void:
    for type in InputController.PLACEABLE:
        assert_bool(_icon(type).drawn_bounds().has_area()).is_true()


func test_every_picture_stays_inside_its_slot() -> void:
    # 그림이 칸 밖으로 넘치면 옆 칸을 덮는다.
    var room := Rect2(Vector2.ZERO, BOX_SIZE)
    for type in InputController.PLACEABLE:
        assert_bool(room.encloses(_icon(type).drawn_bounds())).is_true()


func test_the_picture_is_the_same_shape_as_the_thing_in_the_world() -> void:
    # 인벤토리에서 본 실루엣과 땅에 놓은 실루엣이 같아야 한다.
    for type in InputController.PLACEABLE:
        assert_int(BlockMeshes.boxes_of(type).size()).is_greater(0)
        assert_bool(_icon(type).drawn_bounds().has_area()).is_true()


func test_things_of_different_shapes_draw_differently() -> void:
    # 부품마다 실루엣이 갈려야 눈으로 훑을 수 있다.
    var seen: Array[String] = []
    var shaped: Array[int] = [
        BlockType.DETECTOR, BlockType.BOX, BlockType.BRANCH,
        BlockType.REPEATER, BlockType.ACTUATOR, BlockType.CHEST,
    ]
    for type in shaped:
        var mark := str(BlockMeshes.boxes_of(type))
        assert_bool(seen.has(mark)).is_false()
        seen.append(mark)


func test_flattening_keeps_up_as_up() -> void:
    # 위에 있는 것은 그림에서도 위에 있어야 한다.
    var high := BlockIcon.flatten(Vector3(0.0, 0.5, 0.0))
    var low := BlockIcon.flatten(Vector3(0.0, -0.5, 0.0))
    assert_float(high.y).is_less(low.y)


func test_showing_the_same_thing_twice_changes_nothing() -> void:
    var icon := _icon(BlockType.WOOD)
    icon.show_block(BlockType.WOOD)
    assert_int(icon.block_type()).is_equal(BlockType.WOOD)


func test_an_open_door_and_a_closed_door_look_different() -> void:
    # 자동문은 첫 장치다. 그 결과가 그림에서도 갈려야 한다.
    assert_str(str(BlockMeshes.boxes_of(BlockType.DOOR_OPEN))).is_not_equal(
        str(BlockMeshes.boxes_of(BlockType.DOOR_CLOSED)))
