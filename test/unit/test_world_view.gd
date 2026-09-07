extends GdUnitTestSuite

## WorldView 검증: build_cells 의 빈 경우, 크기·형태, 순서, 층별 색 규칙 ①~④, 층 클램프,
## 결정성, focus_position(플레이어 발 위치 추적), follow_player_layer, build_player_marker,
## 캐시(활성 층 | 인스턴스 | revision), view→sim 소스 가드(res://view 전체 순회), Node2D 이되 sim
## 클래스 아님.
##
## build_cells·build_player_marker 는 트리 밖에서 동작한다 — add_child 하지 않는다.
## 단위 테스트에서만 허용되는 상태 직접 조작(place_at, player.layer 대입, set_id_at)은 주석으로 표시한다.

const SEED := 20250901
const CELLS_PER_LAYER := 25 * Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE  # 6400
const SPAWN := Vector2i(8, 8)

## view→sim 가드가 순회하는 디렉터리와, `submit(`·`Input.` 이 유일하게 허용되는 파일.
const VIEW_DIR := "res://view"
const MAIN_SOURCE := "res://view/main.gd"


func _view(seed := SEED) -> WorldView:
    var view: WorldView = auto_free(WorldView.new())
    var sim := Simulation.create_default(seed)
    assert_object(sim).is_not_null()
    view.simulation = sim
    return view


## 첫 틱을 돌려 스폰 (8,8) 청크 (0,0) 중심으로 25 청크를 로드한 뒤 돌려준다.
func _loaded_view(seed := SEED) -> WorldView:
    var view := _view(seed)
    view.simulation.step()
    assert_int(view.simulation.state.chunks.loaded_count()).is_equal(25)
    return view


## build_cells 결과를 [Vector2i → Color] 로.
func _cell_map(cells: Array) -> Dictionary:
    var map: Dictionary = {}
    for cell: Array in cells:
        map[Vector2i(cell[0], cell[1])] = cell[2]
    return map


func _assert_color(actual: Color, expected: Color, label: String) -> void:
    assert_bool(actual.is_equal_approx(expected)).override_failure_message(
        "%s: %s != %s" % [label, actual, expected]
    ).is_true()


## 청크 (0,0) 안에서 [param layer] 가 air 인 첫 로컬 좌표. 없으면 (-1,-1).
func _first_air_local(chunk: Chunk, layer: int) -> Vector2i:
    for y in Chunk.CHUNK_SIZE:
        for x in Chunk.CHUNK_SIZE:
            if chunk.get_id(x, y, layer) == 0:
                return Vector2i(x, y)
    return Vector2i(-1, -1)


## 플레이어 발 칸에서 실제로 걸을 수 있는 첫 방향. sim 이 쓰는 같은 판정(resolve_walk)으로 고른다 —
## 읽기만 한다. 결정적이다(DIRECTIONS 순서 고정, 시드 고정).
func _walkable_dir(sim: Simulation) -> Vector2i:
    var feet := sim.state.player.cell()
    for dir: Vector2i in MovementRules.DIRECTIONS:
        if MovementRules.resolve_walk(sim.state.chunks, sim.registry, feet, sim.state.player.layer, dir) != feet:
            return dir
    assert_bool(false).override_failure_message("발 칸 %s 에서 걸을 방향이 없다" % feet).is_true()
    return Vector2i.ZERO


## 걷기 명령을 제출하고 한 칸(4틱) 걷는 동안 틱마다 [param on_tick] 을 부른다. 도착 칸을 돌려준다.
func _walk_one_cell(view: WorldView, on_tick: Callable) -> Vector2i:
    var sim := view.simulation
    var dir := _walkable_dir(sim)
    var start := sim.state.player.cell()
    sim.submit(MovePlayerCommand.create(dir.x, dir.y))
    for i in PlayerState.SUBUNITS / PlayerState.WALK_SPEED:
        sim.step()
        on_tick.call(i)
    assert_bool(sim.state.player.is_moving()).is_false()
    assert_bool(sim.state.player.cell() == start + dir).is_true()
    return start + dir


## 다이아몬드 4점의 중심(평균).
func _centroid(points: PackedVector2Array) -> Vector2:
    var sum := Vector2.ZERO
    for p in points:
        sum += p
    return sum / points.size()


func _assert_vec(actual: Vector2, expected: Vector2, label: String) -> void:
    assert_bool(actual.is_equal_approx(expected)).override_failure_message(
        "%s: %s != %s" % [label, actual, expected]
    ).is_true()


# --- 빈 경우 ---

func test_null_simulation_yields_empty() -> void:
    var view: WorldView = auto_free(WorldView.new())
    assert_object(view.simulation).is_null()
    assert_array(view.build_cells()).is_empty()


