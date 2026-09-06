class_name GameMain
extends Node3D

## 게임 진입점. 시뮬레이션을 소유하고 고정 틱으로 굴린다.
##
## 시뮬레이션 갱신은 _process 에서 하지 않는다. 고정 간격으로 불리는
## _physics_process 안에서 TickDriver 가 모은 만큼만 진행한다.
## 경과 시간은 정수 마이크로초로 재므로 실수가 시뮬레이션 쪽으로 새지 않는다.
##
## 표현 레이어는 시뮬레이션을 읽기만 한다. 아이소 렌더는 M1 에서 붙는다.

const SEED := 20250901

var simulation: Simulation
var driver: TickDriver
var _last_usec: int = 0


func _ready() -> void:
    simulation = Simulation.new(SEED)
    driver = TickDriver.new()
    _last_usec = Time.get_ticks_usec()


func _physics_process(_delta: float) -> void:
    var now := Time.get_ticks_usec()
    var elapsed := now - _last_usec
    _last_usec = now
    simulation.advance(driver.pump(elapsed))
