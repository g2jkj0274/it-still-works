extends GdUnitTestSuite

## 파스텔 팔레트 검증.
##
## 아트 방향은 밝고 경쾌함이다. 어둡거나 쨍한 색이 섞이면 톤이 무너진다.
## 눈으로만 지키면 언젠가 새어 들어오므로 규칙으로 못박는다.


func test_every_block_has_a_colour() -> void:
    for type in BlockType.COUNT:
        if type == BlockType.EMPTY:
            continue
        assert_bool(Palette.of_block(type) != Palette.MISSING).is_true()


func test_block_colours_are_pastel() -> void:
    for type in BlockType.COUNT:
        if type == BlockType.EMPTY:
            continue
        var colour := Palette.of_block(type)
        assert_float(colour.v).is_greater_equal(Palette.MIN_VALUE)
        assert_float(colour.s).is_less_equal(Palette.MAX_SATURATION)


func test_creature_colours_are_pastel() -> void:
    for colour in [
        Palette.CHARACTER_SKIN, Palette.CHARACTER_BODY, Palette.CHARACTER_LEGS,
        Palette.THREAT,
    ]:
        assert_float(colour.v).is_greater_equal(Palette.MIN_VALUE)
        assert_float(colour.s).is_less_equal(Palette.MAX_SATURATION)


func test_the_earth_side_stays_pastel_and_is_not_mistaken_for_wood() -> void:
    var side := Palette.GROUND_SIDE
    assert_float(side.v).is_greater_equal(Palette.MIN_VALUE)
    assert_float(side.s).is_less_equal(Palette.MAX_SATURATION)

    # 흙 옆면이 나무 줄기와 붙어 있으면 나무가 흙기둥으로 보인다.
    var wood := Palette.of_block(BlockType.WOOD)
    assert_float(Vector3(
        side.r - wood.r, side.g - wood.g, side.b - wood.b).length()).is_greater(0.12)


func test_the_variation_is_a_multiplier_around_one() -> void:
    for i in 200:
        var cell := Vector3i(i % 17, (i / 17) % 13, i % 5)
        assert_float(Palette.variation_of(cell)).is_between(
            1.0 - Palette.VARIATION - 0.001, 1.0 + Palette.VARIATION + 0.001)


func test_the_sky_and_the_sea_stay_pastel() -> void:
    # 화면에서 가장 넓은 자리를 차지하는 색들이다. 톤이 여기서 어긋나면 다 어긋난다.
    for colour in [Palette.SKY_DAY, Palette.SEA]:
        assert_float(colour.v).is_greater_equal(Palette.MIN_VALUE)
        assert_float(colour.s).is_less_equal(Palette.MAX_SATURATION)


func test_the_ground_cover_stays_pastel() -> void:
    # 바깥에서 가져온 모델도 색은 팔레트가 준다. 톤 규칙은 여기에도 걸린다.
    for colour in Palette.COVER_COLOURS:
        assert_float(colour.v).is_greater_equal(Palette.MIN_VALUE)
        assert_float(colour.s).is_less_equal(Palette.MAX_SATURATION)


func test_the_grass_is_told_apart_from_the_bare_ground() -> void:
    var grass := Palette.COVER_GRASS
    var ground := Palette.of_block(BlockType.GROUND)
    assert_float(Vector3(
        grass.r - ground.r, grass.g - ground.g, grass.b - ground.b).length()).is_greater(0.05)


func test_the_sea_is_told_apart_from_the_sky() -> void:
    # 위에서 내려다보는 시점이라 바다와 하늘이 화면에서 맞닿는다.
    # 붙여 두면 어디가 물이고 어디가 하늘인지 알 수 없다.
    var sea := Palette.SEA
    var sky := Palette.SKY_DAY
    assert_float(Vector3(
        sea.r - sky.r, sea.g - sky.g, sea.b - sky.b).length()).is_greater(0.12)


func test_the_sea_is_told_apart_from_the_ground() -> void:
    # 물가가 보이지 않으면 섬이 섬으로 보이지 않는다.
    var sea := Palette.SEA
    var ground := Palette.of_block(BlockType.GROUND)
    assert_float(Vector3(sea.r - ground.r, sea.g - ground.g, sea.b - ground.b).length()).is_greater(0.12)


func test_neighbouring_blocks_do_not_look_identical() -> void:
    # 같은 종류라도 칸마다 아주 조금씩 달라야 넓은 면이 단조롭지 않다.
    var left := Palette.varied(Palette.of_block(BlockType.GROUND), Vector3i(4, 4, 1))
    var right := Palette.varied(Palette.of_block(BlockType.GROUND), Vector3i(5, 4, 1))
    assert_bool(left.is_equal_approx(right)).is_false()


func test_the_variation_is_the_same_every_run() -> void:
    var cell := Vector3i(7, 3, 2)
    var once := Palette.varied(Palette.of_block(BlockType.ORE), cell)
    var twice := Palette.varied(Palette.of_block(BlockType.ORE), cell)
    assert_bool(once.is_equal_approx(twice)).is_true()


