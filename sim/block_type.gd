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

## 돌. 지하를 이루는 흔한 암반. 흙보다 단단해 보이고 광석과는 다르다.
const ROCK := 13

## 꺼진 등.
const LAMP_DARK := 14

## 켜진 등. 둘레를 밝힌다. 문과 마찬가지로 작동기가 여닫는다.
const LAMP_LIT := 15

## 궤짝. 물건을 넣어 둔다. 손이 모자라야 왕복에 값이 붙고, 넣어 둘 곳이
## 있어야 손이 모자란 것이 짜증이 아니라 살림이 된다.
const CHEST := 16

## 모래. 물가에 깔린다. 유리의 재료다.
const SAND := 17

## 불씨돌. 굽는 데 드는 것이자 관솔불의 재료다. 흙 아래 얕은 곳에 든다.
const EMBER := 18

## 판자. 나무를 켠 것. **제작법 대부분이 이것을 거친다.**
const PLANK := 19

## 관솔불. 놓으면 작게 밝힌다. 작동기가 여닫지 못해 늘 켜져 있다.
##
## 등과 갈라 둔 까닭은 **첫 굴에 빛이 있어야 하기 때문**이다. 등은 광석이
## 들고 광석은 돌 곡괭이가 있어야 캐는데, 파고 내려가기 시작하는 것은
## 나무 곡괭이일 때다.
const TORCH := 20

## 화로. **작동기가 때려야 한 번 돈다.** 손으로는 돌아가지 않는다.
##
## 이것이 이 게임이 마인크래프트와 갈리는 자리다. 저쪽 화로는 연료만 있으면
## 혼자 돌지만 여기서는 회로가 필요하다. 그래서 트리를 올라가려면 회로를
## 지어야 하고, 회로를 지으려면 트리를 올라가야 한다(스펙 §3.6).
const FURNACE := 21

## 불이 붙은 화로. 신호가 닿는 동안이다. 등과 같은 짝이다.
const FURNACE_LIT := 22

## 작업대. 세 칸 안에 서면 쇳덩이가 드는 것을 만들 수 있다.
const BENCH := 23

## 구운 것들.
const INGOT := 24
const BRICK := 25
const GLASS := 26
const COOKED_CROP := 27

## 튼튼한 문. 위협이 부수지 못한다.
const IRON_DOOR_CLOSED := 28
const IRON_DOOR_OPEN := 29

## 도구. 손에 들면 무엇을 캘 수 있는지가 달라진다.
## 격자에 놓이지 않는다 — 물건이지 블록이 아니다.
const WOOD_PICK := 30
const STONE_PICK := 31
const STONE_AXE := 32
const STONE_SHOVEL := 33
const IRON_PICK := 34
const IRON_AXE := 35

const COUNT := 36

## 도구는 여기부터다. 이 아래는 전부 격자에 놓이는 블록이다.
const FIRST_TOOL := WOOD_PICK

const _NAMES: PackedStringArray = [
    "empty", "ground", "ore", "wood",
    "door_closed", "door_open", "detector", "actuator", "repeater", "box", "branch", "field", "crop",
    "rock", "lamp_dark", "lamp_lit", "chest",
    "sand", "ember", "plank", "torch",
    "furnace", "furnace_lit", "bench",
    "ingot", "brick", "glass", "cooked_crop",
    "iron_door_closed", "iron_door_open",
    "wood_pick", "stone_pick", "stone_axe", "stone_shovel", "iron_pick", "iron_axe",
]


static func is_valid(type: int) -> bool:
    return type >= 0 and type < COUNT


## 손에만 드는 것인가. 격자에 놓이지 않는다.
##
## 이름이 `is_tool` 이 아닌 까닭은 Godot 의 `Script.is_tool()` 과 부딪히기
## 때문이다. `BlockType.is_tool(...)` 은 조용히 그쪽으로 붙어 인자 수가 틀렸다는
## 엉뚱한 오류만 낸다.
static func is_handheld(type: int) -> bool:
    return type >= FIRST_TOOL and type < COUNT