func test_unloaded_world_yields_empty() -> void:
    var view := _view()
    assert_int(view.simulation.state.chunks.loaded_count()).is_equal(0)
    assert_array(view.build_cells()).is_empty()


# --- 크기·형태 ---

func test_loaded_world_has_one_entry_per_cell() -> void:
    var view := _loaded_view()
    var cells := view.build_cells()
    assert_int(cells.size()).is_equal(CELLS_PER_LAYER)
    for cell: Array in cells:
        assert_int(cell.size()).is_equal(3)
        assert_int(typeof(cell[0])).is_equal(TYPE_INT)
        assert_int(typeof(cell[1])).is_equal(TYPE_INT)
        assert_int(typeof(cell[2])).is_equal(TYPE_COLOR)


# --- 순서 ---

func test_order_is_chunk_sorted_then_y_outer_x_inner() -> void:
    var view := _loaded_view()
    var cells := view.build_cells()
    # 첫 청크 (-2,-2) 의 (0,0) → 월드 (-32,-32).
    assert_int(cells[0][0]).is_equal(-32)
    assert_int(cells[0][1]).is_equal(-32)
    # 청크 안: x 안쪽 루프.
    assert_int(cells[1][0]).is_equal(-31)
    assert_int(cells[1][1]).is_equal(-32)
    # 16 번째는 다음 행.
    assert_int(cells[16][0]).is_equal(-32)
    assert_int(cells[16][1]).is_equal(-31)
    # 256 번째는 다음 청크 (-1,-2).
    assert_int(cells[256][0]).is_equal(-16)
    assert_int(cells[256][1]).is_equal(-32)
    # 5 청크(1280) 뒤는 다음 청크 행 (-2,-1).
    assert_int(cells[1280][0]).is_equal(-32)
    assert_int(cells[1280][1]).is_equal(-16)
    # 마지막은 청크 (2,2) 의 (15,15) → 월드 (47,47).
    var last: Array = cells[cells.size() - 1]
    assert_int(last[0]).is_equal(47)
    assert_int(last[1]).is_equal(47)


# --- UNDER 층 ---

func test_under_layer_is_fully_opaque_and_not_bedrock() -> void:
    var view := _loaded_view()
    view.set_active_layer(Chunk.LAYER_UNDER)
    var cells := view.build_cells()
    assert_int(cells.size()).is_equal(CELLS_PER_LAYER)
    for cell: Array in cells:
        var c: Color = cell[2]
        assert_float(c.a).override_failure_message("(%d,%d) 알파" % [cell[0], cell[1]]).is_equal(1.0)
        assert_bool(c.is_equal_approx(Palette.BEDROCK)).override_failure_message(
            "(%d,%d) 가 BEDROCK" % [cell[0], cell[1]]
        ).is_false()


func test_under_layer_air_cell_is_bedrock() -> void:
    var view := _loaded_view()
    view.set_active_layer(Chunk.LAYER_UNDER)
    var chunk := view.simulation.state.chunks.get_chunk(0, 0)
    assert_bool(chunk.set_id(3, 3, Chunk.LAYER_UNDER, 0, 0)).is_true()
    var map := _cell_map(view.build_cells())
    _assert_color(map[Vector2i(3, 3)], Palette.BEDROCK, "(3,3) 뚫린 UNDER")
    # 이웃은 여전히 블록 색.
    assert_bool(map[Vector2i(4, 3)].is_equal_approx(Palette.BEDROCK)).is_false()


# --- GROUND 층 ---

func test_ground_layer_rules_one_and_three() -> void:
    var view := _loaded_view()
    assert_int(view.active_layer).is_equal(Chunk.LAYER_GROUND)
    var registry := view.simulation.registry
    var chunks := view.simulation.state.chunks
    var air_count := 0
    var block_count := 0
    for cell: Array in view.build_cells():
        var wx: int = cell[0]
        var wy: int = cell[1]
        var color: Color = cell[2]
        var id := chunks.get_id_at(wx, wy, Chunk.LAYER_GROUND)
        if id != 0:
            block_count += 1
            _assert_color(color, Palette.color_for(registry, id), "규칙① (%d,%d)" % [wx, wy])
        else:
            air_count += 1
            var below_id := chunks.get_id_at(wx, wy, Chunk.LAYER_UNDER)
            assert_bool(registry.has_at(below_id, BlockRegistry.ATTR_SOLID)).is_true()
            _assert_color(color, Palette.dim(Palette.color_for(registry, below_id)), "규칙③ (%d,%d)" % [wx, wy])
            assert_float(color.a).is_equal(1.0)
    assert_int(air_count).is_greater(0)
    assert_int(block_count).is_greater(0)


