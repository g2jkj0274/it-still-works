class_name MovementRules
extends RefCounted

## 격자 위 이동 판정.
##
## 전부 정수 연산이고 상태를 바꾸지 않는다. 실제 이동은 명령이 이 판정 결과를
## 받아 적용한다.

## 걸을 수 있는 네 방향. 순서가 고정되어 있어야 판정이 항상 같다.
const DIRECTIONS: Array[Vector3i] = [
    Vector3i(0, -1, 0),
    Vector3i(0, 1, 0),
    Vector3i(1, 0, 0),
    Vector3i(-1, 0, 0),
]


static func is_direction(dir: Vector3i) -> bool:
    return DIRECTIONS.has(dir)


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


## 한 걸음 뒤의 발 위치. 갈 수 없으면 제자리를 돌려준다.
##
## 한 칸 턱은 오르고, 낮은 곳으로는 떨어진다. 딛을 곳이 없는 칸으로는 나가지
## 않는다. 그래서 섬 밖 바다로 걸어 나갈 수 없다.
static func resolve_step(grid: VoxelGrid, feet: Vector3i, dir: Vector3i) -> Vector3i:
    if not is_direction(dir):
        return feet

    var target := feet + dir
    var stepped := feet

    if can_occupy(grid, target):
        stepped = target
    elif can_occupy(grid, target + VoxelGrid.UP) and grid.is_free(feet + VoxelGrid.UP * CharacterState.HEIGHT):
        stepped = target + VoxelGrid.UP
    else:
        return feet

    var landed := settle(grid, stepped)
    if not is_supported(grid, landed):
        return feet
    return landed
