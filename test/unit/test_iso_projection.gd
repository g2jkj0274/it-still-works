extends GdUnitTestSuite

## 아이소 투영 검증: 상수 비율, top 기준 정의(원점·축·음수), 다이아몬드 네 점, 왕복(중심·오프셋),
## Node 아님.

const W := IsoProjection.TILE_W
const H := IsoProjection.TILE_H

## 왕복 검사 범위(정사각, 양 끝 포함).
const ROUNDTRIP_RANGE := 7


func _assert_vec(actual: Vector2, expected: Vector2, label: String) -> void:
    assert_bool(actual.is_equal_approx(expected)).override_failure_message(
        "%s: %s != %s" % [label, actual, expected]
    ).is_true()


# --- 상수 ---

func test_tile_is_two_to_one() -> void:
    assert_int(W).is_equal(2 * H)
    assert_int(W).is_equal(32)
    assert_int(H).is_equal(16)


# --- top 기준 정의 ---

func test_origin_top_is_zero() -> void:
    _assert_vec(IsoProjection.cell_to_screen(0, 0), Vector2(0, 0), "origin")


func test_axes() -> void:
    _assert_vec(IsoProjection.cell_to_screen(1, 0), Vector2(16, 8), "(1,0)")
    _assert_vec(IsoProjection.cell_to_screen(0, 1), Vector2(-16, 8), "(0,1)")
    _assert_vec(IsoProjection.cell_to_screen(1, 1), Vector2(0, 16), "(1,1)")


func test_negative_cell() -> void:
    _assert_vec(IsoProjection.cell_to_screen(-1, -1), Vector2(0, -16), "(-1,-1)")
    _assert_vec(IsoProjection.cell_to_screen(-1, 0), Vector2(-16, -8), "(-1,0)")


func test_cell_center_is_top_plus_half_height() -> void:
    _assert_vec(IsoProjection.cell_center(0, 0), Vector2(0, 8), "center(0,0)")
    _assert_vec(IsoProjection.cell_center(3, -2), IsoProjection.cell_to_screen(3, -2) + Vector2(0, 8), "center(3,-2)")


# --- 다이아몬드 ---

func test_diamond_points_clockwise_from_top() -> void:
    var d := IsoProjection.diamond(0, 0)
    assert_int(d.size()).is_equal(4)
    _assert_vec(d[0], Vector2(0, 0), "top")
    _assert_vec(d[1], Vector2(16, 8), "right")
    _assert_vec(d[2], Vector2(0, 16), "bottom")
    _assert_vec(d[3], Vector2(-16, 8), "left")


func test_diamond_is_translated_by_top() -> void:
    var top := IsoProjection.cell_to_screen(4, -3)
    var d := IsoProjection.diamond(4, -3)
    _assert_vec(d[0], top, "top")
    _assert_vec(d[1], top + Vector2(W / 2.0, H / 2.0), "right")
    _assert_vec(d[2], top + Vector2(0, H), "bottom")
    _assert_vec(d[3], top + Vector2(-W / 2.0, H / 2.0), "left")


## 다이아몬드의 네 변 중점은 인접 셀과 공유된다 — 중심이 top + (0, H/2) 라는 정의와 정합.
func test_diamond_center_matches_cell_center() -> void:
    for wx in range(-2, 3):
        for wy in range(-2, 3):
            var d := IsoProjection.diamond(wx, wy)
            var mid := (d[0] + d[2]) / 2.0
            _assert_vec(mid, IsoProjection.cell_center(wx, wy), "mid(%d,%d)" % [wx, wy])


# --- 왕복 ---

func test_roundtrip_center_all_cells() -> void:
    for wx in range(-ROUNDTRIP_RANGE, ROUNDTRIP_RANGE + 1):
        for wy in range(-ROUNDTRIP_RANGE, ROUNDTRIP_RANGE + 1):
            var c := Vector2i(wx, wy)
            var back := IsoProjection.screen_to_cell(IsoProjection.cell_center(wx, wy))
            assert_bool(back == c).override_failure_message(
                "roundtrip %s → %s" % [c, back]
            ).is_true()


func test_roundtrip_center_with_offsets() -> void:
    var offsets: Array = [
        Vector2(W / 4.0, 0), Vector2(-W / 4.0, 0),
        Vector2(0, H / 4.0), Vector2(0, -H / 4.0),
    ]
    for wx in range(-ROUNDTRIP_RANGE, ROUNDTRIP_RANGE + 1):
        for wy in range(-ROUNDTRIP_RANGE, ROUNDTRIP_RANGE + 1):
            var c := Vector2i(wx, wy)
            var center := IsoProjection.cell_center(wx, wy)
            for offset: Vector2 in offsets:
                var back := IsoProjection.screen_to_cell(center + offset)
                assert_bool(back == c).override_failure_message(
                    "roundtrip %s + %s → %s" % [c, offset, back]
                ).is_true()


## top 꼭짓점 바로 아래는 자기 셀, top 바로 위는 (wx-1, wy-1).
func test_screen_to_cell_at_top_vertex_boundary() -> void:
    var top := IsoProjection.cell_to_screen(2, 5)
    assert_bool(IsoProjection.screen_to_cell(top + Vector2(0, 1)) == Vector2i(2, 5)).is_true()
    assert_bool(IsoProjection.screen_to_cell(top - Vector2(0, 1)) == Vector2i(1, 4)).is_true()


# --- Node 아님 ---

func test_projection_is_not_a_node() -> void:
    var p: Variant = IsoProjection.new()
    assert_str(p.get_class()).is_equal("RefCounted")
    assert_bool(p is Node).is_false()