func test_ground_layer_air_over_hole_is_void() -> void:
    var view := _loaded_view()
    var chunk := view.simulation.state.chunks.get_chunk(0, 0)
    var local := _first_air_local(chunk, Chunk.LAYER_GROUND)
    assert_bool(local.x >= 0).override_failure_message("청크 (0,0) GROUND 에 air 가 없다").is_true()
    var before := _cell_map(view.build_cells())
    assert_float(before[local].a).is_equal(1.0)
    assert_bool(chunk.set_id(local.x, local.y, Chunk.LAYER_UNDER, 0, 0)).is_true()
    var after := _cell_map(view.build_cells())
    _assert_color(after[local], Palette.VOID, "규칙④ %s" % local)
    assert_float(after[local].a).is_equal(0.0)


# --- UPPER 층 ---

func test_upper_layer_floor_and_void() -> void:
    var view := _loaded_view()
    view.set_active_layer(Chunk.LAYER_UPPER)
    var registry := view.simulation.registry
    var chunks := view.simulation.state.chunks
    var floor_count := 0
    var void_count := 0
    for cell: Array in view.build_cells():
        var wx: int = cell[0]
        var wy: int = cell[1]
        var color: Color = cell[2]
        # 생성기는 UPPER 에 블록을 놓지 않는다.
        assert_int(chunks.get_id_at(wx, wy, Chunk.LAYER_UPPER)).is_equal(0)
        var ground_id := chunks.get_id_at(wx, wy, Chunk.LAYER_GROUND)
        if registry.has_at(ground_id, BlockRegistry.ATTR_SOLID):
            floor_count += 1
            _assert_color(color, Palette.dim(Palette.color_for(registry, ground_id)), "UPPER 바닥 (%d,%d)" % [wx, wy])
        else:
            void_count += 1
            _assert_color(color, Palette.VOID, "UPPER VOID (%d,%d)" % [wx, wy])
    assert_int(floor_count).is_greater(0)
    assert_int(void_count).is_greater(0)


# --- 층 클램프 ---

func test_set_active_layer_clamps() -> void:
    var view := _view()
    view.set_active_layer(-1)
    assert_int(view.active_layer).is_equal(0)
    view.set_active_layer(5)
    assert_int(view.active_layer).is_equal(Chunk.LAYERS - 1)
    view.set_active_layer(Chunk.LAYER_GROUND)
    assert_int(view.active_layer).is_equal(1)


# --- 결정성 ---

func test_build_cells_is_deterministic() -> void:
    var view := _loaded_view()
    var a := view.build_cells()
    var b := view.build_cells()
    assert_int(a.size()).is_equal(b.size())
    for i in a.size():
        assert_int(a[i][0]).is_equal(b[i][0])
        assert_int(a[i][1]).is_equal(b[i][1])
        assert_bool((a[i][2] as Color).is_equal_approx(b[i][2])).is_true()
    # 다른 인스턴스, 같은 시드도 같다.
    var other := _loaded_view()
    var c := other.build_cells()
    for i in a.size():
        assert_bool((a[i][2] as Color).is_equal_approx(c[i][2])).is_true()


## build_cells 는 상태를 바꾸지 않는다 — 해시가 같다.
func test_build_cells_does_not_change_state_hash() -> void:
    var view := _loaded_view()
    var before := view.simulation.state_hash()
    view.build_cells()
    view.set_active_layer(Chunk.LAYER_UPPER)
    view.build_cells()
    view.focus_position()
    view.follow_player_layer()
    WorldView.build_player_marker(view.simulation.state.player.sub, Vector2i(0, 1), Chunk.LAYER_GROUND, Chunk.LAYER_GROUND)
    assert_str(view.simulation.state_hash()).is_equal(before)


# --- focus_position: 플레이어 발 칸 다이아몬드 중심 ---

func test_focus_position_null_simulation_is_zero() -> void:
    var empty: WorldView = auto_free(WorldView.new())
    _assert_vec(empty.focus_position(), Vector2.ZERO, "null focus")


func test_focus_position_is_spawn_foot_cell_center() -> void:
    var view := _view()
    _assert_vec(view.focus_position(), IsoProjection.cell_center(SPAWN.x, SPAWN.y), "틱 전")
    view.simulation.step()
    _assert_vec(view.focus_position(), IsoProjection.cell_center(SPAWN.x, SPAWN.y), "첫 틱 뒤")
    # 로드 중심과 무관하게 발 위치다: 다른 청크에 세우면 그 칸 중심.
    # 단위 테스트에서만 허용되는 상태 직접 조작.
    view.simulation.state.player.place_at(Vector2i(-8, 40), Chunk.LAYER_GROUND)
    _assert_vec(view.focus_position(), IsoProjection.cell_center(-8, 40), "옮긴 뒤")


