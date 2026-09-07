class_name PlayerState
extends RefCounted

## 플레이어의 격자 위 위치·목표·층·방향 (M1-6a, 헌법 P3·P8).
##
## 위치는 칸보다 잘게 잡는다. 한 칸을 SUBUNITS(1000) 서브유닛으로 나눠 정수만으로 부드러운
## 이동을 만든다. 실수를 쓰지 않으므로 결정론이 유지된다(P3).
##
## 걸을 수 있는지는 여전히 칸 단위로 판정한다([MovementRules]). 서브유닛은 칸과 칸 사이를
## 어떻게 건너는지만 정한다.
##
## 세계는 층 3개의 2D 격자다(DECISIONS 2026-09-06). 높이 축은 없다 — 위치는 Vector2i 와
## 층 인덱스 하나다. 낙하·층 이동은 M3 gravity 규칙과 함께 온다. 여기에는 없다.
##
## 이 파일에는 Node·부동소수·난수·파일 IO 가 없다. 정수 좌표만 다룬다.

## 한 칸을 나눈 수. 칸 원점 = cell * SUBUNITS.
const SUBUNITS := 1000

## 한 틱에 나아가는 서브유닛. SUBUNITS 를 나누어떨어뜨려야 칸 경계에 정확히 선다.
## 1000 / 250 = 칸당 4틱 = 초당 5칸(20 tps).
##
## 대각선도 같은 속도다. 맞추려는 것은 **화면에서 보이는 빠르기**다. 월드에서는 대각선이
## sqrt(2) 배 먼 거리지만, 아이소메트릭 투영이 화면 세로를 눌러 주어 화면에서 재면 두 걸음의
## 길이가 같아진다(32×16 다이아몬드에서 격자 축 한 칸과 격자 대각 한 칸의 화면 길이가 같다).
## 길이가 같으니 시간도 같아야 한다. 그래서 축별 clampi 로 두 축을 동시에 같은 속도로 옮긴다.
const WALK_SPEED := 250

## 발의 위치(서브유닛).
var sub: Vector2i = Vector2i.ZERO

## 걸어가는 목표(서브유닛). 도착하면 [member sub] 와 같아진다.
var target: Vector2i = Vector2i.ZERO

## 서 있는 층. Chunk.LAYER_*.
var layer: int = Chunk.LAYER_GROUND

## 바라보는 방향. 8방향 중 하나. 블록을 놓고 부술 목표를 정할 때 쓴다(M1-7).
var facing: Vector2i = Vector2i(0, 1)


# --- 좌표 변환 ---

## 칸 → 그 칸 원점의 서브유닛.
static func sub_of(cell_position: Vector2i) -> Vector2i:
    return cell_position * SUBUNITS


## 서브유닛 → 칸. 음수에서도 아래로 내린다 (-1 → -1, -1000 → -1, -1001 → -2).
static func cell_of(sub_position: Vector2i) -> Vector2i:
    return Vector2i(floor_div(sub_position.x), floor_div(sub_position.y))


## 서브유닛 한 축을 SUBUNITS 로 나눈 floor 몫.
## GDScript 의 정수 나눗셈은 0 쪽으로 자른다. 음수에서도 아래로 내리게 맞춘다.
static func floor_div(value: int) -> int:
    if value >= 0:
        return value / SUBUNITS
    return -((-value + SUBUNITS - 1) / SUBUNITS)


# --- 조회 ---

## 발이 놓인 칸.
func cell() -> Vector2i:
    return cell_of(sub)


## 걸어가는 목표 칸. 멈춰 있으면 지금 칸과 같다.
func target_cell() -> Vector2i:
    return cell_of(target)


func is_moving() -> bool:
    return sub != target


# --- 변경 ---

## 칸 원점에 즉시 세우고 층을 정한다. 진행 중이던 이동은 지운다.
func place_at(cell_position: Vector2i, p_layer: int) -> void:
    sub = sub_of(cell_position)
    target = sub
    layer = p_layer


## 목표 칸을 정한다. 실제 이동은 틱마다 [method advance] 가 진행한다.
## 걸을 수 있는지는 여기서 묻지 않는다 — 호출자(명령)가 [MovementRules] 로 판정한 뒤 부른다.
func walk_to(cell_position: Vector2i) -> void:
    target = sub_of(cell_position)


## 목표 쪽으로 한 틱만큼 나아간다. 멈춰 있으면 아무것도 하지 않는다.
func advance() -> void:
    if not is_moving():
        return
    var remaining := target - sub
    sub += Vector2i(
        clampi(remaining.x, -WALK_SPEED, WALK_SPEED),
        clampi(remaining.y, -WALK_SPEED, WALK_SPEED),
    )


# --- 해시 ---

## 해시 입력이 되는 정규 필드 목록. 순서 고정.
## WorldState 가 values 뒤·chunks 앞에 이어 붙인다(M1-6a-2).
func to_hash_fields() -> Array:
    var fields: Array = []
    fields.append(["player.sub", "%d,%d" % [sub.x, sub.y]])
    fields.append(["player.target", "%d,%d" % [target.x, target.y]])
    fields.append(["player.layer", layer])
    fields.append(["player.facing", "%d,%d" % [facing.x, facing.y]])
    return fields
