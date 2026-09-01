class_name MovementRules
extends RefCounted

## 격자 위 이동 판정.
##
## 전부 정수 연산이고 상태를 바꾸지 않는다. 실제 이동은 명령이 이 판정 결과를
## 받아 적용한다.

## 걸을 수 있는 여덟 방향. 순서가 고정되어 있어야 판정이 항상 같다.
##
## 대각선이 있어야 화면의 위아래좌우와 맞는다. 아이소메트릭에서는 격자 축이
## 비스듬히 놓여 네 방향만으로는 어느 키도 화면과 나란해지지 않는다.
const DIRECTIONS: Array[Vector3i] = [
    Vector3i(0, -1, 0),
    Vector3i(0, 1, 0),
    Vector3i(1, 0, 0),
    Vector3i(-1, 0, 0),
    Vector3i(1, -1, 0),
    Vector3i(-1, -1, 0),
    Vector3i(1, 1, 0),
    Vector3i(-1, 1, 0),
]


static func is_direction(dir: Vector3i) -> bool:
    return DIRECTIONS.has(dir)


## 두 축을 한꺼번에 건너는 걸음인가.
static func is_diagonal(dir: Vector3i) -> bool:
    return dir.x != 0 and dir.y != 0


## 발 칸을 [param feet] 로 두었을 때 몸 전체가 들어가는가.
static func can_occupy(grid: VoxelGrid, feet: Vector3i) -> bool:
    for offset in CharacterState.HEIGHT:
        if not grid.is_free(feet + VoxelGrid.UP * offset):
            return false
    return true


## 발밑이 단단한가. 격자 밖은 단단하지 않다.
static func is_supported(grid: VoxelGrid, feet: Vector3i) -> bool:
    return grid.is_solid(feet - VoxelGrid.UP)


## 지지될 때까지 떨어뜨린다. 격자 바닥 아래로는 내려가지 않는다.
static func settle(grid: VoxelGrid, feet: Vector3i) -> Vector3i:
    var result := feet
    while result.z > 0 and not is_supported(grid, result) and can_occupy(grid, result - VoxelGrid.UP):
        result -= VoxelGrid.UP
    return result


## 한 걸음 뒤에 도착할 칸. 갈 수 없으면 제자리를 돌려준다.
##
## 한 칸 턱은 오른다. 떨어지는 것은 여기서 처리하지 않는다. 걸음은 걸음이고
## 낙하는 낙하다. 다만 떨어진 끝에 딛을 곳이 없다면 애초에 나가지 않는다.
## 그래서 섬 밖 바다로 걸어 나갈 수 없다.
static func resolve_walk(grid: VoxelGrid, feet: Vector3i, dir: Vector3i) -> Vector3i:
    if not is_direction(dir):
        return feet
    if is_diagonal(dir):
        return _resolve_diagonal(grid, feet, dir)

    var target := feet + dir
    var stepped := feet

    if can_occupy(grid, target):
        stepped = target
    elif can_occupy(grid, target + VoxelGrid.UP) and grid.is_free(feet + VoxelGrid.UP * CharacterState.HEIGHT):
        stepped = target + VoxelGrid.UP
    else:
        return feet

    if not is_supported(grid, settle(grid, stepped)):
        return feet
    return stepped


## 대각선 걸음.
##
## 양옆이 모두 열려 있어야 지나간다. 한쪽이라도 막혀 있으면 모서리를 뚫고
## 지나가는 꼴이 된다.
##
## 대각선으로는 턱을 오르지 않는다. 같은 높이로만 건넌다. 떨어지는 것은
## 시뮬레이션이 뒤이어 처리한다.
static func _resolve_diagonal(grid: VoxelGrid, feet: Vector3i, dir: Vector3i) -> Vector3i:
    if not can_occupy(grid, feet + Vector3i(dir.x, 0, 0)):
        return feet
    if not can_occupy(grid, feet + Vector3i(0, dir.y, 0)):
        return feet

    var target := feet + dir
    if not can_occupy(grid, target):
        return feet
    if not is_supported(grid, settle(grid, target)):
        return feet
    return target