func test_focus_position_slides_every_tick_while_walking_and_lands_on_next_cell() -> void:
    var view := _loaded_view()
    var seen: Array[Vector2] = [view.focus_position()]
    var dest := _walk_one_cell(view, func(_i: int) -> void:
        var now := view.focus_position()
        assert_bool(now.is_equal_approx(seen[seen.size() - 1])).override_failure_message(
            "틱 %d 에 focus 가 안 움직였다: %s" % [seen.size(), now]).is_false()
        # 항상 발 서브유닛의 투영 + 다이아몬드 중심 오프셋이다.
        _assert_vec(now, IsoProjection.sub_to_screen(view.simulation.state.player.sub)
            + Vector2(0.0, IsoProjection.TILE_H / 2.0), "틱 %d" % seen.size())
        seen.append(now))
    assert_int(seen.size()).is_equal(5)
    _assert_vec(view.focus_position(), IsoProjection.cell_center(dest.x, dest.y), "도착")
    # 걷는 동안 모든 값이 서로 다르다.
    for i in seen.size():
        for j in seen.size():
            if i != j:
                assert_bool(seen[i].is_equal_approx(seen[j])).is_false()


# --- follow_player_layer ---

func test_follow_player_layer_first_call_matches_player_layer() -> void:
    var view := _view()
    view.set_active_layer(Chunk.LAYER_UPPER)
    assert_int(view.active_layer).is_equal(Chunk.LAYER_UPPER)
    view.follow_player_layer()
    assert_int(view.active_layer).is_equal(view.simulation.state.player.layer)
    assert_int(view.active_layer).is_equal(Chunk.LAYER_GROUND)


func test_follow_player_layer_keeps_peek_while_player_layer_unchanged() -> void:
    var view := _view()
    view.follow_player_layer()
    # Q/E 엿보기.
    view.set_active_layer(Chunk.LAYER_UNDER)
    view.follow_player_layer()
    view.simulation.step()
    view.follow_player_layer()
    assert_int(view.active_layer).is_equal(Chunk.LAYER_UNDER)
    assert_int(view.simulation.state.player.layer).is_equal(Chunk.LAYER_GROUND)


func test_follow_player_layer_tracks_player_layer_change() -> void:
    var view := _view()
    view.follow_player_layer()
    view.set_active_layer(Chunk.LAYER_UNDER)
    # 층 변경: 단위 테스트에서만 허용되는 상태 직접 조작(M1 에는 층을 바꾸는 명령이 없다).
    view.simulation.state.player.layer = Chunk.LAYER_UPPER
    view.follow_player_layer()
    assert_int(view.active_layer).is_equal(Chunk.LAYER_UPPER)
    # 그 뒤 엿봐도 층이 그대로면 되돌리지 않는다.
    view.set_active_layer(Chunk.LAYER_GROUND)
    view.follow_player_layer()
    assert_int(view.active_layer).is_equal(Chunk.LAYER_GROUND)
    # 다시 바뀌면 따라간다. 테스트에서만 허용.
    view.simulation.state.player.layer = Chunk.LAYER_UNDER
    view.follow_player_layer()
    assert_int(view.active_layer).is_equal(Chunk.LAYER_UNDER)


func test_follow_player_layer_without_simulation_does_nothing() -> void:
    var empty: WorldView = auto_free(WorldView.new())
    empty.set_active_layer(Chunk.LAYER_UPPER)
    empty.follow_player_layer()
    assert_int(empty.active_layer).is_equal(Chunk.LAYER_UPPER)


# --- build_player_marker (P4 상태는 보인다) ---

func test_player_marker_is_empty_on_other_layer() -> void:
    var sub := PlayerState.sub_of(SPAWN)
    assert_array(WorldView.build_player_marker(sub, Vector2i(0, 1), Chunk.LAYER_GROUND, Chunk.LAYER_UPPER)).is_empty()
    assert_array(WorldView.build_player_marker(sub, Vector2i(0, 1), Chunk.LAYER_UNDER, Chunk.LAYER_GROUND)).is_empty()
    assert_array(WorldView.build_player_marker(sub, Vector2i(0, 1), Chunk.LAYER_GROUND, Chunk.LAYER_GROUND)).is_not_empty()


