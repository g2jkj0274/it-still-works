class_name WireView
extends Node3D

## 부품 사이의 배선을 그린다.
##
## 회로를 읽기만 한다. 배선이 바뀌었을 때만 다시 만든다.
##
## **배선은 부품 위로 넘어간다.** 예전에는 칸 한가운데에서 칸 한가운데로 곧게
## 이었는데, 부품이 자기 칸을 거의 채우는 메시라서 맞닿은 두 부품을 이으면
## 배선이 통째로 부품 안에 파묻혔다. 회로 게임인데 회로가 화면에 없었다.
##
## 그래서 세 토막으로 그린다. 올라가고 · 건너가고 · 내려온다. 어느 칸에
## 놓아도 부품 지붕 위를 지나므로 반드시 보인다.
##
## 흐르지 않는 배선은 흐린 색이다(스펙 §4.1). 왜 흐르지 않는지는 말하지 않는다.
## 그것이 이 게임에서 "원인을 알려주지 않음"의 유일한 보상이므로 잘 보여야 한다.
##
## **방향이 보여야 한다.** 스펙 §4.1 은 "배선은 방향이 있다. 출발에서 도착으로만
## 흐른다"고 못박는데, 굵기가 일정한 막대로는 어느 쪽이 출발인지 알 수 없었다.
## 도착 쪽으로 갈수록 가늘어진다.
##
## **신호가 지나가는 것이 보여야 한다.** 1틱에 한 부품씩 나아가는 것이 이 게임의
## 코어인데, 화면에서는 "회색이던 막대가 노래졌다"로만 나타났다. 흐르는 배선
## 위로 밝은 점 하나가 출발에서 도착으로 달린다. 표현일 뿐이라 결정론과 무관하다.

## 한 칸이 화면에서 사십 픽셀 남짓이다. 0.08 은 세 픽셀이라 보이지 않았다.
const THICKNESS := 0.15

## 부품 지붕에서 얼마나 더 위로 띄울 것인가. 칸 절반이 0.5 다.
const LIFT := 0.62

## 배선 하나를 이루는 토막 수. 올라가고, 건너가고, 내려온다.
const PIECES := 3

## 도착 쪽 굵기의 배수. 1 보다 작아야 어느 쪽으로 흐르는지 보인다.
const TAIL := 0.45

## 신호 점이 배선 하나를 지나는 데 걸리는 시간(초).
const SPARK_SECONDS := 0.28

## 신호 점의 크기.
const SPARK_SIZE := 0.26

const LIVE_COLOUR := Palette.WIRE_LIVE
const IDLE_COLOUR := Palette.WIRE_IDLE
const FALSE_LIVE_COLOUR := Palette.WIRE_FALSE_LIVE
const FALSE_IDLE_COLOUR := Palette.WIRE_FALSE_IDLE

var _circuit: Circuit
var _node: MultiMeshInstance3D
var _sparks: MultiMeshInstance3D
var _last_signature: String = ""
var _build_count: int = 0

## 배선마다 지금 흐르는지와, 흐르기 시작한 때.
var _live: PackedInt32Array = PackedInt32Array()
var _since: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true

    var mesh := BoxMesh.new()
    # z 방향 길이 1 을 기준으로 두고 배선 길이만큼 늘려 쓴다.
    mesh.size = Vector3(THICKNESS, THICKNESS, 1.0)
    mesh.material = material

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_colors = true
    multimesh.mesh = mesh
    multimesh.instance_count = 0

    _node = MultiMeshInstance3D.new()
    _node.name = "Wires"
    _node.multimesh = multimesh
    add_child(_node)

    _sparks = _make_sparks()
    add_child(_sparks)


func bind(circuit: Circuit) -> void:
    _circuit = circuit
    _last_signature = ""


func sync() -> void:
    if _circuit == null:
        return
    if _signature() != _last_signature:
        rebuild()
    refresh_flow()
    _run_sparks()


## 흐르기 시작한 배선 위로 밝은 점을 태워 보낸다.
func _run_sparks() -> void:
    var links := _circuit.links()
    var now := Time.get_ticks_msec() / 1000.0
    var multimesh := _sparks.multimesh
    var shown := 0

    for i in links.size():
        var live := is_live(links[i])
        if live and _live[i] == 0:
            _since[i] = now
        _live[i] = 1 if live else 0
        if not live:
            continue

        var along := (now - _since[i]) / SPARK_SECONDS
        if along > 1.0:
            continue

        _reserve_sparks(shown + 1)
        multimesh.set_instance_transform(
            shown, Transform3D(Basis(), _point_along(links[i], along)))
        multimesh.set_instance_color(shown, colour_of(links[i]))
        shown += 1

    multimesh.visible_instance_count = shown


## 배선 위 [param along](0~1) 지점의 자리.
static func point_along(link: Array, along: float) -> Vector3:
    var path := path_of(link)
    var legs := PIECES
    var step := clampf(along, 0.0, 1.0) * legs
    var leg := mini(int(step), legs - 1)
    return path[leg].lerp(path[leg + 1], step - leg)


