class_name IsoProjection
extends RefCounted

## 아이소메트릭 투영 (헌법 P8). 셀 격자 좌표 ↔ 화면 좌표. 전부 static, 상태 없음.
##
## 기준점은 셀 다이아몬드의 **위 꼭짓점(top)** 이다. `cell_to_screen(wx, wy)` 는 그 셀
## 다이아몬드의 top 을 돌려준다. 원점 셀 (0,0) 의 top 이 화면 (0,0).
##   - +x 는 화면 오른쪽 아래로 (TILE_W/2, TILE_H/2)
##   - +y 는 화면 왼쪽 아래로 (-TILE_W/2, TILE_H/2)
##
## 표현 레이어 전용 — sim 은 이 파일을 모른다. 실수는 여기(화면)에만 산다.

## 다이아몬드 가로 폭(픽셀). TILE_W == 2 * TILE_H 인 2:1 아이소.
const TILE_W := 32

## 다이아몬드 세로 높이(픽셀).
const TILE_H := 16


## 셀 (wx, wy) 의 다이아몬드 **위 꼭짓점(top)** 화면 좌표.
static func cell_to_screen(wx: int, wy: int) -> Vector2:
    return Vector2((wx - wy) * TILE_W / 2.0, (wx + wy) * TILE_H / 2.0)


## 셀 다이아몬드의 중심 = top + (0, TILE_H/2).
static func cell_center(wx: int, wy: int) -> Vector2:
    return cell_to_screen(wx, wy) + Vector2(0.0, TILE_H / 2.0)


## 화면 좌표 → 그 점을 담는 셀. [method cell_to_screen] 의 역.
##
## 도출: top 정의에서 p.x / TILE_W = (wx - wy) / 2, p.y / TILE_H = (wx + wy) / 2 + t
## (t ∈ [0, 1) 는 다이아몬드 안에서 top 으로부터 내려간 비율). 두 식을 더하고 빼면
##   fx = p.x / TILE_W + p.y / TILE_H = wx + t
##   fy = p.y / TILE_H - p.x / TILE_W = wy + t
## 이므로 셀 (wx, wy) 의 다이아몬드는 (fx, fy) 평면의 단위 정사각형 [wx, wx+1) × [wy, wy+1) 에
## 대응한다. floor 로 정수화하면 음수에서도 맞다. 따라서 셀 중심(t = 1/2)은 항상 자기 셀로
## 돌아온다: screen_to_cell(cell_center(c)) == c.
static func screen_to_cell(p: Vector2) -> Vector2i:
    var fx := p.x / TILE_W + p.y / TILE_H
    var fy := p.y / TILE_H - p.x / TILE_W
    return Vector2i(int(floor(fx)), int(floor(fy)))


## 셀 다이아몬드의 네 꼭짓점. top → right → bottom → left (시계 방향).
static func diamond(wx: int, wy: int) -> PackedVector2Array:
    var top := cell_to_screen(wx, wy)
    return PackedVector2Array([
        top,
        top + Vector2(TILE_W / 2.0, TILE_H / 2.0),
        top + Vector2(0.0, TILE_H),
        top + Vector2(-TILE_W / 2.0, TILE_H / 2.0),
    ])