func test_player_marker_body_is_diamond_rising_from_foot() -> void:
    var sub := PlayerState.sub_of(SPAWN) + Vector2i(250, 0)  # 걷는 중간 위치도 그대로 투영된다.
    var marker := WorldView.build_player_marker(sub, Vector2i(0, 1), Chunk.LAYER_GROUND, Chunk.LAYER_GROUND)
    assert_int(marker.size()).is_equal(2)
    var body: PackedVector2Array = marker[0]
    var dot: PackedVector2Array = marker[1]
    assert_int(body.size()).is_equal(4)
    assert_int(dot.size()).is_equal(4)
    var foot := IsoProjection.sub_to_screen(sub) + Vector2(0.0, IsoProjection.TILE_H / 2.0)
    var w := IsoProjection.TILE_W / 4.0
    var side := -(IsoProjection.TILE_H / 4.0 + 3.0)
    _assert_vec(body[0], foot, "아래 = 발")
    _assert_vec(body[1], foot + Vector2(w, side), "오른쪽")
    _assert_vec(body[2], foot + Vector2(0.0, -(IsoProjection.TILE_H / 2.0 + 6.0)), "위")
    _assert_vec(body[3], foot + Vector2(-w, side), "왼쪽")
    # 몸은 발에서 위로만 솟는다.
    for p in body:
        assert_float(p.y).is_less_equal(foot.y)


func test_player_marker_facing_dot_is_lower_left_for_positive_y() -> void:
    var sub := PlayerState.sub_of(SPAWN)
    var facing := Vector2i(0, 1)
    var marker := WorldView.build_player_marker(sub, facing, Chunk.LAYER_GROUND, Chunk.LAYER_GROUND)
    var foot := IsoProjection.sub_to_screen(sub) + Vector2(0.0, IsoProjection.TILE_H / 2.0)
    var body_center := foot + Vector2(0.0, -(IsoProjection.TILE_H / 4.0 + 3.0))
    var dot_center := _centroid(marker[1])
    var delta := dot_center - body_center
    assert_float(delta.x).is_less(0.0)
    assert_float(delta.y).is_greater(0.0)
    _assert_vec(delta, IsoProjection.dir_to_screen(facing) * 4.0, "facing 오프셋")
    assert_float(delta.length()).is_equal_approx(4.0, 1e-4)
    # 점은 반지름 2 의 다이아몬드(top → right → bottom → left).
    _assert_vec(marker[1][0], dot_center + Vector2(0, -2), "dot top")
    _assert_vec(marker[1][1], dot_center + Vector2(2, 0), "dot right")
    _assert_vec(marker[1][2], dot_center + Vector2(0, 2), "dot bottom")
    _assert_vec(marker[1][3], dot_center + Vector2(-2, 0), "dot left")


func test_player_marker_dot_is_four_pixels_from_body_center_in_all_directions() -> void:
    var sub := PlayerState.sub_of(Vector2i(-3, 7))
    var foot := IsoProjection.sub_to_screen(sub) + Vector2(0.0, IsoProjection.TILE_H / 2.0)
    var body_center := foot + Vector2(0.0, -(IsoProjection.TILE_H / 4.0 + 3.0))
    var centers: Array[Vector2] = []
    for facing: Vector2i in MovementRules.DIRECTIONS:
        var marker := WorldView.build_player_marker(sub, facing, Chunk.LAYER_UNDER, Chunk.LAYER_UNDER)
        var delta := _centroid(marker[1]) - body_center
        assert_float(delta.length()).override_failure_message("%s" % facing).is_equal_approx(4.0, 1e-4)
        _assert_vec(delta, IsoProjection.dir_to_screen(facing) * 4.0, "facing %s" % facing)
        # 몸 중심은 facing 과 무관하다.
        _assert_vec(_centroid(marker[0]), body_center, "몸 %s" % facing)
        centers.append(_centroid(marker[1]))
    # 8방향의 점은 서로 다르다.
    for i in centers.size():
        for j in centers.size():
            if i != j:
                assert_bool(centers[i].is_equal_approx(centers[j])).is_false()


func test_player_marker_is_pure() -> void:
    var sub := PlayerState.sub_of(SPAWN) + Vector2i(500, 250)
    var a := WorldView.build_player_marker(sub, Vector2i(1, -1), Chunk.LAYER_GROUND, Chunk.LAYER_GROUND)
    var b := WorldView.build_player_marker(sub, Vector2i(1, -1), Chunk.LAYER_GROUND, Chunk.LAYER_GROUND)
    assert_bool(a[0] == b[0]).is_true()
    assert_bool(a[1] == b[1]).is_true()
    # 입력이 다르면 다르다.
    var c := WorldView.build_player_marker(sub + Vector2i(1, 0), Vector2i(1, -1), Chunk.LAYER_GROUND, Chunk.LAYER_GROUND)
    assert_bool(a[0] == c[0]).is_false()
    var d := WorldView.build_player_marker(sub, Vector2i(-1, 1), Chunk.LAYER_GROUND, Chunk.LAYER_GROUND)
    assert_bool(a[0] == d[0]).is_true()
    assert_bool(a[1] == d[1]).is_false()