func test_the_variation_stays_subtle() -> void:
    # 변주가 크면 종류를 알아볼 수 없게 된다.
    var base := Palette.of_block(BlockType.WOOD)
    for i in 200:
        var cell := Vector3i(i % 17, (i / 17) % 13, i % 5)
        var shade := Palette.varied(base, cell)
        assert_float(absf(shade.v - base.v)).is_less_equal(Palette.VARIATION + 0.001)
        assert_float(shade.v).is_between(0.0, 1.0)


## 같은 물건의 두 상태. 서로만 갈리면 되고 다른 블록과 멀 필요는 없다.
const PAIRED_STATES: Array[int] = [
    BlockType.DOOR_OPEN, BlockType.LAMP_LIT,
    BlockType.IRON_DOOR_OPEN, BlockType.FURNACE_LIT,
]


## 이 물음에서 뺄 것.
##
## **도구는 세상에 놓이지 않는다.** 굴 벽에 나란히 박히는 일이 없으므로
## 블록끼리 갈려야 한다는 규칙이 걸리지 않는다. 손에 든 그림에서만 서로
## 갈리면 되고, 그것은 아래 test_tools_are_told_apart_in_hand 가 본다.
func _skipped(type: int) -> bool:
    return type == BlockType.EMPTY or PAIRED_STATES.has(type) or BlockType.is_handheld(type)


func test_different_blocks_are_told_apart() -> void:
    # 색이 붙어 있어도 된다. 다만 그때는 **생김새가 갈려야 한다.**
    #
    # 파스텔은 쓸 수 있는 폭이 좁다(명도 0.60 이상, 채도 0.45 이하). 블록이
    # 열몇 종을 넘어가면 색만으로는 더 가를 자리가 없다. 그래서 이 게임은
    # 처음부터 키와 바닥 넓이로도 가르기로 했고, 그 규칙을 여기서도 쓴다.
    var seen: Array[int] = []
    for type in BlockType.COUNT:
        if _skipped(type):
            continue
        for other in seen:
            var apart := _distance(Palette.of_block(type), Palette.of_block(other)) > 0.12
            var shaped := _shape_of(type) != _shape_of(other)
            assert_bool(apart or shaped).override_failure_message(
                "%s 와 %s 가 색으로도 모양으로도 갈리지 않는다" % [
                    BlockType.name_of(type), BlockType.name_of(other)]).is_true()
        seen.append(type)


func test_blocks_that_share_a_colour_are_a_short_list() -> void:
    # 모양으로 갈린다고 해서 색을 마구 겹쳐도 되는 것은 아니다.
    # 겹치는 짝이 늘어나면 화면이 한 덩어리로 보인다.
    var close := 0
    var seen: Array[int] = []
    for type in BlockType.COUNT:
        if _skipped(type):
            continue
        for other in seen:
            if _distance(Palette.of_block(type), Palette.of_block(other)) <= 0.12:
                close += 1
        seen.append(type)
    assert_int(close).is_less_equal(2)


func test_tools_are_told_apart_in_hand() -> void:
    # 도구는 세상에 놓이지 않고 손에 든 그림으로만 보인다.
    # 거기서는 생김새가 먼저 가른다 — 곡괭이의 가로날, 도끼의 치우친 날,
    # 삽의 아래로 넓은 날. 색은 등급을 말한다.
    var tools: Array[int] = []
    for type in BlockType.COUNT:
        if BlockType.is_handheld(type):
            tools.append(type)
    assert_int(tools.size()).is_greater(1)

    for i in tools.size():
        for j in range(i + 1, tools.size()):
            var apart := _distance(Palette.of_block(tools[i]), Palette.of_block(tools[j])) > 0.12
            var shaped := _shape_of(tools[i]) != _shape_of(tools[j])
            assert_bool(apart or shaped).override_failure_message(
                "%s 와 %s 가 손에서 갈리지 않는다" % [
                    BlockType.name_of(tools[i]), BlockType.name_of(tools[j])]).is_true()


func _shape_of(block_type: int) -> PackedVector3Array:
    return BlockMeshes.for_block(block_type).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func test_a_lit_lamp_is_told_apart_from_a_dark_one() -> void:
    # 켜졌는지 꺼졌는지가 보이지 않으면 자동 조명(스펙 §5)이 아무것도 보여주지 못한다.
    assert_float(_distance(
        Palette.of_block(BlockType.LAMP_LIT),
        Palette.of_block(BlockType.LAMP_DARK))).is_greater(0.12)


func test_an_open_door_is_told_apart_from_a_closed_one() -> void:
    # 색이 같아도 된다. 생김새가 가른다 — 열린 문은 한쪽으로 물러난 얇은 판이다.
    assert_bool(BlockMeshes.for_block(BlockType.DOOR_OPEN).surface_get_arrays(0)[
        Mesh.ARRAY_VERTEX] == BlockMeshes.for_block(BlockType.DOOR_CLOSED
        ).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]).is_false()


func _distance(a: Color, b: Color) -> float:
    return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