## 손에 들 수 있는가. 빈 칸만 들 수 없다.
##
## **통과 여부와는 다른 물음이다.** 관솔불은 지나갈 수 있지만 손에 들리고,
## 도구는 격자에 놓이지 않지만 손에 들린다. 인벤토리가 [method is_solid] 를
## 쓰고 있었기 때문에 관솔불이 손에 들어오지 않았다.
static func is_carryable(type: int) -> bool:
    return is_valid(type) and type != EMPTY


## 화면에 그려지는가. 빈 칸과 손에만 드는 것만 그려지지 않는다.
##
## **지나갈 수 있는지와는 다른 물음이다.** 열린 문과 관솔불은 지나갈 수
## 있지만 자리에 남아 있고, 남아 있으면 보여야 한다.
static func is_drawn(type: int) -> bool:
    return is_valid(type) and type != EMPTY and not is_handheld(type)


## 격자 한 칸에 놓일 수 있는가. 도구는 놓이지 않는다.
static func is_placeable(type: int) -> bool:
    return is_solid(type) and not is_handheld(type)


## 통과할 수 없는가. 열린 문은 자리에 있어도 지나갈 수 있다.
##
## 관솔불은 지나갈 수 있다. 굴을 밝히려고 놓은 것이 길을 막으면
## 밝힌 굴을 되돌아 나올 수 없다.
static func is_solid(type: int) -> bool:
    if type == EMPTY or type == DOOR_OPEN or type == TORCH:
        return false
    return is_valid(type)


## 부술 것이 있는가. 열린 문도 부술 수 있다.
static func is_breakable(type: int) -> bool:
    return is_valid(type) and type != EMPTY


static func is_door(type: int) -> bool:
    if type == IRON_DOOR_CLOSED or type == IRON_DOOR_OPEN:
        return true
    return type == DOOR_CLOSED or type == DOOR_OPEN


## 위협이 부수지 못하는 문인가. 밤에 회로를 지키는 값이 여기서 생긴다.
static func is_strong_door(type: int) -> bool:
    return type == IRON_DOOR_CLOSED or type == IRON_DOOR_OPEN


## 화로인가. 불이 붙었든 꺼졌든.
static func is_furnace(type: int) -> bool:
    return type == FURNACE or type == FURNACE_LIT


## 등인가. 작동기가 켜고 끈다.
static func is_lamp(type: int) -> bool:
    return type == LAMP_DARK or type == LAMP_LIT


## 스스로 빛나는가. 관솔불은 회로 없이 늘 켜져 있다.
static func is_light(type: int) -> bool:
    if type == FURNACE_LIT:
        return true
    return type == LAMP_LIT or type == TORCH


static func lit_lamp() -> int:
    return LAMP_LIT


static func dark_lamp() -> int:
    return LAMP_DARK


## 회로 부품인가.
static func is_part(type: int) -> bool:
    if type == DETECTOR or type == ACTUATOR or type == REPEATER:
        return true
    return type == BOX or type == BRANCH


static func opened_door(type: int = DOOR_CLOSED) -> int:
    return IRON_DOOR_OPEN if is_strong_door(type) else DOOR_OPEN


static func closed_door(type: int = DOOR_CLOSED) -> int:
    return IRON_DOOR_CLOSED if is_strong_door(type) else DOOR_CLOSED


## 부쉈을 때 손에 들어오는 재료. 열린 문을 부수면 문이 들어온다.
static func material_of(type: int) -> int:
    if type == DOOR_OPEN:
        return DOOR_CLOSED
    if type == IRON_DOOR_OPEN:
        return IRON_DOOR_CLOSED
    if type == LAMP_LIT:
        return LAMP_DARK
    if type == FURNACE_LIT:
        return FURNACE
    return type


## 진단과 직렬화용 이름. 게임 화면에 그대로 내보내지 않는다.
static func name_of(type: int) -> String:
    if not is_valid(type):
        return "invalid"
    return _NAMES[type]
