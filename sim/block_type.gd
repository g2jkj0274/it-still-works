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

## 광석. 부품을 만드는 데 든다. 섬 바깥쪽 자원지와 지하 깊은 곳에 있다.
const ORE := 2

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

## 갈림길. 조건을 판정해 신호를 한쪽으로만 보낸다.
const BRANCH := 10

## 밭. 작물이 자란다.
const FIELD := 11

## 거둔 작물. 먹을 거리다.
const CROP := 12

## 묶음. 회로 하나를 통째로 압축해 담은 부품. 안은 밖에서 보이지 않는다.
const BUNDLE := 13

## 돌. 지하를 이루는 흔한 암반. 흙보다 단단해 보이고 광석과는 다르다.
const ROCK := 14

## 꺼진 등.
const LAMP_DARK := 15

## 켜진 등. 둘레를 밝힌다. 문과 마찬가지로 작동기가 여닫는다.
const LAMP_LIT := 16

## 궤짝. 물건을 넣어 둔다. 손이 모자라야 왕복에 값이 붙고, 넣어 둘 곳이
## 있어야 손이 모자란 것이 짜증이 아니라 살림이 된다.
const CHEST := 17

const COUNT := 18

const _NAMES: PackedStringArray = [
    "empty", "ground", "ore", "wood",
    "door_closed", "door_open", "detector", "actuator", "repeater", "box", "branch", "field", "crop",
    "bundle", "rock", "lamp_dark", "lamp_lit", "chest",
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


## 등인가. 작동기가 켜고 끈다.
static func is_lamp(type: int) -> bool:
    return type == LAMP_DARK or type == LAMP_LIT


static func lit_lamp() -> int:
    return LAMP_LIT


static func dark_lamp() -> int:
    return LAMP_DARK


## 회로 부품인가.
static func is_part(type: int) -> bool:
    if type == DETECTOR or type == ACTUATOR or type == REPEATER:
        return true
    return type == BOX or type == BRANCH or type == BUNDLE


## 종류 번호만으로는 어느 것인지 가려지지 않는 부품인가.
##
## 묶음은 안에 무엇이 들었는지가 저마다 다르다. 인벤토리에서 종류와 함께
## **어느 것인지**를 들고 다녀야 하고, 같은 번호끼리만 한 칸에 쌓인다.
static func is_uniquely_made(type: int) -> bool:
    return type == BUNDLE


static func opened_door() -> int:
    return DOOR_OPEN


static func closed_door() -> int:
    return DOOR_CLOSED


## 부쉈을 때 손에 들어오는 재료. 열린 문을 부수면 문이 들어온다.
static func material_of(type: int) -> int:
    if type == DOOR_OPEN:
        return DOOR_CLOSED
    if type == LAMP_LIT:
        return LAMP_DARK
    return type


## 진단과 직렬화용 이름. 게임 화면에 그대로 내보내지 않는다.
static func name_of(type: int) -> String:
    if not is_valid(type):
        return "invalid"
    return _NAMES[type]
