class_name WorldView
extends Node2D

## 로드된 청크의 한 층을 아이소메트릭 다이아몬드로 그리고, 그 위에 플레이어 마커를 얹는다
## (헌법 P8 "한 화면에 한 층", P4 "상태는 보인다").
##
## sim 을 읽기만 한다. `simulation.state` 를 고치거나 명령을 제출하는 코드는 여기 없다 —
## 입력은 main 이 맡는다. [method build_cells]·[method build_player_marker] 는 순수 판단이라
## 노드 트리 밖에서도 돌고 테스트된다. [method _draw] 는 그 결과를 그리기만 한다.
##
## 바닥 규칙(DECISIONS 2026-09-06 "층 3개" 파생): 바닥 = 아래 층의 solid 칸. 지하층 아래는
## 암묵 기반암. view 코드라 `id == 0`(air) 판정은 허용된다(sim 이 아니다). 그러나 바닥 여부는
## DECISIONS 원문대로 `solid` 속성으로 묻는다 — 이름·id 로 분기하지 않으며, M6 에 액체(solid
## 아님)가 아래 층에 놓여도 바닥으로 그려지는 일을 막는다.
##
## 성능(M1-5 결함 수정): 셀 6400개를 셀마다 draw_colored_polygon 하면 드로우콜 6400. 대신 모든
## 다이아몬드를 삼각형 배열 하나로 묶어 RenderingServer 에 한 번 넘긴다([method build_triangles]).
## 셀 목록·삼각형 배열은 `활성 층 | 시뮬레이션 인스턴스 | 청크 revision` 키로 캐시하고, 키가
## 바뀔 때만 다시 만든다([method _cells_for_draw]). 캐시는 표현 상태다 — sim 에는 아무것도 쓰지
## 않는다. 플레이어 마커는 캐시하지 않는다 — 매 refresh 마다 꼭짓점 8개를 새로 계산한다.

## 주입되는 시뮬레이션. null 이면 아무것도 그리지 않는다.
var simulation: Simulation = null

## 지금 그리는 층. 기본은 지상.
var active_layer: int = Chunk.LAYER_GROUND

## [method follow_player_layer] 가 마지막으로 본 플레이어 층. 표현 상태 — 변화 감지 메모일 뿐,
## sim 으로 되먹임하지 않는다. -1 은 "아직 본 적 없음"이라 첫 호출이 무조건 맞춘다.
var _last_player_layer: int = -1

## [method _cells_for_draw] 캐시 키. "%d|%d|%d" % [active_layer, 시뮬레이션 인스턴스 id,
## chunks.revision()]. revision 은 해시 밖의 변경 표지라 SHA 계산 없이 틱마다 비교할 수 있다.
## 인스턴스 id 가 들어가는 이유: M1-10 이 새 Simulation 을 주입하면 revision 이 0 부터 다시 시작해
## 옛 키와 겹칠 수 있다. 인스턴스가 다르면 키도 달라야 한다.
var _cached_key: String = ""
var _cached_cells: Array = []
## `_cached_cells` 에서 만든 삼각형 배열 `[indices, points, colors]`. 키가 같으면 그대로 쓴다.
var _cached_triangles: Array = []


## 층을 바꾼다. 범위 밖은 클램프. 실제로 바뀔 때만 다시 그린다.
func set_active_layer(layer: int) -> void:
    var clamped := clampi(layer, 0, Chunk.LAYERS - 1)
    if clamped == active_layer:
        return
    active_layer = clamped
    refresh()


## 카메라가 볼 화면 좌표 = 플레이어 발 칸 다이아몬드의 중심. 서브유닛 위치를 그대로 투영하므로
## 걷는 동안 틱마다 미끄러진다. 시뮬레이션이 없으면 ZERO.
func focus_position() -> Vector2:
    if simulation == null:
        return Vector2.ZERO
    return IsoProjection.sub_to_screen(simulation.state.player.sub) \
        + Vector2(0.0, IsoProjection.TILE_H / 2.0)


## 플레이어 층이 바뀌었으면 활성 층을 따라간다. 첫 호출은 무조건 맞춘다. 층이 그대로면 아무것도
## 하지 않으므로 Q/E 로 다른 층을 엿본 상태는 되돌리지 않는다. 시뮬레이션이 없으면 아무것도 안 한다.
func follow_player_layer() -> void:
    if simulation == null:
        return
    var player := simulation.state.player
    if player.layer != _last_player_layer:
        set_active_layer(player.layer)
        _last_player_layer = player.layer


