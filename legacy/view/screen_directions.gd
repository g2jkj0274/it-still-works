class_name ScreenDirections
extends RefCounted

## 화면에서 본 방향을 격자 방향으로 옮긴다.
##
## 키는 화면을 기준으로 눌린다. W 는 "위", D 는 "오른쪽"이다. 그런데 시뮬레이션이
## 아는 것은 격자 방향뿐이다. 그 사이를 여기서 잇는다. 회전은 표현 레이어의 일이고
## 시뮬레이션의 이동 규칙은 그대로 둔다.
##
## 카메라에서 직접 뽑으므로 시점을 돌리면 조작도 따라 돈다.
##
## 걸을 수 있는 방향이 여덟이라 아이소메트릭에서도 화면과 나란해진다. 요가 45도일
## 때 격자 대각선 네 개가 화면의 위아래좌우와 맞고, 격자 축 네 개가 화면 대각선과
## 맞는다. 요가 0도면 그 둘이 뒤바뀐다.
##
## 어느 쪽이든 여기서 고르는 것은 "화면에서 가장 그 쪽을 향하는 격자 방향"이다.
## 그래서 시점을 돌려도 키와 화면이 어긋나지 않는다.

const RIGHT := Vector2i(1, 0)
const UP := Vector2i(0, 1)
const LEFT := Vector2i(-1, 0)
const DOWN := Vector2i(0, -1)

const UP_RIGHT := Vector2i(1, 1)
const UP_LEFT := Vector2i(-1, 1)
const DOWN_RIGHT := Vector2i(1, -1)
const DOWN_LEFT := Vector2i(-1, -1)

## 화면에서 갈 수 있는 여덟 쪽. 키 하나로 넷, 두 개를 겹쳐 눌러 나머지 넷.
const SCREEN_ORDER: Array[Vector2i] = [
    RIGHT, UP, LEFT, DOWN, UP_RIGHT, UP_LEFT, DOWN_RIGHT, DOWN_LEFT,
]


## [param screen] 쪽으로 가려면 격자에서 어느 방향인가.
##
## 화면에서 가장 그 쪽을 향하는 격자 방향을 고른다. 같은 값이 나오면
## [constant MovementRules.DIRECTIONS] 의 앞선 것이 이긴다. 차례가 고정되어야
## 같은 상황에서 늘 같은 방향이 나온다.
static func grid_for(camera: Camera3D, screen: Vector2i) -> Vector3i:
    if camera == null or not SCREEN_ORDER.has(screen):
        return Vector3i.ZERO

    var wanted := Vector2(screen).normalized()
    var best := Vector3i.ZERO
    var best_score := 0.0

    for direction in MovementRules.DIRECTIONS:
        var delta := screen_delta_of(camera, direction)
        if delta.is_zero_approx():
            continue
        var score := delta.normalized().dot(wanted)
        if score > best_score:
            best_score = score
            best = direction
    return best


## [param grid] 로 한 칸 갈 때 화면에서 어디로 움직이는가.
## 위를 양수로 읽는다. 화면 좌표는 아래가 양수이므로 뒤집어 둔 값이다.
static func screen_delta_of(camera: Camera3D, grid: Vector3i) -> Vector2:
    var basis := camera.global_transform.basis
    var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
    var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()

    # 격자 (x, y) 는 월드 (x, z) 다. 높이는 이동과 무관하다.
    var world := Vector3(grid.x, 0.0, grid.y)

    # 위아래는 기울기만큼 눌려 보인다. 그 눌림까지 셈해야 화면과 맞는다.
    # 카메라가 뒤로 보는 축의 높이 성분이 곧 그 눌림이다.
    var squash: float = absf(basis.z.y)
    return Vector2(world.dot(right), world.dot(forward) * squash)
