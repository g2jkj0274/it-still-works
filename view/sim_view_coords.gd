class_name SimViewCoords
extends RefCounted

## 시뮬레이션 격자 좌표와 Godot 월드 좌표 사이의 유일한 접점.
##
## 격자는 z 를 높이로 쓰고 Godot 은 y 가 위다. 그 축 바꿈이 여기 한 곳에만 있다.
## 변환은 표현 레이어의 일이다. 시뮬레이션은 Godot 좌표를 알지 못한다.

## 복셀 한 칸의 변 길이.
const CELL_SIZE := 1.0


## Godot 월드 좌표를 격자 좌표로 되돌린다. 칸 (i,j,k) 는
## [i,i+1] x [j,j+1] x [k,k+1] 을 차지한다.
static func world_to_grid_point(world: Vector3) -> Vector3:
    return Vector3(world.x, world.z, world.y) / CELL_SIZE


## 방향 벡터의 축 바꿈. 위치와 달리 자리 옮김이 없다.
static func world_to_grid_direction(world: Vector3) -> Vector3:
    return Vector3(world.x, world.z, world.y)


## 서브유닛 위치에 해당하는 월드 좌표. 칸과 칸 사이도 나타낸다.
static func sub_to_world(sub: Vector3i) -> Vector3:
    var scale := float(CharacterState.SUBUNITS)
    return Vector3(
        (sub.x / scale + 0.5) * CELL_SIZE,
        (sub.z / scale + 0.5) * CELL_SIZE,
        (sub.y / scale + 0.5) * CELL_SIZE,
    )


## 칸의 한가운데에 해당하는 월드 좌표.
static func cell_to_world(cell: Vector3i) -> Vector3:
    return Vector3(
        (cell.x + 0.5) * CELL_SIZE,
        (cell.z + 0.5) * CELL_SIZE,
        (cell.y + 0.5) * CELL_SIZE,
    )