## 그릴 셀 목록. 각 원소 `[wx: int, wy: int, color: Color]`. 순수 판단 — 상태를 바꾸지 않는다.
##
## 순서: `chunks.loaded_sorted()`((cy, cx) 순) 청크마다 y 바깥·x 안쪽 루프. 결정적이다.
## 색 규칙(active_layer 의 셀 id 가 `id`):
##   ① id != 0                      → 그 블록의 색
##   ② id == 0, 지하층               → BEDROCK (암묵 기반암 바닥)
##   ③ id == 0, 아래 층 셀이 solid   → 아래 층 색의 dim (바닥)
##   ④ 그 외                        → VOID (바닥 없음 — 떨어지는 칸. 기반암과 구별된다)
##
## 구현: 청크마다 `to_bytes()` 를 한 번 얻어 바이트열 인덱스로 id 를 읽는다(get_id 768회 대신).
## 인덱스 = (layer * 16 + y) * 16 + x — `Chunk.index_of` 의 정의와 같다. 색은 id 별로 한 번만
## 계산해 표에 둔다(id 는 1바이트라 최대 256개).
func build_cells() -> Array:
    var cells: Array = []
    if simulation == null:
        return cells
    var registry := simulation.registry
    var layer := active_layer
    var layer_base := layer * Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE
    var below_base := (layer - 1) * Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE
    var is_under := layer == Chunk.LAYER_UNDER
    # id → 색 표. 규칙 ① 용과 규칙 ③/④ 용(아래 층 id → 바닥색 또는 VOID).
    var block_colors := PackedColorArray()
    var floor_colors := PackedColorArray()
    block_colors.resize(Chunk.MAX_BYTE + 1)
    floor_colors.resize(Chunk.MAX_BYTE + 1)
    for id in Chunk.MAX_BYTE + 1:
        var c := Palette.color_for(registry, id)
        block_colors[id] = c
        if registry.has_at(id, BlockRegistry.ATTR_SOLID):
            floor_colors[id] = Palette.dim(c)
        else:
            floor_colors[id] = Palette.VOID
    var loaded := simulation.state.chunks.loaded_sorted()
    cells.resize(loaded.size() * Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE)
    var n := 0
    for entry: Array in loaded:
        var key: Vector2i = entry[0]
        var chunk: Chunk = entry[1]
        var bytes := chunk.to_bytes()
        var base_x := key.x * Chunk.CHUNK_SIZE
        var base_y := key.y * Chunk.CHUNK_SIZE
        for y in Chunk.CHUNK_SIZE:
            var row := layer_base + y * Chunk.CHUNK_SIZE
            var below_row := below_base + y * Chunk.CHUNK_SIZE
            var wy := base_y + y
            for x in Chunk.CHUNK_SIZE:
                var id := bytes[row + x]
                var color: Color
                if id != 0:
                    color = block_colors[id]
                elif is_under:
                    color = Palette.BEDROCK
                else:
                    color = floor_colors[bytes[below_row + x]]
                cells[n] = [base_x + x, wy, color]
                n += 1
    return cells


## 셀 목록을 삼각형 배열 하나로. 결과 `[indices: PackedInt32Array, points: PackedVector2Array,
## colors: PackedColorArray]`. 셀당 꼭짓점 4(top→right→bottom→left)·인덱스 6(두 삼각형).
## 알파 0(VOID) 셀은 건너뛴다. 순수 함수 — 입력 순서대로 결정적이다.
static func build_triangles(cells: Array) -> Array:
    var opaque := 0
    for cell: Array in cells:
        if (cell[2] as Color).a > 0.0:
            opaque += 1
    var indices := PackedInt32Array()
    var points := PackedVector2Array()
    var colors := PackedColorArray()
    indices.resize(opaque * 6)
    points.resize(opaque * 4)
    colors.resize(opaque * 4)
    var half_w := IsoProjection.TILE_W / 2.0
    var half_h := IsoProjection.TILE_H / 2.0
    var v := 0
    var i := 0
    for cell: Array in cells:
        var color: Color = cell[2]
        if color.a <= 0.0:
            continue
        var top := IsoProjection.cell_to_screen(cell[0], cell[1])
        points[v] = top
        points[v + 1] = Vector2(top.x + half_w, top.y + half_h)
        points[v + 2] = Vector2(top.x, top.y + IsoProjection.TILE_H)
        points[v + 3] = Vector2(top.x - half_w, top.y + half_h)
        colors[v] = color
        colors[v + 1] = color
        colors[v + 2] = color
        colors[v + 3] = color
        indices[i] = v
        indices[i + 1] = v + 1
        indices[i + 2] = v + 2
        indices[i + 3] = v
        indices[i + 4] = v + 2
        indices[i + 5] = v + 3
        v += 4
        i += 6
    return [indices, points, colors]


