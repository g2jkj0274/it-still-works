class_name TickDriver
extends RefCounted

## 실시간 경과를 고정 틱 수로 환산한다.
##
## 시뮬레이션 자체는 실시간을 모른다. 표현 레이어가 프레임마다 경과 시간을
## 정수 마이크로초로 바꿔 넣어주면 이 객체가 실행해야 할 틱 수를 돌려준다.
## 실수 delta 를 정수 마이크로초로 바꾸는 일은 이 클래스 바깥, 표현 레이어의 몫이다.
## sim/ 안에는 실수가 들어오지 않는다.
##
## 남은 시간은 다음 호출로 이월된다. 그래서 프레임률이 달라져도 같은 실시간에
## 같은 틱 수가 나온다.

## 한 번의 호출에서 따라잡을 최대 틱 수.
const DEFAULT_MAX_TICKS_PER_PUMP := 5

var _interval_usec: int
var _max_ticks_per_pump: int
var _accumulated_usec: int = 0
var _dropped_usec: int = 0


func _init(p_interval_usec: int = Simulation.TICK_INTERVAL_USEC, p_max_ticks_per_pump: int = DEFAULT_MAX_TICKS_PER_PUMP) -> void:
    _interval_usec = maxi(p_interval_usec, 1)
    _max_ticks_per_pump = maxi(p_max_ticks_per_pump, 1)


## 경과한 [param elapsed_usec] 를 받아 이번에 실행할 틱 수를 돌려준다.
## 음수 경과는 무시한다.
func pump(elapsed_usec: int) -> int:
    if elapsed_usec > 0:
        _accumulated_usec += elapsed_usec

    var ticks := _accumulated_usec / _interval_usec
    _accumulated_usec -= ticks * _interval_usec

    if ticks > _max_ticks_per_pump:
        # 크게 밀렸을 때는 따라잡기를 포기한다.
        # 밀린 만큼 전부 실행하면 다음 호출이 더 밀리는 악순환이 된다.
        _dropped_usec += (ticks - _max_ticks_per_pump) * _interval_usec
        ticks = _max_ticks_per_pump

    return ticks


## 아직 틱이 되지 못하고 남은 시간. 표현 레이어의 보간에 쓴다.
func remainder_usec() -> int:
    return _accumulated_usec


## 따라잡기를 포기하고 버린 누적 시간. 진단용이며 시뮬레이션 판단에 쓰지 않는다.
func dropped_usec() -> int:
    return _dropped_usec


func interval_usec() -> int:
    return _interval_usec


func reset() -> void:
    _accumulated_usec = 0
    _dropped_usec = 0
