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

## 흙의 옆면. 윗면은 풀, 옆면은 흙이다.
##
## 한 색으로 여섯 면을 다 칠하면 놓은 블록이 땅에 묻힌다. 세 칸짜리 탑을
## 세워도 "벽을 세웠다"가 아니라 "그림자가 생겼다"로 보였다. 옆면이 드러나야
## 블록이 땅에서 솟아오르고, 파 놓은 구덩이에 깊이가 생긴다.
const GROUND_SIDE := Color(0.66, 0.60, 0.46)
## 광석. 지하와 자원지에서 캔다. 잿빛 돌 사이에서 푸르게 도드라진다.
## 감지기의 하늘빛과는 떨어뜨려 두었다. 붙으면 회로 부품으로 보인다.
const ORE := Color(0.58, 0.70, 0.86)

## 돌. 지하를 이루는 흔한 암반.
const ROCK := Color(0.72, 0.71, 0.74)

## 돌의 옆면. 켜켜이 쌓인 것이 보이도록 조금 어둡게.
const ROCK_SIDE := Color(0.64, 0.63, 0.67)
const WOOD := Color(0.80, 0.63, 0.48)

## 나뭇잎. 블록이 아니라 줄기 위에 덧그리는 것이라 블록 색 목록에는 없다.
const LEAF := Color(0.56, 0.80, 0.50)
const DOOR := Color(0.95, 0.84, 0.58)
const DETECTOR := Color(0.60, 0.82, 0.94)
const ACTUATOR := Color(0.96, 0.70, 0.76)
const REPEATER := Color(0.84, 0.92, 0.66)
const BOX := Color(0.76, 0.68, 0.95)
const BRANCH := Color(0.98, 0.72, 0.56)
const FIELD := Color(0.72, 0.60, 0.66)
const CROP := Color(0.96, 0.98, 0.74)

## 등. 꺼진 것은 잿빛이 돌고 켜진 것은 환하다.
const LAMP_DARK := Color(0.80, 0.78, 0.62)
const LAMP_LIT := Color(1.0, 0.96, 0.72)

## 궤짝. 나무로 짠 것이라 나무빛이되 조금 붉다.
const CHEST := Color(0.86, 0.70, 0.52)

## 아래 넷은 **빈자리를 찾아서** 골랐다.
##
## 파스텔은 쓸 수 있는 폭이 좁다(명도 0.60 이상, 채도 0.45 이하). 블록이
## 열몇 종을 넘으면 색만으로 가를 자리가 남지 않는다. 그래서 눈으로 고르지
## 않고, 이미 있는 열다섯 색에서 모두 0.13 넘게 떨어진 자리를 찾아서 잡았다.
## 그 결과 **새로 겹치는 짝이 하나도 없다** (기존의 나무·궤짝 하나뿐).
##
## 뜻에 맞는 색이 아니라 남은 색이라는 점은 인정한다. 판자가 나무보다
## 노란 것은 그 자리밖에 남지 않았기 때문이다.

## 모래. 물가에 깔린다.
const SAND := Color(0.96, 0.84, 0.72)

## 불씨돌. 잿빛 돌 사이에서 붉게 도드라진다.
## 광석의 푸른빛과 색상환에서 마주 보게 두어 굴 벽에서 둘이 갈린다.
const EMBER := Color(0.92, 0.54, 0.52)

## 판자. 갓 켠 것이라 나무보다 밝고 누르다.
const PLANK := Color(0.84, 0.84, 0.48)

## 관솔불. 늘 켜져 있으므로 켜진 등 가까이 두되 갈릴 만큼은 떨어뜨렸다.
const TORCH := Color(1.0, 0.98, 0.60)

## 도구. **손에만 들리므로 세상에 놓이지 않는다.**
##
## 그래서 블록끼리의 색 규칙에서 뺀다. 굴 벽에 나란히 박히는 일이 없고,
## 손에 든 그림에서만 서로 갈리면 된다 — 거기서는 생김새가 먼저 가른다
## (곡괭이는 가로날, 도끼는 치우친 날, 삽은 아래로 넓은 날).
const TOOL_WOOD := Color(0.80, 0.68, 0.52)
const TOOL_STONE := Color(0.74, 0.74, 0.78)
const BUNDLE := Color(0.56, 0.93, 0.78)

const CHARACTER_SKIN := Color(0.98, 0.86, 0.74)
const CHARACTER_BODY := Color(0.72, 0.86, 0.94)
const CHARACTER_LEGS := Color(0.62, 0.68, 0.82)
const THREAT := Color(0.82, 0.68, 0.86)

## 부품 위에 얹는 설정 표시. 어느 부품 색 위에 얹혀도 읽히도록 톤을 낮춰 잡는다.
##
## **갈래마다 색을 달리한다.** 한 색으로 통일했더니, 열두 픽셀짜리 같은 색
## 알갱이 열여덟 종이 되어 판에 스무 개 놓이면 그냥 알갱이 스무 개였다.
## 형태만으로 갈리기에는 화면에서 너무 작다. 금지된 것은 글자와 기호이지
## 색이 아니다 — 형태로 갈래 안을 가르고, 색으로 갈래끼리 가른다.
##
## 파스텔 규칙은 블록 몸통 색의 것이다. 표시는 몸통 위에 얹히므로 반대로
## 톤이 낮아야 읽힌다.
const PART_MARK := Color(0.34, 0.36, 0.44)

