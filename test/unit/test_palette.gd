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
    var once := Palette.varied(Palette.of_block(BlockType.STONE), cell)
    var twice := Palette.varied(Palette.of_block(BlockType.STONE), cell)
    assert_bool(once.is_equal_approx(twice)).is_true()


func test_the_variation_stays_subtle() -> void:
    # 변주가 크면 종류를 알아볼 수 없게 된다.
    var base := Palette.of_block(BlockType.WOOD)
    for i in 200:
        var cell := Vector3i(i % 17, (i / 17) % 13, i % 5)
        var shade := Palette.varied(base, cell)
        assert_float(absf(shade.v - base.v)).is_less_equal(Palette.VARIATION + 0.001)
        assert_float(shade.v).is_between(0.0, 1.0)


func test_different_blocks_are_told_apart() -> void:
    var seen: Array = []
    for type in BlockType.COUNT:
        if type == BlockType.EMPTY or type == BlockType.DOOR_OPEN:
            continue
        var colour := Palette.of_block(type)
        for other: Color in seen:
            assert_float(_distance(colour, other)).is_greater(0.12)
        seen.append(colour)


func _distance(a: Color, b: Color) -> float:
    return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
