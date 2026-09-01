class_name ScreenDirections
extends RefCounted

## 화면에서 본 방향을 격자 방향으로 옮긴다.
##
## 키는 화면을 기준으로 눌린다. W 는 "위", D 는 "오른쪽"이다. 그런데 시뮬레이션이
## 아는 것은 격자 축뿐이다. 그 사이를 여기서 잇는다. 회전은 표현 레이어의 일이고
## 시뮬레이션의 이동 규칙은 그대로 둔다.
##
## 카메라에서 직접 뽑으므로 시점을 돌리면 조작도 따라 돈다.
##
## 알아 둘 것: 아이소메트릭 시점에서는 **어떤 격자 방향도 화면의 정확한 위아래를
## 가리키지 못한다.** 네 방향이 모두 비스듬히 놓이기 때문이다. 요를 0도(또는 90도
## 배수)로 돌리면 축이 화면과 나란해지지만 다이아몬드 모양은 사라진다.
## 그래서 여기서는 네 격자 방향을 화면 각도 순으로 늘어놓고 오른쪽·위·왼쪽·아래에
## 차례로 물린다. 각 키가 적어도 제 쪽으로는 가게 하는 배치다.

const RIGHT := Vector2i(1, 0)
const UP := Vector2i(0, 1)
const LEFT := Vector2i(-1, 0)
const DOWN := Vector2i(0, -1)

## 화면 방향을 도는 차례. 오른쪽에서 시작해 반시계로 돈다.
const SCREEN_ORDER: Array[Vector2i] = [RIGHT, UP, LEFT, DOWN]


## [param screen] 쪽으로 가려면 격자에서 어느 방향인가.
static func grid_for(camera: Camera3D, screen: Vector2i) -> Vector3i:
    var slot := SCREEN_ORDER.find(screen)
    if slot < 0 or camera == null:
        return Vector3i.ZERO

    var ordered := _by_screen_angle(camera)
    if ordered.size() != SCREEN_ORDER.size():
        return Vector3i.ZERO
    return ordered[slot]


## [param grid] 로 한 칸 갈 때 화면에서 어디로 움직이는가.
## 위를 양수로 읽는다. 화면 좌표는 아래가 양수이므로 뒤집는다.
static func screen_delta_of(camera: Camera3D, grid: Vector3i) -> Vector2:
    var basis := camera.global_transform.basis
    var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
    var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()

    # 격자 (x, y) 는 월드 (x, z) 다. 높이는 이동과 무관하다.
    var world := Vector3(grid.x, 0.0, grid.y)
    return Vector2(world.dot(right), world.dot(forward))


## 격자 네 방향을 화면 각도 순으로 늘어놓는다.
## 오른쪽(각도 0)에 가장 가까운 것부터 반시계로.
static func _by_screen_angle(camera: Camera3D) -> Array[Vector3i]:
    var entries: Array = []
    for direction in MovementRules.DIRECTIONS:
        var delta := screen_delta_of(camera, direction)
        if delta.is_zero_approx():
            continue
        entries.append([_turn_of(delta), direction])
    entries.sort_custom(func(left: Array, right: Array) -> bool: return left[0] < right[0])

    var ordered: Array[Vector3i] = []
    for entry: Array in entries:
        ordered.append(entry[1])
    return ordered


## 0 에서 1 사이로 나타낸 각도. 오른쪽이 0, 위가 0.25 다.
static func _turn_of(delta: Vector2) -> float:
    var turn := atan2(delta.y, delta.x) / TAU
    return turn if turn >= 0.0 else turn + 1.0
