extends GdUnitTestSuite

## 아이소 투영 검증: 상수 비율, top 기준 정의(원점·축·음수), 다이아몬드 네 점, 왕복(중심·오프셋),
## 서브유닛 투영(칸 원점 일치·칸 중심), 방향 투영(8방향 단위·위/오른쪽 키·ZERO), Node 아님.

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


# --- 서브유닛 투영 ---

## 8×8 격자(음수 포함): 칸 원점 서브유닛의 투영 == 그 칸의 top.
func test_sub_to_screen_matches_cell_to_screen_on_grid() -> void:
    for wx in range(-4, 4):
        for wy in range(-4, 4):
            var sub := PlayerState.sub_of(Vector2i(wx, wy))
            _assert_vec(
                IsoProjection.sub_to_screen(sub),
                IsoProjection.cell_to_screen(wx, wy),
                "sub(%d,%d)" % [wx, wy],
            )


func test_sub_to_screen_origin_is_zero() -> void:
    _assert_vec(IsoProjection.sub_to_screen(Vector2i.ZERO), Vector2.ZERO, "sub origin")


## 칸 한가운데 (500,500) 은 top 에서 (0, H/2) 아래 = cell_center.
func test_sub_to_screen_half_cell_is_cell_center() -> void:
    var half := PlayerState.SUBUNITS / 2
    _assert_vec(IsoProjection.sub_to_screen(Vector2i(half, half)), Vector2(0, H / 2.0), "half(0,0)")
    var base := PlayerState.sub_of(Vector2i(3, -2))
    _assert_vec(
        IsoProjection.sub_to_screen(base + Vector2i(half, half)),
        IsoProjection.cell_center(3, -2),
        "half(3,-2)",
    )


## 서브유닛 한 축 이동은 칸 이동을 SUBUNITS 로 나눈 만큼 화면에서 움직인다(선형).
func test_sub_to_screen_is_linear_in_subunits() -> void:
    var quarter := PlayerState.SUBUNITS / 4
    var expected := IsoProjection.cell_to_screen(1, 0) / 4.0
    _assert_vec(IsoProjection.sub_to_screen(Vector2i(quarter, 0)), expected, "quarter +x")


# --- 방향 투영 ---

func test_dir_to_screen_eight_directions_are_unit() -> void:
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            var dir := Vector2i(dx, dy)
            if dir == Vector2i.ZERO:
                continue
            var v := IsoProjection.dir_to_screen(dir)
            assert_float(v.length()).override_failure_message(
                "dir %s 의 길이 %f" % [dir, v.length()]
            ).is_equal_approx(1.0, 1e-6)


func test_dir_to_screen_up_key_points_screen_up() -> void:
    var v := IsoProjection.dir_to_screen(Vector2i(-1, -1))
    assert_float(v.x).is_equal_approx(0.0, 1e-6)
    assert_float(v.y).is_less(0.0)


func test_dir_to_screen_right_key_points_screen_right() -> void:
    var v := IsoProjection.dir_to_screen(Vector2i(1, -1))
    assert_float(v.x).is_greater(0.0)
    assert_float(v.y).is_equal_approx(0.0, 1e-6)


func test_dir_to_screen_down_and_left_keys() -> void:
    var down := IsoProjection.dir_to_screen(Vector2i(1, 1))
    assert_float(down.x).is_equal_approx(0.0, 1e-6)
    assert_float(down.y).is_greater(0.0)
    var left := IsoProjection.dir_to_screen(Vector2i(-1, 1))
    assert_float(left.x).is_less(0.0)
    assert_float(left.y).is_equal_approx(0.0, 1e-6)


func test_dir_to_screen_zero_is_zero() -> void:
    _assert_vec(IsoProjection.dir_to_screen(Vector2i.ZERO), Vector2.ZERO, "zero dir")


# --- Node 아님 ---

func test_projection_is_not_a_node() -> void:
    var p: Variant = IsoProjection.new()
    assert_str(p.get_class()).is_equal("RefCounted")
    assert_bool(p is Node).is_false()
