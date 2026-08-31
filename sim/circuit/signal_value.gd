class_name SignalValue
extends RefCounted

## 배선을 흐르는 신호 하나.
##
## 신호는 값을 가진다. 켜짐/꺼짐이 아니다. 값의 갈래는 셋이다.
## 불리언 / 정수 / 실수.
##
## 실수는 1000배 한 정수로 담는다. 3.7 은 3700 이다. 시뮬레이션에 부동소수점을
## 들이지 않으면서 실수의 뜻은 그대로 지킨다. 눈금보다 잘게는 나타내지 못하며
## 그것이 이 게임에서 실수의 정밀도다.

const KIND_NONE := 0
const KIND_BOOL := 1
const KIND_INT := 2
const KIND_REAL := 3

## 실수 신호의 눈금.
const REAL_SCALE := 1000

const _NAMES: PackedStringArray = ["none", "bool", "int", "real"]

var kind: int = KIND_NONE

## 불리언은 0 또는 1, 정수는 값 그대로, 실수는 값에 REAL_SCALE 을 곱한 수.
var raw: int = 0


static func none() -> SignalValue:
    return SignalValue.new()


static func of_bool(value: bool) -> SignalValue:
    return _make(KIND_BOOL, 1 if value else 0)


static func of_int(value: int) -> SignalValue:
    return _make(KIND_INT, value)


## [param whole].[param thousandths] 꼴의 실수. of_real(3, 700) 은 3.7 이다.
static func of_real(whole: int, thousandths: int = 0) -> SignalValue:
    var magnitude := absi(whole) * REAL_SCALE + absi(thousandths)
    var negative := whole < 0 or thousandths < 0
    return _make(KIND_REAL, -magnitude if negative else magnitude)


## 눈금이 곱해진 값을 그대로 담는다.
static func of_real_scaled(scaled: int) -> SignalValue:
    return _make(KIND_REAL, scaled)


static func name_of(kind_value: int) -> String:
    if kind_value < 0 or kind_value >= _NAMES.size():
        return "invalid"
    return _NAMES[kind_value]


## 신호가 흐르고 있는가. 거짓인 불리언도 흐르는 신호다.
func is_present() -> bool:
    return kind != KIND_NONE


func as_bool() -> bool:
    return raw != 0


## 정수로 읽는다. 실수는 소수부가 잘려 나가고 되돌아오지 않는다.
func as_int() -> int:
    if kind != KIND_REAL:
        return raw
    # 0 쪽으로 자른다. -3.7 은 -3 이다.
    if raw < 0:
        return -(-raw / REAL_SCALE)
    return raw / REAL_SCALE


## 눈금이 곱해진 값. 실수가 아니면 눈금을 곱해 돌려준다.
func as_real_scaled() -> int:
    if kind == KIND_REAL:
        return raw
    return raw * REAL_SCALE


func equals(other: SignalValue) -> bool:
    if other == null:
        return false
    return kind == other.kind and raw == other.raw


## 상태 해시에 넣기 위한 글자꼴.
func to_key() -> String:
    return "%s:%d" % [name_of(kind), raw]


static func _make(kind_value: int, raw_value: int) -> SignalValue:
    var value := SignalValue.new()
    value.kind = kind_value
    value.raw = raw_value
    return value