func _point_along(link: Array, along: float) -> Vector3:
    return point_along(link, along)


func rebuild() -> void:
    if _circuit == null:
        return

    var links := _circuit.links()
    var multimesh := _node.multimesh
    multimesh.instance_count = links.size() * PIECES

    _live.resize(links.size())
    _live.fill(0)
    _since.resize(links.size())
    _since.fill(0.0)

    for i in links.size():
        var corners := path_of(links[i])
        for piece in PIECES:
            # 도착 쪽으로 갈수록 가늘어진다. 어느 쪽으로 흐르는지가 보여야 한다.
            var thin := lerpf(1.0, TAIL, (piece + 0.5) / PIECES)
            multimesh.set_instance_transform(
                i * PIECES + piece, _span(corners[piece], corners[piece + 1], thin))

    _last_signature = _signature()
    _build_count += 1
    refresh_flow()


## 배선 하나가 지나는 네 점. 올라가고, 건너가고, 내려온다.
static func path_of(link: Array) -> Array[Vector3]:
    var from: Vector3 = SimViewCoords.cell_to_world(link[0])
    var to: Vector3 = SimViewCoords.cell_to_world(link[1])
    var lift := Vector3.UP * LIFT
    return [from, from + lift, to + lift, to]


## 배선마다 지금 신호가 흐르는지에 따라 색을 바꾼다.
func refresh_flow() -> void:
    if _circuit == null:
        return
    var links := _circuit.links()
    var multimesh := _node.multimesh
    for i in links.size():
        var colour := colour_of(links[i])
        for piece in PIECES:
            var at := i * PIECES + piece
            if at < multimesh.instance_count:
                multimesh.set_instance_color(at, colour)


## 배선 하나의 색. 어느 출구에서 나가는지와 지금 흐르는지로 정해진다.
##
## 참과 거짓으로 갈리는 것은 갈림길뿐이다. 묶음도 출구가 여럿일 수 있지만
## 그 출구들은 참·거짓이 아니라 저마다 다른 값이 나오는 구멍이다.
func colour_of(link: Array) -> Color:
    var live := is_live(link)
    if _is_false_exit(link):
        return FALSE_LIVE_COLOUR if live else FALSE_IDLE_COLOUR
    return LIVE_COLOUR if live else IDLE_COLOUR


func _is_false_exit(link: Array) -> bool:
    if int(link[2]) != BranchPart.PORT_FALSE:
        return false
    var source := _circuit.part_at(link[0])
    return source != null and source.kind() == BlockType.BRANCH


## 이 배선에 지금 신호가 흐르는가.
func is_live(link: Array) -> bool:
    var source := _circuit.part_at(link[0])
    if source == null:
        return false
    return source.output_at(link[2]).is_present()


func live_count() -> int:
    var live := 0
    for link: Array in _circuit.links():
        if is_live(link):
            live += 1
    return live


## 그려진 배선의 수. 토막이 아니라 배선을 센다.
func wire_count() -> int:
    return _node.multimesh.instance_count / PIECES


## 그려진 토막의 수. 배선 하나가 여러 토막이다.
func piece_count() -> int:
    return _node.multimesh.instance_count


## 지금 달리고 있는 신호 점의 수.
func spark_count() -> int:
    return _sparks.multimesh.visible_instance_count


func build_count() -> int:
    return _build_count


## 두 점을 잇는 가늘고 긴 상자의 자리와 방향.
func _span(from: Vector3, to: Vector3, thin: float = 1.0) -> Transform3D:
    var offset := to - from
    var length := offset.length()
    if length < 0.0001:
        return Transform3D(Basis().scaled(Vector3.ZERO), from)

    var direction := offset / length
    var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
    # 모서리가 벌어지지 않도록 토막을 굵기만큼 늘려 겹친다.
    var basis := Basis.looking_at(direction, up).scaled(
        Vector3(thin, thin, length + THICKNESS))
    return Transform3D(basis, from + offset * 0.5)


func _make_sparks() -> MultiMeshInstance3D:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    material.emission_enabled = true
    material.emission = Color.WHITE
    material.emission_energy_multiplier = 0.8

    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE * SPARK_SIZE
    mesh.material = material

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_colors = true
    multimesh.mesh = mesh
    multimesh.instance_count = 0

    var node := MultiMeshInstance3D.new()
    node.name = "Sparks"
    node.multimesh = multimesh
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return node


## 신호 점을 그만큼 담을 자리를 잡아 둔다.
func _reserve_sparks(needed: int) -> void:
    var multimesh := _sparks.multimesh
    if multimesh.instance_count < needed:
        multimesh.instance_count = needed + 32


func _signature() -> String:
    var parts := PackedStringArray()
    for link: Array in _circuit.links():
        parts.append("%s>%s" % [link[0], link[1]])
    return "|".join(parts)