## 플레이어 마커의 꼭짓점 (P4 상태는 보인다). 순수 함수.
##
## 플레이어가 활성 층에 없으면 빈 배열(다른 층에서는 그리지 않는다). 있으면 `[body, facing_dot]`:
##   - body: 발 화면 좌표 `foot = sub_to_screen(sub) + (0, TILE_H/2)` 를 아래 꼭짓점으로 하고 위로
##     솟은 다이아몬드 4점 — 아래(foot) → 오른쪽 → 위 → 왼쪽. 가로 TILE_W/2, 세로 TILE_H/2 + 6.
##   - facing_dot: 몸 중심 `foot + (0, -(TILE_H/4 + 3))` 에서 `dir_to_screen(facing)` 쪽으로 4px
##     옮긴 점을 중심으로 한 반지름 2 의 작은 다이아몬드 4점(top → right → bottom → left).
##     원 대신 다이아몬드 — 헤드리스에서 꼭짓점으로 검증하기 쉽다.
## sub 가 서브유닛이라 걷는 동안 마커가 자연히 미끄러진다.
static func build_player_marker(sub: Vector2i, facing: Vector2i, player_layer: int, active_layer_: int) -> Array[PackedVector2Array]:
    var marker: Array[PackedVector2Array] = []
    if player_layer != active_layer_:
        return marker
    var foot := IsoProjection.sub_to_screen(sub) + Vector2(0.0, IsoProjection.TILE_H / 2.0)
    var side_dy := -(IsoProjection.TILE_H / 4.0 + 3.0)
    var body := PackedVector2Array([
        foot,
        foot + Vector2(IsoProjection.TILE_W / 4.0, side_dy),
        foot + Vector2(0.0, -(IsoProjection.TILE_H / 2.0 + 6.0)),
        foot + Vector2(-IsoProjection.TILE_W / 4.0, side_dy),
    ])
    var body_center := foot + Vector2(0.0, side_dy)
    var dot_center := body_center + IsoProjection.dir_to_screen(facing) * 4.0
    var dot := PackedVector2Array([
        dot_center + Vector2(0.0, -2.0),
        dot_center + Vector2(2.0, 0.0),
        dot_center + Vector2(0.0, 2.0),
        dot_center + Vector2(-2.0, 0.0),
    ])
    marker.append(body)
    marker.append(dot)
    return marker


## 그리기용 셀 목록. `활성 층 | 시뮬레이션 인스턴스 | 청크 revision` 이 마지막과 같으면 캐시된
## 같은 Array 인스턴스를, 다르면 [method build_cells] 로 다시 만든 것을 돌려준다. 삼각형 배열도
## 같은 키로 함께 갱신된다. 걷는 동안(청크 경계 안, 블록 변경 없음)에는 revision 이 그대로라
## 틱마다 refresh 해도 다시 만들지 않는다.
func _cells_for_draw() -> Array:
    if simulation == null:
        return []
    var key := "%d|%d|%d" % [
        active_layer, simulation.get_instance_id(), simulation.state.chunks.revision()]
    if key != _cached_key:
        _cached_cells = build_cells()
        _cached_triangles = build_triangles(_cached_cells)
        _cached_key = key
    return _cached_cells


## 다음 프레임에 다시 그린다. 트리 밖에서 불려도 안전하다(CanvasItem.queue_redraw 는 트리 밖이면 무시).
## main 이 틱마다 부르므로 마커(캐시 밖)도 틱마다 갱신된다.
func refresh() -> void:
    queue_redraw()


func _draw() -> void:
    _cells_for_draw()
    if not _cached_triangles.is_empty():
        var indices: PackedInt32Array = _cached_triangles[0]
        if not indices.is_empty():
            RenderingServer.canvas_item_add_triangle_array(
                get_canvas_item(), indices, _cached_triangles[1], _cached_triangles[2])
    if simulation == null:
        return
    var player := simulation.state.player
    var marker := build_player_marker(player.sub, player.facing, player.layer, active_layer)
    if marker.is_empty():
        return
    draw_colored_polygon(marker[0], Palette.PLAYER)
    draw_colored_polygon(marker[1], Palette.PLAYER_FACING)
