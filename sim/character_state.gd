class_name CharacterState
extends RefCounted

## 격자 위 캐릭터의 위치와 방향.
##
## 좌표는 정수 격자 칸이다. 칸 사이의 중간 위치는 없다.
## 걷는 동안의 부드러운 움직임은 표현 레이어가 보간해 만든다.

## 캐릭터가 차지하는 높이. 발 칸과 머리 칸.
const HEIGHT := 2

## 발이 놓인 칸.
var position: Vector3i = Vector3i.ZERO

## 바라보는 수평 방향. 블록을 놓고 부술 목표를 정할 때 쓴다.
var facing: Vector3i = Vector3i(0, 1, 0)


func _init(p_position: Vector3i = Vector3i.ZERO, p_facing: Vector3i = Vector3i(0, 1, 0)) -> void:
    position = p_position
    facing = p_facing


func head_position() -> Vector3i:
    return position + VoxelGrid.UP * (HEIGHT - 1)


## 몸이 차지하는 칸들. 아래에서 위로.
func occupied_cells() -> Array[Vector3i]:
    var cells: Array[Vector3i] = []
    for offset in HEIGHT:
        cells.append(position + VoxelGrid.UP * offset)
    return cells


func occupies(pos: Vector3i) -> bool:
    if pos.x != position.x or pos.y != position.y:
        return false
    return pos.z >= position.z and pos.z < position.z + HEIGHT
