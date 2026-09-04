extends GdUnitTestSuite

## 블록 생김새 검증.
##
## 색만으로는 파스텔 열몇 종을 가를 수 없다. 모양이 실제로 서로 다른지,
## 그리고 한 칸을 벗어나지 않는지를 못박는다.


func _mesh(block_type: int) -> ArrayMesh:
    return BlockMeshes.for_block(block_type)


func _points(block_type: int) -> PackedVector3Array:
    return _mesh(block_type).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func _drawn_types() -> Array[int]:
    var types: Array[int] = []
    for block_type in BlockType.COUNT:
        if block_type != BlockType.EMPTY:
            types.append(block_type)
    return types


func test_every_block_has_a_shape() -> void:
    for block_type in _drawn_types():
        var mesh := _mesh(block_type)
        assert_object(mesh).is_not_null()
        assert_int(mesh.get_surface_count()).is_equal(1)


func test_no_shape_spills_out_of_its_cell() -> void:
    # 칸을 넘으면 옆 칸의 블록을 뚫고 나온다.
    var half := SimViewCoords.CELL_SIZE * 0.5 + 0.001
    for block_type in _drawn_types():
        var box := _mesh(block_type).get_aabb()
        assert_float(box.position.x).is_greater_equal(-half)
        assert_float(box.position.y).is_greater_equal(-half)
        assert_float(box.position.z).is_greater_equal(-half)
        assert_float(box.end.x).is_less_equal(half)
        assert_float(box.end.y).is_less_equal(half)
        assert_float(box.end.z).is_less_equal(half)


func test_terrain_fills_its_cell() -> void:
    # 이어 붙였을 때 틈이 보이면 안 된다.
    for block_type in [BlockType.GROUND, BlockType.STONE, BlockType.WOOD]:
        var size := _mesh(block_type).get_aabb().size
        assert_float(size.x).is_equal_approx(SimViewCoords.CELL_SIZE, 0.001)
        assert_float(size.y).is_equal_approx(SimViewCoords.CELL_SIZE, 0.001)
        assert_float(size.z).is_equal_approx(SimViewCoords.CELL_SIZE, 0.001)


func test_an_open_door_does_not_look_like_a_closed_one() -> void:
    # 자동문은 스펙 §5 의 첫 장치다. 열린 것이 보이지 않으면 만든 보람이 없다.
    assert_bool(_points(BlockType.DOOR_OPEN) == _points(BlockType.DOOR_CLOSED)).is_false()


func test_an_open_door_leaves_room_to_pass() -> void:
    var open_box := _mesh(BlockType.DOOR_OPEN).get_aabb()
    var closed_box := _mesh(BlockType.DOOR_CLOSED).get_aabb()
    assert_float(open_box.size.z).is_less(closed_box.size.z * 0.5)
    # 한쪽으로 물러나 있어야 남은 자리가 지나갈 자리로 보인다.
    assert_float(absf(open_box.get_center().z)).is_greater(0.1)


func test_a_field_lies_low_enough_to_walk_on() -> void:
    assert_float(_mesh(BlockType.FIELD).get_aabb().size.y).is_less(0.5)


func test_every_part_has_its_own_silhouette() -> void:
    var seen: Array = []
    for block_type in _drawn_types():
        if not BlockType.is_part(block_type):
            continue
        var shape := _points(block_type)
        for other: PackedVector3Array in seen:
            assert_bool(shape == other).is_false()
        seen.append(shape)


func test_a_part_never_looks_like_plain_terrain() -> void:
    var ground := _points(BlockType.GROUND)
    for block_type in _drawn_types():
        if BlockType.is_part(block_type):
            assert_bool(_points(block_type) == ground).is_false()


func test_the_top_of_a_block_is_lighter_than_its_underside() -> void:
    # 빛 하나만으로는 윗면과 옆면의 차이가 약해 쌓아 올린 것이 덩어리로 보인다.
    var arrays := _mesh(BlockType.GROUND).surface_get_arrays(0)
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]

    var top := 0.0
    var bottom := 1.0
    for i in normals.size():
        if normals[i].y > 0.9:
            top = colours[i].r
        elif normals[i].y < -0.9:
            bottom = colours[i].r
    assert_float(top).is_greater(bottom)


func test_earth_shows_grass_on_top_and_soil_on_the_side() -> void:
    # 한 색으로 여섯 면을 다 칠하면 놓은 블록이 땅에 묻힌다. 세 칸짜리 탑을
    # 세워도 "벽을 세웠다"가 아니라 "그림자가 생겼다"로 보였다.
    var arrays := _mesh(BlockType.GROUND).surface_get_arrays(0)
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]

    var top := Color.BLACK
    var side := Color.BLACK
    for i in normals.size():
        if normals[i].y > 0.9:
            top = colours[i]
        elif absf(normals[i].y) < 0.1:
            side = colours[i]

    # 밝기가 아니라 빛깔이 달라야 한다. 초록 위에 흙색 옆면이다.
    assert_float(top.h).is_not_equal(side.h)
    assert_float(top.g).is_greater(side.g)


func test_a_block_with_one_colour_keeps_it_on_every_side() -> void:
    var arrays := _mesh(BlockType.WOOD).surface_get_arrays(0)
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]

    for i in normals.size():
        if absf(normals[i].y) < 0.1:
            # 옆면끼리는 밝기만 다르고 빛깔은 같다.
            assert_float(colours[i].h).is_equal_approx(Palette.of_block(BlockType.WOOD).h, 0.01)


func test_the_two_visible_sides_are_shaded_apart() -> void:
    # 아이소메트릭에서는 옆면 두 쪽이 함께 보인다. 같은 밝기면 모서리가 사라진다.
    assert_float(absf(BlockMeshes.FACE_SIDE_X - BlockMeshes.FACE_SIDE_Z)).is_greater(0.02)