# --- 소스 가드: view 는 sim 을 읽기만 한다 (res://view 전체 순회) ---

## view 에 있어서는 안 되는 문자열. 상태 쓰기·명령 큐·난수·해시 계산·비공개 필드·직접 생성.
func test_view_sources_do_not_mutate_sim() -> void:
    var needles: Array = [
        "set_center(", "set_value(", "set_id(", "set_id_at(", "set_durability", "erase_value(",
        "restore_snapshot(", "place_at(", "walk_to(",
        "player.sub =", "player.target =", "player.facing =", "player.layer =", "player.advance(",
        "state.player =", "state.chunks =", "state.registry =", "state.tick =",
        "clear_dirty(", "set_state(", "next_int(", "next_range(", "submit_at(", "state_hash(",
        ".queue.", "._loaded", "._snapshots", "._persist", "._values", "._ids", "._durability",
        "._dirty", "._revision",
        "randi", "randf", "compute_hash(",
        "Simulation" + ".new(",
        # 옛 로드 중심 이름. 이 파일 자신이 걸리지 않도록 이어 붙여 만든다.
        "SetLoad" + "Center", "_pending" + "_center", "load_" + "center",
    ]
    for needle: String in needles:
        var offenders := PackedStringArray()
        _collect_files_containing(VIEW_DIR, needle, offenders)
        assert_array(Array(offenders)).override_failure_message(
            "view 에 '%s' 가 있다: %s" % [needle, offenders]).is_empty()


## 명령 제출과 입력 읽기는 main.gd 에만. view 전체 등장 횟수 == main.gd 등장 횟수.
func test_submit_and_input_appear_only_in_main() -> void:
    for needle: String in ["submit(", "Input."]:
        var in_view := _count_in_dir(VIEW_DIR, needle)
        var in_main := _count_in_file(MAIN_SOURCE, needle)
        assert_int(in_view).override_failure_message(
            "'%s' 가 main.gd 밖의 view 에 있다 (view %d, main %d)" % [needle, in_view, in_main]
        ).is_equal(in_main)
    assert_int(_count_in_file(MAIN_SOURCE, "submit(")).is_greater(0)


func _count_in_file(path: String, needle: String) -> int:
    assert_bool(FileAccess.file_exists(path)).override_failure_message(path).is_true()
    return FileAccess.get_file_as_string(path).count(needle)


func _count_in_dir(dir_path: String, needle: String) -> int:
    var total := 0
    var dir := DirAccess.open(dir_path)
    assert_object(dir).is_not_null()
    if dir == null:
        return 0
    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        var path := dir_path.path_join(entry)
        if dir.current_is_dir():
            total += _count_in_dir(path, needle)
        elif entry.get_extension() == "gd":
            total += FileAccess.get_file_as_string(path).count(needle)
        entry = dir.get_next()
    dir.list_dir_end()
    return total


func _collect_files_containing(dir_path: String, needle: String, offenders: PackedStringArray) -> void:
    var dir := DirAccess.open(dir_path)
    assert_object(dir).is_not_null()
    if dir == null:
        return
    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        var path := dir_path.path_join(entry)
        if dir.current_is_dir():
            _collect_files_containing(path, needle, offenders)
        elif entry.get_extension() == "gd":
            if FileAccess.get_file_as_string(path).contains(needle):
                offenders.append(path)
        entry = dir.get_next()
    dir.list_dir_end()


# --- Node2D 이되 sim 클래스 아님 ---

func test_world_view_is_node2d_not_sim() -> void:
    var view: Variant = auto_free(WorldView.new())
    assert_bool(view is Node2D).is_true()
    assert_bool(view is RefCounted).is_false()
    assert_bool(ClassDB.is_parent_class(view.get_class(), "Node2D")).is_true()
    assert_bool(view is Chunk).is_false()
    assert_bool(view is ChunkWorld).is_false()
    assert_bool(view is WorldState).is_false()
    assert_bool(view is Simulation).is_false()


# --- 캐시: _cells_for_draw 는 `층 | 인스턴스 | revision` 이 같으면 같은 인스턴스 ---

func test_cells_for_draw_returns_same_instance_while_state_unchanged() -> void:
    var view := _loaded_view()
    var a: Array = view._cells_for_draw()
    var b: Array = view._cells_for_draw()
    assert_bool(is_same(a, b)).override_failure_message("캐시 히트가 같은 Array 인스턴스가 아니다").is_true()
    # 내용은 build_cells 와 같다.
    var fresh := view.build_cells()
    assert_int(a.size()).is_equal(fresh.size())
    for i in a.size():
        assert_int(a[i][0]).is_equal(fresh[i][0])
        assert_int(a[i][1]).is_equal(fresh[i][1])
        assert_bool((a[i][2] as Color).is_equal_approx(fresh[i][2])).is_true()


