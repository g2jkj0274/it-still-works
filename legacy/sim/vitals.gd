class_name Vitals
extends RefCounted

## 생존 지표. 체력과 포만도.
##
## 포만도는 시간에 따라 준다. 0이 되면 체력이 서서히 준다.
## 굶주림은 갑작스럽지 않다. 밥을 찾을 틈이 있어야 한다.

const MAX_HEALTH := 20
const MAX_FULLNESS := 20

## 이 틱마다 포만도가 1 준다. 가득 찬 배가 다 빌 때까지 4분.
const FULLNESS_DECAY_TICKS := 12 * Simulation.TICK_RATE

## 배가 빈 채로 이 틱이 지나면 체력이 1 준다.
const STARVE_TICKS := 5 * Simulation.TICK_RATE

## 되살아날 때 채워지는 포만도. 가득 차지는 않는다.
const REVIVE_FULLNESS := MAX_FULLNESS / 2

var health: int = MAX_HEALTH
var fullness: int = MAX_FULLNESS

var _decay_countdown: int = FULLNESS_DECAY_TICKS
var _starve_countdown: int = STARVE_TICKS


func is_dead() -> bool:
    return health <= 0


func tick() -> void:
    if is_dead():
        return

    _decay_countdown -= 1
    if _decay_countdown <= 0:
        _decay_countdown = FULLNESS_DECAY_TICKS
        fullness = maxi(fullness - 1, 0)

    if fullness > 0:
        _starve_countdown = STARVE_TICKS
        return

    _starve_countdown -= 1
    if _starve_countdown <= 0:
        _starve_countdown = STARVE_TICKS
        damage(1)


func damage(amount: int) -> void:
    if amount <= 0:
        return
    health = maxi(health - amount, 0)


func feed(amount: int) -> void:
    if amount <= 0:
        return
    fullness = mini(fullness + amount, MAX_FULLNESS)


## 죽은 뒤 다시 일어난다. 배는 절반만 찬다.
func revive() -> void:
    health = MAX_HEALTH
    fullness = maxi(fullness, REVIVE_FULLNESS)
    _decay_countdown = FULLNESS_DECAY_TICKS
    _starve_countdown = STARVE_TICKS


func to_hash_fields() -> Array:
    return [
        ["vitals.health", health],
        ["vitals.fullness", fullness],
        ["vitals.decay", _decay_countdown],
        ["vitals.starve", _starve_countdown],
    ]
