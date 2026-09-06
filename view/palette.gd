class_name Palette
extends RefCounted

## 블록 이름 → 단색 팔레트 (헌법 P12). 표현 레이어 전용, 전부 static.
##
## `BlockRegistry.name_of` 는 표현 레이어 전용 — P2 의 렌더링 예외다. sim 은 이름을 보지 않는다.
## 여기서 쓰는 단색 사각형(다이아몬드)은 P12 가 M6 까지 허용하는 플레이스홀더다. M7 에서
## `tools/pixelart/` 가 만든 스프라이트로 전량 교체된다.
##
## 톤: 밝고 채도 높은 메이플스토리2 계열. 값은 조정 가능하나 키 집합은 `data/blocks.json` 의 이름
## 집합과 항상 같아야 한다 — 테스트가 양방향으로 강제한다(새 블록 = 팔레트도 한 줄).

## 지하층 아래의 암묵 기반암(DECISIONS 2026-09-06 "층 3개" 파생). 어둡고 차가운 회청색.
const BEDROCK := Color(0.16, 0.16, 0.20)

## 바닥 없음(떨어지는 칸). 투명 — 그리지 않는다. 기반암과 눈으로 구별돼야 한다.
const VOID := Color(0, 0, 0, 0)

## 팔레트에 없는 이름. 마젠타 — 누락이 화면에서 바로 보이게.
const UNKNOWN := Color(1, 0, 1)

## 아래 층 블록을 바닥으로 그릴 때 곱하는 밝기.
const FLOOR_DIM := 0.55

const NAME_TO_COLOR: Dictionary = {
    "air": Color(0, 0, 0, 0),
    "dirt": Color(0.62, 0.42, 0.24),
    "stone": Color(0.62, 0.65, 0.70),
    "sand": Color(0.96, 0.87, 0.50),
    "wood": Color(0.78, 0.55, 0.30),
    "grass": Color(0.45, 0.82, 0.35),
}


## 블록 [param id] 의 색. [param registry] 가 null 이거나 이름이 팔레트에 없으면 UNKNOWN.
## name_of 는 표현 레이어 전용 — P2 의 렌더링 예외. 단색은 P12 가 M6 까지 허용하는 플레이스홀더.
static func color_for(registry: BlockRegistry, id: int) -> Color:
    if registry == null:
        return UNKNOWN
    var name := registry.name_of(id)
    if not NAME_TO_COLOR.has(name):
        return UNKNOWN
    return NAME_TO_COLOR[name]


## 바닥용 어둡게. RGB 에 FLOOR_DIM 을 곱하고 알파는 그대로 둔다.
static func dim(c: Color) -> Color:
    return Color(c.r * FLOOR_DIM, c.g * FLOOR_DIM, c.b * FLOOR_DIM, c.a)