func test_cells_for_draw_rebuilds_after_chunk_center_moves() -> void:
    var view := _loaded_view()
    var a: Array = view._cells_for_draw()
    # 청크 이동: 단위 테스트에서만 허용되는 상태 직접 조작. 다음 틱의 동기화가 중심을 (1,0) 으로 옮긴다.
    view.simulation.state.player.place_at(Vector2i(24, 8), Chunk.LAYER_GROUND)
    view.simulation.step()
    var c: Array = view._cells_for_draw()
    assert_bool(is_same(a, c)).override_failure_message("상태가 바뀌었는데 캐시를 돌려줬다").is_false()
    assert_int(c.size()).is_equal(CELLS_PER_LAYER)
    # 새 중심 (1,0): 첫 청크 (-1,-2) 의 (0,0) → 월드 (-16,-32).
    assert_int(c[0][0]).is_equal(-16)
    assert_int(c[0][1]).is_equal(-32)
    # 한 번 더 부르면 다시 히트.
    assert_bool(is_same(c, view._cells_for_draw())).is_true()


func test_cells_for_draw_rebuilds_after_layer_change() -> void:
    var view := _loaded_view()
    var ground: Array = view._cells_for_draw()
    view.set_active_layer(Chunk.LAYER_UNDER)
    var under: Array = view._cells_for_draw()
    assert_bool(is_same(ground, under)).is_false()
    for cell: Array in under:
        assert_float((cell[2] as Color).a).is_equal(1.0)
    # 같은 층으로 set 해도 실제 변경이 없으면 히트.
    view.set_active_layer(Chunk.LAYER_UNDER)
    assert_bool(is_same(under, view._cells_for_draw())).is_true()


## 걷는 동안(청크 경계 안, 블록 변경 없음) revision 이 그대로라 캐시가 유지된다 — 틱마다 SHA 를 안 센다.
func test_cells_for_draw_stays_cached_while_walking() -> void:
    var view := _loaded_view()
    var a: Array = view._cells_for_draw()
    var rev := view.simulation.state.chunks.revision()
    _walk_one_cell(view, func(i: int) -> void:
        assert_bool(is_same(a, view._cells_for_draw())).override_failure_message(
            "걷는 틱 %d 에 캐시가 깨졌다" % i).is_true()
        assert_int(view.simulation.state.chunks.revision()).is_equal(rev))
    assert_bool(view.simulation.state.chunks.center() == Vector2i(0, 0)).is_true()


func test_cells_for_draw_rebuilds_after_loaded_chunk_edit() -> void:
    var view := _loaded_view()
    var a: Array = view._cells_for_draw()
    var chunks := view.simulation.state.chunks
    var rev := chunks.revision()
    # 블록 편집: 단위 테스트에서만 허용되는 상태 직접 조작. 지하 (8,8) 을 뚫어 지상 (8,8) 이 VOID 가 된다.
    assert_int(chunks.get_id_at(SPAWN.x, SPAWN.y, Chunk.LAYER_UNDER)).is_not_equal(0)
    assert_bool(chunks.set_id_at(SPAWN.x, SPAWN.y, Chunk.LAYER_UNDER, 0, 0)).is_true()
    assert_int(chunks.revision()).is_greater(rev)
    var b: Array = view._cells_for_draw()
    assert_bool(is_same(a, b)).override_failure_message("청크가 바뀌었는데 캐시를 돌려줬다").is_false()
    var map := _cell_map(b)
    _assert_color(map[SPAWN], Palette.VOID, "뚫린 (8,8)")
    # 같은 값을 다시 쓰면 변경이 아니라(set_id 가 false) revision 이 그대로 — 히트.
    var rev_after := chunks.revision()
    assert_bool(chunks.set_id_at(SPAWN.x, SPAWN.y, Chunk.LAYER_UNDER, 0, 0)).is_false()
    assert_int(chunks.revision()).is_equal(rev_after)
    assert_bool(is_same(b, view._cells_for_draw())).is_true()


## 같은 시드의 Simulation 둘은 revision 이 같지만 인스턴스가 다르니 키가 달라야 한다(M1-10 재주입 대비).
func test_cells_for_draw_key_distinguishes_simulation_instances() -> void:
    var view := _loaded_view()
    var a_sim := view.simulation
    var b_sim := Simulation.create_default(SEED)
    b_sim.step()
    assert_int(b_sim.state.chunks.revision()).is_equal(a_sim.state.chunks.revision())
    var a: Array = view._cells_for_draw()
    view.simulation = b_sim
    var b: Array = view._cells_for_draw()
    assert_bool(is_same(a, b)).override_failure_message("다른 인스턴스인데 캐시를 돌려줬다").is_false()
    view.simulation = a_sim
    var a2: Array = view._cells_for_draw()
    assert_bool(is_same(a2, b)).is_false()
    # 내용은 같다(같은 시드).
    assert_int(a2.size()).is_equal(b.size())
    for i in a2.size():
        assert_bool((a2[i][2] as Color).is_equal_approx(b[i][2])).is_true()


