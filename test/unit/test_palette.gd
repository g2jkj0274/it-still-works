extends GdUnitTestSuite

## 팔레트 검증: 레지스트리 전체 id 매핑, air 투명, 범위 밖·null → UNKNOWN, dim, 키 집합이
## blocks.json 이름 집합과 양방향으로 같음, 상수 구별, 플레이어 색(블록 팔레트 밖).


func _registry() -> BlockRegistry:
    var registry := BlockRegistry.load_default()
    assert_object(registry).is_not_null()
    return registry


func _assert_color(actual: Color, expected: Color, label: String) -> void:
    assert_bool(actual.is_equal_approx(expected)).override_failure_message(
        "%s: %s != %s" % [label, actual, expected]
    ).is_true()


# --- 매핑 ---

func test_every_registry_id_has_a_color() -> void:
    var registry := _registry()
    assert_int(registry.count()).is_greater(0)
    for id in registry.count():
        var c := Palette.color_for(registry, id)
        assert_bool(c.is_equal_approx(Palette.UNKNOWN)).override_failure_message(
            "id %d (%s) 의 색이 UNKNOWN" % [id, registry.name_of(id)]
        ).is_false()


func test_air_is_transparent() -> void:
    var registry := _registry()
    assert_str(registry.name_of(0)).is_equal("air")
    assert_float(Palette.color_for(registry, 0).a).is_equal(0.0)


func test_non_air_is_opaque() -> void:
    var registry := _registry()
    for id in range(1, registry.count()):
        assert_float(Palette.color_for(registry, id).a).override_failure_message(
            "id %d 알파" % id
        ).is_equal(1.0)


func test_out_of_range_id_is_unknown() -> void:
    var registry := _registry()
    _assert_color(Palette.color_for(registry, -1), Palette.UNKNOWN, "-1")
    _assert_color(Palette.color_for(registry, 99), Palette.UNKNOWN, "99")
    _assert_color(Palette.color_for(registry, registry.count()), Palette.UNKNOWN, "count()")


func test_null_registry_is_unknown() -> void:
    _assert_color(Palette.color_for(null, 0), Palette.UNKNOWN, "null/0")
    _assert_color(Palette.color_for(null, 1), Palette.UNKNOWN, "null/1")


## 이름이 팔레트에 없는 표를 만들어 UNKNOWN 을 확인한다.
func test_unlisted_name_is_unknown() -> void:
    var text := JSON.stringify([{
        "id": 0, "name": "mystery", "durability": 0,
        "solid": false, "pushable": false, "conductive": false, "container": false,
        "emits_sound": false, "gravity": false, "flammable": false, "liquid": false,
    }])
    var registry := BlockRegistry.from_text(text)
    assert_object(registry).is_not_null()
    _assert_color(Palette.color_for(registry, 0), Palette.UNKNOWN, "mystery")


# --- dim ---

func test_dim_scales_rgb_and_keeps_alpha() -> void:
    var c := Color(1.0, 0.5, 0.2, 0.8)
    var d := Palette.dim(c)
    assert_float(d.r).is_equal_approx(1.0 * Palette.FLOOR_DIM, 0.0001)
    assert_float(d.g).is_equal_approx(0.5 * Palette.FLOOR_DIM, 0.0001)
    assert_float(d.b).is_equal_approx(0.2 * Palette.FLOOR_DIM, 0.0001)
    assert_float(d.a).is_equal_approx(0.8, 0.0001)
    assert_float(Palette.FLOOR_DIM).is_equal_approx(0.55, 0.0001)


func test_dim_of_opaque_stays_opaque_and_of_transparent_stays_transparent() -> void:
    assert_float(Palette.dim(Color(0.3, 0.3, 0.3, 1.0)).a).is_equal(1.0)
    assert_float(Palette.dim(Palette.VOID).a).is_equal(0.0)


# --- 키 집합 = blocks.json 이름 집합 (양방향) ---

func test_palette_keys_equal_block_names() -> void:
    var registry := _registry()
    var names: Dictionary = {}
    for id in registry.count():
        names[registry.name_of(id)] = true
    # 표 → 팔레트: 모든 블록 이름이 팔레트에 있다.
    for name: String in names.keys():
        assert_bool(Palette.NAME_TO_COLOR.has(name)).override_failure_message(
            "blocks.json 의 '%s' 가 Palette.NAME_TO_COLOR 에 없다" % name
        ).is_true()
    # 팔레트 → 표: 팔레트에 남는 이름이 없다.
    for key: String in Palette.NAME_TO_COLOR.keys():
        assert_bool(names.has(key)).override_failure_message(
            "Palette.NAME_TO_COLOR 의 '%s' 가 blocks.json 에 없다" % key
        ).is_true()
    assert_int(Palette.NAME_TO_COLOR.size()).is_equal(registry.count())


# --- 상수 구별 ---

func test_special_colors_are_distinct() -> void:
    assert_float(Palette.VOID.a).is_equal(0.0)
    assert_float(Palette.BEDROCK.a).is_equal(1.0)
    assert_bool(Palette.BEDROCK.is_equal_approx(Palette.UNKNOWN)).is_false()
    assert_bool(Palette.BEDROCK.is_equal_approx(Palette.VOID)).is_false()
    var registry := _registry()
    for id in registry.count():
        assert_bool(Palette.color_for(registry, id).is_equal_approx(Palette.BEDROCK)).override_failure_message(
            "id %d 색이 BEDROCK 과 같다" % id
        ).is_false()


# --- 플레이어 색 (블록이 아니다 — NAME_TO_COLOR 밖) ---

func test_player_color_is_opaque_and_bright() -> void:
    assert_float(Palette.PLAYER.a).is_equal(1.0)
    assert_float(Palette.PLAYER.v).is_greater_equal(0.8)


func test_player_facing_is_white() -> void:
    _assert_color(Palette.PLAYER_FACING, Color(1.0, 1.0, 1.0), "PLAYER_FACING")
    assert_float(Palette.PLAYER_FACING.a).is_equal(1.0)


func test_player_colors_are_not_block_colors() -> void:
    assert_bool(Palette.PLAYER.is_equal_approx(Palette.PLAYER_FACING)).is_false()
    for key: String in Palette.NAME_TO_COLOR.keys():
        var c: Color = Palette.NAME_TO_COLOR[key]
        assert_bool(c.is_equal_approx(Palette.PLAYER)).override_failure_message(
            "'%s' 색이 PLAYER 와 같다" % key
        ).is_false()
        assert_bool(c.is_equal_approx(Palette.PLAYER_FACING)).override_failure_message(
            "'%s' 색이 PLAYER_FACING 과 같다" % key
        ).is_false()
    for special: Color in [Palette.BEDROCK, Palette.VOID, Palette.UNKNOWN]:
        assert_bool(special.is_equal_approx(Palette.PLAYER)).is_false()
        assert_bool(special.is_equal_approx(Palette.PLAYER_FACING)).is_false()


# --- Node 아님 ---

func test_palette_is_not_a_node() -> void:
    var p: Variant = Palette.new()
    assert_str(p.get_class()).is_equal("RefCounted")
    assert_bool(p is Node).is_false()
