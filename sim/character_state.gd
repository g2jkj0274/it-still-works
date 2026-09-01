class_name CharacterState
extends RefCounted

## 격자 위 캐릭터의 위치와 방향.
##
## 위치는 칸보다 잘게 잡는다. 한 칸을 1000 서브유닛으로 나눠 정수만으로
## 부드러운 이동을 만든다. 실수를 쓰지 않으므로 결정론이 유지된다.
##
## 걸을 수 있는지 없는지는 여전히 칸 단위로 판정한다. 서브유닛은 칸과 칸
## 사이를 어떻게 건너는지만 정한다.

## 캐릭터가 차지하는 높이. 발 칸과 머리 칸.
const HEIGHT := 2

## 한 칸을 나눈 수.
const SUBUNITS := 1000

## 한 틱에 나아가는 거리. 1000 을 나누어떨어뜨려야 칸 경계에 정확히 선다.
const WALK_SPEED := 250

## 대각선으로 건널 때의 축별 속도.
##
## 맞추려는 것은 **화면에서 보이는 빠르기**다. 월드에서는 대각선이 sqrt(2) 배
## 먼 거리지만, 아이소메트릭 투영이 화면 세로를 sin(기울기) = 1/sqrt(3) 만큼
## 눌러 준다. 그래서 화면에서 재면 두 걸음의 길이가 정확히 같아진다.
##
##   격자 축 한 칸   = sqrt(1/2 + 1/2 * 1/3) = sqrt(2/3)
##   격자 대각 한 칸 = sqrt(2) * 1/sqrt(3)   = sqrt(2/3)
##
## 길이가 같으니 시간도 같아야 한다. 그래서 곧은 걸음과 같은 속도로 둔다.
##
## 다만 화면 좌우로 가는 두 방향만은 세로 눌림을 받지 않아 sqrt(3) 배 길어 보인다.
## 이것은 블록 자체가 세로보다 가로로 넓은 것과 같은 이치라 어색하지 않다.
##
## 값을 따로 둔 것은 나중에 손볼 자리를 남겨 두기 위해서다.
const DIAGONAL_WALK_TICKS := 4
const DIAGONAL_WALK_SPEED := WALK_SPEED

## 떨어질 때의 속도. 걷기보다 빨라야 무게가 느껴진다.
const FALL_SPEED := 500

## 발의 위치(서브유닛).
var sub_position: Vector3i = Vector3i.ZERO

## 걸어가는 목표(서브유닛). 도착하면 [member sub_position] 과 같아진다.
var move_target: Vector3i = Vector3i.ZERO

## 바라보는 수평 방향. 블록을 놓고 부술 목표를 정할 때 쓴다.
var facing: Vector3i = Vector3i(0, 1, 0)


static func sub_of(cell: Vector3i) -> Vector3i:
    return cell * SUBUNITS


static func cell_of(sub: Vector3i) -> Vector3i:
    return Vector3i(_floor_div(sub.x), _floor_div(sub.y), _floor_div(sub.z))


static func _floor_div(value: int) -> int:
    # GDScript 의 정수 나눗셈은 0 쪽으로 자른다. 음수에서도 아래로 내리게 맞춘다.
    if value >= 0:
        return value / SUBUNITS
    return -((-value + SUBUNITS - 1) / SUBUNITS)


## 발이 놓인 칸.
func cell() -> Vector3i:
    return cell_of(sub_position)


## 걸어가는 목표 칸. 멈춰 있으면 지금 칸과 같다.
func target_cell() -> Vector3i:
    return cell_of(move_target)


func is_moving() -> bool:
    return sub_position != move_target


## 칸 한가운데에 즉시 세운다. 진행 중이던 이동은 지운다.
func place_at(cell_position: Vector3i) -> void:
    sub_position = sub_of(cell_position)
    move_target = sub_position


## 목표 칸을 정한다. 실제 이동은 틱마다 [method advance] 가 진행한다.
func walk_to(cell_position: Vector3i) -> void:
    move_target = sub_of(cell_position)


## 목표 쪽으로 한 틱만큼 나아간다.
func advance() -> void:
    if not is_moving():
        return

    var remaining := move_target - sub_position
    var speed := _speed_for(remaining)
    sub_position += Vector3i(
        clampi(remaining.x, -speed, speed),
        clampi(remaining.y, -speed, speed),
        clampi(remaining.z, -speed, speed),
    )


## 지금 남은 거리에 맞는 속도. 떨어질 때가 가장 빠르고 대각선이 가장 느리다.
func _speed_for(remaining: Vector3i) -> int:
    if remaining.z < 0:
        return FALL_SPEED
    if remaining.x != 0 and remaining.y != 0:
        return DIAGONAL_WALK_SPEED
    return WALK_SPEED


func head_position() -> Vector3i:
    return cell() + VoxelGrid.UP * (HEIGHT - 1)


## 몸이 걸쳐 있는 칸들. 걷는 도중에는 떠난 칸과 갈 칸 양쪽을 차지한다.
func occupied_cells() -> Array[Vector3i]:
    var cells: Array[Vector3i] = []
    for base in _base_cells():
        for offset in HEIGHT:
            var occupied := base + VoxelGrid.UP * offset
            if not cells.has(occupied):
                cells.append(occupied)
    return cells


func occupies(pos: Vector3i) -> bool:
    return occupied_cells().has(pos)


## 바라보는 쪽 바로 앞 칸.
func facing_cell() -> Vector3i:
    return cell() + facing


func _base_cells() -> Array[Vector3i]:
    var bases: Array[Vector3i] = [cell()]
    var target := target_cell()
    if target != bases[0]:
        bases.append(target)
    return bases
