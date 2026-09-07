extends GdUnitTestSuite

## WorldView 검증: build_cells 의 빈 경우, 크기·형태, 순서, 층별 색 규칙 ①~④, 층 클램프,
## 결정성, focus_cell, 소스 가드(sim 을 바꾸지 않음), Node2D 이되 sim 클래스 아님.
##
## build_cells 는 트리 밖에서 동작한다 — add_child 하지 않는다.

const SEED := 20250901
const CELLS_PER_LAYER := 25 * Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE  # 6400

const VIEW_SOURCES: Array = [
    "res://view/world_view.gd",
    "res://view/palette.gd",
    "res://view/iso_projection.gd",
]


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
    view.focus_cell()
    assert_str(view.simulation.state_hash()).is_equal(before)


# --- focus_cell ---

func test_focus_cell() -> void:
    var empty: WorldView = auto_free(WorldView.new())
    assert_bool(empty.focus_cell() == Vector2i(0, 0)).is_true()

    var view := _view()
    assert_bool(view.focus_cell() == Vector2i(8, 8)).is_true()

    view.simulation.step()
    assert_bool(view.focus_cell() == Vector2i(8, 8)).is_true()

    # 청크 이동: 단위 테스트에서만 허용되는 상태 직접 조작. 다음 틱의 동기화가 중심을 옮긴다.
    view.simulation.state.player.place_at(Vector2i(24, 8), Chunk.LAYER_GROUND)
    view.simulation.step()
    assert_bool(view.simulation.state.chunks.center() == Vector2i(1, 0)).is_true()
    assert_bool(view.focus_cell() == Vector2i(24, 8)).is_true()

    view.simulation.state.player.place_at(Vector2i(-8, 40), Chunk.LAYER_GROUND)
    view.simulation.step()
    assert_bool(view.simulation.state.chunks.center() == Vector2i(-1, 2)).is_true()
    assert_bool(view.focus_cell() == Vector2i(-8, 40)).is_true()


# --- 소스 가드: view 는 sim 을 읽기만 한다 ---

func test_view_sources_do_not_mutate_sim() -> void:
    for path: String in VIEW_SOURCES:
        assert_bool(FileAccess.file_exists(path)).override_failure_message(path).is_true()
        var source := FileAccess.get_file_as_string(path)
        for token: String in ["submit(", "set_center(", "set_value(", "state.tick", "randi", "randf", "set_id(", "set_durability("]:
            assert_bool(source.contains(token)).override_failure_message(
                "%s 에 '%s' 가 있다" % [path, token]
            ).is_false()


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


# --- 캐시: _cells_for_draw 는 `층 | 청크 해시` 가 같으면 같은 인스턴스 ---

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
