class_name UiTheme
extends RefCounted

## 화면에 얹히는 것들의 빛깔과 치수를 한곳에 모은다.
##
## 모으기 전에는 여섯 파일이 저마다 색을 정했다. `TEXT_COLOUR` 가 네 곳에
## 조금씩 다른 값으로 있었고, 판의 바탕이 어떤 곳은 흰색 0.78 이고 어떤 곳은
## 0.92 였다. 간격도 모서리도 글자 크기도 파일마다 달랐다. **체계가 없으면
## 아무리 손봐도 만든 티가 나지 않는다.**
##
## ## 왜 어두운 판인가
##
## 게임 팔레트는 파스텔이다 — 명도 0.60 이상, 채도 0.45 이하([Palette]).
## 그 위에 흰 판을 얹으면 화면에서 가장 밝은 것이 UI 가 되고, 정작 봐야 할
## 블록이 뒤로 물러난다. **화면에서 밝은 것은 세계여야 한다.**
##
## 그래서 판은 파스텔 선 아래로 내린다. 어두운 판에 밝은 글씨다. 낮의 밝은
## 지면 위에서도, 밤의 어두운 지면 위에서도 같은 판이 읽힌다 — 판이 스스로
## 배경을 들고 있기 때문이다.
##
## ## 글꼴
##
## **글꼴 자산이 아직 없다.** 지금은 엔진 기본 글꼴이고, 그것만으로도
## 만든 티가 덜 난다. 크기와 간격만이라도 한 자에서 재도록 여기 모아 둔다.
## 글꼴 파일이 들어오면 [method apply] 한 곳만 고치면 된다.

# ── 빛깔 ──────────────────────────────────────────────────────

## 판의 바탕. 반투명이라 뒤의 세계가 비친다.
const PANEL := Color(0.08, 0.09, 0.12, 0.82)

## 판의 테두리. 바탕과 세계 사이에 가는 선 하나를 둔다.
const PANEL_EDGE := Color(1.0, 1.0, 1.0, 0.12)

## 판 위의 글자.
const INK := Color(0.95, 0.96, 0.98)
const INK_DIM := Color(0.72, 0.75, 0.82)
const INK_FAINT := Color(0.52, 0.55, 0.62)

## 눈이 가야 할 곳. 게임의 배선 빛깔에서 끌어왔다.
const ACCENT := Color(1.0, 0.88, 0.52)

## 지표.
const HEALTH := Color(0.93, 0.45, 0.47)
const FOOD := Color(0.95, 0.76, 0.40)

## 채워지지 않은 부분. 판 위에 얹히므로 흰빛을 아주 옅게 쓴다.
const TRACK := Color(1.0, 1.0, 1.0, 0.14)

## 낮과 밤.
const DAY := Color(0.98, 0.86, 0.48)
const NIGHT := Color(0.36, 0.40, 0.62)

## 세계 위에 판 없이 놓이는 글자. 스스로 배경을 들고 다녀야 한다.
const OUTLINE := Color(0.06, 0.07, 0.10, 0.72)
const OUTLINE_SIZE := 5

# ── 치수 ──────────────────────────────────────────────────────

## 간격의 눈금. 이 다섯 말고 다른 수를 쓰지 않는다.
const GAP_TIGHT := 4.0
const GAP := 8.0
const GAP_WIDE := 12.0
const GAP_LOOSE := 16.0
const GAP_EDGE := 20.0

## 모서리. 작은 것과 판.
const RADIUS_SMALL := 5
const RADIUS := 9

## 글자 크기의 눈금.
const TEXT_SMALL := 12
const TEXT := 14
const TEXT_TITLE := 17


## 판 하나. 어디서든 같은 판이 나온다.
static func panel_style(radius: int = RADIUS) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.set_corner_radius_all(radius)
    style.set_border_width_all(1)
    style.border_color = PANEL_EDGE
    return style


## 속이 빈 판. 칸을 나누어 보일 때 쓴다.
static func slot_style(fill: Color, edge: Color, radius: int = RADIUS_SMALL) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.set_corner_radius_all(radius)
    style.set_border_width_all(1)
    style.border_color = edge
    return style


## 글자 하나. 크기와 빛깔을 한 자에서 잰다.
##
## [param outlined] 는 판 없이 세계 위에 놓일 때다. 그때만 테두리를 두른다 —
## 판 안에서 테두리를 두르면 글자가 뭉개진다.
static func apply(label: Label, size: int = TEXT, colour: Color = INK,
        outlined: bool = false) -> void:
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", colour)
    if outlined:
        label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
        label.add_theme_color_override("font_outline_color", OUTLINE)
    else:
        label.add_theme_constant_override("outline_size", 0)
