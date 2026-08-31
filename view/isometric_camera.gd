class_name IsometricCamera
extends Camera3D

## 아이소메트릭 고정 시점 카메라.
##
## 각도와 투영은 고정이다. 캐릭터를 따라가더라도 회전하거나 확대하지 않는다.
## 시점이 고정이어야 격자와 화면의 대응이 흔들리지 않는다.

## 진짜 아이소메트릭 기울기. atan(1 / sqrt(2)).
const PITCH_DEGREES := -35.264
const YAW_DEGREES := 45.0

## 직교 투영에서 화면에 담기는 세로 폭.
const VIEW_SIZE := 26.0

## 초점에서 카메라까지의 거리. 직교 투영이라 크기에는 영향이 없고 잘림만 정한다.
const DISTANCE := 60.0

var _focus: Vector3 = Vector3.ZERO


func _ready() -> void:
    projection = PROJECTION_ORTHOGONAL
    size = VIEW_SIZE
    near = 0.1
    far = 200.0
    rotation_degrees = Vector3(PITCH_DEGREES, YAW_DEGREES, 0.0)
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