## 감지기가 무엇을 보는가.
const PART_MARK_EYE := Color(0.20, 0.42, 0.46)

## 갈림길이 무엇을 재는가.
const PART_MARK_JUDGE := Color(0.44, 0.26, 0.44)

## 되풀이가 어떻게 도는가.
const PART_MARK_TURN := Color(0.50, 0.34, 0.18)

## 묶음이 얼마나 삼켰는가.
const PART_MARK_BUNDLE := Color(0.22, 0.40, 0.26)

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
## 섬을 둘러싼 물.
##
## 하늘과 붙여 두면 물가가 사라진다. 위에서 내려다보는 시점이라 바다와 하늘이
## 화면에서 맞닿으므로, 뭍·물·하늘이 세 가지로 읽혀야 한다.
const SEA := Color(0.50, 0.72, 0.86)

## 땅에 깔린 풀과 꽃의 빛깔.
##
## 잔돌은 뺐다. 캘 수 있는 광석과 색이 붙어 있어서, 부술 수 없는
## 조약돌을 캐려다 "부수기가 고장났다"고 결론짓는 사람이 나온다.
##
## 바깥에서 가져온 모델은 제 색을 달고 온다. 그대로 두면 톤이 흩어지므로
## **모양만 받고 색은 여기서 준다.** 색을 한 곳에 모아 둔다는 규칙은
## 가져온 것에도 그대로 적용된다.
const COVER_GRASS := Color(0.76, 0.90, 0.58)
const COVER_LEAF := Color(0.62, 0.84, 0.66)
const COVER_FLOWER_YELLOW := Color(0.99, 0.92, 0.62)
const COVER_FLOWER_PURPLE := Color(0.84, 0.74, 0.96)
const COVER_FLOWER_RED := Color(0.98, 0.74, 0.74)
const COVER_MUSHROOM := Color(0.96, 0.78, 0.72)

## 땅에 깔리는 것들의 빛깔 전부. 톤 검사가 훑는다.
const COVER_COLOURS: Array[Color] = [
    COVER_GRASS, COVER_LEAF, COVER_FLOWER_YELLOW, COVER_FLOWER_PURPLE,
    COVER_FLOWER_RED, COVER_MUSHROOM,
]

const SKY_DAY := Color(0.66, 0.82, 0.92)
const SKY_NIGHT := Color(0.14, 0.17, 0.34)
const AMBIENT_DAY := Color(0.43, 0.46, 0.52)
const AMBIENT_NIGHT := Color(0.12, 0.16, 0.32)

## 해와 달의 빛깔. 세기는 [SkyView] 가 정하고 여기서는 빛깔만 정한다.
##
## 밤에 밝기만 낮추면 초록이 그대로 초록이라 흐린 낮이 된다. 달빛을 파랗게
## 돌리면 명도를 크게 낮추지 않고도 밤이 된다.
const SUNLIGHT := Color(1.0, 0.97, 0.90)
const MOONLIGHT := Color(0.58, 0.70, 1.0)

const _BLOCKS: Dictionary[int, Color] = {
    BlockType.GROUND: GROUND,
    BlockType.ORE: ORE,
    BlockType.ROCK: ROCK,
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
    BlockType.LAMP_DARK: LAMP_DARK,
    BlockType.LAMP_LIT: LAMP_LIT,
    BlockType.CHEST: CHEST,
    BlockType.BUNDLE: BUNDLE,
    BlockType.SAND: SAND,
    BlockType.EMBER: EMBER,
    BlockType.PLANK: PLANK,
    BlockType.TORCH: TORCH,
    BlockType.WOOD_PICK: TOOL_WOOD,
    BlockType.STONE_PICK: TOOL_STONE,
    BlockType.STONE_AXE: TOOL_STONE,
    BlockType.STONE_SHOVEL: TOOL_STONE,
}


## 그 블록의 옆면 색. 따로 정하지 않았으면 윗면과 같다.
const _SIDES: Dictionary[int, Color] = {
    BlockType.GROUND: GROUND_SIDE,
    BlockType.ROCK: ROCK_SIDE,
}


static func of_block(block_type: int) -> Color:
    return _BLOCKS.get(block_type, MISSING)


## 옆면 색. 윗면과 다른 것은 흙뿐이다.
static func side_of(block_type: int) -> Color:
    return _SIDES.get(block_type, of_block(block_type))


## 칸마다 주는 명암의 배수. 1 을 기준으로 아주 조금 위아래로 흔든다.
##
## 색 자체가 아니라 배수를 돌려주는 이유는, 면마다 색이 다른 블록이 생겼기
## 때문이다. 색은 면이 정하고 이 값은 칸이 정한다.
static func variation_of(cell: Vector3i) -> float:
    return 1.0 + (_cell_noise(cell) * 2.0 - 1.0) * VARIATION


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
