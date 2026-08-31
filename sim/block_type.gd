class_name BlockType
extends RefCounted

## 복셀 한 칸에 들어갈 수 있는 블록 종류.
##
## 회로 부품과는 별개다. 부품 목록은 docs/spec.md 4.2 에서만 바꾼다.
## 여기의 지형 블록은 docs/spec.md 3.1 을 따른다.

## 빈 칸. 0 이어야 새로 만든 격자가 곧바로 빈 상태가 된다.
const EMPTY := 0

## 섬의 지면.
const GROUND := 1

## 광석 자원지.
const STONE := 2

## 나무. 목재 획득처이자 기본 건축재.
const WOOD := 3

const COUNT := 4

const _NAMES: PackedStringArray = ["empty", "ground", "stone", "wood"]


static func is_valid(type: int) -> bool:
    return type >= 0 and type < COUNT


## 빈 칸이 아니면 통과할 수 없다.
static func is_solid(type: int) -> bool:
    return is_valid(type) and type != EMPTY


## 진단과 직렬화용 이름. 게임 화면에 그대로 내보내지 않는다.
static func name_of(type: int) -> String:
    if not is_valid(type):
        return "invalid"
    return _NAMES[type]
