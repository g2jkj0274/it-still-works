class_name DayCycle
extends RefCounted

## 낮과 밤.
##
## 지금이 낮인지 밤인지는 틱만으로 정해진다. 따로 들고 있는 상태가 없으므로
## 저장하고 불러올 때 어긋날 여지가 없다.
##
## 밤이 이 게임의 리듬이자 시험 사이클이다. 낮에 만든 장치가 밤에 시험받는다.

const DAY_TICKS := 7 * 60 * Simulation.TICK_RATE
const NIGHT_TICKS := 3 * 60 * Simulation.TICK_RATE
const CYCLE_TICKS := DAY_TICKS + NIGHT_TICKS


## 한 주기 안에서 지금 몇 번째 틱인가.
static func phase_tick(tick: int) -> int:
    return posmod(tick, CYCLE_TICKS)


static func is_night(tick: int) -> bool:
    return phase_tick(tick) >= DAY_TICKS


## 첫날은 1일이다.
static func day_number(tick: int) -> int:
    return tick / CYCLE_TICKS + 1


## 이 틱에 밤이 시작되는가.
static func is_nightfall(tick: int) -> bool:
    return phase_tick(tick) == DAY_TICKS


## 이 틱에 날이 밝는가.
static func is_daybreak(tick: int) -> bool:
    return tick > 0 and phase_tick(tick) == 0
