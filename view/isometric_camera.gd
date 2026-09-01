class_name IsometricCamera
extends Camera3D

## 아이소메트릭 시점 카메라.
##
## 기울기와 투영은 고정이다. 캐릭터를 따라가되 스스로 기울어지지 않는다.
##
## 좌우 회전과 확대는 사람이 정한다. 아이소메트릭에서는 네 격자 방향이 모두
## 비스듬히 놓여 어떤 방향도 화면의 정확한 위아래를 가리키지 못한다. 축을 화면과
## 나란히 두고 싶으면 요를 0도로 돌리면 되고, 그때도 조작은 카메라를 따라간다.

## 진짜 아이소메트릭 기울기. atan(1 / sqrt(2)).
const PITCH_DEGREES := -35.264
const YAW_DEGREES := 45.0

## 직교 투영에서 화면에 담기는 세로 폭. 작을수록 가깝게 보인다.
const DEFAULT_VIEW_SIZE := 15.0
const MIN_VIEW_SIZE := 7.0
const MAX_VIEW_SIZE := 34.0

## 휠 한 칸에 바뀌는 폭.
const ZOOM_STEP := 1.5

## 한 번에 도는 각도. 45도씩이라 여덟 번이면 제자리다.
const YAW_STEP := 45.0

## 초점에서 카메라까지의 거리. 직교 투영이라 크기에는 영향이 없고 잘림만 정한다.
const DISTANCE := 60.0

var _focus: Vector3 = Vector3.ZERO
var _yaw: float = YAW_DEGREES


func _ready() -> void:
    projection = PROJECTION_ORTHOGONAL
    size = DEFAULT_VIEW_SIZE
    near = 0.1
    far = 300.0
    _apply_yaw()
    focus_on(_focus)


## [param target] 을 화면 한가운데에 두도록 즉시 옮긴다.
func focus_on(target: Vector3) -> void:
    _focus = target
    position = _focus + transform.basis.z * DISTANCE


## 초점을 [param target] 쪽으로 [param weight] 만큼 당긴다.
func follow(target: Vector3, weight: float) -> void:
    focus_on(_focus.lerp(target, clampf(weight, 0.0, 1.0)))


func focus_point() -> Vector3:
    return _focus


## 가까이 당기거나 멀리 민다. [param steps] 가 음수면 가까워진다.
func zoom_by(steps: int) -> void:
    size = clampf(size + steps * ZOOM_STEP, MIN_VIEW_SIZE, MAX_VIEW_SIZE)


func view_size() -> float:
    return size


## 시점을 좌우로 돌린다. 조작 방향도 따라 돈다.
func turn_by(steps: int) -> void:
    _yaw = fmod(_yaw + steps * YAW_STEP, 360.0)
    _apply_yaw()
    focus_on(_focus)


func yaw_degrees() -> float:
    return _yaw


func _apply_yaw() -> void:
    rotation_degrees = Vector3(PITCH_DEGREES, _yaw, 0.0)
