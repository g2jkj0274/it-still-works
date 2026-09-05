class_name Notice
extends CanvasLayer

## 방금 무슨 일이 있었는지 한 줄로 알리고 스스로 사라진다.
##
## 저장했는지 불러왔는지는 화면에 아무 변화가 없어 알 수가 없다. 그것만
## 알린다. **회로가 왜 안 도는지는 여기서도 말하지 않는다.**
##
## 늘 떠 있으면 화면을 가리므로 잠깐 보이고 지워진다.

const SECONDS := 2.0
const TOP_MARGIN := 24.0
const PADDING := 10.0

## 빛깔과 치수는 [UiTheme] 이 정한다.

var _label: Label
var _panel: Panel
var _anchor: Control
var _left: float = 0.0


func _ready() -> void:
    _anchor = Control.new()
    _anchor.name = "Anchor"
    _anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
    _anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_anchor)

    var style := UiTheme.panel_style()

    _panel = Panel.new()
    _panel.name = "Line"
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_theme_stylebox_override("panel", style)
    _anchor.add_child(_panel)

    _label = Label.new()
    _label.name = "Text"
    # 핫바와 같은 이유로 줄바꿈을 켜지 않는다. 켜면 칸 폭이 0 에 가깝게 잡힌다.
    _label.autowrap_mode = TextServer.AUTOWRAP_OFF
    _label.clip_text = true
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    UiTheme.apply(_label, UiTheme.TEXT, UiTheme.INK)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_child(_label)

    visible = false


func _process(delta: float) -> void:
    if not visible:
        return
    _left -= delta
    if _left <= 0.0:
        visible = false


## [param text] 를 잠깐 보인다.
func say(text: String, seconds: float = SECONDS) -> void:
    _label.text = text
    _left = seconds
    visible = true
    _lay_out()


func text() -> String:
    return _label.text


func seconds_left() -> float:
    return _left


func panel_rect() -> Rect2:
    return Rect2(_panel.position, _panel.size)


## 글이 통째로 화면 안에 들어와 있는가.
func fully_visible() -> bool:
    return Rect2(Vector2.ZERO, _screen_size()).encloses(panel_rect())


func _screen_size() -> Vector2:
    var viewport := get_viewport()
    if viewport == null:
        return Vector2(1152, 648)
    return viewport.get_visible_rect().size


## 글자 너비를 직접 재서 칸을 잡는다. 부품 설명 줄과 같은 이유다.
func _lay_out() -> void:
    var screen := _screen_size()
    var measured := _measure()

    var width := minf(measured.x + PADDING * 2.0, screen.x - PADDING * 2.0)
    var height := measured.y + PADDING * 2.0

    _panel.size = Vector2(width, height)
    _panel.position = Vector2((screen.x - width) * 0.5, TOP_MARGIN)
    _label.position = Vector2(PADDING, PADDING)
    _label.size = Vector2(width - PADDING * 2.0, measured.y)


func _measure() -> Vector2:
    var font := _label.get_theme_font("font")
    var font_size := _label.get_theme_font_size("font_size")
    if font == null:
        return Vector2(_label.text.length() * 8.0, 16.0)
    return font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
