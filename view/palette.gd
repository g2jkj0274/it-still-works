class_name Palette
extends RefCounted

## 게임 전체의 빛깔.
##
## 아트 방향은 아이소메트릭 파스텔, 밝고 경쾌함이다. 색을 한 곳에 모아 두어야
## 톤이 흩어지지 않는다. 새 블록을 넣을 때도 여기만 고치면 된다.
##
## 밝고(명도 높고) 채도 낮은 색만 쓴다. 그 규칙은 테스트가 지킨다.

## 팔레트에 없는 것을 물었을 때.
const MISSING := Color(1.0, 0.0, 1.0)

## 파스텔의 경계.
const MIN_VALUE := 0.60
const MAX_SATURATION := 0.45

## 같은 종류 블록의 칸마다 주는 명도 변주 폭.
## 넓은 면이 단조로워 보이지 않을 만큼만, 종류를 알아볼 수 있을 만큼 작게.
const VARIATION := 0.045

## 파스텔은 쓸 수 있는 폭이 좁다. 색상환에 고르게 펴야 서로 구별된다.
const GROUND := Color(0.64, 0.84, 0.58)
const STONE := Color(0.68, 0.74, 0.84)
const WOOD := Color(0.80, 0.63, 0.48)
const DOOR := Color(0.95, 0.84, 0.58)
const DETECTOR := Color(0.60, 0.82, 0.94)
const ACTUATOR := Color(0.96, 0.70, 0.76)
const REPEATER := Color(0.84, 0.92, 0.66)
const BOX := Color(0.76, 0.68, 0.95)
const BRANCH := Color(0.98, 0.72, 0.56)
const FIELD := Color(0.72, 0.60, 0.66)
const CROP := Color(0.96, 0.98, 0.74)
const BUNDLE := Color(0.56, 0.93, 0.78)

const CHARACTER_SKIN := Color(0.98, 0.86, 0.74)
const CHARACTER_BODY := Color(0.72, 0.86, 0.94)
const CHARACTER_LEGS := Color(0.62, 0.68, 0.82)
const THREAT := Color(0.82, 0.68, 0.86)

const HIGHLIGHT := Color(1.0, 1.0, 1.0, 0.32)

## 묶으려고 고른 칸 표시. 값이 드나드는 자리는 배선 색과 짝을 맞춘다.
## 밝은 지면 위에 얹히므로 흰 것은 보이지 않는다. 고른 칸은 톤을 낮춰 잡는다.
const MARK_CHOSEN := Color(0.52, 0.55, 0.68, 0.48)
const MARK_ENTRY := Color(0.98, 0.82, 0.34, 0.48)
const MARK_EXIT := Color(0.42, 0.72, 0.98, 0.48)
## 배선 색. 갈림길의 참 쪽과 거짓 쪽을 나눠 보여준다.
## 밝으면 지금 신호가 흐르는 것이고 흐리면 흐르지 않는 것이다.
const WIRE_LIVE := Color(1.0, 0.92, 0.60)
const WIRE_IDLE := Color(0.72, 0.72, 0.70)
const WIRE_FALSE_LIVE := Color(0.62, 0.86, 1.0)
const WIRE_FALSE_IDLE := Color(0.58, 0.66, 0.74)

## 하늘빛과 햇빛의 세기는 팔레트가 아니라 [SkyView] 가 정한다.
##
## 여기 적힌 것은 빛의 **빛깔**이다. 세기까지 여기서 정하면 색을 고르는 일과
## 노출을 맞추는 일이 한 상수에 섞인다.
##
## 낮 빛깔을 낮춰 잡은 것은 이유가 있다. 이보다 밝으면 볕 든 지면이 흰색으로
## 날아가 블록 경계도 팔레트의 칸별 변주도 보이지 않는다. 실제로 재어 보고
## 볕 든 흙이 팔레트에 적힌 제 색으로 나오는 지점을 골랐다.
## 섬을 둘러싼 물. 하늘보다 조금 짙어 물가가 눈에 보인다.
const SEA := Color(0.56, 0.78, 0.90)

const SKY_DAY := Color(0.66, 0.82, 0.92)
const SKY_NIGHT := Color(0.17, 0.20, 0.32)
const AMBIENT_DAY := Color(0.43, 0.46, 0.52)
const AMBIENT_NIGHT := Color(0.16, 0.18, 0.27)

const _BLOCKS: Dictionary[int, Color] = {
    BlockType.GROUND: GROUND,
    BlockType.STONE: STONE,
    BlockType.WOOD: WOOD,
    BlockType.DOOR_CLOSED: DOOR,
    BlockType.DOOR_OPEN: DOOR,
    BlockType.DETECTOR: DETECTOR,
    BlockType.ACTUATOR: ACTUATOR,
    BlockType.REPEATER: REPEATER,
    BlockType.BOX: BOX,
    BlockType.BRANCH: BRANCH,
    BlockType.FIELD: FIELD,
    BlockType.CROP: CROP,
    BlockType.BUNDLE: BUNDLE,
}


static func of_block(block_type: int) -> Color:
    return _BLOCKS.get(block_type, MISSING)


## 칸마다 아주 조금 다른 명암을 준다.
##
## 넓은 지면이 한 덩어리 색으로 보이지 않게 하는 것이 전부다.
## 자리에서 값을 뽑으므로 실행할 때마다 같은 무늬가 나온다.
static func varied(base: Color, cell: Vector3i) -> Color:
    var noise := _cell_noise(cell)
    var shifted := base.v + (noise * 2.0 - 1.0) * VARIATION
    var shade := base
    shade.v = clampf(shifted, 0.0, 1.0)
    return shade


## 칸 좌표에서 0..1 사이의 값을 뽑는다. 난수가 아니라 뒤섞기다.
static func _cell_noise(cell: Vector3i) -> float:
    var mixed := cell.x * 73856093 ^ cell.y * 19349663 ^ cell.z * 83492791
    return float(absi(mixed) % 1000) / 999.0
