extends GdUnitTestSuite

## 플레이어 상태 검증: 상수, sub/cell 왕복(음수 포함), floor_div 표, 4틱에 한 칸(직진·대각선),
## 멈춘 상태 advance 무변화, place_at, walk_to, 해시 필드, 기본값, 소스 가드, Node 아님.


func _player_at(cell: Vector2i, layer: int = Chunk.LAYER_GROUND) -> PlayerState:
    var player := PlayerState.new()
    player.place_at(cell, layer)
    return player


# --- 상수 ---

func test_walk_speed_divides_subunits_into_four_ticks() -> void:
    assert_int(PlayerState.SUBUNITS).is_equal(1000)
    assert_int(PlayerState.WALK_SPEED).is_equal(250)
    assert_int(PlayerState.SUBUNITS % PlayerState.WALK_SPEED).is_equal(0)
    assert_int(PlayerState.SUBUNITS / PlayerState.WALK_SPEED).is_equal(4)


# --- 기본값 ---

func test_defaults() -> void:
    var player := PlayerState.new()
    assert_that(player.sub).is_equal(Vector2i.ZERO)
    assert_that(player.target).is_equal(Vector2i.ZERO)
    assert_int(player.layer).is_equal(Chunk.LAYER_GROUND)
    assert_that(player.facing).is_equal(Vector2i(0, 1))
    assert_bool(player.is_moving()).is_false()
    assert_that(player.cell()).is_equal(Vector2i.ZERO)


# --- 좌표 변환 ---

func test_sub_of_scales_cell_by_subunits() -> void:
    assert_that(PlayerState.sub_of(Vector2i(0, 0))).is_equal(Vector2i(0, 0))
    assert_that(PlayerState.sub_of(Vector2i(3, -2))).is_equal(Vector2i(3000, -2000))


func test_cell_of_floors_negative_coordinates() -> void:
    assert_that(PlayerState.cell_of(Vector2i(0, 0))).is_equal(Vector2i(0, 0))
    assert_that(PlayerState.cell_of(Vector2i(999, 999))).is_equal(Vector2i(0, 0))
    assert_that(PlayerState.cell_of(Vector2i(1000, 1000))).is_equal(Vector2i(1, 1))
    assert_that(PlayerState.cell_of(Vector2i(-1, -1))).is_equal(Vector2i(-1, -1))
    assert_that(PlayerState.cell_of(Vector2i(-1000, -1000))).is_equal(Vector2i(-1, -1))
    assert_that(PlayerState.cell_of(Vector2i(-1001, 0))).is_equal(Vector2i(-2, 0))


func test_sub_cell_round_trip() -> void:
    for c: Vector2i in [Vector2i(0, 0), Vector2i(8, 8), Vector2i(-1, 5), Vector2i(-17, -33), Vector2i(1000, -1000)]:
        assert_that(PlayerState.cell_of(PlayerState.sub_of(c))).is_equal(c)


func test_floor_div_table() -> void:
    var cases: Array = [
        [0, 0], [1, 0], [999, 0], [1000, 1], [1001, 1], [1999, 1], [2000, 2],
        [-1, -1], [-999, -1], [-1000, -1], [-1001, -2], [-1999, -2], [-2000, -2], [-2001, -3],
    ]
    for c: Array in cases:
        assert_int(PlayerState.floor_div(c[0])).override_failure_message(
            "floor_div(%d) != %d" % [c[0], c[1]]
        ).is_equal(c[1])


# --- place_at / walk_to ---

func test_place_at_sets_cell_origin_and_layer() -> void:
    var player := _player_at(Vector2i(8, 8), Chunk.LAYER_UPPER)
    assert_that(player.sub).is_equal(Vector2i(8000, 8000))
    assert_that(player.target).is_equal(Vector2i(8000, 8000))
    assert_int(player.layer).is_equal(Chunk.LAYER_UPPER)
    assert_that(player.cell()).is_equal(Vector2i(8, 8))
    assert_that(player.target_cell()).is_equal(Vector2i(8, 8))
    assert_bool(player.is_moving()).is_false()


func test_place_at_clears_pending_move() -> void:
    var player := _player_at(Vector2i(0, 0))
    player.walk_to(Vector2i(1, 0))
    player.advance()
    assert_bool(player.is_moving()).is_true()
    player.place_at(Vector2i(-3, 4), Chunk.LAYER_UNDER)
    assert_bool(player.is_moving()).is_false()
    assert_that(player.sub).is_equal(Vector2i(-3000, 4000))
    assert_that(player.target).is_equal(player.sub)
    assert_int(player.layer).is_equal(Chunk.LAYER_UNDER)


func test_walk_to_sets_target_but_not_cell() -> void:
    var player := _player_at(Vector2i(2, 2))
    player.walk_to(Vector2i(3, 2))
    assert_bool(player.is_moving()).is_true()
    assert_that(player.cell()).is_equal(Vector2i(2, 2))
    assert_that(player.target_cell()).is_equal(Vector2i(3, 2))
    assert_that(player.target).is_equal(Vector2i(3000, 2000))