func test_cells_for_draw_null_simulation_is_empty_and_does_not_change_hash() -> void:
    var empty: WorldView = auto_free(WorldView.new())
    assert_array(empty._cells_for_draw()).is_empty()
    var view := _loaded_view()
    var before := view.simulation.state_hash()
    view._cells_for_draw()
    view.set_active_layer(Chunk.LAYER_UPPER)
    view._cells_for_draw()
    assert_str(view.simulation.state_hash()).is_equal(before)


# --- 삼각형 배열: VOID 제외, 셀당 꼭짓점 4·인덱스 6 ---

func test_build_triangles_empty_input() -> void:
    var tri := WorldView.build_triangles([])
    assert_int(tri.size()).is_equal(3)
    assert_int((tri[0] as PackedInt32Array).size()).is_equal(0)
    assert_int((tri[1] as PackedVector2Array).size()).is_equal(0)
    assert_int((tri[2] as PackedColorArray).size()).is_equal(0)


func test_build_triangles_skips_void_and_counts_match() -> void:
    var view := _loaded_view()
    view.set_active_layer(Chunk.LAYER_UPPER)  # 바닥과 VOID 가 섞인 층.
    var cells := view.build_cells()
    var opaque := 0
    for cell: Array in cells:
        if (cell[2] as Color).a > 0.0:
            opaque += 1
    assert_int(opaque).is_greater(0)
    assert_int(opaque).is_less(cells.size())
    var tri := WorldView.build_triangles(cells)
    var indices: PackedInt32Array = tri[0]
    var points: PackedVector2Array = tri[1]
    var colors: PackedColorArray = tri[2]
    assert_int(indices.size()).is_equal(6 * opaque)
    assert_int(points.size()).is_equal(4 * opaque)
    assert_int(colors.size()).is_equal(4 * opaque)
    for idx in indices:
        assert_bool(idx >= 0 and idx < points.size()).is_true()
    for c in colors:
        assert_float(c.a).is_greater(0.0)


func test_build_triangles_geometry_matches_diamond() -> void:
    var cells: Array = [
        [3, -2, Color(1, 0, 0)],
        [0, 0, Palette.VOID],       # 건너뜀
        [-5, 7, Color(0, 1, 0)],
    ]
    var tri := WorldView.build_triangles(cells)
    var indices: PackedInt32Array = tri[0]
    var points: PackedVector2Array = tri[1]
    var colors: PackedColorArray = tri[2]
    assert_int(points.size()).is_equal(8)
    assert_int(indices.size()).is_equal(12)
    var d0 := IsoProjection.diamond(3, -2)
    var d1 := IsoProjection.diamond(-5, 7)
    for k in 4:
        assert_bool(points[k].is_equal_approx(d0[k])).override_failure_message("셀0 꼭짓점 %d" % k).is_true()
        assert_bool(points[4 + k].is_equal_approx(d1[k])).override_failure_message("셀1 꼭짓점 %d" % k).is_true()
        assert_bool(colors[k].is_equal_approx(Color(1, 0, 0))).is_true()
        assert_bool(colors[4 + k].is_equal_approx(Color(0, 1, 0))).is_true()
    # 두 삼각형 (0,1,2), (0,2,3) — 다이아몬드 대각선 top→bottom 으로 분할.
    assert_array(Array(indices.slice(0, 6))).is_equal([0, 1, 2, 0, 2, 3])
    assert_array(Array(indices.slice(6, 12))).is_equal([4, 5, 6, 4, 6, 7])


func test_build_triangles_is_deterministic() -> void:
    var view := _loaded_view()
    var cells := view.build_cells()
    var a := WorldView.build_triangles(cells)
    var b := WorldView.build_triangles(cells)
    assert_bool((a[0] as PackedInt32Array) == (b[0] as PackedInt32Array)).is_true()
    assert_bool((a[1] as PackedVector2Array) == (b[1] as PackedVector2Array)).is_true()
    assert_bool((a[2] as PackedColorArray) == (b[2] as PackedColorArray)).is_true()
    # 지상층은 전부 불투명 → 6400 셀 × 6.
    assert_int((a[0] as PackedInt32Array).size()).is_equal(6 * CELLS_PER_LAYER)
