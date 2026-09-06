class_name WorldView
extends Node2D

## 로드된 청크의 한 층을 아이소메트릭 다이아몬드로 그린다 (헌법 P8 "한 화면에 한 층").
##
## sim 을 읽기만 한다. `simulation.state` 를 고치거나 명령을 제출하는 코드는 여기 없다 —
## 입력은 main(M1-5b)이 맡는다. [method build_cells] 는 순수 판단이라 노드 트리 밖에서도
## 돌고 테스트된다. [method _draw] 는 그 결과를 그리기만 한다.
##
## 바닥 규칙(DECISIONS 2026-09-06 "층 3개" 파생): 바닥 = 아래 층의 solid 칸. 지하층 아래는
## 암묵 기반암. view 코드라 `id == 0`(air) 판정은 허용된다(sim 이 아니다). 그러나 바닥 여부는
## DECISIONS 원문대로 `solid` 속성으로 묻는다 — 이름·id 로 분기하지 않으며, M6 에 액체(solid
## 아님)가 아래 층에 놓여도 바닥으로 그려지는 일을 막는다.

## 주입되는 시뮬레이션. null 이면 아무것도 그리지 않는다.
var simulation: Simulation = null

## 지금 그리는 층. 기본은 지상.
var active_layer: int = Chunk.LAYER_GROUND


## 층을 바꾼다. 범위 밖은 클램프. 실제로 바뀔 때만 다시 그린다.
func set_active_layer(layer: int) -> void:
    var clamped := clampi(layer, 0, Chunk.LAYERS - 1)
    if clamped == active_layer:
        return
    active_layer = clamped
    refresh()


## 카메라가 볼 셀. 로드 중심 청크의 중앙 셀. 중심이 없으면 (8, 8), 시뮬레이션이 없으면 (0, 0).
func focus_cell() -> Vector2i:
    if simulation == null:
        return Vector2i.ZERO
    var chunks := simulation.state.chunks
    if not chunks.has_center():
        return Vector2i(Chunk.CHUNK_SIZE / 2, Chunk.CHUNK_SIZE / 2)
    var c := chunks.center()
    return Vector2i(
        c.x * Chunk.CHUNK_SIZE + Chunk.CHUNK_SIZE / 2,
        c.y * Chunk.CHUNK_SIZE + Chunk.CHUNK_SIZE / 2)


## 그릴 셀 목록. 각 원소 `[wx: int, wy: int, color: Color]`. 순수 판단 — 상태를 바꾸지 않는다.
##
## 순서: `chunks.loaded_sorted()`((cy, cx) 순) 청크마다 y 바깥·x 안쪽 루프. 결정적이다.
## 색 규칙(active_layer 의 셀 id 가 `id`):
##   ① id != 0                      → 그 블록의 색
##   ② id == 0, 지하층               → BEDROCK (암묵 기반암 바닥)
##   ③ id == 0, 아래 층 셀이 solid   → 아래 층 색의 dim (바닥)
##   ④ 그 외                        → VOID (바닥 없음 — 떨어지는 칸. 기반암과 구별된다)
func build_cells() -> Array:
    var cells: Array = []
    if simulation == null:
        return cells
    var registry := simulation.registry
    var layer := active_layer
    var below := layer - 1
    for entry: Array in simulation.state.chunks.loaded_sorted():
        var key: Vector2i = entry[0]
        var chunk: Chunk = entry[1]
        var base_x := key.x * Chunk.CHUNK_SIZE
        var base_y := key.y * Chunk.CHUNK_SIZE
        for y in Chunk.CHUNK_SIZE:
            for x in Chunk.CHUNK_SIZE:
                var id := chunk.get_id(x, y, layer)
                var color: Color
                if id != 0:
                    color = Palette.color_for(registry, id)
                elif layer == Chunk.LAYER_UNDER:
                    color = Palette.BEDROCK
                else:
                    var below_id := chunk.get_id(x, y, below)
                    if registry.has_at(below_id, BlockRegistry.ATTR_SOLID):
                        color = Palette.dim(Palette.color_for(registry, below_id))
                    else:
                        color = Palette.VOID
                cells.append([base_x + x, base_y + y, color])
    return cells


## 다음 프레임에 다시 그린다. 트리 밖에서 불려도 안전하다(CanvasItem.queue_redraw 는 트리 밖이면 무시).
func refresh() -> void:
    queue_redraw()


func _draw() -> void:
    for cell: Array in build_cells():
        var color: Color = cell[2]
        if color.a > 0.0:
            draw_colored_polygon(IsoProjection.diamond(cell[0], cell[1]), color)