func test_walk_to_does_not_touch_facing_or_layer() -> void:
    var player := _player_at(Vector2i(0, 0), Chunk.LAYER_UPPER)
    player.walk_to(Vector2i(-1, 0))
    assert_that(player.facing).is_equal(Vector2i(0, 1))
    assert_int(player.layer).is_equal(Chunk.LAYER_UPPER)


# --- advance ---

func test_advance_reaches_next_cell_in_exactly_four_ticks() -> void:
    var player := _player_at(Vector2i(0, 0))
    player.walk_to(Vector2i(1, 0))
    for tick in 3:
        player.advance()
        assert_bool(player.is_moving()).override_failure_message(
            "%d틱 뒤에 이미 멈췄다" % (tick + 1)
        ).is_true()
        assert_that(player.sub).is_equal(Vector2i(250 * (tick + 1), 0))
    player.advance()
    assert_bool(player.is_moving()).is_false()
    assert_that(player.sub).is_equal(player.target)
    assert_that(player.cell()).is_equal(Vector2i(1, 0))


func test_advance_negative_direction_takes_four_ticks() -> void:
    var player := _player_at(Vector2i(0, 0))
    player.walk_to(Vector2i(0, -1))
    for tick in 3:
        player.advance()
        assert_bool(player.is_moving()).is_true()
    player.advance()
    assert_bool(player.is_moving()).is_false()
    assert_that(player.sub).is_equal(Vector2i(0, -1000))
    assert_that(player.cell()).is_equal(Vector2i(0, -1))


func test_advance_diagonal_takes_four_ticks_too() -> void:
    var player := _player_at(Vector2i(0, 0))
    player.walk_to(Vector2i(-1, 1))
    for tick in 3:
        player.advance()
        assert_bool(player.is_moving()).is_true()
        assert_that(player.sub).is_equal(Vector2i(-250 * (tick + 1), 250 * (tick + 1)))
    player.advance()
    assert_bool(player.is_moving()).is_false()
    assert_that(player.sub).is_equal(Vector2i(-1000, 1000))
    assert_that(player.cell()).is_equal(Vector2i(-1, 1))


func test_advance_when_stopped_changes_nothing() -> void:
    var player := _player_at(Vector2i(5, -5), Chunk.LAYER_UNDER)
    var before := player.to_hash_fields()
    for i in 10:
        player.advance()
    assert_array(player.to_hash_fields()).is_equal(before)
    assert_that(player.sub).is_equal(Vector2i(5000, -5000))


func test_cell_stays_at_origin_until_arrival() -> void:
    # 칸은 발 위치의 floor 다. 앞으로 갈 때는 도착 틱까지 출발 칸이다.
    var player := _player_at(Vector2i(0, 0))
    player.walk_to(Vector2i(1, 1))
    for tick in 3:
        player.advance()
        assert_that(player.cell()).is_equal(Vector2i(0, 0))
    player.advance()
    assert_that(player.cell()).is_equal(Vector2i(1, 1))


# --- 해시 필드 ---

func test_hash_fields_order_and_format() -> void:
    var player := _player_at(Vector2i(-2, 3), Chunk.LAYER_UPPER)
    player.walk_to(Vector2i(-1, 3))
    player.advance()
    player.facing = Vector2i(1, -1)
    var fields := player.to_hash_fields()
    assert_int(fields.size()).is_equal(4)
    assert_array(fields[0]).is_equal(["player.sub", "-1750,3000"])
    assert_array(fields[1]).is_equal(["player.target", "-1000,3000"])
    assert_array(fields[2]).is_equal(["player.layer", 2])
    assert_array(fields[3]).is_equal(["player.facing", "1,-1"])


func test_hash_fields_differ_when_state_differs() -> void:
    var a := _player_at(Vector2i(0, 0))
    var b := _player_at(Vector2i(0, 0))
    assert_str(SimHash.hash_fields(a.to_hash_fields())).is_equal(SimHash.hash_fields(b.to_hash_fields()))
    b.facing = Vector2i(1, 0)
    assert_str(SimHash.hash_fields(a.to_hash_fields())).is_not_equal(SimHash.hash_fields(b.to_hash_fields()))
    b.facing = Vector2i(0, 1)
    b.layer = Chunk.LAYER_UNDER
    assert_str(SimHash.hash_fields(a.to_hash_fields())).is_not_equal(SimHash.hash_fields(b.to_hash_fields()))


# --- 소스 가드 ---

func test_source_has_no_forbidden_tokens() -> void:
    var source := FileAccess.get_file_as_string("res://sim/player_state.gd")
    assert_str(source).is_not_empty()
    for token: String in ["float", "randi", "randf", "FileAccess", "JSON", "Vector3i", "HEIGHT", "FALL_SPEED", "name_of(", "_process", "delta"]:
        assert_bool(source.contains(token)).override_failure_message(
            "player_state.gd 에 금지 토큰 '%s' 가 있다" % token
        ).is_false()


# --- Node 아님 ---

func test_player_is_not_a_node() -> void:
    var player: Variant = PlayerState.new()
    assert_str(player.get_class()).is_equal("RefCounted")
    assert_bool(ClassDB.is_parent_class(player.get_class(), "Node")).is_false()
    assert_bool(player is Node).is_false()
    assert_bool(player is RefCounted).is_true()
