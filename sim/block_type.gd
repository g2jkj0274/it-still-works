class_name BlockType
extends RefCounted

## 복셀 한 칸에 들어갈 수 있는 블록 종류.
##
## 지형 블록은 docs/spec.md 3.1, 회로 부품은 4.2 를 따른다.
## 부품 목록을 늘리려면 반드시 스펙을 먼저 고친다.

## 빈 칸. 0 이어야 새로 만든 격자가 곧바로 빈 상태가 된다.
const EMPTY := 0

## 섬의 지면.
const GROUND := 1

## 광석 자원지.
const STONE := 2

## 나무. 목재 획득처이자 기본 건축재.
const WOOD := 3

## 닫힌 문. 막혀 있다.
const DOOR_CLOSED := 4

## 열린 문. 지나갈 수 있다. 빈 칸과 달리 자리에 남아 있다.
const DOOR_OPEN := 5

## 감지기. 지정한 대상을 보고 신호를 낸다.
const DETECTOR := 6

## 작동기. 붙어 있는 블록을 작동시킨다.
const ACTUATOR := 7

## 되풀이. 받은 신호를 정한 간격으로 반복해 내보낸다.
const REPEATER := 8

## 상자. 값 하나를 담는다.
const BOX := 9

const COUNT := 10

const _NAMES: PackedStringArray = [
    "empty", "ground", "stone", "wood",
    "door_closed", "door_open", "detector", "actuator", "repeater", "box",
]


static func is_valid(type: int) -> bool:
    return type >= 0 and type < COUNT


## 통과할 수 없는가. 열린 문은 자리에 있어도 지나갈 수 있다.
static func is_solid(type: int) -> bool:
    return is_valid(type) and type != EMPTY and type != DOOR_OPEN


## 부술 것이 있는가. 열린 문도 부술 수 있다.
static func is_breakable(type: int) -> bool:
    return is_valid(type) and type != EMPTY


static func is_door(type: int) -> bool:
    return type == DOOR_CLOSED or type == DOOR_OPEN


## 회로 부품인가.
static func is_part(type: int) -> bool:
    return type == DETECTOR or type == ACTUATOR or type == REPEATER or type == BOX


static func opened_door() -> int:
    return DOOR_OPEN


static func closed_door() -> int:
    return DOOR_CLOSED


## 부쉈을 때 손에 들어오는 재료. 열린 문을 부수면 문이 들어온다.
static func material_of(type: int) -> int:
    if type == DOOR_OPEN:
        return DOOR_CLOSED
    return type


## 진단과 직렬화용 이름. 게임 화면에 그대로 내보내지 않는다.
static func name_of(type: int) -> String:
    if not is_valid(type):
        return "invalid"
    return _NAMES[type]
